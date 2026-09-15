# DF.AutoTestCLIDist

Public distribution repository for the `autotest` executable built from the
private `DF-Packages/cn.dfdfdf.autotest-cli` source repository.

This repository contains installer scripts and package metadata. Versioned
binaries and `SHA256SUMS` are stored as GitHub Release assets instead of being
committed to the repository.

## Install on macOS

```bash
curl -fsSL https://raw.githubusercontent.com/DF-Packages/cn.dfdfdf.autotest-cli-dist/master/scripts/install.sh | bash
```

Pin a release or choose another install directory when required:

```bash
AUTOTEST_CLI_VERSION=v0.1.0 \
AUTOTEST_CLI_INSTALL_DIR="$HOME/.local/bin" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/DF-Packages/cn.dfdfdf.autotest-cli-dist/master/scripts/install.sh)"
```

## Install on Windows

```powershell
irm https://raw.githubusercontent.com/DF-Packages/cn.dfdfdf.autotest-cli-dist/master/scripts/install.ps1 | iex
```

Pin a release with `$env:AUTOTEST_CLI_VERSION = 'v0.1.0'` before running the
installer.

## Release asset contract

Every release tag must use `v<semver>` and contain:

- `autotest-aarch64-apple-darwin.tar.gz`
- `autotest-x86_64-apple-darwin.tar.gz`
- `autotest-x86_64-pc-windows-msvc.zip`
- `SHA256SUMS`

The source repository's release workflow builds, tests, packages, checksums,
and uploads these assets. It also synchronizes both installer scripts to this
repository. The source repository must define `DIST_GITHUB_TOKEN` with
`contents:write` access to this repository; `DIST_GITHUB_REPO` may override the
default destination for staging tests.

## Installed files

The default binary locations are:

- macOS: `~/.local/bin/autotest`
- Windows: `%LOCALAPPDATA%\dfdfdf\bin\autotest.exe`

Installation metadata is written under `~/.dfdfdf/autotest-cli/install.json`
on macOS and `%USERPROFILE%\.dfdfdf\autotest-cli\install.json` on Windows.
