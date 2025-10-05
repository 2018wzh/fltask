import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../src/rust/api/simple.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  Timer? _timer;
  SystemResourceInfo? _systemResources;
  final List<FlSpot> _cpuData = [];
  final List<FlSpot> _memoryData = [];
  double _timeIndex = 0;
  final int _maxDataPoints = 60; // 显示最近60个数据点

  @override
  void initState() {
    super.initState();
    _loadSystemResources();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadSystemResources();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadSystemResources() {
    try {
      final resources = getSystemResources();
      setState(() {
        _systemResources = resources;
        _timeIndex++;

        // 添加CPU数据点
        _cpuData.add(FlSpot(_timeIndex, resources.cpuUsage));
        if (_cpuData.length > _maxDataPoints) {
          _cpuData.removeAt(0);
        }

        // 添加内存数据点
        final memoryPercentage =
            (resources.memoryUsed.toDouble() /
                resources.memoryTotal.toDouble()) *
            100;
        _memoryData.add(FlSpot(_timeIndex, memoryPercentage));
        if (_memoryData.length > _maxDataPoints) {
          _memoryData.removeAt(0);
        }
      });
    } catch (e) {
      debugPrint('加载系统资源失败: $e');
    }
  }

  String _formatBytes(BigInt bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var suffixIndex = 0;

    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }

    return '${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_systemResources == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final resources = _systemResources!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CPU 使用率图表
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.memory, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'CPU 使用率',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${resources.cpuUsage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _cpuData.isNotEmpty
                        ? LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 25,
                                verticalInterval: 10,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: colorScheme.outline.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: colorScheme.outline.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    interval: 10,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${(value - _timeIndex).toInt()}s',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 25,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              minX: _cpuData.isNotEmpty ? _cpuData.first.x : 0,
                              maxX: _timeIndex,
                              minY: 0,
                              maxY: 100,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _cpuData,
                                  isCurved: true,
                                  color: colorScheme.primary,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: Text('正在收集数据...')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 内存使用率图表
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.memory, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '内存使用率',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_formatBytes(resources.memoryUsed)} / ${_formatBytes(resources.memoryTotal)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _memoryData.isNotEmpty
                        ? LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 25,
                                verticalInterval: 10,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: colorScheme.outline.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: colorScheme.outline.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    interval: 10,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${(value - _timeIndex).toInt()}s',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 25,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              minX: _memoryData.isNotEmpty
                                  ? _memoryData.first.x
                                  : 0,
                              maxX: _timeIndex,
                              minY: 0,
                              maxY: 100,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _memoryData,
                                  isCurved: true,
                                  color: Colors.orange,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: Text('正在收集数据...')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 磁盘使用情况
          if (resources.diskUsage.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.harddisk, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          '磁盘使用情况',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...resources.diskUsage.map((disk) {
                      final usagePercentage =
                          (disk.usedSpace.toDouble() /
                              disk.totalSpace.toDouble()) *
                          100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${disk.name} (${disk.mountPoint})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${_formatBytes(disk.usedSpace)} / ${_formatBytes(disk.totalSpace)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: usagePercentage / 100,
                              backgroundColor: colorScheme.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                usagePercentage > 80
                                    ? Colors.red
                                    : usagePercentage > 60
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${usagePercentage.toStringAsFixed(1)}% 已使用',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 网络使用情况
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.network, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        '网络使用情况',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '发送',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _formatBytes(resources.networkUsage.bytesSent),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${resources.networkUsage.packetsSent} 数据包',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '接收',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _formatBytes(
                                resources.networkUsage.bytesReceived,
                              ),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${resources.networkUsage.packetsReceived} 数据包',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
