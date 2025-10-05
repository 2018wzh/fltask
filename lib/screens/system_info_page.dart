import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../src/rust/api/simple.dart';

class SystemInfoPage extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final bool networkUnitIsBps;

  const SystemInfoPage({
    super.key,
    this.refreshNotifier,
    this.networkUnitIsBps = false,
  });

  @override
  State<SystemInfoPage> createState() => _SystemInfoPageState();
}

class _SystemInfoPageState extends State<SystemInfoPage> {
  SystemInfo? _systemInfo;
  SystemResourceInfo? _systemResources;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    widget.refreshNotifier?.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _loadSystemInfo();
  }

  void _loadSystemInfo() {
    setState(() {
      _isLoading = true;
    });

    try {
      final info = getSystemInfo();
      final resources = getSystemResources();
      setState(() {
        _systemInfo = info;
        _systemResources = resources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载系统信息失败: $e')));
      }
    }
  }

  void refresh() {
    _loadSystemInfo();
  }

  String _formatBytes(BigInt bytes, {bool isRate = false}) {
    if (isRate && widget.networkUnitIsBps) {
      final bits = bytes * BigInt.from(8);
      const suffixes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
      var value = bits.toDouble();
      var suffixIndex = 0;
      while (value >= 1000 && suffixIndex < suffixes.length - 1) {
        value /= 1000;
        suffixIndex++;
      }
      return '${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
    }

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var suffixIndex = 0;

    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }

    return '${value.toStringAsFixed(2)} ${suffixes[suffixIndex]}${isRate ? '/s' : ''}';
  }

  String _formatUptime(BigInt uptimeSeconds) {
    final duration = Duration(seconds: uptimeSeconds.toInt());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days 天 $hours 小时 $minutes 分钟';
    } else if (hours > 0) {
      return '$hours 小时 $minutes 分钟';
    } else {
      return '$minutes 分钟';
    }
  }

  String _formatTimestamp(BigInt timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_systemInfo == null || _systemResources == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            const Text('无法加载系统信息'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSystemInfo, child: const Text('重试')),
          ],
        ),
      );
    }

    final info = _systemInfo!;
    final resources = _systemResources!;

    return RefreshIndicator(
      onRefresh: () async => _loadSystemInfo(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 系统概览
            _buildInfoCard(
              title: '系统概览',
              icon: MdiIcons.monitor,
              iconColor: Colors.blue,
              children: [
                _buildInfoRow('操作系统', info.osName, icon: MdiIcons.microsoft),
                _buildInfoRow('版本', info.osVersion, icon: MdiIcons.tagOutline),
                _buildInfoRow('内核版本', info.kernelVersion, icon: MdiIcons.cog),
                _buildInfoRow(
                  '主机名',
                  info.hostname,
                  icon: MdiIcons.desktopTower,
                ),
                _buildInfoRow(
                  '开机时间',
                  _formatTimestamp(info.bootTime),
                  icon: MdiIcons.clockOutline,
                ),
                _buildInfoRow(
                  '运行时间',
                  _formatUptime(info.uptime),
                  icon: MdiIcons.timerOutline,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 处理器信息
            _buildInfoCard(
              title: '处理器',
              icon: MdiIcons.memory,
              iconColor: Colors.orange,
              children: [
                _buildInfoRow('型号', info.cpuBrand, icon: MdiIcons.chip),
                _buildInfoRow(
                  '核心数',
                  '${info.cpuCores}',
                  icon: MdiIcons.viewList,
                ),
                _buildInfoRow(
                  '当前使用率',
                  '${resources.cpuUsage.toStringAsFixed(1)}%',
                  icon: MdiIcons.speedometer,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 内存信息
            _buildInfoCard(
              title: '内存',
              icon: MdiIcons.memory,
              iconColor: Colors.green,
              children: [
                _buildInfoRow(
                  '总内存',
                  _formatBytes(info.totalMemory),
                  icon: MdiIcons.memory,
                ),
                _buildInfoRow(
                  '已使用',
                  _formatBytes(resources.memoryUsed),
                  icon: MdiIcons.progressUpload,
                ),
                _buildInfoRow(
                  '可用',
                  _formatBytes(resources.memoryAvailable),
                  icon: MdiIcons.progressDownload,
                ),
                _buildInfoRow(
                  '使用率',
                  '${((resources.memoryUsed.toDouble() / resources.memoryTotal.toDouble()) * 100).toStringAsFixed(1)}%',
                  icon: MdiIcons.percent,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 存储信息
            if (resources.diskUsage.isNotEmpty)
              _buildInfoCard(
                title: '存储设备',
                icon: MdiIcons.harddisk,
                iconColor: Colors.purple,
                children: resources.diskUsage.map((disk) {
                  final usagePercentage =
                      (disk.usedSpace.toDouble() / disk.totalSpace.toDouble()) *
                      100;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            MdiIcons.harddisk,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${disk.name} (${disk.mountPoint})',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('总容量', _formatBytes(disk.totalSpace)),
                      _buildInfoRow('已使用', _formatBytes(disk.usedSpace)),
                      _buildInfoRow('可用空间', _formatBytes(disk.availableSpace)),
                      _buildInfoRow(
                        '使用率',
                        '${usagePercentage.toStringAsFixed(1)}%',
                      ),
                      if (disk != resources.diskUsage.last) const Divider(),
                    ],
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            // 网络信息
            _buildInfoCard(
              title: '网络统计',
              icon: MdiIcons.network,
              iconColor: Colors.teal,
              children: [
                _buildInfoRow(
                  '发送字节数',
                  _formatBytes(resources.networkUsage.bytesSent),
                  icon: MdiIcons.upload,
                ),
                _buildInfoRow(
                  '接收字节数',
                  _formatBytes(resources.networkUsage.bytesReceived),
                  icon: MdiIcons.download,
                ),
                _buildInfoRow(
                  '发送数据包',
                  '${resources.networkUsage.packetsSent}',
                  icon: MdiIcons.packageUp,
                ),
                _buildInfoRow(
                  '接收数据包',
                  '${resources.networkUsage.packetsReceived}',
                  icon: MdiIcons.packageDown,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
