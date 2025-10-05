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

  Color _getMemoryUsageColor(BigInt memoryUsage) {
    final megabytes = memoryUsage / BigInt.from(1024 * 1024);
    if (megabytes > 512) return Colors.red;
    if (megabytes > 256) return Colors.orange;
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
            top: 2,
            bottom: 2,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasChildren
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          _ProcessDetailsDialog(process: widget.process),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),

                  // 进程名
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.process.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // PID
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${widget.process.pid}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // CPU使用率
                  SizedBox(
                    width: 70,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          MdiIcons.cpu64Bit,
                          size: 14,
                          color: _getCpuUsageColor(widget.process.cpuUsage),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.process.cpuUsage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getCpuUsageColor(widget.process.cpuUsage),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 内存使用
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          MdiIcons.memory,
                          size: 14,
                          color: _getMemoryUsageColor(
                            widget.process.memoryUsage,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatBytes(widget.process.memoryUsage),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getMemoryUsageColor(
                              widget.process.memoryUsage,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 状态
                  SizedBox(
                    width: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.process.status == 'Running'
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.process.status == 'Running' ? '运行' : '停止',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.process.status == 'Running'
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
                    padding: EdgeInsets.zero,
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

class _ProcessDetailsDialog extends StatelessWidget {
  final ProcessInfo process;

  const _ProcessDetailsDialog({required this.process});

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

  Color _getMemoryUsageColor(BigInt memoryUsage) {
    final mb = memoryUsage.toDouble() / (1024 * 1024);
    if (mb > 500) return Colors.red;
    if (mb > 100) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进程名和PID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    process.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'PID: ${process.pid}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 资源使用情况
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // CPU使用率
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CPU使用率',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            MdiIcons.cpu64Bit,
                            size: 14,
                            color: _getCpuUsageColor(process.cpuUsage),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${process.cpuUsage.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getCpuUsageColor(process.cpuUsage),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 内存使用
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '内存使用',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            MdiIcons.memory,
                            size: 14,
                            color: _getMemoryUsageColor(process.memoryUsage),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatBytes(process.memoryUsage),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getMemoryUsageColor(process.memoryUsage),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 状态
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: process.status == 'Running'
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                process.status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: process.status == 'Running'
                      ? Colors.green
                      : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
