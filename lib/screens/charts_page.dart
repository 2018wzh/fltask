import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../src/rust/api/simple.dart';

class ChartsPage extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final bool networkUnitIsBps;
  final int refreshInterval;

  const ChartsPage({
    super.key,
    this.refreshNotifier,
    this.networkUnitIsBps = false,
    this.refreshInterval = 1,
  });

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  Timer? _timer;
  SystemInfo? _systemInfo;
  SystemResourceInfo? _systemResources;
  SystemResourceInfo? _previousSystemResources;
  final List<FlSpot> _cpuData = [];
  final List<FlSpot> _memoryData = [];
  final List<FlSpot> _swapData = [];
  final List<FlSpot> _networkReceiveData = [];
  final List<FlSpot> _networkSendData = [];
  double _timeIndex = 0; // 按真实经过时间(秒)累计
  final int _maxDataPoints = 60;
  DateTime? _lastSampleTime;
  DateTime? _startTime;

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
    _initializeCpuData();
    _loadSystemResources();
    _startTime = DateTime.now();
    _lastSampleTime = null;
    _timer = Timer.periodic(
      Duration(seconds: widget.refreshInterval),
      (_) => _loadSystemResources(),
    );
    widget.refreshNotifier?.addListener(_onRefresh);
  }

  @override
  void didUpdateWidget(covariant ChartsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      // 重建定时器以应用新的刷新间隔
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(seconds: widget.refreshInterval),
        (_) => _loadSystemResources(),
      );
    }
  }

  void _initializeCpuData() {
    final info = getSystemInfo();
    setState(() {
      _systemInfo = info;
      _cpuCoreData.clear();
      for (int i = 0; i < (info.cpuCores); i++) {
        _cpuCoreData.add([]);
      }
    });
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefresh);
    _timer?.cancel();
    super.dispose();
  }

  void _onRefresh() {
    _loadSystemResources();
  }

  void _loadSystemResources() {
    try {
      final resources = getSystemResources();
      final now = DateTime.now();
      double elapsedSeconds = 0;
      if (_lastSampleTime != null) {
        elapsedSeconds =
            now.difference(_lastSampleTime!).inMilliseconds / 1000.0;
      } else {
        _startTime ??= now;
      }
      _lastSampleTime = now;
      setState(() {
        _systemResources = resources;
        // 使用真实经过时间推进 x 轴
        _timeIndex += elapsedSeconds;
        if (_timeIndex.isNaN || _timeIndex.isInfinite) _timeIndex = 0;

        // 添加CPU数据点
        _cpuData.add(FlSpot(_timeIndex, resources.cpuUsage));
        if (_cpuData.length > _maxDataPoints) {
          _cpuData.removeAt(0);
        }

        // 真实多核 CPU 数据（来自 Rust cpuPerCore）
        final perCore = resources.cpuPerCore;
        // 如果核心数量发生变化，调整数据结构
        if (perCore.length != _cpuCoreData.length) {
          if (perCore.length > _cpuCoreData.length) {
            // 添加新的核心列表
            for (int i = _cpuCoreData.length; i < perCore.length; i++) {
              _cpuCoreData.add([]);
            }
          } else {
            // 缩减（极少发生）
            _cpuCoreData.removeRange(perCore.length, _cpuCoreData.length);
          }
        }
        for (int i = 0; i < perCore.length; i++) {
          final usage = perCore[i].clamp(0, 100).toDouble();
          _cpuCoreData[i].add(FlSpot(_timeIndex, usage));
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

        // 实际交换分区数据
        if (resources.swapTotal > BigInt.zero) {
          final swapPercentage =
              (resources.swapUsed.toDouble() / resources.swapTotal.toDouble()) *
              100;
          _swapData.add(FlSpot(_timeIndex, swapPercentage));
        } else {
          _swapData.add(FlSpot(_timeIndex, 0));
        }
        if (_swapData.length > _maxDataPoints) {
          _swapData.removeAt(0);
        }

        // 计算网络速度
        double receiveSpeed = 0;
        double sendSpeed = 0;
        if (_previousSystemResources != null) {
          final interval = elapsedSeconds > 0
              ? elapsedSeconds
              : widget.refreshInterval.toDouble();
          if (interval > 0) {
            receiveSpeed =
                (resources.networkUsage.bytesReceived -
                        _previousSystemResources!.networkUsage.bytesReceived)
                    .toDouble() /
                interval;
            sendSpeed =
                (resources.networkUsage.bytesSent -
                        _previousSystemResources!.networkUsage.bytesSent)
                    .toDouble() /
                interval;
          }
        }

        _networkReceiveData.add(FlSpot(_timeIndex, receiveSpeed));
        _networkSendData.add(FlSpot(_timeIndex, sendSpeed));

        if (_networkReceiveData.length > _maxDataPoints) {
          _networkReceiveData.removeAt(0);
        }
        if (_networkSendData.length > _maxDataPoints) {
          _networkSendData.removeAt(0);
        }

        _previousSystemResources = resources;
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

  String _formatSpeed(double bytesPerSecond) {
    if (widget.networkUnitIsBps) {
      final bitsPerSecond = bytesPerSecond * 8;
      const suffixes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
      var value = bitsPerSecond;
      var suffixIndex = 0;
      while (value >= 1000 && suffixIndex < suffixes.length - 1) {
        value /= 1000;
        suffixIndex++;
      }
      return '${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
    } else {
      const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
      var value = bytesPerSecond;
      var suffixIndex = 0;
      while (value >= 1024 && suffixIndex < suffixes.length - 1) {
        value /= 1024;
        suffixIndex++;
      }
      return '${value.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
    }
  }

  Widget _buildGnomeStyleChart({
    required String title,
    required Color color,
    required List<FlSpot> data,
    String? subtitle,
    double maxY = 100,
    String yAxisSuffix = '%',
    String Function(double)? yAxisFormatter,
    String? yAxisLabel,
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
                            reservedSize: 45,
                            interval: maxY / 4,
                            getTitlesWidget: (value, meta) {
                              if (meta.axisPosition == 0 &&
                                  yAxisLabel != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    yAxisLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                );
                              }
                              final text = yAxisFormatter != null
                                  ? yAxisFormatter(value)
                                  : '${value.toInt()}$yAxisSuffix';
                              return Text(
                                text,
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
                            color: color.withAlpha(77), // 0.3 opacity
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final value = spot.y;
                              final formattedValue = yAxisFormatter != null
                                  ? _formatSpeed(value)
                                  : '${value.toStringAsFixed(2)}$yAxisSuffix';
                              return LineTooltipItem(
                                formattedValue,
                                TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
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
            '${_systemInfo?.cpuCores ?? 0} 个逻辑核心',
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
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            touchedSpots.sort(
                              (a, b) => a.barIndex.compareTo(b.barIndex),
                            );
                            return touchedSpots.map((spot) {
                              final index = spot.barIndex;
                              final value = spot.y;
                              return LineTooltipItem(
                                'CPU$index: ${value.toStringAsFixed(2)}%',
                                TextStyle(
                                  color:
                                      _cpuCoreColors[index %
                                          _cpuCoreColors.length],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
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

  void refresh() {
    _loadSystemResources();
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
                  subtitle: resources.swapTotal > BigInt.zero
                      ? '${_formatBytes(resources.swapUsed)} / ${_formatBytes(resources.swapTotal)}'
                      : '未启用',
                  maxY: 100,
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
                  subtitle: _networkReceiveData.isNotEmpty
                      ? _formatSpeed(_networkReceiveData.last.y)
                      : '0.0 B/s',
                  maxY: _networkReceiveData.isEmpty
                      ? 1024
                      : (_networkReceiveData
                                    .map((e) => e.y)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2)
                            .clamp(1024, double.infinity),
                  yAxisSuffix: '',
                  yAxisFormatter: (value) => _formatSpeed(value).split(' ')[0],
                  yAxisLabel: _formatSpeed(
                    _networkReceiveData.isEmpty
                        ? 1024
                        : (_networkReceiveData
                                      .map((e) => e.y)
                                      .reduce((a, b) => a > b ? a : b) *
                                  1.2)
                              .clamp(1024, double.infinity),
                  ).split(' ')[1],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGnomeStyleChart(
                  title: '网络发送',
                  color: const Color(0xFFE74C3C),
                  data: _networkSendData,
                  subtitle: _networkSendData.isNotEmpty
                      ? _formatSpeed(_networkSendData.last.y)
                      : '0.0 B/s',
                  maxY: _networkSendData.isEmpty
                      ? 1024
                      : (_networkSendData
                                    .map((e) => e.y)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2)
                            .clamp(1024, double.infinity),
                  yAxisSuffix: '',
                  yAxisFormatter: (value) => _formatSpeed(value).split(' ')[0],
                  yAxisLabel: _formatSpeed(
                    _networkSendData.isEmpty
                        ? 1024
                        : (_networkSendData
                                      .map((e) => e.y)
                                      .reduce((a, b) => a > b ? a : b) *
                                  1.2)
                              .clamp(1024, double.infinity),
                  ).split(' ')[1],
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
