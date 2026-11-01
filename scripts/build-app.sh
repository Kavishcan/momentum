#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi
# Keep compiler output out of synced folders that add signing-breaking Finder metadata.
checkout_key="$(printf '%s' "$PWD" | shasum -a 256 | cut -c 1-12)"
build_path="${MOMENTUM_BUILD_PATH:-${TMPDIR:-/tmp}/momentum-build-$checkout_key}"
swift build -c "$configuration" --scratch-path "$build_path"
binary_dir="$(swift build -c "$configuration" --scratch-path "$build_path" --show-bin-path)"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/momentum-bundle.XXXXXX")"
next_app="$PWD/build/.Momentum-next-$$.app"
trap 'rm -rf "$stage_dir" "$next_app"' EXIT
staged_app="$stage_dir/Momentum.app"
app_dir="$PWD/build/Momentum.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources" "$PWD/build"
cp "$binary_dir/Momentum" "$staged_app/Contents/MacOS/Momentum"
cp Resources/Info.plist "$staged_app/Contents/Info.plist"
codesign --force --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"
archive="$PWD/build/Momentum-macos-$(uname -m).zip"
ditto -c -k --keepParent --norsrc --noextattr "$staged_app" "$archive"
# Replace the bundle as a whole instead of modifying a running executable in place.
ditto --norsrc --noextattr "$staged_app" "$next_app"
codesign --verify "$next_app"
if [[ -d "$app_dir" ]]; then mv "$app_dir" "$stage_dir/Previous.app"; fi
if ! mv "$next_app" "$app_dir"; then
  if [[ -d "$stage_dir/Previous.app" ]]; then mv "$stage_dir/Previous.app" "$app_dir"; fi
  exit 1
fi
echo "Built $app_dir"
echo "Packaged $archive"
echo 'Quit any older Momentum instance, then open build/Momentum.app'
