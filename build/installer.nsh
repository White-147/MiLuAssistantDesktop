; ============================================================
; MiLuAssistantDesktop 自定义 NSIS 安装器脚本
; 增强：实时进度明细显示、欢迎页自定义文案
; ============================================================

; 显示安装细节（实时进度：当前正在复制的文件）
!macro customInstall
  SetDetailsPrint both
  DetailPrint "正在安装 MiLuAssistantDesktop..."
  SetDetailsPrint listonly
!macroend

!macro customUnInstall
  SetDetailsPrint both
  DetailPrint "正在卸载 MiLuAssistantDesktop..."
  SetDetailsPrint listonly
!macroend

; 欢迎页标题
!macro customWelcomePage
  !define MUI_WELCOMEPAGE_TITLE "欢迎安装 MiLuAssistantDesktop"
  !define MUI_WELCOMEPAGE_TEXT "MiLu AI 助手的 Windows 桌面版。$\r$\n$\r$\n本安装向导将引导您完成安装。$\r$\n$\r$\n您可以自定义安装位置；安装完成后会自动创建桌面快捷方式与开始菜单快捷方式。"
!macroend
