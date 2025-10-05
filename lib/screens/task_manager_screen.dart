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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 标签栏
                  TabBar(
                    controller: _tabController,
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
