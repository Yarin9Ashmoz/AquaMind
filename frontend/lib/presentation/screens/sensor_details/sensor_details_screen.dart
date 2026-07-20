import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';
import '../../../data/models/sensor.dart';

class SensorDetailsScreen extends StatefulWidget {
  final Sensor sensor;

  const SensorDetailsScreen({super.key, required this.sensor});

  @override
  State<SensorDetailsScreen> createState() => _SensorDetailsScreenState();
}

class _SensorDetailsScreenState extends State<SensorDetailsScreen> {
  bool _isMeasuring = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    // Synchronize current UI state with the global provider store
    final currentSensor = state.sensors.firstWhere(
      (s) => s.sensorId == widget.sensor.sensorId,
      orElse: () => widget.sensor,
    );

    final status = _getStatus(currentSensor.moisture);
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          currentSensor.name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRenameDialog(context, state, currentSensor),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Sensor'),
                  content: const Text(
                    'Are you sure you want to delete this sensor? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed ?? false) {
                await state.deleteSensorById(currentSensor.sensorId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero Card: Moisture Ring and Real-time Controls
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Circular Visual Gauge for Moisture Tracking
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: currentSensor.moisture / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            "${currentSensor.moisture.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Trigger live telemetry collection from ESP32
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isMeasuring
                          ? null
                          : () async {
                              setState(() => _isMeasuring = true);
                              try {
                                await state.requestMeasurement(currentSensor.sensorId);

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("✅ Measurement requested - waiting for data..."),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }

                                await Future.delayed(const Duration(seconds: 1));
                                await state.fetchSensors();
                              } on TimeoutException catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("⏱️ Request timed out - server may be slow"),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                                print("❌ Timeout: $e");
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("❌ Error: ${e.toString().split('\n').first}"),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                                print("❌ Error requesting measurement: $e");
                              }

                              if (mounted) {
                                setState(() => _isMeasuring = false);
                              }
                            },
                      icon: _isMeasuring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(CupertinoIcons.drop_fill, size: 20),
                      label: Text(
                        _isMeasuring ? "Sampling Telemetry..." : "Measure Now",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Metadata Grid Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Hardware Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            
            // Refactored descriptive parameters UI
            _buildInfoCard("Device Status", state.statusText, Icons.bolt, Colors.amber),
            _buildInfoCard("Plant Classification", currentSensor.plantType, Icons.grass, Colors.green),
            _buildInfoCard("Deployment Zone", currentSensor.locationType, Icons.location_on_outlined, Colors.red),
            _buildInfoCard("Last Sync Timestamp", currentSensor.lastUpdate.toString().split('.').first, Icons.access_time, Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  // Helper builder generating modular uniform info blocks
  Widget _buildInfoCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }

  // Modifies properties on remote IoT infrastructure via Provider action
  void _showRenameDialog(BuildContext context, DashboardState state, Sensor sensor) {
    final controller = TextEditingController(text: sensor.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Sensor"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter asset name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  state.renameSensor(sensor.sensorId, controller.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Evaluates environmental water volume ratios
  String _getStatus(double moisture) {
    if (moisture < 20) return "Dry";
    if (moisture < 40) return "Low";
    if (moisture < 70) return "Good";
    return "Wet";
  }

  // Color mapping system providing quick visual cues for state thresholds
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