<p align="center">
  <img src="./assets/icon.png" alt="MiLuAssistantDesktop icon" width="112">
</p>

<h1 align="center">MiLuAssistantDesktop</h1>

<p align="center">A Windows desktop installer edition based on MiLuAssistantWeb, packaging the local AI assistant experience with Electron and NSIS.</p>

<p align="center">
  <a href="./README.md">简体中文</a> | <a href="./README.en.md">English</a>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows-0078D4?style=for-the-badge">
  <img alt="Stack" src="https://img.shields.io/badge/stack-Electron%20%2B%20NSIS%20%2B%20Python-2E7D32?style=for-the-badge">
  <img alt="Package" src="https://img.shields.io/badge/package-desktop%20installer-F59E0B?style=for-the-badge">
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-blue?style=for-the-badge"></a>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/desktop-overview.png" alt="MiLuAssistantDesktop running UI screenshot" width="900">
</p>

MiLuAssistantDesktop packages the MiLuAssistantWeb Python backend and web console into a native Windows application. It focuses on installability, local process orchestration, tray behavior, user data isolation, and a delivery experience suitable for demos or packaged distribution.

## Relationship

- **Web base**: [MiLuAssistantWeb](https://github.com/White-147/MiLuAssistantWeb)
- **Current repository**: Electron shell, installer, backend process management, tray integration, and Windows user-data isolation.
- **Purpose**: turn a developer-oriented web/backend project into a double-clickable Windows application.

## Runtime Flow

1. Electron starts and shows `src/loading.html`.
2. First launch initializes the workspace through `python-env/python.exe -m milu init --defaults --accept-security`.
3. The app finds a local free port and starts `python-env/python.exe -m milu app --host 127.0.0.1 --port <port>`.
4. `BrowserWindow` loads the local Web UI after the backend is ready.
5. Closing the window minimizes to tray, and quitting the app terminates the backend process.
6. User data is isolated under `%LOCALAPPDATA%\MiLuAssistantDesktop`.

## Tech Stack

- **Desktop**: Electron, electron-builder, NSIS.
- **Backend runtime**: Windows embeddable Python, MiLu Python package.
- **Build scripts**: PowerShell, Node.js, C# launcher / uninstaller.
- **Web UI source**: MiLuAssistantWeb backend and console.

## Local Development

Install MiLuAssistantWeb into the active Python environment first:

```powershell
cd D:\code\MiLuAssistantWeb
pip install -e .
```

Then start the desktop shell:

```powershell
cd D:\code\MiLuAssistantDesktop
npm install
powershell -ExecutionPolicy Bypass -File scripts\dev-start.ps1
npm start
```

## Build Installer

```powershell
cd D:\code\MiLuAssistantDesktop
npm install
powershell -ExecutionPolicy Bypass -File scripts\build-python-env.ps1
npm run dist
```

The installer is emitted under `D:\code` with a name such as `MiLuAssistantDesktop-Setup-<version>.exe`.

## License and Security

This repository uses the Apache License 2.0. See [LICENSE](LICENSE).

Security reporting instructions are in [SECURITY.md](SECURITY.md), and contribution notes are in [CONTRIBUTING.md](CONTRIBUTING.md).
