#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${1:-$ROOT_DIR/lib}"
VERSIONS_FILE="$ROOT_DIR/tools/tool-versions.env"

if [[ ! -f "$VERSIONS_FILE" ]]; then
  echo "Missing $VERSIONS_FILE" >&2
  exit 1
fi

source "$VERSIONS_FILE"
mkdir -p "$DEST_DIR"

download_and_verify() {
  local url="$1"
  local target="$2"
  local expected_sha="$3"
  local label="$4"
  local tmp="${target}.tmp"

  rm -f "$tmp"
  echo "Downloading $label..."
  curl --fail --location --retry 3 --retry-delay 2 "$url" --output "$tmp"

  local actual_sha
  if command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "$tmp" | awk '{print $1}')"
  else
    actual_sha="$(shasum -a 256 "$tmp" | awk '{print $1}')"
  fi

  if [[ "$actual_sha" != "$expected_sha" ]]; then
    rm -f "$tmp"
    echo "$label checksum mismatch." >&2
    echo "Expected: $expected_sha" >&2
    echo "Actual:   $actual_sha" >&2
    exit 1
  fi

  mv "$tmp" "$target"
  echo "$label verified: $actual_sha"
}

download_and_verify "$APKTOOL_URL" "$DEST_DIR/apktool.jar" "$APKTOOL_SHA256" "Apktool $APKTOOL_VERSION"
download_and_verify "$UBER_SIGNER_URL" "$DEST_DIR/uber-apk-signer.jar" "$UBER_SIGNER_SHA256" "Uber APK Signer $UBER_SIGNER_VERSION"

echo
echo "Installed Android tools into: $DEST_DIR"
java -jar "$DEST_DIR/apktool.jar" --version
java -jar "$DEST_DIR/uber-apk-signer.jar" --version
