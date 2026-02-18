#!/bin/bash
# Install kr - the kuberise CLI tool
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/kuberise/kuberise.io/main/scripts/install-kr.sh | sh
#
# Environment variables:
#   KR_VERSION      - Version to install (default: latest release)
#   KR_INSTALL_DIR  - Installation directory (default: /usr/local/bin)

set -euo pipefail

REPO="kuberise/kuberise.io"

if [ -n "${KR_VERSION:-}" ]; then
  VERSION="$KR_VERSION"
else
  RESPONSE=$(curl -sSL "https://api.github.com/repos/$REPO/releases/latest")
  VERSION=$(echo "$RESPONSE" | grep '"tag_name"' | cut -d '"' -f4 || true)
  if [ -z "$VERSION" ]; then
    echo "Error: could not determine latest version." >&2
    echo "The repository may not have any releases yet." >&2
    echo "Set KR_VERSION manually, e.g.: KR_VERSION=0.3.0 sh install-kr.sh" >&2
    exit 1
  fi
fi

INSTALL_DIR="${KR_INSTALL_DIR:-/usr/local/bin}"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Error: install directory '$INSTALL_DIR' does not exist." >&2
  exit 1
fi

echo "Downloading kr $VERSION..."
HTTP_CODE=$(curl -sSL -w "%{http_code}" "https://github.com/$REPO/releases/download/$VERSION/kr" \
  -o "$INSTALL_DIR/kr")
if [ "$HTTP_CODE" != "200" ]; then
  rm -f "$INSTALL_DIR/kr"
  echo "Error: download failed (HTTP $HTTP_CODE)." >&2
  echo "Check that release '$VERSION' exists at https://github.com/$REPO/releases" >&2
  exit 1
fi
chmod +x "$INSTALL_DIR/kr"

echo "kr $VERSION installed to $INSTALL_DIR/kr"
echo ""
echo "Run 'kr --help' to get started."
