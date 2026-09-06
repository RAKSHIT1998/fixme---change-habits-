#!/bin/bash
# Configure code signing for Fix Me, then regenerate the Xcode project.
#
#   ./Scripts/configure-signing.sh --profile full     --bundle-id com.you.fixme --team ABCDE12345
#   ./Scripts/configure-signing.sh --profile personal --bundle-id com.you.fixme --team ABCDE12345
#   ./Scripts/configure-signing.sh --profile full     --bundle-id com.you.fixme          # simulator
#
# Profiles:
#   full      HealthKit + App Groups. Requires a PAID Apple Developer Program team.
#   personal  No entitlements at all. Builds on a device with a FREE Apple ID.
#             HealthKit auto-verification and the widget's shared data are off; the app
#             detects both and falls back to manual completion.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="full"
BUNDLE_ID=""
TEAM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)   PROFILE="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --team)      TEAM="$2"; shift 2 ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$PROFILE" != "full" && "$PROFILE" != "personal" ]]; then
  echo "error: --profile must be 'full' or 'personal'" >&2
  exit 1
fi

# --- Entitlements -----------------------------------------------------------
# Written as real files rather than generated from project.yml, so switching
# profiles never touches the project spec.
write_entitlements() {
  local path="$1" body="$2"
  cat > "$path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
${body}</dict>
</plist>
EOF
}

if [[ "$PROFILE" == "full" ]]; then
  write_entitlements FixMe/Resources/FixMe.entitlements \
"	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>\$(FIXME_APP_GROUP)</string>
	</array>
"
  write_entitlements FixMeWidgets/FixMeWidgets.entitlements \
"	<key>com.apple.security.application-groups</key>
	<array>
		<string>\$(FIXME_APP_GROUP)</string>
	</array>
"
else
  # A free "Personal Team" provisioning profile supports neither capability, and
  # Xcode refuses to sign anything that requests them.
  write_entitlements FixMe/Resources/FixMe.entitlements ""
  write_entitlements FixMeWidgets/FixMeWidgets.entitlements ""
fi

# --- Signing.xcconfig -------------------------------------------------------
if [[ -n "$BUNDLE_ID" ]]; then
  /usr/bin/sed -i '' "s|^FIXME_BUNDLE_ID *=.*|FIXME_BUNDLE_ID = ${BUNDLE_ID}|" Signing.xcconfig
fi
/usr/bin/sed -i '' "s|^DEVELOPMENT_TEAM *=.*|DEVELOPMENT_TEAM = ${TEAM}|" Signing.xcconfig

WROTE_TEAM=$(grep '^DEVELOPMENT_TEAM' Signing.xcconfig | cut -d= -f2- | xargs)
WROTE_ID=$(grep '^FIXME_BUNDLE_ID' Signing.xcconfig | cut -d= -f2- | xargs)

if [[ -n "$TEAM" && "$WROTE_TEAM" != "$TEAM" ]]; then
  echo "error: failed to write DEVELOPMENT_TEAM to Signing.xcconfig" >&2
  exit 1
fi
if [[ -n "$BUNDLE_ID" && "$WROTE_ID" != "$BUNDLE_ID" ]]; then
  echo "error: failed to write FIXME_BUNDLE_ID to Signing.xcconfig" >&2
  exit 1
fi

xcodegen generate >/dev/null

echo "Profile:    ${PROFILE}"
echo "Bundle id:  ${WROTE_ID}"
echo "Team:       ${WROTE_TEAM:-<none — Simulator only>}"
if [[ "$PROFILE" == "personal" ]]; then
  echo
  echo "Note: HealthKit and App Groups are disabled in this profile."
  echo "      Step/workout habits fall back to manual completion."
fi
