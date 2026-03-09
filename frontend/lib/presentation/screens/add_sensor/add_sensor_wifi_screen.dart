import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'add_sensor_success_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:wifi_iot/wifi_iot.dart';
import '../../state/dashboard_state.dart';

class AddSensorWifiScreen extends StatefulWidget {
  final BluetoothDevice device;
  final String deviceName;
  final String sensorName;
  final String plantType;
  final String locationType;

  const AddSensorWifiScreen({
    super.key,
    required this.device,
    required this.deviceName,
    required this.sensorName,
    required this.plantType,
    required this.locationType,
  });

  @override
  State<AddSensorWifiScreen> createState() => _AddSensorWifiScreenState();
}

class _AddSensorWifiScreenState extends State<AddSensorWifiScreen> {
  String? ssid; // Changed to nullable to prevent Dropdown Assertion Error
  String password = "";
  bool isLoading = false;
  List<WifiNetwork> networks = [];

  @override
  void initState() {
    super.initState();
    scanWifi(); // Start scanning for local networks immediately
  }

  /// Scans for nearby WiFi networks using the wifi_iot plugin
  Future<void> scanWifi() async {
    try {
      List<WifiNetwork> result = await WiFiForIoTPlugin.loadWifiList();
      if (mounted) {
        setState(() {
          networks = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("WiFi scan failed: ${e.toString()}")),
        );
      }
    }
  }

  /// Filters out duplicate SSIDs and null values to prevent Dropdown crashes
  List<DropdownMenuItem<String>> _getUniqueWifiItems() {
    final seenSsid = <String>{};
    return networks
        .where((net) => net.ssid != null && net.ssid!.isNotEmpty)
        .where((net) => seenSsid.add(net.ssid!)) // Only allow unique SSIDs
        .map((net) => DropdownMenuItem(
              value: net.ssid,
              child: Text(net.ssid!),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WiFi Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connect your sensor to WiFi",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // WiFi SSID Dropdown with duplicate protection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Choose WiFi",
                prefixIcon: Icon(Icons.wifi),
              ),
              // Safety check: only set value if it exists in the current network list
              value: (ssid != null && networks.any((net) => net.ssid == ssid)) ? ssid : null,
              items: _getUniqueWifiItems(),
              onChanged: (value) {
                setState(() {
                  ssid = value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: "WiFi Password",
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onChanged: (v) => password = v,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleFinish,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Finish"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Orchestrates BLE data transmission and Backend registration
  Future<void> _handleFinish() async {
    if (ssid == null || ssid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a WiFi network")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Prepare JSON payload for the ESP32
      final payload = {
        "name": widget.sensorName,
        "plantType": widget.plantType,
        "locationType": widget.locationType,
        "ssid": ssid,
        "password": password,
      };

      final jsonString = jsonEncode(payload);

      // 2. Ensure Bluetooth connection is active
      if (widget.device.connectionState != BluetoothConnectionState.connected) {
        await widget.device.connect();
      }

      // 3. Find the specific BLE Service and Characteristic (matching ESP32 UUIDs)
      List<BluetoothService> services = await widget.device.discoverServices();
      
      final service = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase() == "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
      );

      final characteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
      );

      // 4. Send the WiFi credentials to the ESP32 over BLE
      await characteristic.write(
        Uint8List.fromList(utf8.encode(jsonString)),
        withoutResponse: false,
      );

      // 5. Register the sensor in the Cloud Backend (Render)
      // Note: We use the MAC address (device.id) as the sensorId
      await context.read<DashboardState>().createSensor(
        sensorId: widget.device.id.toString(),
        name: widget.sensorName,
        plantType: widget.plantType,
        locationType: widget.locationType,
        moisture: 0,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AddSensorSuccessScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}