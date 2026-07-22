# cloudbox-ai

云端 AI 工具便携环境合集（Windows）。

通过云盘同步，实现多台电脑共享 AI 工具配置，开箱即用。

## 系统要求

- Windows 10 / 11（64 位）
- 网络连接（首次安装需下载依赖）
- 管理员权限（CCswitch MSI 安装需要）
- 云盘同步工具（如百度网盘，可选，用于多设备同步）

## 目录结构

```
cloudbox-ai/
├── setup.bat             一键安装所有依赖 + 配置环境变量（双击）
├── setup.ps1             安装核心逻辑
├── cleanup.bat           离机清痕（双击）
├── cleanup.ps1           清理核心逻辑
├── 启动.bat              启动便携环境（Launch.bat）
├── README.md
├── LICENSE               GPL v3
├── .gitignore
│
├── tools/                （自动安装，不入库）
│   ├── node-v22.14.0-win-x64/   Node.js + claude CLI
│   ├── python-full/             Python 完整版
│   ├── git-full/                Git (PortableGit)
│   └── CCswitch/                CCswitch（正规 MSI 安装后复制到此目录）
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

以管理员身份双击 `setup.bat`，自动完成以下操作：

**下载并安装到 `tools/`：**

- Node.js v22.14.0（便携 zip）
- Python 3.12.8（含 pip）
- Git (PortableGit 2.47.1)
- CCswitch（从 GitHub 获取最新 MSI，正规安装后将程序复制到 `tools/CCswitch/`）
- claude-code CLI（预装到便携 Node）

**配置用户级环境变量：**

- `CLAUDE_CONFIG_DIR` → `configs\.claude`
- 将便携 Node.js 路径加入用户 `PATH`
- 其他工具的配置目录由 CCswitch 管理

已安装的工具自动跳过，可重复运行。换机器后重新运行即可自动配置。

> **检查更新**：再次运行 `setup.bat` 时，CCswitch 和 claude-code 会自动比对版本，有新版则更新。Node.js、Python、Git 为便携版，保持已安装不变。

> **关于 CCswitch 的安装方式**：该 MSI 由 Tauri/WiX 打包，安装目录被写死为 `%LOCALAPPDATA%\Programs\CC Switch`，命令行无法改。为了把程序统一放进 `tools/CCswitch/`，`setup.bat` 会先正规安装（保留开始菜单快捷方式，指向 `tools/CCswitch`），再把程序文件复制到 `tools/CCswitch/`，最后删除 `%LOCALAPPDATA%` 里的原目录。安装用的 MSI 下载到临时目录，装完即删，不占用项目空间。
>
> ⚠️ 由于原安装目录已被删除，**控制面板 → 程序和功能里的“CC Switch”卸载项已失效**（指向不存在的路径）。要卸载 CCswitch，直接删除 `tools/CCswitch/` 文件夹即可。

### 2. 配置 CCswitch

打开 CCswitch → 设置 → 高级 → **配置文件目录**，将各工具的配置目录指向 `configs/` 子目录：

| 配置项 | 路径 |
|--------|------|
| CC Switch 配置目录 | `<本项目路径>\configs\.cc-switch` |
| Claude Code 配置目录 | `<本项目路径>\configs\.claude` |
| Codex 配置目录 | `<本项目路径>\configs\.codex` |
| Gemini 配置目录 | `<本项目路径>\configs\.gemini` |
| OpenCode 配置目录 | `<本项目路径>\configs\opencode` |
| OpenClaw 配置目录 | `<本项目路径>\configs\.openclaw` |
| Hermes 配置目录 | `<本项目路径>\configs\.hermes` |

> `CLAUDE_CONFIG_DIR` 已由 `setup.bat` 自动设置，其他工具的配置目录由 CCswitch 管理。

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

## 换机器

在新机器上：

1. 将 `cloudbox-ai` 文件夹复制过去（或通过云盘同步）
2. 以管理员身份双击 `setup.bat` → 自动安装依赖 + 配置环境变量
3. 打开 CCswitch → 在设置中确认配置目录

在旧机器上（可选）：

4. 双击 `cleanup.bat` → 清除本机环境变量、PATH

## 离机清痕

双击 `cleanup.bat`，一键清除本机所有 cloudbox-ai 相关痕迹：

- 用户级环境变量（`CLAUDE_CONFIG_DIR`）
- 用户/系统 `PATH` 中的 cloudbox-ai 条目（系统 PATH 需管理员权限）

> 仅清理环境变量和 PATH，不卸载程序、不删除任何文件。如需彻底清除，手动删除 cloudbox-ai 文件夹即可。

## 云盘同步

将本项目放在云盘同步文件夹中（如百度网盘），`configs/` 目录中的配置即可自动同步到所有设备。

同步内容包括：API 密钥、工具配置、Claude Code 的项目配置和记忆等。

## 手动安装（可选）

1. **Node.js**：https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip → 解压到 `tools/node-v22.14.0-win-x64/`
2. **预装 claude**：在该目录下执行 `npm.cmd install -g @anthropic-ai/claude-code`
3. **Python**：https://www.nuget.org/api/v2/package/python/3.12.8 → 解压到 `tools/python-full/`
4. **Git**：https://github.com/git-for-windows/git/releases → 下载 PortableGit → 解压到 `tools/git-full/`
5. **CCswitch**：从 [GitHub releases](https://github.com/farion1231/cc-switch/releases) 下载 Windows MSI → 双击正常安装（默认装到 `%LOCALAPPDATA%\Programs\CC Switch`）→ 将安装目录内的文件复制到 `tools/CCswitch/`（该 MSI 的安装目录写死，无法直接指定）

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| `setup.bat` 连接 GitHub 失败 | 检查网络连接，可能需要代理或重试 |
| CCswitch MSI 安装 1603/1612 错误 | 通常是旧安装残留的注册表记录导致；`setup.bat` 会自动清理并重试。若仍失败，先重启电脑（清挂起重启）再运行 |
| CCswitch 装完 `tools/CCswitch/` 里没有 exe | 旧版残留触发了空安装，重新运行 `setup.bat` 即可（已内置自愈） |
| 控制面板无法卸载 CCswitch | 属正常现象，直接删除 `tools/CCswitch/` 文件夹即可 |
| `cleanup.bat` 无法清理系统 PATH | 需要以管理员身份运行 |
| `启动.bat` 报错工具未安装 | 先运行 `setup.bat` 安装依赖 |

## 许可证

本项目采用 [GPL v3](LICENSE) 许可证。
