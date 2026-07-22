import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';
import '../sensor_details/sensor_details_screen.dart';
import '../add_sensor/add_sensor_bluetooth_screen.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  @override
  void initState() {
    super.initState();
    // Safely fire async infrastructure fetch after initial component layout mount
    Future.microtask(() {
      if (mounted) {
        context.read<DashboardState>().loadSensors();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Sensors",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : state.error != null
          ? _buildErrorState(state)
          : state.sensors.isEmpty
          ? _buildEmptyState()
          : _buildSensorList(state),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSensorBluetoothScreen()),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Sync Error: ${state.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: state.loadSensors,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Retry Connection"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "No Active Sensors",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the '+' button below to pair your first AquaMind ESP32 hardware transceiver node.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorList(DashboardState state) {
    return RefreshIndicator(
      onRefresh: state.loadSensors,
      color: Colors.blue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.sensors.length,
        itemBuilder: (context, i) {
          final s = state.sensors[i];

          // Dynamic colors mapped directly against hardware telemetry
          final Color moistureColor = s.moisture < 30.0
              ? Colors.orange
              : Colors.blue;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey(s.sensorId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              confirmDismiss: (_) => _confirmDeleteDialog(context, s),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Icon(
                      s.plantType == "pot"
                          ? Icons.local_florist_outlined
                          : Icons.park_outlined,
                      color: Colors.blue[700],
                    ),
                  ),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.opacity, size: 14, color: moistureColor),
                        const SizedBox(width: 4),
                        Text(
                          "Moisture: ${s.moisture.toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.mode_edit_outline_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () => _showRenameDialog(context, s),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SensorDetailsScreen(sensor: s),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Launches clean confirmation block prior to invoking data mutations
  Future<bool> _confirmDeleteDialog(
    BuildContext context,
    dynamic sensor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Sensor Asset?'),
        content: Text(
          'Are you sure you want to delete "${sensor.name}" from your cloud dashboard? This action is permanent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await context.read<DashboardState>().deleteSensorById(sensor.sensorId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed entity target "${sensor.name}"'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
    return confirmed ?? false;
  }

  // Inline model to inject target label mutations smoothly
  void _showRenameDialog(BuildContext context, dynamic sensor) {
    String newName = sensor.name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Rename Asset Node"),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: sensor.name,
              labelText: "Updated Sensor Title",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => newName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (newName.trim().isNotEmpty) {
                  context.read<DashboardState>().renameSensor(
                    sensor.sensorId,
                    newName.trim(),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text(
                "Save Changes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
