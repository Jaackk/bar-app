#!/bin/bash
# Local validation only: never archives, uploads, changes teams or deletes app data.
set -euo pipefail
cd "$(dirname "$0")/.."
expected="${1:?Usage: bash scripts/validate-mac.sh EXPECTED_COMMIT [PRO_UDID] [SMALL_UDID]}"
actual=$(git rev-parse HEAD)
if [[ "$actual" != "$(git rev-parse "$expected^{commit}")" ]]; then
  echo "Wrong checkout: expected $expected, found $actual" >&2; exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or separately preserve local edits before recording candidate validation." >&2; exit 1
fi
[[ "$(uname -s)" == Darwin ]] || { echo 'This script requires macOS and full Xcode.' >&2; exit 1; }
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
major=$(xcodebuild -version | head -1 | awk '{print $2}' | cut -d. -f1)
[[ "$major" -ge 26 ]] || { echo 'Use Xcode 26 or newer for current App Store SDK requirements.' >&2; exit 1; }
output="build/validation-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$output"
printf '%s\n' "$actual" > "$output/commit.txt"
xcrun simctl list devices available -j > "$output/devices.json"
pro="${2:-$(python3 - "$output/devices.json" <<'PY'
import json,sys
devices=[d for group in json.load(open(sys.argv[1]))['devices'].values() for d in group if d.get('isAvailable')]
print(next((d['udid'] for d in reversed(devices) if 'iPhone' in d['name'] and 'Pro' in d['name'] and 'Max' not in d['name']),''))
PY
)}"
small="${3:-$(python3 - "$output/devices.json" <<'PY'
import json,sys
devices=[d for group in json.load(open(sys.argv[1]))['devices'].values() for d in group if d.get('isAvailable')]
print(next((d['udid'] for d in reversed(devices) if any(n in d['name'] for n in ['iPhone SE (3rd','iPhone 13 mini','iPhone 16e','iPhone 17e'])),''))
PY
)}"
if [[ -z "$pro" || -z "$small" || "$pro" == "$small" ]]; then
  echo 'Install a Pro and a smaller supported iPhone simulator in Xcode, or supply their UDIDs as arguments 2 and 3.' >&2
  xcrun simctl list devices available; exit 1
fi
python3 scripts/test-content-integrity.py 2>&1 | tee "$output/content-tests.log"
python3 scripts/test-menu-monitor.py 2>&1 | tee "$output/menu-tests.log"
swift test --parallel 2>&1 | tee "$output/core-debug.log"
swift test --configuration release 2>&1 | tee "$output/core-release.log"
xcodebuild -resolvePackageDependencies -project BAR.xcodeproj -scheme BAR 2>&1 | tee "$output/packages.log"
xcodebuild build-for-testing -project BAR.xcodeproj -scheme BAR -configuration Debug \
  -destination "platform=iOS Simulator,id=$pro" -derivedDataPath "$output/DerivedData" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/native-build.log"
for device in "$pro" "$small"; do
  xcodebuild test-without-building -project BAR.xcodeproj -scheme BAR -configuration Debug \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath "$output/DerivedData" \
    -parallel-testing-enabled NO -resultBundlePath "$output/UI-$device.xcresult" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/UI-$device.log"
done
xcodebuild build analyze -project BAR.xcodeproj -scheme BAR -configuration Release \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$output/ReleaseData" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/release-build.log"
printf '\nAutomated Mac checks passed at %s. Evidence: %s\n' "$actual" "$output"
echo 'Next: install Release on your physical iPhone, complete docs/release/MAC-VALIDATION.txt and the real-shift pilot. No upload has been performed.'
