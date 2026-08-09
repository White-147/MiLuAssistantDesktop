<p align="center">
  <img src="./assets/logo.png" alt="MiLuAssistantDesktop logo" width="132">
</p>

<h1 align="center">MiLuAssistantDesktop</h1>

<p align="center">基于 MiLuAssistantWeb 改造的 Windows 桌面安装包版本，使用 Electron 与 Inno Setup 封装本地 AI 助手运行体验。</p>

<p align="center">
  <a href="./README.md">简体中文</a> | <a href="./README.en.md">English</a>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows-0078D4?style=for-the-badge">
  <img alt="Stack" src="https://img.shields.io/badge/stack-Electron%20%2B%20Inno%20Setup%20%2B%20Python-2E7D32?style=for-the-badge">
  <img alt="Package" src="https://img.shields.io/badge/package-desktop%20installer-F59E0B?style=for-the-badge">
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-blue?style=for-the-badge"></a>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/desktop-overview.png" alt="MiLuAssistantDesktop 运行界面截图" width="900">
</p>

MiLuAssistantDesktop 是基于 MiLuAssistantWeb 改造的 Windows 桌面安装包版本。项目使用 Electron + electron-builder 生成应用目录，再用 **Inno Setup 6** 编译为原生 Windows 安装包，将 MiLu 的 Python 后端和 Web 控制台封装为原生 Windows 应用，提供更适合交付、演示和售卖的安装体验。

## 项目关系

- **Web 基座**：[MiLuAssistantWeb](https://github.com/White-147/MiLuAssistantWeb)
- **当前项目**：MiLuAssistantDesktop，负责桌面外壳、安装包、后端进程托管、托盘和用户数据隔离。
- **改造目的**：将原本需要开发环境启动的前后端项目，封装为普通用户可以安装和双击运行的 Windows 应用。

## 运行流程

1. Electron 启动后先显示 `src/loading.html`，UI 立即出现（秒开）。
2. 后台启动 `python-env/python.exe -m milu app --host 127.0.0.1 --port <port>`（自动寻找空闲端口）。
3. 首次启动由 milu 自动初始化工作区/配置；技能库等补充初始化在 UI 加载后后台执行，不阻塞启动。
4. 后端就绪后，`BrowserWindow` 加载本地 Web UI。
5. 关闭窗口时最小化到系统托盘，退出应用时自动结束后端进程。
6. 用户数据隔离在 `%LOCALAPPDATA%\MiLuAssistantDesktop` 下。
7. 启动提速：默认通过 `MILU_DISABLED_CHANNELS` 按需加载频道模块（仅启用 console 界面频道），避免未启用的重 SDK（如飞书 lark_oapi 约 20s）拖慢启动——实测后端就绪约 4 秒。

## 安装器特性（Inno Setup）

- 支持安装过程中**取消/中止**（NSIS 不支持）。
- 可选勾选：桌面快捷方式、开始菜单快捷方式、开机自启动（卸载时自动清理注册表）。
- 自定义安装目录、品牌向导界面（白底 + Web logo 图标）。
- 安装/卸载前自动关闭运行中的应用，避免文件占用。

## 技术栈

- **桌面端**：Electron、electron-builder（win-unpacked）、Inno Setup 6。
- **后端运行时**：Windows embeddable Python、MiLu Python package。
- **构建脚本**：PowerShell、Node.js。
- **Web UI 来源**：MiLuAssistantWeb 的 Python 后端与前端控制台。

## 本地开发

先确保 MiLuAssistantWeb 已安装到当前 Python 环境：

```powershell
cd D:\code\MiLuAssistantWeb
pip install -e .
```

然后启动桌面壳：

```powershell
cd D:\code\MiLuAssistantDesktop
npm install
powershell -ExecutionPolicy Bypass -File scripts\dev-start.ps1
npm start
```

## 构建安装包

```powershell
cd D:\code\MiLuAssistantDesktop
npm install
powershell -ExecutionPolicy Bypass -File scripts\build-python-env.ps1     # 构建嵌入式 Python 运行时
python scripts\build-docs.py <docs 源 md> docs-dist                     # 生成本地文档（或直接使用已生成的 docs-dist/）

# 1. 生成应用目录（win-unpacked，含 python-env 与 console）
npx electron-builder --win --dir

# 2. 用 Inno Setup 6 编译安装包（需先安装 Inno Setup，ISCC 加入 PATH 或指定完整路径）
"D:\soft\program\Inno Setup 6\ISCC.exe" installer.iss
```

安装包输出到仓库内 `release/` 目录，文件名形如 `MiLuAssistantDesktop-Setup-<version>.exe`。

## 系统要求

- **开发**：Windows 10/11、Node.js 18+、Python 3.10+。
- **构建**：需要可访问 Python 官方 embeddable package 下载地址。
- **运行**：Windows 10/11 x64。

## 说明

本项目是 MiLuAssistantWeb 的安装包化延伸，不是新的后端业务系统。后续如果要开发新的 AI 漫剧生产项目，应使用独立仓库 `MiLuStudio`，避免与当前旧版 MiLu 助手项目混淆。
