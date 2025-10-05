import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../src/rust/api/simple.dart';

class ProcessListItem extends StatelessWidget {
  final ProcessInfo process;
  final VoidCallback onKill;

  const ProcessListItem({
    super.key,
    required this.process,
    required this.onKill,
  });

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _ProcessDetailsDialog(process: process),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进程名和PID
              Row(
                children: [
                  Icon(
                    MdiIcons.application,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      process.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'PID: ${process.pid}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  IconButton(
                    onPressed: onKill,
                    icon: Icon(MdiIcons.close, color: Colors.red, size: 20),
                    tooltip: '结束进程',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 资源使用情况
              Row(
                children: [
                  // CPU使用率
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          MdiIcons.memory,
                          size: 16,
                          color: _getCpuUsageColor(process.cpuUsage),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CPU: ${process.cpuUsage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getCpuUsageColor(process.cpuUsage),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 内存使用
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          MdiIcons.memory,
                          size: 16,
                          color: _getMemoryUsageColor(process.memoryUsage),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '内存: ${_formatBytes(process.memoryUsage)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getMemoryUsageColor(process.memoryUsage),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 状态
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: process.status == 'Running'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      process.status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: process.status == 'Running'
                            ? Colors.green
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // 命令行
              Text(
                process.command,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
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

    return '${value.toStringAsFixed(2)} ${suffixes[suffixIndex]}';
  }

  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return '未知';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            MdiIcons.information,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('进程详细信息', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('进程名称', process.name),
              _buildDetailRow('进程ID', '${process.pid}'),
              _buildDetailRow('父进程ID', process.parentPid?.toString() ?? '无'),
              _buildDetailRow('状态', process.status),
              _buildDetailRow(
                'CPU使用率',
                '${process.cpuUsage.toStringAsFixed(2)}%',
              ),
              _buildDetailRow('内存使用', _formatBytes(process.memoryUsage)),
              _buildDetailRow('启动时间', _formatTimestamp(process.startTime)),
              _buildDetailRow('命令行', process.command),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
