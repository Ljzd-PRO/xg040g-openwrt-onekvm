// SPDX-License-Identifier: GPL-2.0-only
/*
 * Adapted from Ljzd-PRO/xg040g-openwrt-switch commit
 * 22bd32ab0cb417138763174f3840a67584ff63cf.
 */

#include <linux/delay.h>
#include <linux/io.h>
#include <linux/kobject.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/stop_machine.h>
#include <linux/sysfs.h>

#define XG040G_PLL_BASE		0x1fa20000
#define XG040G_PLL_SIZE		0x1000
#define XG040G_MCUCFG_BASE	0x1efbe000
#define XG040G_MCUCFG_SIZE	0x1000

#define REG_CLK_MUX		0x1e0
#define REG_PLL_LOCK		0x268
#define REG_ARMPLL_PCW		0x2b4
#define REG_ARMPLL_CHG		0x2b8
#define REG_MCU_UNLOCK		0x640
#define REG_MCU_SOURCE		0x7c0

struct xg040g_oc {
	void __iomem *pll;
	void __iomem *mcucfg;
	struct kobject *kobj;
	struct mutex lock;
	unsigned int requested_mhz;
	bool allow_overclock;
	int last_error;
};

static struct xg040g_oc oc;

static unsigned int xg040g_actual_mhz(void)
{
	u32 pcw = readl(oc.pll + REG_ARMPLL_PCW);
	u32 chg = readl(oc.pll + REG_ARMPLL_CHG);
	u32 pcw_int = (pcw >> 24) & 0x7f;
	u32 posdiv = (chg >> 4) & 0x7;

	return (pcw_int * 50) >> posdiv;
}

struct xg040g_switch_data {
	unsigned int target_mhz;
	bool finish;
};

static int xg040g_switch_pll(void *arg)
{
	struct xg040g_switch_data *data = arg;
	u32 val;

	if (!data->finish) {
		val = readl(oc.pll + REG_CLK_MUX);
		writel(val | BIT(2), oc.pll + REG_CLK_MUX);

		val = readl(oc.mcucfg + REG_MCU_UNLOCK);
		writel((val & ~GENMASK(4, 0)) | 0x12,
		       oc.mcucfg + REG_MCU_UNLOCK);
		val = readl(oc.mcucfg + REG_MCU_SOURCE);
		writel((val & ~GENMASK(10, 9)) | (3 << 9),
		       oc.mcucfg + REG_MCU_SOURCE);

		val = readl(oc.pll + REG_PLL_LOCK);
		writel((val & ~GENMASK(7, 0)) | 0x12,
		       oc.pll + REG_PLL_LOCK);
		val = readl(oc.pll + REG_ARMPLL_PCW);
		writel((val & 0x00ffffff) | ((data->target_mhz / 50) << 24),
		       oc.pll + REG_ARMPLL_PCW);

		val = readl(oc.pll + REG_ARMPLL_CHG);
		val &= 0xffffff8e;
		val |= !(readl(oc.pll + REG_ARMPLL_CHG) & BIT(0));
		writel(val, oc.pll + REG_ARMPLL_CHG);
		return 0;
	}

	val = readl(oc.pll + REG_CLK_MUX);
	writel(val | BIT(0), oc.pll + REG_CLK_MUX);
	val = readl(oc.mcucfg + REG_MCU_UNLOCK);
	writel((val & ~GENMASK(4, 0)) | 0x12, oc.mcucfg + REG_MCU_UNLOCK);
	val = readl(oc.mcucfg + REG_MCU_SOURCE);
	writel((val & ~GENMASK(10, 9)) | (1 << 9),
	       oc.mcucfg + REG_MCU_SOURCE);
	val = readl(oc.pll + REG_CLK_MUX);
	writel(val & ~BIT(2), oc.pll + REG_CLK_MUX);
	val = readl(oc.pll + REG_PLL_LOCK);
	writel(val & ~GENMASK(7, 0), oc.pll + REG_PLL_LOCK);
	return 0;
}

static int xg040g_set_frequency(unsigned int target_mhz)
{
	struct xg040g_switch_data data = { .target_mhz = target_mhz };
	unsigned int actual;
	int ret;

	if (target_mhz != 1200 && target_mhz != 1300 && target_mhz != 1400) {
		oc.last_error = -EINVAL;
		return -EINVAL;
	}
	if (target_mhz > 1200 && !READ_ONCE(oc.allow_overclock)) {
		oc.last_error = -EPERM;
		return -EPERM;
	}

	mutex_lock(&oc.lock);
	ret = stop_machine(xg040g_switch_pll, &data, cpu_online_mask);
	if (ret)
		goto out;
	msleep(1000);
	data.finish = true;
	ret = stop_machine(xg040g_switch_pll, &data, cpu_online_mask);
	if (ret)
		goto out;

	actual = xg040g_actual_mhz();
	if (actual != target_mhz) {
		ret = -EIO;
		pr_err("xg040g-an7581-oc: requested %u MHz, read back %u MHz\n",
		       target_mhz, actual);
	} else {
		oc.requested_mhz = target_mhz;
		pr_info("xg040g-an7581-oc: CPU PLL set to %u MHz\n", actual);
	}
out:
	oc.last_error = ret;
	mutex_unlock(&oc.lock);
	return ret;
}

