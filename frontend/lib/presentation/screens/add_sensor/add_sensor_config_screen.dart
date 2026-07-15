import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_wifi_screen.dart';
import '../../../data/services/api_service.dart'; 

class AddSensorConfigScreen extends StatefulWidget {
  final String deviceName;
  final BluetoothDevice device;

  const AddSensorConfigScreen({super.key, required this.deviceName, required this.device});

  @override
  State<AddSensorConfigScreen> createState() => _AddSensorConfigScreenState();
}

class _AddSensorConfigScreenState extends State<AddSensorConfigScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService(); // Instance of your updated cloud API service
  
  String plantType = "pot";
  String locationType = "indoor";
  int dryToleranceDays = 3; 
  
  // Local state variables to hold extra informational metadata fetched from Gemini
  String? _aiPlantInfo;
  String? _aiLightRequirement;
  bool _isLoadingAi = false;

  @override
  void dispose() {
    _controller.dispose(); 
    super.dispose();
  }

  /// Triggers the device camera via ApiService, submits the picture to Gemini,
  /// and auto-fills the screen's interactive form controls with the response.
  void _onScanWithAiPressed() async {
    try {
      // 1. Fire the combined camera picker and multipart upload request
      final result = await _apiService.identifyPlantWithAI();
      
      // Safety exit if the operation was aborted by the user
      if (result == null) return;

      // 2. Reflect loading state on the UI thread
      setState(() {
        _isLoadingAi = true;
      });

      // 3. Extract and safely clamp values returning from the GenAI backend dictionary
      final String extractedName = result['plant_name'] ?? "";
      final int suggestedDays = result['watering_frequency_days'] ?? 3;
      final String? shortInfo = result['short_info'];
      final String? lightReq = result['light_requirement'];

      // Clamp target days to safe bounds supported by the 0-14 generated dropdown items
      int clampedDays = suggestedDays;
      if (clampedDays < 0) clampedDays = 0;
      if (clampedDays > 14) clampedDays = 14;

      // 4. Bind the model outputs to the UI state variables
      setState(() {
        _controller.text = extractedName;
        dryToleranceDays = clampedDays;
        _aiPlantInfo = shortInfo;
        _aiLightRequirement = lightReq;
        _isLoadingAi = false;
      });

      // Notify user of successful parsing completion
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plant profile successfully processed by AquaMind AI!")),
        );
      }

    } catch (e) {
      setState(() {
        _isLoadingAi = false;
      });
      
      // Handle fallback and bubble network or exception logs out onto a SnackBar overlay
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI Scanning Exception encountered: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configure Sensor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView( // Wrapped in scroll view to prevent layout overflows with newly added info cards
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Device: ${widget.deviceName}", 
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // NEW: AI Identification Action Trigger Banner
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingAi ? null : _onScanWithAiPressed,
                  icon: _isLoadingAi 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isLoadingAi ? "Analyzing Plant Furiously..." : "Auto-Fill Setup via Plant AI Camera"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Sensor Name",
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: plantType,
                decoration: const InputDecoration(labelText: "Plant Type", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: "pot", child: Text("Pot")),
                  DropdownMenuItem(value: "garden", child: Text("Garden")),
                ],
                onChanged: (v) => setState(() => plantType = v!),
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: locationType,
                decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: "indoor", child: Text("Indoor")),
                  DropdownMenuItem(value: "outdoor", child: Text("Outdoor")),
                ],
                onChanged: (v) => setState(() => locationType = v!),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: dryToleranceDays,
                decoration: const InputDecoration(
                  labelText: "Dry Tolerance (Days)", 
                  helperText: "For how many days can the plant stay dry?",
                  border: OutlineInputBorder()
                ),
                items: List.generate(15, (index) => index).map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value == 0 ? "No delay (0 days)" : "$value Days"),
                  );
                }).toList(),
                onChanged: (v) => setState(() => dryToleranceDays = v!),
              ),
              
              // NEW: Conditional UI Card Block to display rich AI data if available
              if (_aiPlantInfo != null || _aiLightRequirement != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green.shade50.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.eco, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "AI Insights & Care Profile",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (_aiLightRequirement != null) ...[
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: "Light Needs: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: _aiLightRequirement),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (_aiPlantInfo != null)
                          Text(_aiPlantInfo!, style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 40), // Spacing buffer before action buttons
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_controller.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a sensor name")),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddSensorWifiScreen(
                          device: widget.device,
                          sensorName: _controller.text,
                          plantType: plantType,
                          locationType: locationType,
                          dryToleranceDays: dryToleranceDays, 
                        ),
                      ),
                    );
                  },
                  child: const Text("Continue to WiFi"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}