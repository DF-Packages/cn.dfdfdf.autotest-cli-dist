#!/usr/bin/env bash
# Installs a prebuilt AutoTest CLI binary from the public dist repository.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DF-Packages/cn.dfdfdf.autotest-cli-dist/master/scripts/install.sh | bash
#
# Optional environment variables:
#   AUTOTEST_CLI_GITHUB_REPO=owner/repo
#   AUTOTEST_CLI_INSTALL_DIR=~/.local/bin
#   AUTOTEST_CLI_META_DIR=~/.dfdfdf/autotest-cli
#   AUTOTEST_CLI_VERSION=v0.1.0

set -euo pipefail

BIN_NAME="autotest"
REPO="${AUTOTEST_CLI_GITHUB_REPO:-DF-Packages/cn.dfdfdf.autotest-cli-dist}"
INSTALL_DIR="${AUTOTEST_CLI_INSTALL_DIR:-${HOME}/.local/bin}"
META_DIR="${AUTOTEST_CLI_META_DIR:-${HOME}/.dfdfdf/autotest-cli}"
META_FILE="${META_DIR}/install.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

die() {
  echo "Error: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

need awk
need curl
need mktemp
need tar

detect_target() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "${os}-${arch}" in
    Darwin-arm64) echo "aarch64-apple-darwin" ;;
    Darwin-x86_64) echo "x86_64-apple-darwin" ;;
    Linux-*) die "V1 prebuilt releases support macOS and Windows Unity Editors only" ;;
    MINGW*|MSYS*|CYGWIN*) die "use scripts/install.ps1 from PowerShell on Windows" ;;
    *) die "unsupported platform: ${os} ${arch}" ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "required command not found: sha256sum or shasum"
  fi
}

TARGET="$(detect_target)"
ASSET="${BIN_NAME}-${TARGET}.tar.gz"
CHECKSUMS="SHA256SUMS"

if [[ -n "${AUTOTEST_CLI_VERSION:-}" ]]; then
  TAG="${AUTOTEST_CLI_VERSION}"
  [[ "${TAG}" == v* ]] || TAG="v${TAG}"
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
else
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
fi

echo "==> Fetching release info: ${API_URL}"
RELEASE_JSON="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: ${BIN_NAME}-installer" \
  "${API_URL}")" \
  || die "failed to fetch release; verify repository access and that a release exists"

TAG="$(printf '%s' "${RELEASE_JSON}" \
  | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"
[[ -n "${TAG}" ]] || die "could not parse tag_name from the GitHub API response"

VERSION="${TAG#v}"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

echo "==> Downloading ${ASSET} (${TAG})"
curl -fsSL -o "${TMP_DIR}/${ASSET}" "${BASE_URL}/${ASSET}" \
  || die "download failed: ${BASE_URL}/${ASSET}"
curl -fsSL -o "${TMP_DIR}/${CHECKSUMS}" "${BASE_URL}/${CHECKSUMS}" \
  || die "checksum file missing: ${BASE_URL}/${CHECKSUMS}"

echo "==> Verifying checksum"
EXPECTED="$(awk -v file="${ASSET}" '$2 == file { print $1; exit }' "${TMP_DIR}/${CHECKSUMS}")"
[[ -n "${EXPECTED}" ]] || die "no checksum entry for ${ASSET}"
ACTUAL="$(sha256_file "${TMP_DIR}/${ASSET}")"
[[ "${ACTUAL}" == "${EXPECTED}" ]] \
  || die "checksum mismatch for ${ASSET} (expected ${EXPECTED}, got ${ACTUAL})"

tar -xzf "${TMP_DIR}/${ASSET}" -C "${TMP_DIR}"
[[ -x "${TMP_DIR}/${BIN_NAME}" ]] || die "archive does not contain executable ${BIN_NAME}"

mkdir -p "${INSTALL_DIR}" "${META_DIR}"
DEST="${INSTALL_DIR}/${BIN_NAME}"
STAGED_DEST="${DEST}.tmp.$$"
cp "${TMP_DIR}/${BIN_NAME}" "${STAGED_DEST}"
chmod 755 "${STAGED_DEST}"
mv -f "${STAGED_DEST}" "${DEST}"

cat >"${META_FILE}" <<EOF
{
  "version": "${VERSION}",
  "binary": "${DEST}",
  "install_dir": "${INSTALL_DIR}",
  "github_repo": "${REPO}",
  "install_method": "remote",
  "target": "${TARGET}",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo
    echo "NOTE: ${INSTALL_DIR} is not in PATH."
    echo "Add this to your shell profile: export PATH=\"${INSTALL_DIR}:\$PATH\""
    ;;
esac

echo "Installed ${BIN_NAME} ${VERSION} -> ${DEST}"
"${DEST}" --version
