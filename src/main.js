const { app, BrowserWindow, shell, dialog, Menu, Tray } = require("electron");
const path = require("path");
const { spawn } = require("child_process");
const net = require("net");
const fs = require("fs");

const BACKEND_HOST = "127.0.0.1";
const DEFAULT_PORT = 8088;
const READY_TIMEOUT_MS = 180_000;

let mainWindow = null;
let backendProcess = null;
let tray = null;
let backendPort = DEFAULT_PORT;
let isQuitting = false;
let startTime = 0;

let _backendReadyResolve = null;
const backendReadyPromise = new Promise((r) => { _backendReadyResolve = r; });

// ─── App data isolation ────────────────────────────────────────────

function getAppDataRoot() {
  return path.join(
    process.env.LOCALAPPDATA || path.join(require("os").homedir(), "AppData", "Local"),
    "MiLu Desktop"
  );
}

function getWorkingDir() {
  return path.join(getAppDataRoot(), "data");
}

function getSecretDir() {
  return path.join(getAppDataRoot(), "secrets");
}

// ─── Python environment ────────────────────────────────────────────

function isDevMode() {
  if (app.isPackaged) return false;
  return fs.existsSync(path.join(__dirname, "..", ".dev-mode"));
}

function readDevConfig() {
  const marker = path.join(__dirname, "..", ".dev-mode");
  if (!fs.existsSync(marker)) return {};
  const text = fs.readFileSync(marker, "utf-8");
  const cfg = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^(\w+)=(.+)/);
    if (m) cfg[m[1]] = m[2].trim();
  }
  return cfg;
}

function getResourcePath(...segments) {
  if (isDevMode()) {
    const cfg = readDevConfig();
    if (cfg.PYTHON_ROOT) return path.join(cfg.PYTHON_ROOT, ...segments);
  }
  const base = app.isPackaged
    ? path.join(process.resourcesPath, "python-env")
    : path.join(__dirname, "..", "python-env");
  return path.join(base, ...segments);
}

function getPythonExe() {
  if (isDevMode()) {
    const cfg = readDevConfig();
    if (cfg.PYTHON_EXE) return cfg.PYTHON_EXE;
  }
  return getResourcePath("python.exe");
}

function buildBackendEnv() {
  const env = { ...process.env };
  const envRoot = getResourcePath();
  env.PATH = `${envRoot};${path.join(envRoot, "Scripts")};${env.PATH || ""}`;
  env.PYTHONIOENCODING = "utf-8";
  env.MILU_WORKING_DIR = getWorkingDir();
  env.MILU_SECRET_DIR = getSecretDir();
  return env;
}

// ─── Docs path ──────────────────────────────────────────────────────

function getDocsHtmlPath() {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, "docs", "milu-docs-zh.html");
  }
  return path.join(__dirname, "..", "docs-dist", "milu-docs-zh.html");
}

// ─── Network helpers ───────────────────────────────────────────────

function findFreePort(host = BACKEND_HOST) {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, host, () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
    srv.on("error", reject);
  });
}

function waitForBackendReady(timeoutMs = READY_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Backend startup timed out")), timeoutMs);
    backendReadyPromise.then(() => {
      clearTimeout(timer);
      resolve();
    });
  });
}

// ─── Loading status helper ─────────────────────────────────────────

