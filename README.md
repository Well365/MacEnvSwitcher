
# MacEnvSwitcher v4 – Profiles 可视化编辑器 + 组 + 导入/导出 + 团队同步

功能：

- 体检与安装：Xcode/CLT、Homebrew、iTerm2、oh-my-zsh、Python3、Ruby、fastlane、asdf。
- 多版本管理（asdf）：Node.js、pnpm、yarn、Go、Java、Maven、Gradle、Python、Rust（+ 可选 jabba）。
- Profiles（版本矩阵）：Android / Go / Fullstack Node / Signer Node 内置预设。
- Profile 组：Android Team、Go Team、Fullstack Team、Signer/矿工节点。
- 可视化编辑器：增删改查插件与版本、导入/导出 JSON。
- 团队同步：选择一个同步文件夹（可放在 Dropbox/Google Drive/git 工作树），一键 Pull/Push。

文件：

- `~/.mac-bootstrap/profiles.json`
- `~/.mac-bootstrap/groups.json`
- 同步文件夹中也会生成以上两个文件。

第一阶段：启动检查和设置向导 (SetupWizardView.swift)
✅ 应用启动时自动检查必需工具
✅ 按优先级检查：Xcode → Command Line Tools → Homebrew → Oh My Zsh → asdf
✅ 每个工具显示状态、详细日志和安装提示
✅ 提供一键安装和手动安装步骤
✅ 所有工具安装完成后才能继续使用
✅ 可在设置中选择是否每次启动时检查
第二阶段：语言版本管理

✅ 统一的语言管理界面，所有语言集中显示
✅ 左侧语言列表：Node.js、Python、Ruby、Java、Go、Rust
✅ 右侧详细信息：
当前全局版本显示
已安装版本列表（可设为全局、可卸载）
安装新版本（下拉选择 or 手动输入）
实时安装日志显示
✅ 每个语言独立管理，互不干扰

MacEnvSwitcher/
├── MacEnvSwitcherApp.swift      (主应用 - 启动检查逻辑)
├── SetupWizardView.swift        (设置向导 - 新文件)
├── LanguageManagementView.swift (语言管理 - 新文件)
├── EnvironmentManagerView.swift (环境配置 - 保留)
├── Detectors.swift              (检测器 - 已增强)
├── Installers.swift             (安装器 - 已增强)
├── Profiles.swift               (配置管理 - 已增强)
├── Switcher.swift               (环境切换器 - 新增)
└── ConflictResolver.swift       (冲突解决器 - 新增)