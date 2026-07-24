import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/dashboard_state.dart';
import '../../../data/models/sensor.dart';
import '../sensor_details/sensor_details_screen.dart';
import '../add_sensor/add_sensor_intro_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Safely dispatch infrastructure refresh after initial frame deployment
    Future.microtask(() {
      if (mounted) {
        context.read<DashboardState>().loadSensors();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    // Deduplicate array locally as a safety shield against backend list duplication
    final uniqueSensorsMap = <String, Sensor>{};
    for (var sensor in state.sensors) {
      // Use unique sensor identifier (sensorId)
      uniqueSensorsMap[sensor.sensorId] = sensor;
    }
    final displaySensors = uniqueSensorsMap.values.toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "AquaMind",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync cloud telemetry',
            icon: const Icon(Icons.sync_rounded, color: Colors.black87),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Sampling network nodes...'),
                  duration: Duration(seconds: 1),
                ),
              );

              await state.loadSensors();

              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Ecosystem status updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : state.error != null
          ? _buildErrorState(state)
          : RefreshIndicator(
              onRefresh: () => state.loadSensors(),
              color: Colors.blue,
              child: displaySensors.isEmpty
                  ? _buildEmptyState()
                  : _buildDashboardContent(displaySensors),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSensorIntroScreen()),
          );
        },
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }

  Widget _buildErrorState(DashboardState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text("Sync Failure: ${state.error}", textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => state.loadSensors(),
              child: const Text("Retry Connection"),
            ),
          ],
        ),
      ),
    );
  }

  // Generates aggregated matrix insights and renders the primary view list
  Widget _buildDashboardContent(List<Sensor> sensors) {
    // Computing micro-telemetry metrics across all connected hardware objects
    final totalSensors = sensors.length;
    final drySensors = sensors.where((s) {
      final threshold = s.moistureThreshold ?? 25.0;
      return s.moisture < threshold;
    }).length;

    final avgMoisture =
        sensors.map((s) => s.moisture).reduce((a, b) => a + b) / totalSensors;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Aggregated System KPI Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                "System Health",
                drySensors == 0 ? "All Good" : "$drySensors Need Water",
                drySensors == 0 ? Colors.green : Colors.orange,
                drySensors == 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                "Avg Moisture",
                "${avgMoisture.toStringAsFixed(0)}%",
                Colors.blue,
                Icons.opacity_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text(
          "Monitored Nodes",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Core hardware node array iteration block
        ...sensors.map((sensor) => _buildSensorCard(sensor)),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(Sensor sensor) {
    final moisture = sensor.moisture;
    final threshold = sensor.moistureThreshold ?? 25.0;
    final status = _getStatus(moisture, threshold);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SensorDetailsScreen(sensor: sensor),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        radius: 18,
                        child: Icon(
                          sensor.plantType == "pot"
                              ? Icons.local_florist_outlined
                              : Icons.park_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        sensor.name ?? 'Sensor ${sensor.sensorId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Moisture Profile",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (moisture / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    "${moisture.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              "No Active Ecosystem Infrastructure",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the deployment controller (+) below to establish telemetry connection with your first ESP32 moisture module.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatus(double moisture, double threshold) {
    if (moisture < threshold) return "Dry";
    if (moisture < threshold + 15) return "Low";
    if (moisture < 75) return "Good";
    return "Wet";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Dry":
        return Colors.red;
      case "Low":
        return Colors.orange;
      case "Good":
        return Colors.green;
      case "Wet":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
