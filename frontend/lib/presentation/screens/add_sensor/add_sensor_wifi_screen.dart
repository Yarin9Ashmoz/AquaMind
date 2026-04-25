import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:wifi_iot/wifi_iot.dart';
import '../../state/dashboard_state.dart';
import 'add_sensor_success_screen.dart';

class AddSensorWifiScreen extends StatefulWidget {
  final BluetoothDevice device;
  final String sensorName;
  final String plantType;
  final String locationType;
  final int dryToleranceDays; // Received from Config Screen

  const AddSensorWifiScreen({
    super.key,
    required this.device,
    required this.sensorName,
    required this.plantType,
    required this.locationType,
    required this.dryToleranceDays, // Added to constructor
  });

  @override
  State<AddSensorWifiScreen> createState() => _AddSensorWifiScreenState();
}

class _AddSensorWifiScreenState extends State<AddSensorWifiScreen> {
  String? ssid;
  String password = "";
  bool isLoading = false;
  List<WifiNetwork> networks = [];

  @override
  void initState() {
    super.initState();
    scanWifi();
  }

  Future<void> scanWifi() async {
    try {
      List<WifiNetwork> result = await WiFiForIoTPlugin.loadWifiList();
      // Filter duplicates and empty SSIDs
      final uniqueMap = <String, WifiNetwork>{};
      for (var n in result) {
        if (n.ssid != null && n.ssid!.isNotEmpty) uniqueMap[n.ssid!] = n;
      }
      if (mounted) setState(() => networks = uniqueMap.values.toList());
    } catch (e) {
      print("❌ WiFi Scan Error: $e");
    }
  }

  Future<void> _handleFinish() async {
    if (ssid == null) return;
    if (mounted) setState(() => isLoading = true);

    try {
      // 1. Reset connection to prevent Error 133
      try {
        await widget.device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {}

      await widget.device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      
      if (Platform.isAndroid) {
        await widget.device.requestMtu(223).catchError((_) => 0);
      }

      var services = await widget.device.discoverServices();
      BluetoothCharacteristic? targetChar;
      
      for (var s in services) {
        // Search for the specific UART Service UUID
        if (s.uuid.toString().toUpperCase().contains("6E400001")) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toUpperCase().contains("6E400002")) {
              targetChar = c;
            }
          }
        }
      }

      if (targetChar == null) throw Exception("BLE Characteristic not found");

      // 2. Prepare payload for the Hardware (ESP32)
      final payload = {
        "name": widget.sensorName,
        "plant_type": widget.plantType,
        "location_type": widget.locationType,
        "dry_tolerance_days": widget.dryToleranceDays, // Sending config to hardware
        "ssid": ssid,
        "password": password,
      };

      // 3. Write data to the Sensor via Bluetooth
      await targetChar.write(utf8.encode(jsonEncode(payload)), withoutResponse: false);
      await Future.delayed(const Duration(seconds: 2));

      // 4. Create the sensor record in the Cloud/Backend via Provider
      if (mounted) {
        await context.read<DashboardState>().createSensor(
          sensorId: widget.device.remoteId.toString(),
          name: widget.sensorName,
          plantType: widget.plantType,
          locationType: widget.locationType,
          moisture: 0.0, // Initial moisture value
          dryToleranceDays: widget.dryToleranceDays, // Critical: Pass to API
        );
      }

      await widget.device.disconnect();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AddSensorSuccessScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      print("❌ Error in _handleFinish: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection failed. Please restart Bluetooth.")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WiFi Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: networks.any((n) => n.ssid == ssid) ? ssid : null,
              hint: const Text("Select WiFi Network"),
              items: networks.map((n) => DropdownMenuItem(
                value: n.ssid, 
                child: Text(n.ssid!)
              )).toList(),
              onChanged: (v) => setState(() => ssid = v),
              decoration: const InputDecoration(
                labelText: "Network SSID", 
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: "Password", 
                border: OutlineInputBorder()
              ),
              obscureText: true,
              onChanged: (v) => password = v,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
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
}