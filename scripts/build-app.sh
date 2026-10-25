#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi
build_path="${MOMENTUM_BUILD_PATH:-$PWD/.build}"
swift build -c "$configuration" --scratch-path "$build_path"
binary_dir="$(swift build -c "$configuration" --scratch-path "$build_path" --show-bin-path)"
# Stage outside synced folders: File Provider Finder metadata can break signing.
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/momentum-bundle.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
staged_app="$stage_dir/Momentum.app"
app_dir="$PWD/build/Momentum.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources" "$PWD/build"
cp "$binary_dir/Momentum" "$staged_app/Contents/MacOS/Momentum"
cp Resources/Info.plist "$staged_app/Contents/Info.plist"
# Ad-hoc signing supports local development; distribution needs Developer ID + notarization.
codesign --force --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"
# ZIP the clean staging copy before a sync service can add Finder metadata.
archive="$PWD/build/Momentum-macos-$(uname -m).zip"
ditto -c -k --keepParent --norsrc --noextattr "$staged_app" "$archive"
ditto --norsrc --noextattr "$staged_app" "$app_dir"
codesign --verify "$app_dir"
echo "Built $app_dir"
echo "Packaged $archive"
echo 'Launch with: open build/Momentum.app'
