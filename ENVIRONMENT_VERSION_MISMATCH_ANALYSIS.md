# 环境版本不匹配问题分析

## 问题描述

当切换环境配置后，`.tool-versions` 文件已更新，但在终端中执行 `java -version` 和 `ruby -v` 时显示的版本与 `.tool-versions` 中指定的版本不一致。

## 根本原因分析

### 1. Java 版本问题

**现象：**
- `.tool-versions` 中指定：`java 11.0.21`
- 终端显示：`No version is set for command java`

**原因：**
1. **版本未安装**：`asdf list java` 显示只安装了 `temurin-17.0.17+10`，没有 `11.0.21`
2. **asdf 未管理 Java**：Java 可能通过其他方式安装（如 Homebrew 或直接安装），而不是通过 asdf
3. **配置冲突**：`.zshrc` 中的 `use_java` 函数可能与 asdf 的配置冲突

**解决方案：**
- 如果使用 asdf 管理 Java，需要先安装指定版本：`asdf install java 11.0.21`
- 如果不使用 asdf 管理 Java，应该通过环境变量 `JAVA_HOME` 来设置（已在 profile 的 `environmentVars` 中配置）

### 2. Ruby 版本问题

**现象：**
- `.tool-versions` 中指定：`ruby 3.3.8`
- 终端显示：`ruby 3.4.5`
- `asdf current ruby` 显示：`2.7.6`（来自项目目录的 `.tool-versions`）

**原因：**
1. **项目目录优先级**：asdf 优先读取项目目录的 `.tool-versions` 文件，而不是全局的 `~/.tool-versions`
   - 当前在 `~/Documents/idears/MacEnvSwitcher_v4/` 目录下
   - 该目录的 `.tool-versions` 指定了 `ruby 2.7.6`
2. **PATH 优先级问题**：`which ruby` 显示 `/opt/homebrew/opt/ruby/bin/ruby`
   - Homebrew 安装的 Ruby 在 PATH 中的优先级高于 asdf 的 shims
   - 导致即使 asdf 设置了版本，终端仍然使用 Homebrew 的 Ruby
3. **版本管理器冲突**：同时存在多个 Ruby 版本管理器：
   - asdf（管理多个版本）
   - Homebrew（安装了 3.4.5）
   - rbenv（可能在 `.zshrc` 中配置）

**解决方案：**
1. **确保 asdf shims 在 PATH 最前面**：在 `.zshrc` 中确保 asdf 的 shims 路径在 Homebrew 路径之前
2. **强制使用全局版本**：在 shell 配置中使用 `asdf export-shell-version` 来强制使用全局版本
3. **移除项目目录的 `.tool-versions`**：如果不需要项目特定的版本，可以删除项目目录的 `.tool-versions` 文件

## 已实施的修复

### 1. 改进 shell 配置更新逻辑

在 `Profiles.swift` 的 `updateShellProfileFiles` 方法中：

```swift
// 确保 asdf shims 在 PATH 最前面（优先级最高）
configSection += "# Ensure asdf shims have highest priority in PATH\n"
configSection += "if command -v asdf >/dev/null 2>&1; then\n"
configSection += "    export PATH=\"$(asdf where asdf)/shims:$PATH\"\n"
configSection += "fi\n\n"

// 强制设置全局版本，覆盖项目目录的 .tool-versions
configSection += "asdf global \(plugin) \"\(version)\" 2>/dev/null || true\n"
// 确保当前 shell 也使用全局版本
configSection += "eval \"$(asdf export-shell-version sh \(plugin) \(version))\" 2>/dev/null || true\n"
```

### 2. 版本检查和安装

在 `switchGlobalTool` 方法中：
- 检查插件是否已安装，如果没有则自动安装
- 检查版本是否已安装，如果没有则自动安装
- 设置全局版本前先确保版本存在

## 使用建议

### 切换环境后

1. **重新加载 shell 配置**：
   ```bash
   source ~/.zshrc
   ```

2. **或者重新打开终端窗口**：新打开的终端会自动加载新的配置

3. **验证版本**：
   ```bash
   # 检查 asdf 管理的版本
   asdf current
   
   # 检查实际使用的版本
   java -version
   ruby -v
   python --version
   node --version
   ```

### 如果版本仍然不匹配

1. **检查版本是否已安装**：
   ```bash
   asdf list java
   asdf list ruby
   ```

2. **安装缺失的版本**：
   ```bash
   asdf install java 11.0.21
   asdf install ruby 3.3.8
   ```

3. **检查项目目录的 `.tool-versions`**：
   ```bash
   cat .tool-versions  # 当前目录
   cat ~/.tool-versions  # 全局配置
   ```

4. **确保 asdf shims 在 PATH 最前面**：
   ```bash
   echo $PATH | grep asdf
   ```

## 未来改进建议

1. **自动安装缺失版本**：在切换环境时，自动检查并安装缺失的版本
2. **版本冲突检测**：检测多个版本管理器冲突，并给出警告
3. **项目级配置支持**：支持项目目录的 `.tool-versions`，但提供选项是否覆盖全局配置
4. **配置验证**：切换环境后自动验证版本是否正确设置

