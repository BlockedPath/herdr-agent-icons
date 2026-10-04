#!/usr/bin/env bash
# Set an icon as the display name of every detected agent pane.
# Override or add icons in $HERDR_PLUGIN_CONFIG_DIR/icons.conf, one
# `agent=icon` per line. An empty icon keeps that agent's name.
#
# Icon lookup goes through jq. macOS /bin/bash is 3.2 and has no associative
# arrays; `declare -A` fails there and every string key collapses to index 0,
# so a single icons.conf line would be applied to every agent.
herdr="${HERDR_BIN_PATH:-herdr}"

icons='{"claude":"✺","codex":">_","grok":"𝕏","pi":"π","gemini":"✦","cursor":"➤","open_code":"◇"}'
labels='{"claude":"Claude","codex":"Codex","grok":"Grok","pi":"Pi","gemini":"Gemini","cursor":"Cursor","open_code":"OpenCode"}'

conf="${HERDR_PLUGIN_CONFIG_DIR:-}/icons.conf"
if [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ] && [ -f "$conf" ]; then
  icons=$(jq -n --argjson base "$icons" --rawfile conf "$conf" '
    $base + (
      $conf
      | split("\n")
      | map(select(test("^[[:space:]]*(#|$)") | not))
      | map(
          capture("^(?<agent>[^=]+)=(?<icon>.*)$")?
          | .icon |= sub("\r$"; "")
          | select(.agent != null and .agent != "")
          | {(.agent): .icon}
        )
      | add // {}
    )
  ') || exit 1
fi

"$herdr" agent list | jq -j --argjson icons "$icons" --argjson labels "$labels" '
  .result.agents[]
  | . as $a
  | ($labels[$a.agent] // $a.agent) as $harness
  | ($icons[$a.agent] // "") as $icon
  | $a.pane_id, "\u0000", $harness, "\u0000", $icon, "\u0000"
' | while IFS= read -r -d '' pane && IFS= read -r -d '' harness && IFS= read -r -d '' icon; do
  if [ -n "$icon" ]; then
    "$herdr" pane report-metadata "$pane" \
      --source agent-icons --display-agent "$icon" --token "harness=$harness" >/dev/null
  else
    "$herdr" pane report-metadata "$pane" \
      --source agent-icons --token "harness=$harness" >/dev/null
  fi
done
