import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class AddSensorSuccessScreen extends StatefulWidget {
  const AddSensorSuccessScreen({super.key});

  @override
  State<AddSensorSuccessScreen> createState() => _AddSensorSuccessScreenState();
}

class _AddSensorSuccessScreenState extends State<AddSensorSuccessScreen> {
  bool _isNavigating = false;

  /// Purely resets the system routing pipeline to resolve native frame rendering crashes
  void _navigateToHome() {
    // Structural lock to shield application workflow from multiple concurrent interactions
    if (_isNavigating) return;

    setState(() => _isNavigating = true);

    if (mounted) {
      // Annihilates stack and structures an entirely fresh window loop lifecycle
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) =>
            false, // Purges the historical navigation route array seamlessly
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Visual Accentuation Element
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 88,
                  color: Colors.green[500],
                ),
              ),
              const SizedBox(height: 32),

              // Declarative Status Headers
              Text(
                "Sensor Linked Successfully!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "Your AquaMind IoT node is now authenticated, connected to local wireless infrastructure, and actively streaming soil matrix telemetry to the cloud platform.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // Execution Action Control Interface Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isNavigating ? null : _navigateToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isNavigating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "Return to Dashboard",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
