#!/usr/bin/env bash
# Set an icon as the display name of every detected agent pane.
# Override or add icons in $HERDR_PLUGIN_CONFIG_DIR/icons.conf, one
# `agent=icon` per line. An empty icon keeps that agent's name.
herdr="${HERDR_BIN_PATH:-herdr}"

declare -A ICON=(
  [claude]="✺" [codex]=">_" [grok]="𝕏" [pi]="π"
  [gemini]="✦" [cursor]="➤" [open_code]="◇"
)

conf="${HERDR_PLUGIN_CONFIG_DIR:-}/icons.conf"
if [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ] && [ -f "$conf" ]; then
  while IFS='=' read -r agent icon || [ -n "$agent" ]; do
    case "$agent" in '' | \#*) continue ;; esac
    ICON[$agent]="${icon%$'\r'}"
  done <"$conf"
fi

"$herdr" agent list | jq -r '.result.agents[] | "\(.pane_id) \(.agent)"' |
  while read -r pane agent; do
    icon="${ICON[$agent]}"
    if [ -n "$icon" ]; then
      "$herdr" pane report-metadata "$pane" \
        --source agent-icons --display-agent "$icon" >/dev/null
    fi
  done
