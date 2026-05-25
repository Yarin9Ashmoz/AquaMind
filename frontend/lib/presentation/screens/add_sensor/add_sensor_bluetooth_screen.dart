import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_config_screen.dart';

class AddSensorBluetoothScreen extends StatefulWidget {
  const AddSensorBluetoothScreen({super.key});

  @override
  State<AddSensorBluetoothScreen> createState() =>
      _AddSensorBluetoothScreenState();
}

class _AddSensorBluetoothScreenState extends State<AddSensorBluetoothScreen> {
  List<ScanResult> devices = [];
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() async {
    setState(() {
      scanning = true;
      devices = [];
    });

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          devices = results
              .where(
                (r) => r.device.platformName.toUpperCase().contains("AQUAMIND"),
              )
              .toList();
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (e) {
      print("Scan Error: $e");
    }

    await Future.delayed(const Duration(seconds: 8));
    subscription.cancel();
    if (mounted) setState(() => scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Sensor")),
      body: scanning && devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No AquaMind sensors found"),
                  ElevatedButton(
                    onPressed: startScan,
                    child: const Text("Scan Again"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final d = devices[i];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(d.device.platformName),
                  subtitle: Text(d.device.remoteId.toString()),
                  onTap: () async {
                    await FlutterBluePlus.stopScan();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddSensorConfigScreen(
                          deviceName: d.device.platformName,
                          device: d.device,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