static ssize_t actual_mhz_show(struct kobject *kobj,
			       struct kobj_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%u\n", xg040g_actual_mhz());
}

static ssize_t requested_mhz_show(struct kobject *kobj,
				  struct kobj_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%u\n", oc.requested_mhz);
}

static ssize_t requested_mhz_store(struct kobject *kobj,
				   struct kobj_attribute *attr,
				   const char *buf, size_t count)
{
	unsigned int target;
	int ret = kstrtouint(buf, 0, &target);

	if (ret)
		return ret;
	ret = xg040g_set_frequency(target);
	return ret ? ret : count;
}

static ssize_t allow_overclock_show(struct kobject *kobj,
				    struct kobj_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%u\n", READ_ONCE(oc.allow_overclock));
}

static ssize_t allow_overclock_store(struct kobject *kobj,
				     struct kobj_attribute *attr,
				     const char *buf, size_t count)
{
	bool value;
	int ret = kstrtobool(buf, &value);

	if (ret)
		return ret;
	WRITE_ONCE(oc.allow_overclock, value);
	return count;
}

static ssize_t last_error_show(struct kobject *kobj,
			       struct kobj_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%d\n", oc.last_error);
}

static struct kobj_attribute actual_mhz_attr = __ATTR_RO(actual_mhz);
static struct kobj_attribute requested_mhz_attr = __ATTR_RW(requested_mhz);
static struct kobj_attribute allow_overclock_attr = __ATTR_RW(allow_overclock);
static struct kobj_attribute last_error_attr = __ATTR_RO(last_error);

static struct attribute *xg040g_attrs[] = {
	&actual_mhz_attr.attr,
	&requested_mhz_attr.attr,
	&allow_overclock_attr.attr,
	&last_error_attr.attr,
	NULL,
};

static const struct attribute_group xg040g_attr_group = {
	.attrs = xg040g_attrs,
};

static int __init xg040g_oc_init(void)
{
	unsigned int actual;
	int ret;

	if (!of_machine_is_compatible("nokia,xg-040g-md-tcboot"))
		return -ENODEV;

	mutex_init(&oc.lock);
	oc.pll = ioremap(XG040G_PLL_BASE, XG040G_PLL_SIZE);
	oc.mcucfg = ioremap(XG040G_MCUCFG_BASE, XG040G_MCUCFG_SIZE);
	if (!oc.pll || !oc.mcucfg) {
		ret = -ENOMEM;
		goto err_unmap;
	}

	actual = xg040g_actual_mhz();
	if (actual != 1200 && actual != 1300 && actual != 1400) {
		pr_err("xg040g-an7581-oc: unexpected PLL readback %u MHz; refusing to load\n",
		       actual);
		ret = -ERANGE;
		goto err_unmap;
	}
	oc.requested_mhz = actual;
	oc.kobj = kobject_create_and_add("xg040g_cpu", kernel_kobj);
	if (!oc.kobj) {
		ret = -ENOMEM;
		goto err_unmap;
	}
	ret = sysfs_create_group(oc.kobj, &xg040g_attr_group);
	if (ret)
		goto err_kobj;

	pr_info("xg040g-an7581-oc: manually loaded at %u MHz; overclock locked\n",
		actual);
	return 0;

err_kobj:
	kobject_put(oc.kobj);
err_unmap:
	if (oc.mcucfg)
		iounmap(oc.mcucfg);
	if (oc.pll)
		iounmap(oc.pll);
	return ret;
}

static void __exit xg040g_oc_exit(void)
{
	unsigned int actual = xg040g_actual_mhz();

	if (actual == 1300 || actual == 1400) {
		WRITE_ONCE(oc.allow_overclock, true);
		if (xg040g_set_frequency(1200))
			pr_crit("xg040g-an7581-oc: unable to restore 1200 MHz while unloading\n");
	} else if (actual != 1200) {
		pr_crit("xg040g-an7581-oc: unsafe %u MHz readback while unloading; no PLL write attempted\n",
			actual);
	}
	sysfs_remove_group(oc.kobj, &xg040g_attr_group);
	kobject_put(oc.kobj);
	iounmap(oc.mcucfg);
	iounmap(oc.pll);
}

module_init(xg040g_oc_init);
module_exit(xg040g_oc_exit);

MODULE_AUTHOR("XG-040G-MD OpenWrt One-KVM contributors");
#ifdef CONFIG_MODULE_STRIPPED
MODULE_INFO(description, "Opt-in AN7581 CPU PLL control for XG-040G-MD");
#else
MODULE_DESCRIPTION("Opt-in AN7581 CPU PLL control for XG-040G-MD");
#endif
MODULE_LICENSE("GPL");
