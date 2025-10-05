import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'processes_page.dart';
import 'charts_page.dart';
import 'system_info_page.dart';

class TaskManagerScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const TaskManagerScreen({super.key, this.onThemeChanged});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _refreshInterval = 1; // 默认1秒刷新间隔
  bool _autoRefreshEnabled = true; // 自动刷新开关
  Timer? _refreshTimer;
  ThemeMode _themeMode = ThemeMode.system; // 主题模式
  bool _networkUnitIsBps = false; // 网络单位是否为bps

  // 刷新通知器 - 每个页面一个
  final ValueNotifier<int> _processesRefreshNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _chartsRefreshNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _systemInfoRefreshNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _processesRefreshNotifier.dispose();
    _chartsRefreshNotifier.dispose();
    _systemInfoRefreshNotifier.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    if (_autoRefreshEnabled) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshInterval),
        (timer) => _refreshCurrentTab(),
      );
    }
  }

  void _refreshCurrentTab() {
    if (!mounted) return;

    // 触发当前页面的刷新通知
    switch (_tabController.index) {
      case 0:
        _processesRefreshNotifier.value = _processesRefreshNotifier.value + 1;
        break;
      case 1:
        _chartsRefreshNotifier.value = _chartsRefreshNotifier.value + 1;
        break;
      case 2:
        _systemInfoRefreshNotifier.value = _systemInfoRefreshNotifier.value + 1;
        break;
    }
  }

  void _showRefreshIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动刷新设置'),
        content: RadioGroup<int>(
          groupValue: _refreshInterval,
          onChanged: (value) {
            setState(() {
              _refreshInterval = value!;
            });
            _saveSettings();
            _startRefreshTimer(); // 重新启动定时器以应用新的间隔
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择自动刷新时间间隔:'),
              const SizedBox(height: 16),
              ...([1, 2, 5, 10, 30].map(
                (seconds) => RadioListTile<int>(
                  title: Text('${seconds}秒'),
                  value: seconds,
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '任务管理器',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        MdiIcons.monitor,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const Text('一个使用 Flutter 和 Rust 构建的跨平台任务管理器应用。'),
        const SizedBox(height: 16),
        const Text('功能特性:'),
        const Text('• 进程管理和监控'),
        const Text('• 实时系统资源图表'),
        const Text('• 详细的系统信息'),
        const SizedBox(height: 16),
        Text('© 2025 2018wzh', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.cog, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('设置'),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 自动刷新设置分组
                Text(
                  '刷新设置',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 刷新间隔设置
                ListTile(
                  leading: Icon(MdiIcons.timerOutline),
                  title: const Text('刷新间隔'),
                  subtitle: Text('${_refreshInterval}秒'),
                  enabled: _autoRefreshEnabled,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _autoRefreshEnabled
                        ? null
                        : Theme.of(context).disabledColor,
                  ),
                  onTap: _autoRefreshEnabled
                      ? () {
                          Navigator.pop(context);
                          _showRefreshIntervalDialog();
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // 外观设置分组
                Text(
                  '外观',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 主题设置 (预留)
                ListTile(
                  leading: Icon(MdiIcons.palette),
                  title: const Text('主题'),
                  subtitle: Text(_getThemeModeText(_themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeDialog();
                  },
                ),
                // 网络单位设置
                SwitchListTile(
                  title: const Text('以 bps 显示网络速度'),
                  subtitle: const Text('关闭则以 B/s 为单位'),
                  value: _networkUnitIsBps,
                  onChanged: (value) {
                    setState(() {
                      _networkUnitIsBps = value;
                    });
                    // We need to call the parent setState to update the value
                    this.setState(() {
                      _networkUnitIsBps = value;
                    });
                    _saveSettings();
                  },
                  secondary: Icon(MdiIcons.speedometer),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主题设置'),
        content: RadioGroup<ThemeMode>(
          groupValue: _themeMode,
          onChanged: (value) {
            setState(() {
              _themeMode = value!;
            });
            widget.onThemeChanged?.call(value!);
            _saveSettings();
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择主题模式:'),
              const SizedBox(height: 16),
              ...[ThemeMode.system, ThemeMode.light, ThemeMode.dark].map(
                (mode) => RadioListTile<ThemeMode>(
                  title: Text(_getThemeModeText(mode)),
                  value: mode,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _refreshInterval = prefs.getInt('refreshInterval') ?? 1;
      _autoRefreshEnabled = prefs.getBool('autoRefreshEnabled') ?? true;
      final themeIndex =
          prefs.getInt('themeMode') ?? 0; // 0: system, 1: light, 2: dark
      _themeMode = ThemeMode.values[themeIndex];
      _networkUnitIsBps = prefs.getBool('networkUnitIsBps') ?? false;
    });
    _startRefreshTimer();
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('refreshInterval', _refreshInterval);
    await prefs.setBool('autoRefreshEnabled', _autoRefreshEnabled);
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setBool('networkUnitIsBps', _networkUnitIsBps);
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色主题';
      case ThemeMode.dark:
        return '深色主题';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用系统原生标题栏，不显示自定义AppBar
      body: Column(
        children: [
          // 系统标题栏区域（自动处理）
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // 左侧占位，用于平衡右侧菜单按钮
                  const SizedBox(width: 48),
                  // 居中的标签栏
                  Expanded(
                    child: Center(
                      child: IntrinsicWidth(
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.memory, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('进程'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.chartLine, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('图表'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.information, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('信息'),
                                ],
                              ),
                            ),
                          ],
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 右侧下拉菜单
                  PopupMenuButton<String>(
                    icon: Icon(
                      MdiIcons.dotsVertical,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    tooltip: '菜单',
                    onSelected: (value) {
                      switch (value) {
                        case 'settings':
                          _showSettingsDialog();
                          break;
                        case 'about':
                          _showAboutDialog();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      // 自动刷新开关
                      PopupMenuItem<String>(
                        enabled: false,
                        child: StatefulBuilder(
                          builder: (context, setState) => Row(
                            children: [
                              Icon(MdiIcons.refresh, size: 20),
                              const SizedBox(width: 12),
                              const Text('自动刷新'),
                              const Spacer(),
                              Switch(
                                value: _autoRefreshEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _autoRefreshEnabled = value;
                                  });
                                  this.setState(() {
                                    _autoRefreshEnabled = value;
                                  });
                                  _saveSettings();
                                  _startRefreshTimer(); // 重新启动或停止定时器
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(MdiIcons.cog, size: 20),
                            const SizedBox(width: 12),
                            const Text('设置'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'about',
                        child: Row(
                          children: [
                            Icon(MdiIcons.information, size: 20),
                            const SizedBox(width: 12),
                            const Text('关于'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 页面内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ProcessesPage(refreshNotifier: _processesRefreshNotifier),
                ChartsPage(
                  refreshNotifier: _chartsRefreshNotifier,
                  networkUnitIsBps: _networkUnitIsBps,
                  refreshInterval: _refreshInterval,
                ),
                SystemInfoPage(
                  refreshNotifier: _systemInfoRefreshNotifier,
                  networkUnitIsBps: _networkUnitIsBps,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
