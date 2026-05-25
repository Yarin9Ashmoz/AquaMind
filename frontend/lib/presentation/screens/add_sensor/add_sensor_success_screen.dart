import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';
import '../home/home_screen.dart';

class AddSensorSuccessScreen extends StatelessWidget {
  const AddSensorSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green.shade400),
            const SizedBox(height: 20),
            const Text(
              "Sensor Added Successfully!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await context.read<DashboardState>().loadSensors();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text("Back to Home"),
            ),
          ],
        ),
      ),
    );
  }
}
