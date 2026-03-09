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
    Future.microtask(() {
      context.read<DashboardState>().loadSensors();
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
          "AquaMind",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

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

  Widget _buildSensorCard(Sensor sensor) {
    final moisture = sensor.moisture;
    final status = _getStatus(moisture);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        leading: Icon(Icons.eco, color: Colors.green, size: 28),
        title: Text(
          sensor.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "Moisture: $moisture% • $status",
          style: TextStyle(color: statusColor, fontSize: 14),
        ),
        trailing: const Icon(CupertinoIcons.chevron_forward, size: 20),
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
  }

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

  String _getStatus(int moisture) {
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
