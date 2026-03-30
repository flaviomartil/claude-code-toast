# claude-code-toast

Custom Windows toast notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on WSL2.

Get notified when Claude finishes a task — with project name, elapsed time, and a summary of what was done.

![preview](assets/preview.png)

## Features

- **Task completion notifications** — know when Claude is done without watching the terminal
- **Elapsed time tracking** — see how long each task took (green timer badge)
- **Message preview** — shows Claude's last response or notification message
- **Non-intrusive popup** — appears bottom-right, doesn't steal focus, click to dismiss
- **Progress bar** — visual countdown before auto-dismiss (6s default)
- **Purple accent theme** — matches Claude's branding

## Events

| Event | Trigger |
|---|---|
| `UserPromptSubmit` | Starts the timer |
| `Stop` | Shows toast with elapsed time + last message |
| `Notification` | Shows toast with notification content |

## Requirements

- **WSL2** on Windows 10/11
- **[Bun](https://bun.sh)** runtime (`curl -fsSL https://bun.sh/install | bash`)
- **PowerShell** (available by default on Windows via `powershell.exe`)

## Install

```bash
git clone https://github.com/martil/claude-code-toast.git
cd claude-code-toast
chmod +x install.sh
./install.sh
```

The installer automatically adds hooks to `~/.claude/settings.json` for `Stop`, `Notification`, and `UserPromptSubmit` events.

Restart Claude Code after installing.

## Uninstall

```bash
cd claude-code-toast
chmod +x uninstall.sh
./uninstall.sh
```

## How it works

```
Claude Code event
    ↓
notify.js (Bun) — reads event, calculates elapsed time, encodes payload as base64
    ↓
powershell.exe — runs toast.ps1 via WSL interop
    ↓
WinForms popup — custom borderless window, topmost, no-activate, auto-dismiss
```

The toast window uses `WS_EX_NOACTIVATE` + `WS_EX_TOOLWINDOW` flags so it never steals focus from your terminal or editor.

## Customization

Edit `src/toast.ps1` to change:

| What | Where |
|---|---|
| Colors | `FromArgb(...)` calls — accent purple is `124, 58, 237` |
| Size | `$W` and `$H` variables (default 520x200) |
| Position | `$form.Location` — default is bottom-right with 20px margin |
| Duration | `-Duration` param in notify.js (default 6 seconds) |
| Font | `New-Object System.Drawing.Font(...)` calls |

## License

MIT