function updateLoadingStatus(text) {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  const elapsed = Math.round((Date.now() - startTime) / 1000);
  const display = elapsed > 3 ? `${text}（${elapsed}s）` : text;
  const safe = display.replace(/'/g, "\\'").replace(/\n/g, "\\n");
  mainWindow.webContents.executeJavaScript(
    `try { document.getElementById('status').textContent = '${safe}'; } catch(e) {}`
  ).catch(() => {});
}

let elapsedTimer = null;
function startElapsedUpdater(statusText) {
  if (elapsedTimer) clearInterval(elapsedTimer);
  elapsedTimer = setInterval(() => updateLoadingStatus(statusText), 2000);
}
function stopElapsedUpdater() {
  if (elapsedTimer) { clearInterval(elapsedTimer); elapsedTimer = null; }
}

// ─── First-launch init (async, hidden) ─────────────────────────────

function needsInit() {
  const configPath = path.join(getWorkingDir(), "config.json");
  return !fs.existsSync(configPath);
}

function runInitAsync() {
  return new Promise((resolve) => {
    const pythonExe = getPythonExe();
    const env = buildBackendEnv();
    console.log("[MiLu] First launch — running milu init (async, hidden)");

    fs.mkdirSync(getWorkingDir(), { recursive: true });
    fs.mkdirSync(getSecretDir(), { recursive: true });

    const proc = spawn(
      pythonExe,
      ["-u", "-m", "milu", "init", "--defaults", "--accept-security"],
      {
        cwd: getResourcePath(),
        env,
        stdio: ["ignore", "pipe", "pipe"],
        windowsHide: true,
      }
    );

    proc.stdout.on("data", (d) => {
      const line = d.toString().trim();
      if (line) {
        console.log(`[init] ${line}`);
        if (line.includes("Workspace") || line.includes("workspace")) {
          updateLoadingStatus("正在初始化工作区...");
        } else if (line.includes("Skill") || line.includes("skill")) {
          updateLoadingStatus("正在初始化技能库...");
        } else if (line.includes("config")) {
          updateLoadingStatus("正在生成配置文件...");
        }
      }
    });
    proc.stderr.on("data", (d) => {
      const line = d.toString().trim();
      if (line) console.error(`[init:err] ${line}`);
    });

    const timeout = setTimeout(() => {
      console.warn("[MiLu] init timed out after 120s, proceeding anyway");
      try { proc.kill(); } catch {}
      resolve();
    }, 120_000);

    proc.on("exit", (code) => {
      clearTimeout(timeout);
      console.log(`[MiLu] init exited with code ${code}`);
      resolve();
    });

    proc.on("error", (err) => {
      clearTimeout(timeout);
      console.error("[MiLu] init spawn error:", err.message);
      resolve();
    });
  });
}

// ─── Backend lifecycle ─────────────────────────────────────────────

function onBackendOutput(text) {
  if (text.includes("Uvicorn running") || text.includes("Application startup complete")) {
    updateLoadingStatus("服务已就绪，正在加载界面...");
    if (_backendReadyResolve) { _backendReadyResolve(); _backendReadyResolve = null; }
  }
  if (text.includes("Checking for legacy")) updateLoadingStatus("正在迁移配置...");
  else if (text.includes("Initializing MultiAgent")) updateLoadingStatus("正在初始化智能体...");
  else if (text.includes("ProviderManager") || text.includes("provider")) updateLoadingStatus("正在加载模型服务...");
  else if (text.includes("LocalModel")) updateLoadingStatus("正在初始化本地模型...");
}

function startBackend(port) {
  const pythonExe = getPythonExe();
  if (!fs.existsSync(pythonExe)) {
    dialog.showErrorBox(
      "MiLu Desktop",
      `Python environment not found.\n\nExpected: ${pythonExe}`
    );
    app.quit();
    return null;
  }

  const env = buildBackendEnv();

  const proc = spawn(
    pythonExe,
    ["-u", "-m", "milu", "app", "--host", BACKEND_HOST, "--port", String(port)],
    {
      cwd: getResourcePath(),
      env,
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
    }
  );

  proc.stdout.on("data", (d) => {
    const text = d.toString();
    process.stdout.write(text);
    onBackendOutput(text);
  });
  proc.stderr.on("data", (d) => {
    const text = d.toString();
    process.stderr.write(text);
    onBackendOutput(text);
  });
  proc.on("exit", (code) => {
    console.log(`[MiLu] backend exited with code ${code}`);
    backendProcess = null;
    if (!isQuitting) {
      dialog.showErrorBox("MiLu Desktop", `Backend process exited unexpectedly (code ${code}).`);
      app.quit();
    }
  });

  return proc;
}

function killBackend() {
  if (!backendProcess) return Promise.resolve();
  return new Promise((resolve) => {
    backendProcess.removeAllListeners("exit");
    backendProcess.once("exit", resolve);
    try { backendProcess.kill(); } catch { resolve(); }
    setTimeout(() => {
      try { backendProcess?.kill("SIGKILL"); } catch {}
      resolve();
    }, 5000);
  });
}

// ─── Window + Tray ─────────────────────────────────────────────────

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1360, height: 860, minWidth: 900, minHeight: 600,
    title: "MiLu Desktop",
    icon: path.join(__dirname, "..", "assets", "icon.ico"),
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, "loading.html"));
  mainWindow.once("ready-to-show", () => mainWindow.show());

  mainWindow.webContents.setWindowOpenHandler(({ url: newUrl }) => {
    if (newUrl.includes("/milu-docs-zh")) {
      const docsHtml = getDocsHtmlPath();
      if (fs.existsSync(docsHtml)) {
        shell.openPath(docsHtml);
      } else {
        shell.openExternal(newUrl);
      }
    } else if (newUrl.startsWith("http://") || newUrl.startsWith("https://")) {
      shell.openExternal(newUrl);
    }
    return { action: "deny" };
  });

  mainWindow.on("close", (e) => {
    if (!isQuitting) { e.preventDefault(); mainWindow.hide(); }
  });
  mainWindow.on("closed", () => { mainWindow = null; });
}

