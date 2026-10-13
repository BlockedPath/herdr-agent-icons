#!/usr/bin/env bash
# Exercise the plugin through its Herdr CLI boundary; no server required.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HERDR_PLUGIN_CONFIG_DIR="$tmp/config"
export HERDR_BIN_PATH="$tmp/herdr"
export TEST_AGENTS="$tmp/agents.json" TEST_REPORTS="$tmp/reports.jsonl"
export TEST_LIST_STATUS=0 TEST_FAIL_PANE=''
mkdir -p "$HERDR_PLUGIN_CONFIG_DIR"
cat > "$HERDR_BIN_PATH" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2" = 'agent list' ]; then
  cat "$TEST_AGENTS"
  exit "$TEST_LIST_STATUS"
fi
if [ "$1 $2" = 'pane report-metadata' ]; then
  pane=$3
  shift 3
  icon=null
  harness=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --source) shift 2 ;;
      --display-agent) icon=$(jq -n --arg icon "$2" '$icon'); shift 2 ;;
      --token) harness=${2#harness=}; shift 2 ;;
      *) exit 2 ;;
    esac
  done
  if [ "$pane" = "$TEST_FAIL_PANE" ]; then exit 9; fi
  jq -nc --arg pane "$pane" --arg harness "$harness" --argjson icon "$icon" \
    '{pane: $pane, harness: $harness, icon: $icon}' >> "$TEST_REPORTS"
  exit 0
fi
exit 2
STUB
chmod +x "$HERDR_BIN_PATH"

run_plugin() {
  : > "$TEST_REPORTS"
  status=0
  bash "$root/agent-icons.sh" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
}

assert_reports() {
  jq -s . "$TEST_REPORTS" > "$tmp/actual"
  printf '%s\n' "$1" | jq . > "$tmp/expected"
  diff -u "$tmp/expected" "$tmp/actual"
}

printf '%s\n' '{"result":{"agents":[
  {"pane_id":"p1","agent":"claude"},
  {"pane_id":"p2","agent":"codex"},
  {"pane_id":"p3","agent":"pi"},
  {"pane_id":"p4","agent":"custom agent"},
  {"pane_id":"p5","agent":"muse"}
]}}' > "$TEST_AGENTS"
run_plugin
[ "$status" -eq 0 ]
assert_reports '[
  {"pane":"p1","harness":"Claude","icon":"✺"},
  {"pane":"p2","harness":"Codex","icon":">_"},
  {"pane":"p3","harness":"Pi","icon":"π"},
  {"pane":"p4","harness":"custom agent","icon":null},
  {"pane":"p5","harness":"Muse","icon":"∞"}
]'
echo 'PASS distinct defaults and unknown-agent fallback'

printf '# comment\r\n\r\nclaude=old\r\nclaude=✳\r\ncodex=\r\ncustom agent=two words=icon\r\n' > "$HERDR_PLUGIN_CONFIG_DIR/icons.conf"
run_plugin
[ "$status" -eq 0 ]
assert_reports '[
  {"pane":"p1","harness":"Claude","icon":"✳"},
  {"pane":"p2","harness":"Codex","icon":null},
  {"pane":"p3","harness":"Pi","icon":"π"},
  {"pane":"p4","harness":"custom agent","icon":"two words=icon"},
  {"pane":"p5","harness":"Muse","icon":"∞"}
]'
echo 'PASS overrides, empty icons, CRLF, and argument preservation'

# Fail an early update so a later success cannot hide the error.
for pane in p1 p2; do
  export TEST_FAIL_PANE="$pane"
  run_plugin
  [ "$status" -ne 0 ] || { echo 'FAIL metadata error was hidden'; exit 1; }
  jq -se --arg failed "$pane" \
    'map(.pane) == (["p1", "p2", "p3", "p4", "p5"] | map(select(. != $failed)))' \
    "$TEST_REPORTS" > /dev/null
done
echo 'PASS metadata failure exit status'
export TEST_FAIL_PANE=''

printf '{"result":{"agents":[]}}\n' > "$TEST_AGENTS"
run_plugin
[ "$status" -eq 0 ]
assert_reports '[]'
echo 'PASS no agents'

export TEST_LIST_STATUS=7
run_plugin
[ "$status" -ne 0 ] || { echo 'FAIL agent list error was hidden'; exit 1; }
assert_reports '[]'
echo 'PASS agent list failure exit status'
export TEST_LIST_STATUS=0

printf 'not JSON\n' > "$TEST_AGENTS"
run_plugin
[ "$status" -ne 0 ] || { echo 'FAIL JSON error was hidden'; exit 1; }
assert_reports '[]'
echo 'PASS invalid JSON failure exit status'
