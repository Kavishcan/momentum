#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
architecture="${1:-universal}"
case "$architecture" in
  arm64|x86_64) expected_architectures=("$architecture") ;;
  universal) expected_architectures=(arm64 x86_64) ;;
  *) echo "Usage: $0 [arm64|x86_64|universal]" >&2; exit 1 ;;
esac
verify_application() {
  codesign --verify --deep --strict "$1"
  local found
  found="$(lipo -archs "$1/Contents/MacOS/Momentum")"
  for expected in "${expected_architectures[@]}"; do
    if [[ " $found " != *" $expected "* ]]; then
      echo "Expected $expected in Momentum; found: $found" >&2
      return 1
    fi
  done
}
bash scripts/build-app.sh release "$architecture"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/momentum-dmg.XXXXXX")"
mount_point="$stage_dir/verification"
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then hdiutil detach "$mount_point" >/dev/null 2>&1 || true; fi
  rm -rf "$stage_dir"
}
trap cleanup EXIT
payload="$stage_dir/payload"
mkdir -p "$payload" "$mount_point"
# Extract the clean archive rather than copying a bundle with File Provider metadata.
ditto -x -k "build/Momentum-macos-$architecture.zip" "$payload"
verify_application "$payload/Momentum.app"
ln -s /Applications "$payload/Applications"
cat > "$payload/Install Momentum.txt" <<'INSTALL'
Install Momentum

1. Quit any older Momentum instance.
2. Drag Momentum.app onto the Applications folder beside it.
3. Open Momentum from Applications, then eject this disk image.

Requires macOS 14 or later. Your local tasks and settings are kept when updating.

This is a development build: ad-hoc signed, not notarized by Apple.
macOS may ask you to explicitly approve opening it in System Settings.

Source and release notes: https://github.com/Kavishcan/momentum
INSTALL
image="$PWD/build/Momentum-macos-$architecture.dmg"
hdiutil create -volname "Momentum" -srcfolder "$payload" -fs HFS+ -format UDZO -ov "$image"
hdiutil verify "$image"
# Verify the app and installation shortcut inside the actual read-only disk image.
hdiutil attach -readonly -nobrowse -mountpoint "$mount_point" "$image"
mounted=1
verify_application "$mount_point/Momentum.app"
test "$(readlink "$mount_point/Applications")" = /Applications
test -f "$mount_point/Install Momentum.txt"
hdiutil detach "$mount_point"
mounted=0
echo "Created and verified $image"
