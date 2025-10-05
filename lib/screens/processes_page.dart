import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../src/rust/api/simple.dart';
import '../widgets/process_list_item.dart';
import '../widgets/process_tree_item.dart';

class ProcessesPage extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ProcessesPage({super.key, this.refreshNotifier});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  List<ProcessInfo> _processes = [];
  bool _isTreeView = false;
  bool _isLoading = true;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _loadProcesses();
    widget.refreshNotifier?.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _loadProcesses();
  }

  void _loadProcesses() {
    setState(() {
      _isLoading = true;
    });

    try {
      final processes = getProcesses();
      setState(() {
        _processes = processes;
        _isLoading = false;
      });
      _sortProcesses();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载进程失败: $e')));
      }
    }
  }

  void _sortProcesses() {
    setState(() {
      _processes.sort((a, b) {
        int result = 0;
        switch (_sortBy) {
          case 'name':
            result = a.name.compareTo(b.name);
            break;
          case 'pid':
            result = a.pid.compareTo(b.pid);
            break;
          case 'cpu':
            result = a.cpuUsage.compareTo(b.cpuUsage);
            break;
          case 'memory':
            result = a.memoryUsage.compareTo(b.memoryUsage);
            break;
        }
        return _sortAscending ? result : -result;
      });
    });
  }

  List<ProcessInfo> get _filteredProcesses {
    if (_filterText.isEmpty) return _processes;
    return _processes
        .where(
          (process) =>
              process.name.toLowerCase().contains(_filterText.toLowerCase()) ||
              process.command.toLowerCase().contains(_filterText.toLowerCase()),
        )
        .toList();
  }

  void _killProcess(ProcessInfo process) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束进程'),
        content: Text('确定要结束进程 "${process.name}" (PID: ${process.pid}) 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final success = killProcess(pid: process.pid);
              if (success) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('进程已结束')));
                _loadProcesses();
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('结束进程失败')));
              }
            },
            child: const Text('结束'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortHeader(String title, String sortKey, IconData icon) {
    final isActive = _sortBy == sortKey;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortBy == sortKey) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = sortKey;
            _sortAscending = true;
          }
        });
        _sortProcesses();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void refresh() {
    _loadProcesses();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 搜索框和视图切换
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '搜索进程...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterText = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isTreeView = !_isTreeView;
                      });
                    },
                    icon: Icon(
                      _isTreeView ? MdiIcons.viewList : MdiIcons.fileTree,
                    ),
                    tooltip: _isTreeView ? '列表视图' : '树状视图',
                  ),
                  IconButton(
                    onPressed: _loadProcesses,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 排序选项
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSortHeader('进程名', 'name', MdiIcons.application),
                    const SizedBox(width: 16),
                    _buildSortHeader('PID', 'pid', MdiIcons.identifier),
                    const SizedBox(width: 16),
                    _buildSortHeader('CPU', 'cpu', MdiIcons.memory),
                    const SizedBox(width: 16),
                    _buildSortHeader('内存', 'memory', MdiIcons.memory),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 进程列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProcesses.isEmpty
              ? const Center(
                  child: Text('没有找到匹配的进程', style: TextStyle(fontSize: 16)),
                )
              : _isTreeView
              ? _buildTreeView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _filteredProcesses.length,
      itemBuilder: (context, index) {
        final process = _filteredProcesses[index];
        return ProcessListItem(
          process: process,
          onKill: () => _killProcess(process),
        );
      },
    );
  }

  Widget _buildTreeView() {
    // 构建进程树结构
    final Map<int, List<ProcessInfo>> childrenMap = {};
    final List<ProcessInfo> rootProcesses = [];

    for (final process in _filteredProcesses) {
      if (process.parentPid == null) {
        rootProcesses.add(process);
      } else {
        childrenMap.putIfAbsent(process.parentPid!, () => []).add(process);
      }
    }

    return ListView.builder(
      itemCount: rootProcesses.length,
      itemBuilder: (context, index) {
        final process = rootProcesses[index];
        return ProcessTreeItem(
          process: process,
          children: childrenMap[process.pid] ?? [],
          childrenMap: childrenMap,
          onKill: () => _killProcess(process),
          level: 0,
        );
      },
    );
  }
}
