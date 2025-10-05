# FLTask - Flutter 任务管理器

一个使用 Flutter 和 Rust 构建的跨平台任务管理器应用，具有现代化的用户界面和强大的系统监控功能。

## 功能特性

### 🔄 三个主要标签页

#### 1. 进程页面 (Processes)
- **列表视图**: 显示所有运行中的进程
- **树状视图**: 以层次结构显示进程间的父子关系
- **功能特性**:
  - 搜索和筛选进程
  - 多种排序方式 (进程名、PID、CPU使用率、内存使用量)
  - 实时显示 CPU 和内存使用情况
  - 结束进程功能
  - 详细的进程信息对话框

#### 2. 图表页面 (Charts)
- **实时性能监控**:
  - CPU 使用率实时曲线图
  - 内存使用率实时曲线图
  - 磁盘使用情况显示
  - 网络统计信息
- **类似 Windows 任务管理器的图表界面**
- 自动更新 (每秒刷新)

#### 3. 系统信息页面 (System Info)
- **详细系统信息** (类似 macOS 系统信息):
  - 操作系统信息
  - 处理器详细信息
  - 内存规格和使用情况
  - 存储设备信息
  - 网络统计
  - 系统运行时间

## 技术架构

### 前端 (Flutter)
- **Material Design 3** 界面设计
- **响应式布局** 支持多种屏幕尺寸
- **实时数据更新** 和图表显示
- **深色/浅色主题** 自动适配

### 后端 (Rust)
- **跨平台系统 API** 接口设计
- **Flutter Rust Bridge** 实现无缝数据交互
- **预留接口结构** 支持未来扩展

## 安装和运行

### 前置要求
- Flutter SDK (>= 3.9.2)
- Rust (>= 1.90.0)
- flutter_rust_bridge_codegen

### 安装依赖
```bash
flutter pub get
```

### 重新生成 Rust 桥接代码 (如果修改了 Rust 代码)
```bash
flutter_rust_bridge_codegen generate
```

### 运行应用
```bash
flutter run
```

### 支持平台
- ✅ Windows
- ✅ macOS  
- ✅ Linux

## 贡献

欢迎提交 Issue 和 Pull Request！

## 作者

2018wzh

## 许可证

GNU General Public License v3.0 (GPL-3.0)
