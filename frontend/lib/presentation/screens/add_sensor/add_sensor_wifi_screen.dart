import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../../state/dashboard_state.dart';
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
      // Android requires ACCESS_FINE_LOCATION to be granted at runtime before
      // WifiManager will return any scan results, regardless of whether the
      // config screen already asked for it (it only does for outdoor sensors).
      if (Platform.isAndroid) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Location permission is required to scan for WiFi networks.",
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      List<WifiNetwork> result = await WiFiForIoTPlugin.loadWifiList();
      final uniqueMap = <String, WifiNetwork>{};
      for (var n in result) {
        if (n.ssid != null && n.ssid!.isNotEmpty) uniqueMap[n.ssid!] = n;
      }
      if (mounted) setState(() => networks = uniqueMap.values.toList());
    } catch (e) {
      print("❌ WiFi Transceiver Local Scan Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't scan for WiFi networks: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
      // 1. Establish the BLE connection, retrying a couple of times if the
      // handshake times out. This is usually transient radio contention on
      // the ESP32 (its WiFi and BLE share one radio) rather than a
      // permanent failure, so a fresh disconnect/reconnect cycle tends to
      // succeed once the contention clears.
      const maxConnectAttempts = 3;
      for (int attempt = 1; attempt <= maxConnectAttempts; attempt++) {
        // Proactively cycle connection state to bypass Android status-133 errors
        try {
          await widget.device.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}

        setState(() {
          loadingStatusText = attempt == 1
              ? "Establishing BLE connection..."
              : "Retrying BLE connection (attempt $attempt/$maxConnectAttempts)...";
        });

        try {
          await widget.device.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: false,
          );
          break;
        } catch (e) {
          if (attempt == maxConnectAttempts) rethrow;
        }
      }

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

      // 4. Terminate BLE interface so the ESP32 is free to join WiFi and register itself
      await widget.device.disconnect();

      setState(() {
        loadingStatusText = "Waiting for hardware to come online...";
      });

      // 5. Poll the backend until the newly provisioned sensor shows up (the ESP32
      // needs time to join WiFi and POST its registration) instead of assuming a
      // fixed 2s delay is enough, which raced ahead of the hardware and made the
      // sensor missing from the dashboard until the app was restarted.
      if (mounted) {
        final dashboardState = context.read<DashboardState>();
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (mounted && DateTime.now().isBefore(deadline)) {
          await dashboardState.loadSensors(force: true);
          if (dashboardState.sensors.any((s) => s.name == widget.sensorName)) {
            break;
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // 6. Navigate to success screen
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
