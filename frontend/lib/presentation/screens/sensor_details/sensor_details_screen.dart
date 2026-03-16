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
    // מוצאים את הגרסה המעודכנת של החיישן מתוך ה-State למקרה שהנתונים השתנו
    final currentSensor = state.sensors.firstWhere(
      (s) => s.sensorId == widget.sensor.sensorId,
      orElse: () => widget.sensor,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSensor.name),
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
                await state.deleteSensorById(currentSensor.sensorId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showRenameDialog(context, state, currentSensor);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כרטיס המדידה הראשי
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Moisture Level",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          "${currentSensor.moisture.toStringAsFixed(1)}%",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isMeasuring ? null : () async {
                          setState(() => _isMeasuring = true);
                          // רענון מהשרת (ה-ESP ממילא מעדכן כל 30 שניות)
                          await state.fetchSensors();
                          if (mounted) {
                            setState(() => _isMeasuring = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Data updated from server")),
                            );
                          }
                        },
                        icon: _isMeasuring 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                        label: Text(_isMeasuring ? "Measuring..." : "Measure Now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text("Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Status"),
              trailing: Text(state.statusText),
            ),
            ListTile(
              leading: const Icon(Icons.grass),
              title: const Text("Plant Type"),
              trailing: Text(currentSensor.plantType),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text("Location"),
              trailing: Text(currentSensor.locationType),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text("Last Updated"),
              trailing: Text(currentSensor.lastUpdate.toString()),
            ),

            const SizedBox(height: 24),
            const Text(
              "History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text("Graph Placeholder", style: TextStyle(color: Colors.grey)),
                ],
              ),
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
    final controller = TextEditingController(text: sensor.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Sensor"),
          content: TextField(
            controller: controller,
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