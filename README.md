# DeepTutor for Mac — Swift 原生桌面版

面向 Apple Silicon Mac 的非官方桌面启动器。使用系统 AppKit + WebKit，不需要 Electron，不需要 npm 下载 Electron。首次启动仍需安装 HKUDS 官方 DeepTutor Python 核心，DeepTutor 的网页前端由其自身 Node.js 服务运行，但你日常使用时无需打开浏览器。

> **测试版 / Beta：** 这是社区项目，不是 HKUDS 官方发行版。源码经过静态检查，但仍在真实 Apple Silicon Mac 上调试；请勿将其当作已全面验证的稳定安装包。欢迎提交可复现的编译错误与启动日志（提交前请删除 API Key、个人路径及隐私信息）。

## 1. 准备工具（只做一次）

打开 Mac 终端执行：

```bash
brew install python@3.12 node
xcode-select --install
```

如果提示 Command Line Tools 已安装，可以忽略。验证 `swiftc --version` 可以输出版本。

## 2. 一键构建

推荐从 GitHub 克隆源码：

```bash
git clone https://github.com/mohen36/deeptutor-for-mac.git
cd deeptutor-for-mac
zsh build.command
```

如果使用此前下载的 ZIP，则解压后进入包含 `build.command` 的目录，再执行 `zsh build.command`。

构建完成后自动打开 `dist`，其中有新生成的 `DeepTutor for Mac Fixed.app`。将**这个新版**拖入「应用程序」文件夹。旧版的 `DeepTutor for Mac.app` 是之前编译失败遗留的空应用，不要使用。启动前应确保没有旧版本 DeepTutor 占用 `3782`、`8001` 端口。

这版使用本机临时自签名（ad-hoc code signing），未经过 Apple 公证。首次启动如被 Gatekeeper 拦截，请在确认是自己刚构建的应用后，使用 Finder 右键「打开」，或到系统设置的「隐私与安全性」批准。不要全局禁用 Gatekeeper。

## 3. 首次启动

1. 打开 App，点击「安装 / 更新核心」。
2. 等待 Python 包从 PyPI 下载并完成初始化（可能需要数分钟）。
3. 应用会启动 DeepTutor 本地前后端并显示学习界面。
4. 进入「设置 → Models & services」，配置模型提供商、模型名称及 API Key。API Key 只填写在你本机 App 设置中，不要发送给聊天助手。

应用数据保存在 `~/Library/Application Support/DeepTutor-for-Mac/runtime/data/`。请勿删除。首次安装的 Python 环境在相邻的 `.venv` 下。更新桌面 App 不会主动清除你的知识库和学习记录。

## 4. 限制与排错

- Swift 是原生 Mac 外壳，里面的 DeepTutor 界面仍来自本地 WebKit 页面。Python 和 Node.js 是核心运行前提，首次安装需要联网。
- 如果出现端口冲突，可在终端执行 `lsof -i :3782` 和 `lsof -i :8001`，查看占用进程。请先正常退出旧进程，避免关闭其他无关服务。
- 云端模型 API 可能单独计费。没有配置模型时，应用可能正常显示，但 AI 对话不会工作。
- 官方 DeepTutor 当前有自己的网络监听策略；使用 macOS 防火墙或 DeepTutor 设置，确保 `8001`、`3782` 不向不受信任的网络暴露。
- 尚未在真实 macOS 上编译及执行验证。如果出现 Swift 编译报错，请复制终端最后 30 行反馈。

## 项目归属

这是独立社区启动器，并非 HKUDS 官方产品。DeepTutor 由 HKUDS 开发，见 https://github.com/HKUDS/DeepTutor。启动器仅通过 PyPI 安装官方核心，不包含或修改其源码。

此启动器代码以 MIT License 发布，详见 `LICENSE`；DeepTutor 本身遵循其自己的开源许可证。
