# 贡献指南

本仓库主要作为 MiLuAssistantWeb 的 Windows 桌面安装包封装项目和个人项目展示材料维护。欢迎通过 Issue 或 PR 补充打包流程、安装体验、文档说明和本地运行兼容性问题。

## 提交前检查

- 不提交安装包产物、`python-env/`、`docs-dist/`、用户本地数据、运行日志或构建缓存。
- 不提交 API Key、模型 Provider 密钥、Token、Cookie、私钥或真实工作区文件。
- 文档改动请同时考虑 `README.md` 与 `README.en.md` 的中英文一致性。
- 代码改动请说明影响范围，并尽量附上本地验证命令或截图。

## PR 建议

PR 标题建议使用简短动词开头，例如 `docs: ...`、`fix: ...`、`build: ...`。如果改动涉及安装包或启动流程，请在描述中写清楚 Windows 版本、Node/Python 版本和验证结果。
