#!/bin/bash
# Copies new shake-feedback notes from the app on the paired iPhone into work/feedback/inbox.
# Debug builds save notes to Documents/Feedback (FeedbackInbox.swift); see docs/feedback-inbox.md.
#
#   scripts/feedback/pull.sh                    first paired iPhone that is available
#   scripts/feedback/pull.sh --device <id>      a specific phone (UDID or name)
#   scripts/feedback/pull.sh --simulator <udid> a booted Simulator instead
set -euo pipefail

cd "$(dirname "$0")/../.."
bundle_id="com.santiagoalonso.mixlayer"
inbox="work/feedback/inbox"
done_dir="work/feedback/done"
mkdir -p "$inbox" "$done_dir"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

case "${1:-}" in
  --simulator)
    container="$(xcrun simctl get_app_container "${2:?Simulator UDID}" "$bundle_id" data)"
    if [ -d "$container/Documents/Feedback" ]; then
      cp -R "$container/Documents/Feedback" "$staging/"
    fi
    ;;
  *)
    device="${2:-}"
    if [ "${1:-}" != "--device" ] || [ -z "$device" ]; then
      json="$staging/devices.json"
      xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1
      device="$(python3 -I - "$json" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    props, hw = d.get("deviceProperties", {}), d.get("hardwareProperties", {})
    if hw.get("platform") == "iOS" and hw.get("reality") == "physical" \
            and d.get("connectionProperties", {}).get("pairingState") == "paired":
        print(d["identifier"])
        break
PY
)"
    fi
    if [ -z "$device" ]; then
      echo "No paired iPhone found. Unlock the phone and keep it on the same Wi-Fi (or plug it in)." >&2
      exit 1
    fi
    if ! xcrun devicectl device copy from --device "$device" \
        --domain-type appDataContainer --domain-identifier "$bundle_id" \
        --source Documents/Feedback --destination "$staging/Feedback" >"$staging/copy.log" 2>&1; then
      if grep -qi 'no such file\|not found\|doesn.t exist\|failed to retrieve the file node' "$staging/copy.log"; then
        echo "No feedback on the phone yet."
        exit 0
      fi
      cat "$staging/copy.log" >&2
      exit 1
    fi
    ;;
esac

new=0
while IFS= read -r note; do
  folder="$(dirname "$note")"
  id="$(basename "$folder")"
  if [ -e "$inbox/$id" ] || [ -e "$done_dir/$id" ]; then
    continue
  fi
  cp -R "$folder" "$inbox/$id"
  echo "New: $inbox/$id"
  sed -n '3p' "$inbox/$id/note.md" | cut -c1-120
  new=$((new + 1))
done < <(find "$staging" -name note.md | sort)

waiting="$(find "$inbox" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
echo "$new new, $waiting waiting in $inbox"
