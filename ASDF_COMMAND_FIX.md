# ASDF 命令格式修复

## 问题描述
在版本选择界面刷新版本时，会显示 asdf 的命令帮助信息而不是实际的版本号列表。

## 根本原因
新版本的 asdf (v0.18.0) 改变了命令语法：
- 旧语法：`asdf list-all <plugin>`
- 新语法：`asdf list all <plugin>`

使用旧语法会导致 asdf 输出帮助信息而不是版本列表。

## 修复内容

### 1. VersionManager.swift
- 修复 `executeVersionCommand` 方法中的命令语法
- 将所有 `asdf list-all` 改为 `asdf list all`
- 修复参数处理逻辑

### 2. ProfileEditorView.swift 
- 修复 `loadAvailableVersions` 方法中的命令语法
- 将 `asdf list-all` 改为 `asdf list all`

### 3. EnvironmentEditorView.swift
- 修复 `loadAvailableVersions` 方法中的命令语法  
- 将 `asdf list-all` 改为 `asdf list all`

### 4. Installers.swift
- 修复 `listVersions` 方法中的命令语法
- 将 `asdf list-all` 改为 `asdf list all`

## 测试验证
```bash
# 修复前（会显示帮助信息）
asdf list-all nodejs

# 修复后（正常显示版本列表）
asdf list all nodejs
```

## 影响范围
- 所有版本选择下拉菜单
- 版本刷新功能
- 自动版本检测功能

## 结果
现在所有版本选择界面都能正确显示版本号列表，不再出现 asdf 命令帮助信息。