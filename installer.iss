; ============================================================
; MiLuAssistantDesktop — Inno Setup 安装器
; 功能：自定义安装目录、桌面/开始菜单快捷方式、开机自启动（勾选）、
;       品牌图标与向导背景、安装中可取消
; 编译：ISCC.exe installer.iss （需要先执行 electron-builder --dir 生成 win-unpacked）
; ============================================================

#define MyAppName "MiLuAssistantDesktop"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "White-147"
#define MyAppExeName "MiLuAssistantDesktop.exe"
#define MyAppId "{{7C2F4B1E-8D6A-4E3F-9A1B-2C5D6E7F8A9B}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=release
OutputBaseFilename=MiLuAssistantDesktop-Setup-{#MyAppVersion}
SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardImageFile=assets\installer\wizard-164x314.bmp
WizardSmallImageFile=assets\installer\wizard-small-55x58.bmp
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 安装/卸载前自动关闭运行中的应用（避免文件占用）
CloseApplications=yes
CloseApplicationsFilter=*.exe
; 版本信息
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: checkedonce
Name: "startmenu"; Description: "创建开始菜单快捷方式"; GroupDescription: "附加任务:"; Flags: checkedonce
Name: "autostart"; Description: "开机自动启动 MiLuAssistantDesktop"; GroupDescription: "附加任务:"

[Files]
Source: "release\win-unpacked\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenu
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; 开机自启动（HKCU，免管理员；卸载时自动删除）
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// 使用 Inno 默认白色向导背景（品牌元素通过 wizard 图与图标呈现）
procedure InitializeWizard();
begin
end;
