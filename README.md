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

### 数据结构
```rust
// 进程信息
struct ProcessInfo {
    pid: u32,
    name: String,
    cpu_usage: f64,
    memory_usage: u64,
    parent_pid: Option<u32>,
    status: String,
    command: String,
    start_time: u64,
}

// 系统资源信息
struct SystemResourceInfo {
    cpu_usage: f64,
    memory_total: u64,
    memory_used: u64,
    memory_available: u64,
    disk_usage: Vec<DiskInfo>,
    network_usage: NetworkInfo,
}

// 系统信息
struct SystemInfo {
    os_name: String,
    os_version: String,
    kernel_version: String,
    hostname: String,
    cpu_brand: String,
    cpu_cores: u32,
    total_memory: u64,
    boot_time: u64,
    uptime: u64,
}
```

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── screens/                     # 页面文件
│   ├── task_manager_screen.dart # 主界面 (包含标签页)
│   ├── processes_page.dart      # 进程页面
│   ├── charts_page.dart         # 图表页面
│   └── system_info_page.dart    # 系统信息页面
├── widgets/                     # 自定义组件
│   ├── process_list_item.dart   # 进程列表项
│   └── process_tree_item.dart   # 进程树节点
└── src/rust/                    # Rust 桥接代码 (自动生成)
    └── api/
        └── simple.dart          # API 接口

rust/
└── src/
    └── api/
        └── simple.rs            # Rust 实现
```

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
- ✅ Web
- ✅ iOS (需要额外配置)
- ✅ Android (需要额外配置)

## 主要依赖

### Flutter 依赖
- `flutter`: Flutter 核心框架
- `provider`: 状态管理
- `fl_chart`: 图表绘制
- `material_design_icons_flutter`: Material Design 图标
- `flutter_rust_bridge`: Rust 桥接

### Rust 依赖
- 待实现: 实际的系统监控库 (如 `sysinfo`)

## 开发计划

### 当前状态
- ✅ 完整的 UI 界面设计
- ✅ 基础的 Rust 接口结构
- ✅ 模拟数据展示
- ✅ 跨平台支持

### 待实现功能
- [ ] 实际的系统数据获取 (替换模拟数据)
- [ ] 进程管理功能 (暂停、恢复等)
- [ ] 性能历史记录
- [ ] 系统服务管理
- [ ] 启动项管理
- [ ] 资源使用告警
- [ ] 导出功能 (性能报告、进程列表等)

## 界面预览

应用包含以下主要界面：

1. **进程管理界面**: 现代化的进程列表和树状视图
2. **性能监控界面**: 实时图表显示系统资源使用情况
3. **系统信息界面**: 详细的硬件和系统信息展示

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
