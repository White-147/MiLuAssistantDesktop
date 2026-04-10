# MiLu Desktop

基于 Electron + electron-builder + NSIS 的 MiLu 桌面应用。将 MiLu 的 Python 后端打包在 Electron 壳中，提供原生窗口体验和标准 Windows 安装器。

## 架构

```
MiLuEXE/
├── assets/              # 图标等资源
├── scripts/
│   ├── prepare-python-env.ps1   # 构建 conda-pack Python 环境
│   └── dev-start.ps1            # 开发模式快捷配置
├── src/
│   ├── main.js          # Electron 主进程（管理后端生命周期 + BrowserWindow）
│   ├── preload.js       # 预加载脚本（contextBridge）
│   └── loading.html     # 等待后端启动的加载页
├── python-env/          # 打包的 Python 环境（gitignored）
├── package.json         # Electron + electron-builder 配置
└── README.md
```

运行时流程：
1. Electron 启动 → 显示 `loading.html`（加载动画）
2. 后台启动 `python-env/python.exe -m milu app --port <随机空闲端口>`
3. 轮询端口直到后端就绪
4. `BrowserWindow.loadURL("http://127.0.0.1:<port>")` 加载 MiLu Web UI
5. 关闭窗口 → 最小化到系统托盘；退出时自动终止后端进程

## 快速开始（开发模式）

开发模式直接使用系统已安装的 MiLu Python 环境，无需 conda-pack：

```powershell
# 1. 确保 MiLu 已安装到系统 Python
cd D:\code\MiLu
pip install -e .

# 2. 安装 Electron 依赖
cd D:\code\MiLuEXE
npm install

# 3. 配置开发模式
powershell -ExecutionPolicy Bypass -File scripts\dev-start.ps1

# 4. 启动
npm start
```

## 构建安装包

```powershell
# 1. 准备 Python 环境（conda-pack）
powershell -ExecutionPolicy Bypass -File scripts\prepare-python-env.ps1

# 2. 构建 NSIS 安装器
npm run dist

# 安装包输出到 release/ 目录
```

## 图标

将 `icon.ico`（256×256）放入 `assets/` 目录。可以使用在线工具将 SVG 转换为 ICO：

```powershell
# 源 SVG 在 MiLu 仓库：scripts/pack/assets/icon.svg
# 推荐使用 https://convertio.co/svg-ico/ 或 ImageMagick:
magick convert -background none icon.svg -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

## 系统要求

- **开发**: Node.js 18+, Python 3.10+, MiLu 已安装
- **打包**: 以上 + conda, NSIS (makensis on PATH)
- **运行**: Windows 10/11 x64
