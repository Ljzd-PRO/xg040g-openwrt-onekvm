# Repository and GitHub publishing

This repository is the shareable project root. Do not publish the parent
scratch directory that contains device backups, captured stock-firmware pages,
temporary downloads, build outputs, or local credentials.

For a maintainer-oriented map of every top-level directory and common
development workflows, see `docs/structure.md`.

## What belongs in GitHub

- `.github/workflows/firmware.yml`: CI and manually dispatched firmware builds.
- `.github/workflows/release.yml`: manually dispatched publishing from a verified build run.
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

The required `isolated` mode copies the pinned OpenWrt submodule into a Docker
work directory and applies the common and profile-specific patch series there.
This keeps the submodule clean and works on macOS, Linux and WSL2. Direct mode
is rejected for both profiles because it cannot provide the same disposable,
reproducible patch boundary.

## GitHub Actions

The build workflow supports two entry points:

- Push to `main`: build the default `onekvm` profile.
- Manual `workflow_dispatch`: build `minimal`, `onekvm` or `all`.

Publishing is deliberately separate. Run `Build firmware` with the `all`
profile, then dispatch `Release firmware` with the successful build run ID,
the release tag and the prerelease flag. The release workflow requires the
build run and release workflow to use the same commit. Release notes are read
from `docs/releases/<tag>.md`; they are never generated from an inline workflow
template.

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

To build and publish a release:

```bash
# GitHub Actions -> Build firmware -> Run workflow
# profile: all
# runner: ubuntu-24.04

# After that run succeeds:
# GitHub Actions -> Release firmware -> Run workflow
# tag: vYYYY.MM.DD for a stable release, or vYYYY.MM.DD-rc1 for a prerelease
# build_run_id: the successful Build firmware run ID
# prerelease: false for a stable release, true for a prerelease
```

Publish a stable release only after the default management, recovery and
One-KVM paths have passed device smoke tests. Disclose every unfinished
optional hardware or experimental performance test in the release notes.
