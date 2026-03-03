import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';
import '../sensors/sensors_screen.dart';

class AddSensorSuccessScreen extends StatelessWidget {
  const AddSensorSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Sensor Added Successfully!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                print("GO TO MY SENSORS CLICKED");

                await context.read<DashboardState>().loadSensors();

                Navigator.popUntil(context, (route) => route.isFirst);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SensorsScreen()),
                );
              },
              child: const Text("Go to My Sensors"),
            ),
          ],
        ),
      ),
    );
  }
}
