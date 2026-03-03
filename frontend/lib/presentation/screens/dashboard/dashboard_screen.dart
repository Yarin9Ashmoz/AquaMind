import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/dashboard_state.dart';
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
    Future.microtask(() {
      context.read<DashboardState>().loadSensors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      appBar: AppBar(title: const Text("AquaMind")),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => state.loadSensors(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.sensors.length,
                itemBuilder: (context, index) {
                  final sensor = state.sensors[index];
                  return Card(
                    child: ListTile(
                      title: Text(sensor.name),
                      subtitle: Text("Moisture: ${sensor.moisture}%"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SensorDetailsScreen(sensor: sensor),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddSensorIntroScreen(),
            ),
          );
        },
      ),
    );
  }
}
