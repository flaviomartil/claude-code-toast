#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
HOOKS_DIR="$HOME/.claude/hooks"
NOTIFY_SCRIPT="$SRC_DIR/notify.js"

if ! command -v bun &>/dev/null; then
  echo "Error: bun is required. Install it: https://bun.sh"
  exit 1
fi

if ! command -v powershell.exe &>/dev/null; then
  echo "Error: powershell.exe not found. This tool requires WSL2 on Windows."
  exit 1
fi

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$HOME/.claude"
  echo '{}' > "$SETTINGS_FILE"
fi

HOOK_CMD="$(which bun) $NOTIFY_SCRIPT"

HOOK_ENTRY=$(cat <<EOF
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "$HOOK_CMD"
    }
  ]
}
EOF
)

HAS_HOOKS=$(python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f:
    cfg = json.load(f)
hooks = cfg.get('hooks', {})
cmd = '$HOOK_CMD'
found = []
for event in ['Stop', 'Notification', 'UserPromptSubmit']:
    entries = hooks.get(event, [])
    for e in entries:
        for h in e.get('hooks', []):
            if cmd in h.get('command', ''):
                found.append(event)
                break
print(','.join(found))
" 2>/dev/null || echo "")

MISSING=""
for EVENT in Stop Notification UserPromptSubmit; do
  if [[ ! "$HAS_HOOKS" == *"$EVENT"* ]]; then
    MISSING="$MISSING $EVENT"
  fi
done

if [ -z "$MISSING" ]; then
  echo "All hooks already configured. Nothing to do."
  exit 0
fi

python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    cfg = json.load(f)
hooks = cfg.setdefault('hooks', {})
cmd = '$HOOK_CMD'
entry = {'matcher': '', 'hooks': [{'type': 'command', 'command': cmd}]}
for event in '$MISSING'.split():
    existing = hooks.get(event, [])
    already = any(cmd in h.get('command', '') for e in existing for h in e.get('hooks', []))
    if not already:
        existing.append(entry)
        hooks[event] = existing
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
"

echo ""
echo "  claude-code-toast installed!"
echo ""
echo "  Hooks added for:$MISSING"
echo "  Settings: $SETTINGS_FILE"
echo ""
echo "  Restart Claude Code to activate."
echo ""
