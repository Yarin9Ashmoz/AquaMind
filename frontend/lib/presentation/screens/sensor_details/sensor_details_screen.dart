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
  late TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController();
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    // Synchronize current UI state with the global provider store
    final currentSensor = state.sensors.firstWhere(
      (s) => s.sensorId == widget.sensor.sensorId,
      orElse: () => widget.sensor,
    );

    final status = _getStatus(currentSensor.moisture ?? 0.0);
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          currentSensor.name ?? "Unnamed Sensor",
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mode_edit_outline_outlined, size: 22),
            onPressed: () => _showRenameDialog(context, state, currentSensor),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: () => _confirmDelete(context, state, currentSensor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                          value: (currentSensor.moisture ?? 0) / 100,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[100],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${(currentSensor.moisture ?? 0.0).toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Trigger live telemetry collection from ESP32
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isMeasuring
                          ? null
                          : () => _triggerMeasurement(state, currentSensor),
                      icon: _isMeasuring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CupertinoActivityIndicator(
                                radius: 9,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(CupertinoIcons.drop_fill, size: 18),
                      label: Text(
                        _isMeasuring ? "Measuring..." : "Measure Now",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
              child: Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(
                  "Hardware Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoCard(
              "Status\u00A0",
              state.statusText ?? "Unknown",
              Icons.bolt_rounded,
              Colors.amber[700]!,
            ),
            _buildInfoCard(
              "Plant Classification",
              currentSensor.plantType ?? "Unspecified",
              Icons.grass_rounded,
              Colors.green[600]!,
            ),
            _buildInfoCard(
              "Deployment Zone",
              currentSensor.locationType ?? "N/A",
              Icons.location_on_outlined,
              Colors.redAccent,
            ),
            _buildInfoCard(
              "Last Sync Timestamp",
              currentSensor.lastUpdate?.toString().split('.').first ?? "Never",
              Icons.access_time_rounded,
              Colors.blueGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  // Orchestrates the active live pulse requests with fallback timing constraints
  Future<void> _triggerMeasurement(
    DashboardState state,
    Sensor currentSensor,
  ) async {
    if (currentSensor.sensorId == null) return;

    setState(() => _isMeasuring = true);

    try {
      final DateTime? previousUpdate = currentSensor.lastUpdate;

      await state.requestMeasurement(currentSensor.sensorId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📡 Measurement requested - waiting for ESP32..."),
            duration: Duration(seconds: 2),
          ),
        );
      }

      bool updated = false;
      const int maxRetries = 12;

      for (int i = 0; i < maxRetries; i++) {
        await Future.delayed(const Duration(seconds: 1));
        await state.fetchSensors();

        final updatedSensor = state.sensors.firstWhere(
          (s) => s.sensorId == currentSensor.sensorId,
          orElse: () => currentSensor,
        );

        if (updatedSensor.lastUpdate != previousUpdate) {
          updated = true;
          break;
        }
      }

      if (mounted) {
        if (updated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ New measurement received!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Timeout waiting for sensor response."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
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
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print("❌ Error requesting measurement: $e");
    } finally {
      if (mounted) {
        setState(() => _isMeasuring = false);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DashboardState state,
    Sensor currentSensor,
  ) async {
    if (currentSensor.sensorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Sensor'),
        content: const Text(
          'Are you sure you want to delete this sensor? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await state.deleteSensorById(currentSensor.sensorId!);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showRenameDialog(
    BuildContext context,
    DashboardState state,
    Sensor sensor,
  ) {
    _renameController.text = sensor.name ?? "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Rename Sensor"),
          content: TextField(
            controller: _renameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "Sensor Asset Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (_renameController.text.trim().isNotEmpty &&
                    sensor.sensorId != null) {
                  state.renameSensor(
                    sensor.sensorId!,
                    _renameController.text.trim(),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatus(double moisture) {
    if (moisture < 20) return "Dry";
    if (moisture < 40) return "Low";
    if (moisture < 70) return "Good";
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
