import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_success_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:wifi_iot/wifi_iot.dart';
import '../../../data/services/api_service.dart';


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
  String ssid = "";
  String password = "";
  bool isLoading = false;

  List<WifiNetwork> networks = [];

  @override
  void initState() {
    super.initState();
    scanWifi();
  }

  Future<void> scanWifi() async {
    List<WifiNetwork> result = await WiFiForIoTPlugin.loadWifiList();
    setState(() {
      networks = result;
    });
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

            // WiFi SSID dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Choose WiFi"),
              items: networks
                  .map(
                    (net) => DropdownMenuItem(
                      value: net.ssid,
                      child: Text(net.ssid ?? "Unknown"),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  ssid = value ?? "";
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(labelText: "WiFi Password"),
              obscureText: true,
              onChanged: (v) => password = v,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);

                        final payload = {
                          "name": widget.sensorName,
                          "plantType": widget.plantType,
                          "locationType": widget.locationType,
                          "ssid": ssid,
                          "password": password,
                        };

                        final jsonString = jsonEncode(payload);

                        if (widget.device.connectionState !=
                            BluetoothConnectionState.connected) {
                          await widget.device.connect();
                        }

                        List<BluetoothService> services = await widget.device
                            .discoverServices();

                        final service = services.firstWhere(
                          (s) =>
                              s.uuid.toString().toUpperCase() ==
                              "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
                        );

                        final characteristic = service.characteristics
                            .firstWhere(
                              (c) =>
                                  c.uuid.toString().toUpperCase() ==
                                  "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
                            );

                        await characteristic.write(
                          Uint8List.fromList(utf8.encode(jsonString)),
                          withoutResponse: false,
                        );

                        await ApiService().createSensor(
                          sensorId: widget.device.id.toString(),
                          name: widget.sensorName,
                          plantType: widget.plantType,
                          moisture: 0, 
                        );


                        setState(() => isLoading = false);

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddSensorSuccessScreen(),
                          ),
                        );
                      },
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
