import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'add_sensor_wifi_screen.dart';
import '../../../data/services/api_service.dart';

class AddSensorConfigScreen extends StatefulWidget {
  final String deviceName;
  final BluetoothDevice device;

  const AddSensorConfigScreen({
    super.key,
    required this.deviceName,
    required this.device,
  });

  @override
  State<AddSensorConfigScreen> createState() => _AddSensorConfigScreenState();
}

class _AddSensorConfigScreenState extends State<AddSensorConfigScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();

  String plantType = "pot";
  String locationType = "indoor";
  int dryToleranceDays = 3;

  String? _aiPlantInfo;
  String? _aiLightRequirement;
  bool _isLoadingAi = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Pre-populates text editing fields with baseline BLE structural identifiers automatically
    _controller.text = widget.deviceName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fetches current GPS coordinates via Geolocator for dynamic weather processing
  Future<Position?> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location services are disabled on your device."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Location permissions are required for outdoor sensors.",
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location permissions are permanently denied."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (e) {
      debugPrint("❌ GPS Fetching Error: $e");
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  /// Triggers the device camera via ApiService, submits the picture to Gemini,
  /// and auto-fills the screen's interactive form controls with the response payload.
  void _onScanWithAiPressed() async {
    if (_isLoadingAi) return;

    setState(() {
      _isLoadingAi = true;
    });

    try {
      final result = await _apiService.identifyPlantWithAI();

      if (result == null) {
        if (mounted) setState(() => _isLoadingAi = false);
        return;
      }

      final String extractedName = result['plant_name'] ?? "";
      final int suggestedDays = result['watering_frequency_days'] ?? 3;
      final String? shortInfo = result['short_info'];
      final String? lightReq = result['light_requirement'];

      int clampedDays = suggestedDays;
      if (clampedDays < 0) clampedDays = 0;
      if (clampedDays > 14) clampedDays = 14;

      if (mounted) {
        setState(() {
          _controller.text = extractedName;
          dryToleranceDays = clampedDays;
          _aiPlantInfo = shortInfo;
          _aiLightRequirement = lightReq;
          _isLoadingAi = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Plant profile successfully processed by AquaMind AI!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAi = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Scanning Exception encountered: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Validates input, captures GPS location if outdoor, and navigates to WiFi provisioning
  void _onContinuePressed() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please assign a valid label to this sensor asset"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    double? latitude;
    double? longitude;

    // Fetch GPS coordinates only if the deployment environment is set to Outdoor
    if (locationType == "outdoor") {
      final Position? pos = await _getCurrentLocation();
      if (pos != null) {
        latitude = pos.latitude;
        longitude = pos.longitude;
        debugPrint("📍 Captured Location: Lat $latitude, Lon $longitude");
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSensorWifiScreen(
          device: widget.device,
          sensorName: _controller.text.trim(),
          plantType: plantType,
          locationType: locationType,
          dryToleranceDays: dryToleranceDays,
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: const Text(
          "Configure Settings",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hardware target identifier badge
              Row(
                children: [
                  Icon(
                    Icons.developer_board,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Hardware Target: ${widget.deviceName}",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Smart AI Feature Trigger Panel
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isLoadingAi ? null : _onScanWithAiPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isLoadingAi
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : Icon(
                                Icons.auto_awesome,
                                color: Colors.green[700],
                              ),
                        const SizedBox(width: 12),
                        Text(
                          _isLoadingAi
                              ? "Analyzing Plant Profile..."
                              : "Auto-Fill via Plant AI Camera",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Core Metadata Parameters Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sensor Label Form Input Control
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: "Sensor Name",
                        prefixIcon: const Icon(Icons.label_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Plant Layout Classification Dropdown Choice
                    DropdownButtonFormField<String>(
                      value: plantType,
                      decoration: InputDecoration(
                        labelText: "Plant Framework Type",
                        prefixIcon: const Icon(Icons.grass),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "pot",
                          child: Text("Potted Plant"),
                        ),
                        DropdownMenuItem(
                          value: "garden",
                          child: Text("Open Garden"),
                        ),
                      ],
                      onChanged: (v) => setState(() => plantType = v!),
                    ),
                    const SizedBox(height: 20),

                    // Deployment Zone Location Selection Control
                    DropdownButtonFormField<String>(
                      value: locationType,
                      decoration: InputDecoration(
                        labelText: "Deployment Environment",
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "indoor",
                          child: Text("Indoor Structure"),
                        ),
                        DropdownMenuItem(
                          value: "outdoor",
                          child: Text("Outdoor Field"),
                        ),
                      ],
                      onChanged: (v) => setState(() => locationType = v!),
                    ),
                    const SizedBox(height: 20),

                    // Moisture Degradation Dryness Tolerance Matrix Selection
                    DropdownButtonFormField<int>(
                      value: dryToleranceDays,
                      decoration: InputDecoration(
                        labelText: "Dry Tolerance Window",
                        helperText:
                            "Maximum continuous days allowed without water parameters",
                        prefixIcon: const Icon(Icons.wb_sunny_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: List.generate(15, (index) => index).map((
                        int value,
                      ) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            value == 0
                                ? "No delay (Immediate Alert)"
                                : "$value Days",
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => dryToleranceDays = v!),
                    ),
                  ],
                ),
              ),

              // Rich Text Computer Vision Output Meta-Card Block
              if (_aiPlantInfo != null || _aiLightRequirement != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green[50]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assistant_outlined,
                            color: Colors.green[700],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "AI Insights & Care Profile",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      if (_aiLightRequirement != null) ...[
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: "Light Needs: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              TextSpan(
                                text: _aiLightRequirement,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (_aiPlantInfo != null)
                        Text(
                          _aiPlantInfo!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Proceed to target hardware network provisioning stage execution
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoadingAi || _isGettingLocation)
                      ? null
                      : _onContinuePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isGettingLocation
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Acquiring GPS Location...",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          "Continue to WiFi Provisioning",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
