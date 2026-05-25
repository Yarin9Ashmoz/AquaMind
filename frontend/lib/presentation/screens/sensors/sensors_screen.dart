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
    Future.microtask(() {
      context.read<DashboardState>().loadSensors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      appBar: AppBar(title: const Text("My Sensors")),

      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
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
              onRefresh: state.loadSensors,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.sensors.length,
                itemBuilder: (context, i) {
                  final s = state.sensors[i];

                  return Dismissible(
                    key: ValueKey(s.sensorId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete sensor?'),
                          content: Text(
                            'Delete "${s.name}" (ID: ${s.sensorId}) from the database? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed ?? false) {
                        await context.read<DashboardState>().deleteSensorById(
                          s.sensorId,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted sensor "${s.name}"'),
                            ),
                          );
                        }
                      }

                      return confirmed ?? false;
                    },
                    child: ListTile(
                      leading: Icon(
                        s.plantType == "pot" ? Icons.local_florist : Icons.park,
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                        "Moisture: ${s.moisture.toStringAsFixed(1)}%",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              String newName = s.name;

                              return AlertDialog(
                                title: const Text("Rename Sensor"),
                                content: TextField(
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: "Sensor Name",
                                  ),
                                  onChanged: (value) {
                                    newName = value;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      context
                                          .read<DashboardState>()
                                          .renameSensor(s.sensorId, newName);
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
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
                  );
                },
              ),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSensorBluetoothScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
