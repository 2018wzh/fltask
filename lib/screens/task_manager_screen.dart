import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'processes_page.dart';
import 'charts_page.dart';
import 'system_info_page.dart';

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _refreshInterval = 1; // 默认1秒刷新间隔
  bool _autoRefreshEnabled = true; // 自动刷新开关

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRefreshIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动刷新设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择自动刷新时间间隔:'),
            const SizedBox(height: 16),
            ...([1, 2, 5, 10, 30].map(
              (seconds) => RadioListTile<int>(
                title: Text('${seconds}秒'),
                value: seconds,
                groupValue: _refreshInterval,
                onChanged: (value) {
                  setState(() {
                    _refreshInterval = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            )),
          ],
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
                  subtitle: const Text('跟随系统'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: 实现主题设置
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('主题设置功能待实现')));
                  },
                ),
                // 语言设置 (预留)
                ListTile(
                  leading: Icon(MdiIcons.translate),
                  title: const Text('语言'),
                  subtitle: const Text('简体中文'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: 实现语言设置
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('语言设置功能待实现')));
                  },
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
                                  // TODO: 实现自动刷新逻辑
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
              children: [ProcessesPage(), ChartsPage(), SystemInfoPage()],
            ),
          ),
        ],
      ),
    );
  }
}
