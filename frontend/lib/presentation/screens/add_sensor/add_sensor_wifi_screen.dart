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

  List<DropdownMenuItem<String>> _getUniqueWifiItems() {
    final seen = <String>{};

    return networks
        .where((n) => n.ssid != null && n.ssid!.isNotEmpty)
        .where((n) => seen.add(n.ssid!))
        .map((n) => DropdownMenuItem(
              value: n.ssid,
              child: Text(n.ssid!),
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

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Choose WiFi",
                prefixIcon: Icon(Icons.wifi),
              ),
              value: (ssid != null && networks.any((n) => n.ssid == ssid))
                  ? ssid
                  : null,
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

  Future<void> _handleFinish() async {

    if (ssid == null || ssid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select WiFi")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {

      final payload = {
        "name": widget.sensorName,
        "plantType": widget.plantType,
        "locationType": widget.locationType,
        "ssid": ssid,
        "password": password,
      };

      final jsonString = jsonEncode(payload);

      print("Connecting BLE...");

      await widget.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      print("Requesting MTU...");

      await widget.device.requestMtu(256);

      print("Discovering services...");

      List<BluetoothService> services =
          await widget.device.discoverServices();

      BluetoothService? service;

      for (var s in services) {
        if (s.uuid.toString().toUpperCase() ==
            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E") {
          service = s;
        }
      }

      if (service == null) {
        throw Exception("BLE Service not found");
      }

      BluetoothCharacteristic? characteristic;

      for (var c in service.characteristics) {
        if (c.uuid.toString().toUpperCase() ==
            "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") {
          characteristic = c;
        }
      }

      if (characteristic == null) {
        throw Exception("BLE Characteristic not found");
      }

      print("Sending WiFi credentials...");

      await characteristic.write(
        Uint8List.fromList(utf8.encode(jsonString)),
        withoutResponse: false,
      );

      await Future.delayed(const Duration(seconds: 2));

      print("Registering sensor in backend...");

      await context.read<DashboardState>().createSensor(
        sensorId: widget.device.id.toString(),
        name: widget.sensorName,
        plantType: widget.plantType,
        locationType: widget.locationType,
        moisture: 0.0,
      );

      await widget.device.disconnect();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AddSensorSuccessScreen(),
          ),
        );
      }

    } catch (e) {

      print("BLE ERROR: $e");

      try {
        await widget.device.disconnect();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection error: $e")),
        );
      }

    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}