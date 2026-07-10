# Repository and GitHub publishing

This repository is the shareable project root. Do not publish the parent
scratch directory that contains device backups, captured stock-firmware pages,
temporary downloads, build outputs, or local credentials.

For a maintainer-oriented map of every top-level directory and common
development workflows, see `docs/structure.md`.

## What belongs in GitHub

- `.github/workflows/firmware.yml`: CI build and prerelease publishing.
- `configs/`: OpenWrt defconfigs for the supported firmware profiles.
- `docker/`: pinned build container recipe.
- `docs/`: build, flash, hardware status and release notes.
- `experiments/unsupported/`: archived MTU3/UDC experiments and conclusions.
- `locks/`: pinned upstream source and feed commits.
- `package/`: local OpenWrt packages, including One-KVM, LuCI and XG-040G helpers.
- `scripts/`: bootstrap, build, validate, package and source-bundle helpers.
- `upstream/openwrt` and `upstream/one-kvm`: git submodules only.

The following must stay local and are ignored by `.gitignore`: `output/`,
`.cache/`, `downloads/`, `backups/`, `session-pages/`, `tmp-web/`, `tcboot.bin`,
`rclone.conf`, private keys, cookies and raw HTTP captures.

## Source pinning

OpenWrt and One-KVM are stored as submodules so a normal clone can reproduce
the exact source tree without manual repository discovery.

```bash
git clone --recurse-submodules --shallow-submodules REPOSITORY_URL
cd xg040g-openwrt-onekvm
./scripts/bootstrap.sh --offline
```

Three records must agree before a release:

- The parent gitlink for each path under `upstream/`.
- The commit recorded in `locks/sources.lock`.
- The actual checkout reported by `git -C upstream/<name> rev-parse HEAD`.

`./scripts/validate.sh` checks this relationship. The build script never runs
`git submodule update --remote`, so upstream changes are never pulled
implicitly during a build.

## Build modes

Default `isolated` mode copies the pinned OpenWrt submodule into a Docker work
directory and builds there. This keeps the submodule clean and works on macOS,
Linux and WSL2.

Linux users can opt into direct source mode:

```bash
./scripts/build.sh onekvm --source-mode direct --jobs 10
```

Direct mode uses `upstream/openwrt` as `/work/openwrt`; it is intentionally
disabled on the default case-insensitive macOS filesystem.

## GitHub Actions

The workflow supports three entry points:

- Push to `main`: build the default `onekvm` profile.
- Manual `workflow_dispatch`: build `minimal`, `onekvm` or `all`.
- Tag push matching `v*`: build both profiles and publish a prerelease.

Release assets include firmware images, manifests, build metadata, SHA256 sums
and `source-with-submodules.tar.zst`. The `onekvm` profile additionally exports
standalone `one-kvm`, LuCI and Chinese i18n APKs plus APK metadata. GitHub's
generated source ZIP does not include submodule contents, so the tarball is the
archival source package.

## Commit splitting

Keep commits scoped by purpose. The current history follows this shape:

- `chore`: repository bootstrap and policy files.
- `build(deps)`: pinned submodule or feed lock changes.
- `build`: scripts, Docker, reproducibility and release tooling.
- `package`: OpenWrt package implementations and package-specific patches.
- `luci`: LuCI application changes.
- `ci`: GitHub Actions changes.
- `docs`: build, flashing, hardware and release documentation.
- `experiments`: unsupported diagnostic work kept for auditability.

When moving upstream commits, update one upstream at a time. For example,
OpenWrt gitlink plus `locks/sources.lock` belongs in one `build(deps)` commit;
One-KVM source, package hash, `Cargo.lock` and related patches belong in a
separate package/build commit after validation.

## Publishing commands

If the repository has no remote yet:

```bash
gh repo create Ljzd-PRO/xg040g-openwrt-onekvm --public \
  --source=. --remote=origin --push
```

If the repository already exists:

```bash
git remote add origin https://github.com/Ljzd-PRO/xg040g-openwrt-onekvm.git
git push -u origin main
git push --recurse-submodules=check origin main
```

To create a prerelease build:

```bash
git tag vYYYY.MM.DD-rc1
git push origin vYYYY.MM.DD-rc1
```

Keep releases as prerelease until MS2109, CH9329, USB3 `KVMSTORE`, PXE and
rclone/WebDAV have all been validated on hardware.
