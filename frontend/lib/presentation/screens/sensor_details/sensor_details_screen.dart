import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';
import '../../../data/models/sensor.dart';

class SensorDetailsScreen extends StatelessWidget {
  final Sensor sensor;

  const SensorDetailsScreen({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(sensor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete sensor'),
                  content: const Text(
                    'Are you sure you want to delete this sensor? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed ?? false) {
                await state.deleteSensorById(sensor.sensorId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showRenameDialog(context, state, sensor);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Moisture: ${sensor.moisture}%",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text("Status: ${state.statusText}"),
            const SizedBox(height: 8),
            Text("Type: ${sensor.plantType}"),
            const SizedBox(height: 8),
            Text("Location: ${sensor.locationType}"),
            const SizedBox(height: 8),
            Text("Last Updated: ${sensor.lastUpdate}"),

            const SizedBox(height: 24),
            const Divider(),

            const SizedBox(height: 24),
            const Text(
              "History (coming soon)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Text("Graph Placeholder"),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    DashboardState state,
    Sensor sensor,
  ) {
    String newName = sensor.name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Sensor"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: "Sensor Name"),
            onChanged: (value) => newName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                state.renameSensor(sensor.sensorId, newName);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
