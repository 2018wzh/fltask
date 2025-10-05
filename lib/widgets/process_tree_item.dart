import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../src/rust/api/simple.dart';

class ProcessTreeItem extends StatefulWidget {
  final ProcessInfo process;
  final List<ProcessInfo> children;
  final Map<int, List<ProcessInfo>> childrenMap;
  final VoidCallback onKill;
  final int level;

  const ProcessTreeItem({
    super.key,
    required this.process,
    required this.children,
    required this.childrenMap,
    required this.onKill,
    required this.level,
  });

  @override
  State<ProcessTreeItem> createState() => _ProcessTreeItemState();
}

class _ProcessTreeItemState extends State<ProcessTreeItem> {
  bool _isExpanded = false;

  String _formatBytes(BigInt bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var suffixIndex = 0;

    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }

    return '${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  Color _getCpuUsageColor(double cpuUsage) {
    if (cpuUsage > 50) return Colors.red;
    if (cpuUsage > 25) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasChildren = widget.children.isNotEmpty;
    final indent = widget.level * 24.0;

    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(
            left: 8 + indent,
            right: 8,
            top: 4,
            bottom: 4,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasChildren
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 展开/折叠图标
                  SizedBox(
                    width: 24,
                    child: hasChildren
                        ? Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          )
                        : Icon(
                            MdiIcons.circle,
                            size: 8,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                  ),

                  const SizedBox(width: 8),

                  // 进程图标
                  Icon(
                    MdiIcons.application,
                    size: 18,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(width: 8),

                  // 进程信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 进程名和PID
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.process.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'PID: ${widget.process.pid}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // 资源使用情况
                        Row(
                          children: [
                            // CPU使用率
                            Icon(
                              MdiIcons.memory,
                              size: 12,
                              color: _getCpuUsageColor(widget.process.cpuUsage),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.process.cpuUsage.toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getCpuUsageColor(
                                  widget.process.cpuUsage,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(width: 16),

                            // 内存使用
                            Icon(
                              MdiIcons.memory,
                              size: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatBytes(widget.process.memoryUsage),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),

                            const Spacer(),

                            // 状态
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: widget.process.status == 'Running'
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.process.status,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: widget.process.status == 'Running'
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 结束进程按钮
                  IconButton(
                    onPressed: widget.onKill,
                    icon: Icon(MdiIcons.close, color: Colors.red, size: 18),
                    tooltip: '结束进程',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 子进程
        if (_isExpanded && hasChildren)
          ...widget.children.map(
            (childProcess) => ProcessTreeItem(
              process: childProcess,
              children: widget.childrenMap[childProcess.pid] ?? [],
              childrenMap: widget.childrenMap,
              onKill: () => widget.onKill(),
              level: widget.level + 1,
            ),
          ),
      ],
    );
  }
}
