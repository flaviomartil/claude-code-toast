#!/usr/bin/env bun

import { spawn, execSync } from "child_process";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname } from "path";

const HOME = process.env.HOME || process.env.USERPROFILE || "/tmp";
const STATE_DIR = join(HOME, ".claude", "ccnotify");
const STATE_FILE = join(STATE_DIR, "state.json");

try {
  mkdirSync(STATE_DIR, { recursive: true });
} catch {}

const raw = await Bun.stdin.text();
let input;
try {
  input = JSON.parse(raw);
} catch {
  process.exit(0);
}

const cwd = input.cwd || "";
const project = cwd.split("/").pop() || "Claude";
const event = input.hook_event_name || "Stop";
const sessionId = input.session_id || "unknown";

if (event === "UserPromptSubmit") {
  try {
    writeFileSync(STATE_FILE, JSON.stringify({ sessionId, startedAt: Date.now() }));
  } catch {}
  process.exit(0);
}

if (event !== "Stop" && event !== "Notification") {
  process.exit(0);
}

let elapsed = "";
if (event === "Stop") {
  try {
    const state = JSON.parse(readFileSync(STATE_FILE, "utf8"));
    if (state.startedAt) {
      const secs = Math.round((Date.now() - state.startedAt) / 1000);
      if (secs < 60) elapsed = `${secs}s`;
      else if (secs < 3600) elapsed = `${Math.floor(secs / 60)}m${secs % 60}s`;
      else elapsed = `${Math.floor(secs / 3600)}h${Math.floor((secs % 3600) / 60)}m`;
    }
  } catch {}
}

let body = "";
if (event === "Stop") {
  const msg = (input.assistant_message || "").replace(/\n/g, " ").trim().substring(0, 250);
  body = msg || "Finished";
} else if (event === "Notification") {
  body = input.notification_message || "Needs attention";
}
body = body.substring(0, 250);

const titleB64 = Buffer.from(project).toString("base64");
const bodyB64 = Buffer.from(body).toString("base64");
const timerB64 = elapsed ? Buffer.from(elapsed).toString("base64") : "";

const scriptDir = dirname(new URL(import.meta.url).pathname);
const toastScript = join(scriptDir, "toast.ps1");

let winPath;
try {
  winPath = execSync(`wslpath -w "${toastScript}"`).toString().trim();
} catch {
  process.exit(0);
}

const child = spawn(
  "powershell.exe",
  [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    winPath,
    "-TitleB64",
    titleB64,
    "-BodyB64",
    bodyB64,
    ...(timerB64 ? ["-TimerB64", timerB64] : []),
    "-Duration",
    "6",
  ],
  {
    stdio: ["ignore", "ignore", "ignore"],
    detached: true,
  }
);
child.unref();

process.exit(0);
