# Claude Code 便携环境

一套 Windows 上免安装的 Claude Code 运行环境：把 Node.js、Python、Git、CCswitch 放进 `tools/`，双击 `启动.bat` 把它们临时加进 PATH，然后直接用 `claude`。

> 仓库只含脚本，不含 `tools/` 里的二进制工具（体积太大，且含平台相关文件）。按下面步骤自行准备。

## 目录结构

```
cladue_code/
├── 启动.bat        双击启动，设置 PATH 后进入命令行
├── .gitignore
├── README.md
└── tools/          （需自行准备，不入库）
    ├── node-v22.14.0-win-x64/   Node.js（含预装的 claude）
    ├── python-full/             Python 完整版
    ├── git-full/                Git 完整版
    └── ccswitch/                CCswitch
```

## 准备 tools/

### 一键安装（推荐）

双击 `setup.bat`，自动下载并安装所有依赖到 `tools/`：

- Node.js v22.14.0
- Python 3.12.8（含 pip）
- Git (PortableGit)
- CCswitch（从 GitHub 获取最新版）
- claude-code CLI（预装到便携 Node）

已安装的工具会自动跳过，可重复运行。

### 手动安装

1. **Node.js**：从 https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip 下载解压到 `tools/node-v22.14.0-win-x64/`
2. **预装 claude**：在该目录下执行 `npm.cmd install -g @anthropic-ai/claude-code`
3. **Python**：官网完整版，解压/复制到 `tools/python-full/`
4. **Git**：官网 Git，复制到 `tools/git-full/`
5. **CCswitch**：安装后把程序目录复制到 `tools/ccswitch/`

## 使用

1. 双击 `启动.bat`
2. 输入 `claude`

## 中转 API 配置

配置走标准位置 `~/.claude/settings.json`，由 CCswitch 管理。

- 已配置的电脑：直接用，`claude` 自动读取。
- 首次 / 换新电脑：启动后运行 `cc-switch` 配置一次中转地址和密钥。

> 注意：`~/.claude/settings.json` 在用户目录、不在本文件夹，所以换电脑不跟着走，需重新配一次。**该文件含明文密钥，切勿提交或外传。**

## 许可证

本项目采用 [GPL v3](LICENSE) 许可证。
