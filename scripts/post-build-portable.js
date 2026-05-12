/**
 * Post-build script for portable mode.
 * Compiles MiLuAssistantDesktop.exe (launcher) and uninstallerMiLuAssistantDesktop.exe using .NET csc.exe,
 * with the project icon embedded. These tiny exes delegate to app/win-unpacked/.
 */
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const UNPACKED = path.join(ROOT, "app", "win-unpacked");
const EXE_NAME = "MiLuAssistantDesktop.exe";
const SRC_EXE = path.join(UNPACKED, EXE_NAME);

if (!fs.existsSync(SRC_EXE)) {
  console.error(`[post-build] ${EXE_NAME} not found at ${SRC_EXE}`);
  process.exit(1);
}

function findCsc() {
  const bases = [
    "C:\\Windows\\Microsoft.NET\\Framework64",
    "C:\\Windows\\Microsoft.NET\\Framework",
  ];
  for (const base of bases) {
    if (!fs.existsSync(base)) continue;
    const dirs = fs.readdirSync(base)
      .filter(d => d.startsWith("v") && fs.existsSync(path.join(base, d, "csc.exe")))
      .sort()
      .reverse();
    if (dirs.length > 0) return path.join(base, dirs[0], "csc.exe");
  }
  throw new Error("csc.exe not found");
}

const csc = findCsc();
const icon = path.join(ROOT, "assets", "icon.ico");
const iconArg = fs.existsSync(icon) ? `/win32icon:${icon}` : "";

console.log(`[post-build] Using csc: ${csc}`);

// Compile launcher
execFileSync(csc, [
  "/target:winexe",
  `/out:${path.join(ROOT, "MiLuAssistantDesktop.exe")}`,
  iconArg,
  path.join(ROOT, "scripts", "launcher.cs"),
].filter(Boolean), { stdio: "inherit" });
console.log("[post-build] Compiled MiLuAssistantDesktop.exe");

// Compile uninstaller
execFileSync(csc, [
  "/target:winexe",
  `/out:${path.join(ROOT, "uninstallerMiLuAssistantDesktop.exe")}`,
  iconArg,
  "/reference:System.Windows.Forms.dll",
  path.join(ROOT, "scripts", "uninstaller.cs"),
].filter(Boolean), { stdio: "inherit" });
console.log("[post-build] Compiled uninstallerMiLuAssistantDesktop.exe");

console.log("\n[post-build] Portable build ready!");
console.log(`  Launch:     MiLuAssistantDesktop.exe`);
console.log(`  Uninstall:  uninstallerMiLuAssistantDesktop.exe`);
console.log(`  Real app:   app\\win-unpacked\\${EXE_NAME}`);
