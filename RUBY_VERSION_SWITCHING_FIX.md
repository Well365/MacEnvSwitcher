# Ruby 版本切换问题修复

## 问题描述

当从一个配置（如 3.3.8）切换到另一个配置（如 2.7.6）时，在 iTerm2 中运行 `ruby -v` 仍然显示原来系统的版本，而不是配置环境切换后的版本。这与错误提示 `rbenv: version '2.7.6' not installed` 有关。

## 根本原因

1. **版本未安装**: 目标 Ruby 版本（如 2.7.6）实际上没有通过 asdf 安装在系统中
2. **配置未生效**: 虽然配置文件已更新，但shell环境没有正确重新加载
3. **rbenv 冲突**: 系统可能同时安装了 rbenv 和 asdf，导致版本管理冲突

## 解决方案

### 🔧 **1. 自动版本检查和安装**

现在环境切换时会：
- ✅ **检查版本是否已安装** - 在设置全局版本前先检查
- ✅ **自动安装缺失版本** - 如果版本不存在，自动执行 `asdf install`
- ✅ **详细的安装日志** - 显示安装过程和结果
- ✅ **智能错误处理** - 如果安装失败，提供具体的错误信息和建议

### 🔄 **2. 增强的环境重载**

新增了专门的 Ruby 环境重载逻辑：

#### Shell 环境重载
```bash
source $(brew --prefix asdf)/libexec/asdf.sh
source ~/.zshrc
```

#### Ruby 特定检查
- 检测 rbenv 冲突
- 验证 asdf 当前设置
- 直接测试 `ruby -v` 输出
- 提供针对性的故障排除提示

### 🖥️ **3. iTerm2 集成增强**

如果 iTerm2 正在运行，会自动：
- 发送环境切换通知到当前窗口
- 显示预期的版本配置
- 执行验证命令（`ruby -v`, `python --version`, `node --version`）
- 提供故障排除提示

### 📝 **4. 详细的验证和日志**

环境切换后会进行全面验证：
- ✅ 检查 asdf 全局设置是否正确
- ✅ 验证实际命令输出是否匹配预期版本
- ✅ 识别 rbenv/asdf 冲突问题
- ✅ 提供具体的解决建议

## 使用步骤

### 1. 正常切换环境
在应用中选择目标环境配置，点击"切换激活"。

### 2. 查看详细日志
在 asdf 区域查看切换日志，包括：
- 版本安装状态
- 环境重载结果
- Ruby 特定检查结果
- 验证命令输出

### 3. 处理常见问题

#### 如果版本安装失败：
```bash
# 手动检查可用版本
asdf list all ruby

# 手动安装特定版本
asdf install ruby 2.7.6
```

#### 如果仍显示旧版本：
1. **打开新终端标签页** - 这是最简单的解决方案
2. **手动重载配置**:
   ```bash
   source ~/.zshrc
   ```
3. **检查 PATH 设置**:
   ```bash
   which ruby
   ```

#### 如果存在 rbenv 冲突：
1. **禁用 rbenv** (推荐):
   ```bash
   # 在 ~/.zshrc 中注释掉 rbenv 相关行
   # eval "$(rbenv init -)"
   ```
2. **或者完全使用 asdf**:
   ```bash
   # 卸载 rbenv，只使用 asdf 管理 Ruby
   ```

## 新增的日志输出

现在您会看到类似这样的详细日志：

```
[Profile] Frontend Development

[ruby] Checking version 2.7.6
⚠️ Version 2.7.6 not installed, installing...
✅ Successfully installed ruby 2.7.6
[ruby] Set global to 2.7.6 -> code=0
✅ Successfully set ruby global version to 2.7.6

[Reload System Configuration]
[Reload Shell Environment]
Source asdf: ✅
Source .zshrc: ✅

[Ruby Environment Reload]
Current asdf ruby: 2.7.6
Direct ruby -v: ruby 2.7.6p221
✅ Ruby version correctly switched to 2.7.6

[Update Terminal Profile]
✅ Sent environment verification commands to iTerm2
```

## 故障排除

### 常见问题

1. **"rbenv: version not installed"**
   - 解决：禁用 rbenv 或使用 asdf 安装该版本

2. **"ruby -v 还是显示旧版本"**
   - 解决：打开新终端标签页或运行 `source ~/.zshrc`

3. **"版本安装失败"**
   - 解决：检查网络连接，或手动安装该版本

### 检查命令

```bash
# 检查 asdf 状态
asdf current ruby

# 检查实际 Ruby 版本
ruby -v

# 检查 Ruby 路径
which ruby

# 重新加载配置
source ~/.zshrc
```

现在 Ruby 版本切换应该更加可靠和用户友好！如果遇到问题，详细的日志会帮助您快速诊断和解决。