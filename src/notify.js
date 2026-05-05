#!/usr/bin/env bun

import { spawn, execSync } from "child_process";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";

const HOME = process.env.HOME || process.env.USERPROFILE || "/tmp";
const STATE_DIR = join(HOME, ".claude", "ccnotify");
const STATE_FILE = join(STATE_DIR, "state.json");
const CONFIG_FILE = join(STATE_DIR, "config.json");

const DEFAULT_CONFIG = {
  duration: 6,
  position: "bottom-right",
  minElapsed: 5,
  theme: "claude",
  opacity: 0.92,
  ignoreProjects: [],
  sound: {
    enabled: true,
    file: null,
  },
};

try {
  mkdirSync(STATE_DIR, { recursive: true });
} catch {}

function loadConfig() {
  try {
    if (existsSync(CONFIG_FILE)) {
      const raw = JSON.parse(readFileSync(CONFIG_FILE, "utf8"));
      return { ...DEFAULT_CONFIG, ...raw, sound: { ...DEFAULT_CONFIG.sound, ...raw.sound } };
    }
  } catch {}
  try {
    writeFileSync(CONFIG_FILE, JSON.stringify(DEFAULT_CONFIG, null, 2));
  } catch {}
  return DEFAULT_CONFIG;
}

if (process.argv.includes("--test")) {
  const config = loadConfig();
  const scriptDir = dirname(new URL(import.meta.url).pathname);
  const toastScript = join(scriptDir, "toast.ps1");
  let winPath;
  try {
    winPath = execSync(`wslpath -w "${toastScript}"`).toString().trim();
  } catch {
    console.error("Failed to resolve toast.ps1 path. Are you running on WSL2?");
    process.exit(1);
  }

  const configB64 = Buffer.from(JSON.stringify(config)).toString("base64");
  const child = spawn(
    "powershell.exe",
    [
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", winPath,
      "-TitleB64", Buffer.from("test-project").toString("base64"),
      "-BodyB64", Buffer.from("This is a test notification from claude-code-toast").toString("base64"),
      "-TimerB64", Buffer.from("42s").toString("base64"),
      "-ConfigB64", configB64,
      "-Duration", String(config.duration),
    ],
    { stdio: ["ignore", "inherit", "inherit"] }
  );
  child.on("close", () => process.exit(0));
  await new Promise(() => {});
}

const raw = await Bun.stdin.text();
let input;
try {
  input = JSON.parse(raw);
} catch {
  process.exit(0);
}

const config = loadConfig();
const cwd = input.cwd || "";
const project = cwd.split("/").pop() || "Claude";
const ignoreList = Array.isArray(config.ignoreProjects) ? config.ignoreProjects : [];
if (ignoreList.some(p => p && (cwd.includes(p) || project.includes(p)))) process.exit(0);
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

let elapsedSecs = 0;
let elapsed = "";
if (event === "Stop") {
  try {
    const state = JSON.parse(readFileSync(STATE_FILE, "utf8"));
    if (state.startedAt) {
      elapsedSecs = Math.round((Date.now() - state.startedAt) / 1000);
      if (elapsedSecs < 60) elapsed = `${elapsedSecs}s`;
      else if (elapsedSecs < 3600) elapsed = `${Math.floor(elapsedSecs / 60)}m${elapsedSecs % 60}s`;
      else elapsed = `${Math.floor(elapsedSecs / 3600)}h${Math.floor((elapsedSecs % 3600) / 60)}m`;
    }
  } catch {}
}

if (event === "Stop" && config.minElapsed > 0 && elapsedSecs < config.minElapsed) {
  process.exit(0);
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
const configB64 = Buffer.from(JSON.stringify(config)).toString("base64");

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
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", winPath,
    "-TitleB64", titleB64,
    "-BodyB64", bodyB64,
    ...(timerB64 ? ["-TimerB64", timerB64] : []),
    "-ConfigB64", configB64,
    "-Duration", String(config.duration),
  ],
  {
    stdio: ["ignore", "ignore", "ignore"],
    detached: true,
  }
);
child.unref();

process.exit(0);