function createTray() {
  const iconPath = path.join(__dirname, "..", "assets", "icon.ico");
  if (!fs.existsSync(iconPath)) return;

  tray = new Tray(iconPath);
  const contextMenu = Menu.buildFromTemplate([
    { label: "Show MiLu", click: () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } } },
    { label: `Open in Browser (port ${backendPort})`, click: () => shell.openExternal(`http://${BACKEND_HOST}:${backendPort}`) },
    { type: "separator" },
    { label: "Quit", click: () => { isQuitting = true; app.quit(); } },
  ]);
  tray.setToolTip("MiLu Desktop");
  tray.setContextMenu(contextMenu);
  tray.on("double-click", () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } });
}

// ─── App lifecycle ─────────────────────────────────────────────────

app.on("ready", async () => {
  startTime = Date.now();

  createWindow();
  createTray();

  try {
    backendPort = await findFreePort(BACKEND_HOST);
  } catch {
    backendPort = DEFAULT_PORT;
  }

  if (needsInit()) {
    updateLoadingStatus("首次启动，正在初始化环境...");
    await runInitAsync();
  }

  updateLoadingStatus("正在启动后端服务...");
  startElapsedUpdater("正在启动后端服务...");
  console.log(`[MiLu] Starting backend on port ${backendPort}...`);
  console.log(`[MiLu] Working dir: ${getWorkingDir()}`);
  backendProcess = startBackend(backendPort);
  if (!backendProcess) return;

  try {
    await waitForBackendReady();
    stopElapsedUpdater();
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`[MiLu] Backend ready in ${elapsed}s`);
    updateLoadingStatus("服务已就绪，正在加载界面...");
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.loadURL(`http://${BACKEND_HOST}:${backendPort}`);
    }
  } catch (err) {
    stopElapsedUpdater();
    console.error("[MiLu] Backend not ready:", err.message);
    updateLoadingStatus("后端启动超时，请检查日志。");
  }
});

app.on("before-quit", async () => {
  isQuitting = true;
  stopElapsedUpdater();
  await killBackend();
});

app.on("window-all-closed", () => { /* keep running in tray */ });
app.on("activate", () => { if (mainWindow) mainWindow.show(); });
