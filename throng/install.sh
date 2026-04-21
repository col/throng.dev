#!/usr/bin/env bash
set -euo pipefail

# ─── throng bootstrap installer ─────────────────────────────────────────────────
#
# This is a thin stable script hosted at a fixed URL. It resolves the requested
# version, downloads the versioned installer from the release assets, and runs it.
#
# Usage:
#   curl -fsSL https://throng.dev/throng/install.sh | sudo bash
#   curl -fsSL https://throng.dev/throng/install.sh | sudo bash -s -- --version v0.1.0
#   curl -fsSL https://throng.dev/throng/install.sh | sudo bash -s -- --uninstall
#
# ─────────────────────────────────────────────────────────────────────────────────

RELEASES_REPO="col/throng.dev"
RELEASE_PREFIX="throng-"

# ─── Parse arguments ────────────────────────────────────────────────────────────

VERSION=""
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#*=}"
      shift
      ;;
    *)
      PASSTHROUGH_ARGS+=("$1")
      shift
      ;;
  esac
done

# ─── Resolve version ────────────────────────────────────────────────────────────

resolve_latest() {
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases" \
    | grep '"tag_name"' \
    | grep -E "\"${RELEASE_PREFIX}v[0-9]" \
    | head -1 \
    | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ -z "$tag" ]]; then
    echo -e "\033[0;31m✗\033[0m No throng releases found on ${RELEASES_REPO}" >&2
    exit 1
  fi

  # Strip the prefix to get the version
  echo "${tag#${RELEASE_PREFIX}}"
}

if [[ -z "$VERSION" ]]; then
  echo -e "\033[0;34m::\033[0m Resolving latest version..."
  VERSION="$(resolve_latest)"
fi

# Normalise: ensure version starts with v
[[ "$VERSION" == v* ]] || VERSION="v${VERSION}"

RELEASE_TAG="${RELEASE_PREFIX}${VERSION}"
INSTALLER_URL="https://github.com/${RELEASES_REPO}/releases/download/${RELEASE_TAG}/install.sh"

# ─── Download and run versioned installer ────────────────────────────────────────

echo -e "\033[0;34m::\033[0m Installing throng ${VERSION}"
echo -e "\033[2m   ${INSTALLER_URL}\033[0m"
echo ""

INSTALLER=$(mktemp)
trap 'rm -f "$INSTALLER"' EXIT

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$INSTALLER" "$INSTALLER_URL" 2>/dev/null || true)

if [[ "$HTTP_CODE" != "200" ]] || [[ ! -s "$INSTALLER" ]]; then
  echo -e "\033[0;31m✗\033[0m Failed to download installer for version ${VERSION}" >&2
  echo -e "  Check that release \033[1m${RELEASE_TAG}\033[0m exists at:" >&2
  echo -e "  https://github.com/${RELEASES_REPO}/releases" >&2
  exit 1
fi

chmod +x "$INSTALLER"
exec "$INSTALLER" --version "$VERSION" "${PASSTHROUGH_ARGS[@]}"
