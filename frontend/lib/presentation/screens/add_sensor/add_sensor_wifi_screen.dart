import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'add_sensor_success_screen.dart';

class AddSensorWifiScreen extends StatefulWidget {
  final BluetoothDevice device;
  final String sensorName;
  final String plantType;
  final String locationType;
  final int dryToleranceDays;
  final double? latitude;
  final double? longitude;

  const AddSensorWifiScreen({
    super.key,
    required this.device,
    required this.sensorName,
    required this.plantType,
    required this.locationType,
    required this.dryToleranceDays,
    this.latitude,
    this.longitude,
  });

  @override
  State<AddSensorWifiScreen> createState() => _AddSensorWifiScreenState();
}

class _AddSensorWifiScreenState extends State<AddSensorWifiScreen> {
  String? ssid;
  String password = "";
  bool isLoading = false;
  String loadingStatusText = "Connecting to hardware...";
  List<WifiNetwork> networks = [];
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    scanWifi();
  }

  // Scans for localized physical 2.4GHz infrastructure router bands
  Future<void> scanWifi() async {
    try {
      List<WifiNetwork> result = await WiFiForIoTPlugin.loadWifiList();
      final uniqueMap = <String, WifiNetwork>{};
      for (var n in result) {
        if (n.ssid != null && n.ssid!.isNotEmpty) uniqueMap[n.ssid!] = n;
      }
      if (mounted) setState(() => networks = uniqueMap.values.toList());
    } catch (e) {
      print("❌ WiFi Transceiver Local Scan Error: $e");
    }
  }

  // Orchestrates the critical BLE handshake and delegates device onboarding to local ESP32 runtime
  Future<void> _handleFinish() async {
    if (ssid == null || isLoading) return;

    setState(() {
      isLoading = true;
      loadingStatusText = "Establishing BLE connection...";
    });

    try {
      // 1. Proactively cycle connection states to bypass Android status-133 errors
      try {
        await widget.device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {}

      await widget.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      if (Platform.isAndroid) {
        setState(
          () => loadingStatusText = "Optimizing data packet size (MTU)...",
        );
        await widget.device.requestMtu(223).catchError((_) => 0);
      }

      setState(() {
        loadingStatusText = "Locating device configuration protocols...";
      });

      var services = await widget.device.discoverServices();
      BluetoothCharacteristic? targetChar;

      // Extract native Nordic UART service interface pipelines
      for (var s in services) {
        if (s.uuid.toString().toUpperCase().contains("6E400001")) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toUpperCase().contains("6E400002")) {
              targetChar = c;
            }
          }
        }
      }

      if (targetChar == null) {
        throw Exception("Required BLE Characteristic not exposed.");
      }

      setState(() {
        loadingStatusText = "Provisioning network credentials over BLE...";
      });

      // 2. Wrap properties into uniform target payload package (including GPS coordinates)
      final payload = {
        "sensor_id": widget.device.remoteId.toString(),
        "name": widget.sensorName,
        "plant_type": widget.plantType,
        "location_type": widget.locationType,
        "dry_tolerance_days": widget.dryToleranceDays,
        "latitude": widget.latitude,
        "longitude": widget.longitude,
        "ssid": ssid,
        "password": password,
      };

      // 3. Dispatch data down to the ESP32 storage buffer
      await targetChar.write(
        utf8.encode(jsonEncode(payload)),
        withoutResponse: false,
      );

      setState(() {
        loadingStatusText =
            "Awaiting hardware cluster network synchronization...";
      });

      // 4. Terminate BLE interface and allow ESP32 standalone registration pipeline to settle
      await widget.device.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      // 5. Navigate immediately to success screen (Don't hold BLE flow for HTTP fetch)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AddSensorSuccessScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      print("❌ Fatal provision link system failure: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Provisioning failed. Please reset Bluetooth and retry.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
          "Network Provisioning",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Link Device to Internet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select your home router frequency below so your plant sensor can stream telemetry directly to your application.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Interactive Form Input Enclosure
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
                        // SSID Network Selection Field
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: networks.any((n) => n.ssid == ssid)
                              ? ssid
                              : null,
                          hint: const Text("Select WiFi Network"),
                          decoration: InputDecoration(
                            labelText: "Local Network SSID",
                            prefixIcon: const Icon(Icons.wifi),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: networks
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n.ssid,
                                  child: Text(n.ssid!),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => ssid = v),
                        ),
                        const SizedBox(height: 20),

                        // Encrypted Password Input Field
                        TextField(
                          obscureText: _obscurePassword,
                          onChanged: (v) => password = v,
                          decoration: InputDecoration(
                            labelText: "Network Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Execute dynamic configuration submission sequence
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (ssid == null || isLoading)
                          ? null
                          : _handleFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Connect Device",
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

          // Fullscreen blocking process modal overlay to shield UI during network injection
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(radius: 16),
                      const SizedBox(height: 20),
                      Text(
                        loadingStatusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
