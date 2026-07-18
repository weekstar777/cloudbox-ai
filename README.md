# cloudbox-ai

云端 AI 工具便携环境合集（Windows）。

## 目录结构

```
cloudbox-ai/
├── setup.bat             一键安装所有依赖（双击）
├── setup.ps1             安装核心逻辑
├── README.md
├── LICENSE               GPL v3
├── .gitignore
│
├── cladue_code/          Claude Code 便携环境
│   ├── 启动.bat          启动 Claude Code（双击）
│   └── tools/            （自动安装，不入库）
│       ├── node-v22.14.0-win-x64/   Node.js + claude CLI
│       ├── python-full/             Python 完整版
│       ├── git-full/                Git 完整版
│       └── ccswitch/                CCswitch
│
├── gemini/               （预留）
└── codex/                （预留）
```

## 快速开始

### 1. 安装依赖

双击 `setup.bat`，自动下载并安装到 `cladue_code/tools/`：

- Node.js v22.14.0
- Python 3.12.8（含 pip）
- Git (PortableGit)
- CCswitch（从 GitHub 获取最新版）
- claude-code CLI（预装到便携 Node）

已安装的工具自动跳过，可重复运行。

### 2. 配置中转 API

进入 `cladue_code/`，双击 `启动.bat`，在打开的命令行中运行：

```
cc-switch
```

用 CCswitch 配置中转地址和密钥（写入 `~/.claude/settings.json`）。

> 注意：配置在用户目录，换电脑需重新配一次。**该文件含明文密钥，切勿外传。**

### 3. 使用

双击 `cladue_code/启动.bat`，输入 `claude`。

## 手动安装（可选）

1. **Node.js**：https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip → 解压到 `cladue_code/tools/node-v22.14.0-win-x64/`
2. **预装 claude**：在该目录下执行 `npm.cmd install -g @anthropic-ai/claude-code`
3. **Python**：官网完整版 → `cladue_code/tools/python-full/`
4. **Git**：官网 Git → `cladue_code/tools/git-full/`
5. **CCswitch**：从 [GitHub releases](https://github.com/farion1231/cc-switch/releases) 下载 Windows Portable → `cladue_code/tools/ccswitch/`

## 许可证

本项目采用 [GPL v3](LICENSE) 许可证。
