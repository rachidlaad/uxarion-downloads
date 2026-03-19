#!/usr/bin/env sh
set -eu

REPO="rachidlaad/uxarion-downloads"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd tar
need_cmd mktemp

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux) ;;
  *)
    echo "Unsupported OS: $os" >&2
    exit 1
    ;;
esac

case "$arch" in
  x86_64|amd64)
    asset_suffix='linux-x64'
    extracted_binary='package/vendor/x86_64-unknown-linux-musl/codex/codex'
    ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

release_json="$(curl -fsSL "$API_URL")"
tag_name="$(
  printf '%s\n' "$release_json" \
    | sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p'
)"

if [ -z "$tag_name" ]; then
  echo "Could not determine the latest Uxarion release tag." >&2
  exit 1
fi

version="${tag_name#v}"
asset_url="https://github.com/$REPO/releases/download/$tag_name/uxarion-$version-$asset_suffix.tar.xz"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

archive_path="$tmp_dir/runtime.tar.xz"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"

echo "Downloading Uxarion from $asset_url"
curl -fsSL "$asset_url" -o "$archive_path"
tar -xJf "$archive_path" -C "$extract_dir"

binary_path="$extract_dir/$extracted_binary"
if [ ! -x "$binary_path" ]; then
  echo "Downloaded archive did not contain the expected binary." >&2
  exit 1
fi

install_dir="${UXARION_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
target_path="$install_dir/uxarion"
cp "$binary_path" "$target_path"
chmod 755 "$target_path"

echo "Installed Uxarion to $target_path"
case ":${PATH:-}:" in
  *":$install_dir:"*) ;;
  *)
    echo "Add $install_dir to PATH if it is not already there."
    ;;
esac
