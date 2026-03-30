#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/src/notify.js"
CONFIG_DIR="$HOME/.claude/ccnotify"
CONFIG_FILE="$CONFIG_DIR/config.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
BUN="$(which bun 2>/dev/null || echo "")"

if [ -z "$BUN" ]; then
  echo "  Error: bun is required. Install it: https://bun.sh"
  exit 1
fi

if ! command -v powershell.exe &>/dev/null; then
  echo "  Error: powershell.exe not found. This tool requires WSL2 on Windows."
  exit 1
fi

mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" << 'CONF'
{
  "duration": 6,
  "position": "bottom-right",
  "minElapsed": 5,
  "theme": "claude",
  "opacity": 0.92,
  "sound": {
    "enabled": true,
    "file": null
  }
}
CONF
  echo "  Created default config at $CONFIG_FILE"
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

HOOK_CMD="$BUN $NOTIFY_SCRIPT"

RESULT=$("$BUN" -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
const hooks = cfg.hooks || {};
const cmd = '$HOOK_CMD';
const entry = { matcher: '', hooks: [{ type: 'command', command: cmd }] };
const events = ['Stop', 'Notification', 'UserPromptSubmit'];
const added = [];
for (const ev of events) {
  const list = hooks[ev] || [];
  const has = list.some(e => e.hooks?.some(h => h.command?.includes('notify.js')));
  if (!has) {
    list.push(entry);
    hooks[ev] = list;
    added.push(ev);
  }
}
if (added.length) {
  cfg.hooks = hooks;
  fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(cfg, null, 2));
}
console.log(added.join(' ') || 'none');
")

echo ""
if [ "$RESULT" = "none" ]; then
  echo "  All hooks already configured."
else
  echo "  Hooks added: $RESULT"
fi
echo "  Config: $CONFIG_FILE"
echo "  Settings: $SETTINGS_FILE"
echo ""

echo "  Testing notification..."
"$BUN" "$NOTIFY_SCRIPT" --test
echo ""
echo "  Restart Claude Code to activate."
echo ""
