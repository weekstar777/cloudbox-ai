# cloudbox-ai

云端 AI 工具便携环境合集（Windows）。

通过云盘同步，实现多台电脑共享 AI 工具配置，开箱即用。

## 系统要求

- Windows 10 / 11（64 位）
- 网络连接（首次安装需下载依赖）
- 云盘同步工具（如百度网盘，可选，用于多设备同步）

## 目录结构

```
cloudbox-ai/
├── setup.bat             一键安装所有依赖（双击）
├── setup.ps1             安装核心逻辑
├── 启动.bat              启动便携环境（双击）
├── README.md
├── LICENSE               GPL v3
├── .gitignore
│
├── tools/                （自动安装，不入库）
│   ├── node-v22.14.0-win-x64/   Node.js + claude CLI
│   ├── python-full/             Python 完整版
│   ├── git-full/                Git 完整版
│   └── ccswitch/                CCswitch
│
└── configs/              AI 工具配置（不入库，含密钥）
    ├── .cc-switch/              CCswitch 配置
    ├── .claude/                 Claude Code 配置
    ├── .codex/                  Codex 配置
    ├── .gemini/                 Gemini 配置
    ├── opencode/                OpenCode 配置
    ├── .openclaw/               OpenClaw 配置
    └── .hermes/                 Hermes 配置
```

## 快速开始

### 1. 安装依赖

双击 `setup.bat`，自动下载并安装到 `tools/`：

- Node.js v22.14.0
- Python 3.12.8（含 pip）
- Git (PortableGit 2.47.1)
- CCswitch（从 GitHub 获取最新版）
- claude-code CLI（预装到便携 Node）

已安装的工具自动跳过，可重复运行。

### 2. 配置目录（云同步）

打开 CCswitch → 设置 → 高级 → **配置文件目录**，将各工具的配置目录修改为本项目下的 `configs/` 子目录：

| 配置项 | 路径 |
|--------|------|
| CC Switch 配置目录 | `<本项目路径>\configs\.cc-switch` |
| Claude Code 配置目录 | `<本项目路径>\configs\.claude` |
| Codex 配置目录 | `<本项目路径>\configs\.codex` |
| Gemini 配置目录 | `<本项目路径>\configs\.gemini` |
| OpenCode 配置目录 | `<本项目路径>\configs\opencode` |
| OpenClaw 配置目录 | `<本项目路径>\configs\.openclaw` |
| Hermes 配置目录 | `<本项目路径>\configs\.hermes` |

> 将本项目放在云盘同步文件夹中（如百度网盘），配置即可自动同步到所有设备。换电脑后只需重新安装依赖 + 在 CCswitch 中重新指定目录即可。

### 3. 配置中转 API

双击 `启动.bat`，在打开的命令行中运行：

```
cc-switch
```

在 CCswitch 中配置中转地址和 API 密钥。

> ⚠️ **配置含明文密钥，切勿外传。** `configs/` 目录已在 `.gitignore` 中排除，不会被提交到 Git。

### 4. 使用

双击 `启动.bat`，输入 `claude` 即可开始使用。

其他可用命令：

```
claude      - Claude Code CLI
cc-switch   - CCswitch 配置工具
python      - Python 3.12.8
git         - Git 2.47.1
```

## 手动安装（可选）

1. **Node.js**：https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip → 解压到 `tools/node-v22.14.0-win-x64/`
2. **预装 claude**：在该目录下执行 `npm.cmd install -g @anthropic-ai/claude-code`
3. **Python**：https://www.nuget.org/api/v2/package/python/3.12.8 → 解压到 `tools/python-full/`
4. **Git**：PortableGit → `tools/git-full/`
5. **CCswitch**：从 [GitHub releases](https://github.com/farion1231/cc-switch/releases) 下载 Windows Portable → `tools/ccswitch/`

## 许可证

本项目采用 [GPL v3](LICENSE) 许可证。
