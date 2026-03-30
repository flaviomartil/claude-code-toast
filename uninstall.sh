#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/src/notify.js"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "No settings file found. Nothing to uninstall."
  exit 0
fi

HOOK_CMD="$(which bun) $NOTIFY_SCRIPT"

python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    cfg = json.load(f)
hooks = cfg.get('hooks', {})
changed = False
for event in list(hooks.keys()):
    entries = hooks[event]
    filtered = [e for e in entries if not any('$NOTIFY_SCRIPT' in h.get('command', '') for h in e.get('hooks', []))]
    if len(filtered) != len(entries):
        changed = True
        if filtered:
            hooks[event] = filtered
        else:
            del hooks[event]
if changed:
    with open('$SETTINGS_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('Hooks removed successfully.')
else:
    print('No hooks found to remove.')
"

echo ""
echo "  claude-code-toast uninstalled."
echo "  Restart Claude Code to apply."
echo ""
