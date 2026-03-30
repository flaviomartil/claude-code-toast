#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/src/notify.js"
SETTINGS_FILE="$HOME/.claude/settings.json"
BUN="$(which bun 2>/dev/null || echo "")"

if [ -z "$BUN" ]; then
  echo "  Error: bun not found."
  exit 1
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "  No settings file found. Nothing to uninstall."
  exit 0
fi

"$BUN" -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
const hooks = cfg.hooks || {};
let changed = false;
for (const ev of Object.keys(hooks)) {
  const before = hooks[ev].length;
  hooks[ev] = hooks[ev].filter(e => !e.hooks?.some(h => h.command?.includes('notify.js')));
  if (hooks[ev].length !== before) changed = true;
  if (!hooks[ev].length) delete hooks[ev];
}
if (changed) {
  cfg.hooks = hooks;
  fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(cfg, null, 2));
  console.log('  Hooks removed.');
} else {
  console.log('  No hooks found to remove.');
}
"

echo ""
echo "  claude-code-toast uninstalled."
echo "  Config preserved at ~/.claude/ccnotify/config.json"
echo "  Restart Claude Code to apply."
echo ""
