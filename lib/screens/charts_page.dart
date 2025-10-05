import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final List<FlSpot> _swapData = [];
  final List<FlSpot> _networkReceiveData = [];
  final List<FlSpot> _networkSendData = [];
  double _timeIndex = 0;
  final int _maxDataPoints = 60;

  // 模拟多核CPU数据
  final List<List<FlSpot>> _cpuCoreData = [];
  final List<Color> _cpuCoreColors = [
    const Color(0xFFE74C3C), // 红色
    const Color(0xFFE67E22), // 橙色
    const Color(0xFFF1C40F), // 黄色
    const Color(0xFF2ECC71), // 绿色
    const Color(0xFF3498DB), // 蓝色
    const Color(0xFF9B59B6), // 紫色
    const Color(0xFF1ABC9C), // 青色
    const Color(0xFFE91E63), // 粉色
  ];

  @override
  void initState() {
    super.initState();
    // 初始化多核CPU数据
    for (int i = 0; i < 8; i++) {
      _cpuCoreData.add([]);
    }
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

        // 模拟多核CPU数据
        for (int i = 0; i < _cpuCoreData.length; i++) {
          // 基于总CPU使用率，为每个核心生成不同的使用率
          final coreUsage = resources.cpuUsage + (i * 5) % 30 - 15;
          final clampedUsage = coreUsage.clamp(0, 100).toDouble();
          _cpuCoreData[i].add(FlSpot(_timeIndex, clampedUsage));
          if (_cpuCoreData[i].length > _maxDataPoints) {
            _cpuCoreData[i].removeAt(0);
          }
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

        // 模拟交换分区数据
        final swapPercentage = (memoryPercentage * 0.1).clamp(0, 10).toDouble();
        _swapData.add(FlSpot(_timeIndex, swapPercentage));
        if (_swapData.length > _maxDataPoints) {
          _swapData.removeAt(0);
        }

        // 添加网络数据点（模拟实时速度）
        final receiveSpeed =
            resources.networkUsage.bytesReceived.toDouble() /
            1024 /
            1024; // MB/s
        final sendSpeed =
            resources.networkUsage.bytesSent.toDouble() / 1024 / 1024; // MB/s
        _networkReceiveData.add(FlSpot(_timeIndex, receiveSpeed % 10));
        _networkSendData.add(FlSpot(_timeIndex, sendSpeed % 5));
        if (_networkReceiveData.length > _maxDataPoints) {
          _networkReceiveData.removeAt(0);
        }
        if (_networkSendData.length > _maxDataPoints) {
          _networkSendData.removeAt(0);
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

  Widget _buildGnomeStyleChart({
    required String title,
    required Color color,
    required List<FlSpot> data,
    String? subtitle,
    double maxY = 100,
    String yAxisSuffix = '%',
  }) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: data.isNotEmpty
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxY / 4,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}$yAxisSuffix',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
                      borderData: FlBorderData(show: false),
                      minX: data.isNotEmpty ? data.first.x : 0,
                      maxX: _timeIndex,
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: data,
                          isCurved: false,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      '正在收集数据...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiCoreChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CPU 核心',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '${_cpuCoreData.length} 个逻辑核心',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _cpuCoreData.isNotEmpty && _cpuCoreData[0].isNotEmpty
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
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
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
                      borderData: FlBorderData(show: false),
                      minX: _cpuCoreData[0].isNotEmpty
                          ? _cpuCoreData[0].first.x
                          : 0,
                      maxX: _timeIndex,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: _cpuCoreData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return LineChartBarData(
                          spots: data,
                          isCurved: false,
                          color: _cpuCoreColors[index % _cpuCoreColors.length],
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                        );
                      }).toList(),
                    ),
                  )
                : Center(
                    child: Text(
                      '正在收集数据...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_systemResources == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final resources = _systemResources!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // CPU 多核心图表
          _buildMultiCoreChart(),

          const SizedBox(height: 16),

          // 内存和交换分区
          Row(
            children: [
              Expanded(
                child: _buildGnomeStyleChart(
                  title: '内存',
                  color: const Color(0xFF3498DB),
                  data: _memoryData,
                  subtitle:
                      '${_formatBytes(resources.memoryUsed)} / ${_formatBytes(resources.memoryTotal)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGnomeStyleChart(
                  title: '交换分区',
                  color: const Color(0xFF9B59B6),
                  data: _swapData,
                  subtitle: '128 MB / 2.0 GB',
                  maxY: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 网络接收和发送
          Row(
            children: [
              Expanded(
                child: _buildGnomeStyleChart(
                  title: '网络接收',
                  color: const Color(0xFF2ECC71),
                  data: _networkReceiveData,
                  subtitle: 'KB/s',
                  maxY: 20,
                  yAxisSuffix: '',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGnomeStyleChart(
                  title: '网络发送',
                  color: const Color(0xFFE74C3C),
                  data: _networkSendData,
                  subtitle: 'KB/s',
                  maxY: 10,
                  yAxisSuffix: '',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 磁盘使用情况卡片
          if (resources.diskUsage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '磁盘使用情况',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...resources.diskUsage.map((disk) {
                    final usagePercentage =
                        (disk.usedSpace.toDouble() /
                            disk.totalSpace.toDouble()) *
                        100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              disk.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: usagePercentage / 100,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    usagePercentage > 90
                                        ? const Color(0xFFE74C3C)
                                        : usagePercentage > 75
                                        ? const Color(0xFFF39C12)
                                        : const Color(0xFF27AE60),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatBytes(disk.usedSpace)} / ${_formatBytes(disk.totalSpace)} (${usagePercentage.toStringAsFixed(1)}%)',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
