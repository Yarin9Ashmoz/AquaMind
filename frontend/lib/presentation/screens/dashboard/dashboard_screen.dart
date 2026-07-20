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
    // Trigger the initial data fetch safely after the first frame
    Future.microtask(() {
      context.read<DashboardState>().loadSensors();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to state changes from DashboardState
    final state = context.watch<DashboardState>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "AquaMind",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sample now',
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Sampling...')),
              );
              
              // Force refresh data
              await state.loadSensors();
              
              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sample complete')),
                );
              }
            },
          ),
        ],
      ),

      // Conditional rendering based on the UI state
      body: state.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${state.error}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      state.loadSensors();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => state.loadSensors(),
              child: state.sensors.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.sensors.length,
                      itemBuilder: (context, index) {
                        final sensor = state.sensors[index];
                        return _buildSensorCard(sensor);
                      },
                    ),
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.blue),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSensorIntroScreen()),
          );
        },
      ),
    );
  }

  // Modern card layout showcasing moisture levels visually
  Widget _buildSensorCard(Sensor sensor) {
    final moisture = sensor.moisture;
    final status = _getStatus(moisture);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Plant/Sensor Name and Arrow Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: const Icon(Icons.eco, color: Colors.green, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        sensor.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Icon(CupertinoIcons.chevron_forward, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 20),
              
              // Status Row: Label and Colored Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Moisture Level",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Progress Row: Visual Indicator Bar and Percentage Text
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: moisture / 100, // Converts percentage to 0.0 - 1.0 range
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${moisture.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontSize: 16,
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

  // Placeholder screen when no hardware/sensors are linked yet
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              "No Sensors Added Yet",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "Click on + to add a new sensor",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Business logic to evaluate data thresholds
  String _getStatus(double moisture) {
    if (moisture < 20) return "Dry";
    if (moisture < 40) return "Low";
    if (moisture < 70) return "Good";
    return "Wet";
  }

  // Theme map to match visual system colors with state thresholds
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