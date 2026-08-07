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

  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  bool _unexpectedlyDisconnected = false;

  @override
  void initState() {
    super.initState();
    scanWifi();
  }

  @override
  void dispose() {
    _connStateSub?.cancel();
    super.dispose();
  }

  // Scans for localized physical 2.4GHz infrastructure router bands
  Future<void> scanWifi() async {
    try {
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

  // Orchestrates the critical BLE handshake and delegates device onboarding
  Future<void> _handleFinish() async {
    if (ssid == null || isLoading) return;

    setState(() {
      isLoading = true;
      loadingStatusText = "Establishing BLE connection...";
    });

    await _connStateSub?.cancel();
    _connStateSub = null;

    try {
      const maxConnectAttempts = 3;
      BluetoothCharacteristic? targetChar;
      // Conservative default: the un-negotiated Android ATT MTU is 23 bytes,
      // leaving 20 usable payload bytes after the 3-byte ATT header.
      int mtuPayloadLimit = 20;

      for (int attempt = 1; attempt <= maxConnectAttempts; attempt++) {
        // Proactively cycle connection state to bypass Android status-133 errors
        await _connStateSub?.cancel();
        _connStateSub = null;
        try {
          await widget.device.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 800));

        setState(() {
          loadingStatusText = attempt == 1
              ? "Establishing BLE connection..."
              : "Retrying BLE connection (attempt $attempt/$maxConnectAttempts)...";
        });

        try {
          // 1. Connect without forcing MTU upfront
          await widget.device.connect(
            timeout: const Duration(seconds: 10),
            autoConnect: false,
          );

          // Don't trust the connect() future alone on Android — wait for the
          // platform to actually report a connected state before touching
          // GATT, then keep listening so a mid-transfer drop can be detected
          // instead of hanging or throwing an opaque platform exception.
          _unexpectedlyDisconnected = false;
          await widget.device.connectionState
              .firstWhere((s) => s == BluetoothConnectionState.connected)
              .timeout(const Duration(seconds: 5));

          _connStateSub = widget.device.connectionState.listen((state) {
            if (state == BluetoothConnectionState.disconnected) {
              _unexpectedlyDisconnected = true;
            }
          });

          // Allow Android GATT layer to stabilize
          await Future.delayed(const Duration(milliseconds: 600));

          setState(() {
            loadingStatusText = "Locating device configuration protocols...";
          });

          // 2. DISCOVER SERVICES FIRST (Crucial order fix)
          var services = await widget.device.discoverServices();

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

          // 3. OPTIONAL: Safely optimize connection parameters after services are discovered
          if (Platform.isAndroid) {
            try {
              await widget.device.requestConnectionPriority(
                connectionPriorityRequest: ConnectionPriority.high,
              );
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (_) {}

            try {
              await widget.device
                  .requestMtu(223)
                  .timeout(const Duration(seconds: 3));
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (mtuErr) {
              print(
                "⚠️ MTU negotiation timed out/failed — falling back to 20-byte chunked writes: $mtuErr",
              );
            }
          }

          // Use whatever MTU actually got negotiated (falls back to the
          // conservative 20-byte default declared above if it never changed).
          final negotiatedMtu = widget.device.mtuNow;
          if (negotiatedMtu > 23) {
            mtuPayloadLimit = negotiatedMtu - 3;
          }

          break; // Handshake succeeded!
        } catch (e) {
          print("⚠️ BLE Handshake Attempt $attempt failed: $e");
          await _connStateSub?.cancel();
          _connStateSub = null;
          if (attempt == maxConnectAttempts) rethrow;
        }
      }

      final resolvedChar = targetChar!;

      setState(() {
        loadingStatusText = "Provisioning network credentials over BLE...";
      });

      // Wrap properties into uniform target payload package
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

      // '\n' terminates the message so the ESP32 can reassemble chunks; it
      // never occurs raw inside jsonEncode's output (newlines in string
      // values are escaped as the two characters \ and n).
      final payloadBytes = utf8.encode("${jsonEncode(payload)}\n");

      // Dispatch data down to the ESP32 storage buffer, chunked to whatever
      // MTU was actually negotiated so a single oversized write can't get
      // silently truncated or tear down the GATT connection.
      await _writeChunked(resolvedChar, payloadBytes, mtuPayloadLimit);

      // Give the peripheral a beat to finish processing the last chunk
      // before we tear the link down — each chunk write already awaits its
      // ATT write response, this is just extra headroom for the firmware's
      // own JSON parse to run before the radio goes away.
      await Future.delayed(const Duration(milliseconds: 300));

      await _connStateSub?.cancel();
      _connStateSub = null;

      // Terminate BLE interface so ESP32 is free to join WiFi
      try {
        await widget.device.disconnect();
      } catch (_) {}

      setState(() {
        loadingStatusText = "Waiting for hardware to come online...";
      });

      // Poll backend until the sensor registers
      if (mounted) {
        final dashboardState = context.read<DashboardState>();
        final deadline = DateTime.now().add(const Duration(seconds: 8));
        while (mounted && DateTime.now().isBefore(deadline)) {
          await dashboardState.loadSensors(force: true);
          if (dashboardState.sensors.any((s) => s.name == widget.sensorName)) {
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Navigate to success screen
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
      await _connStateSub?.cancel();
      _connStateSub = null;
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Writes [bytes] to [char] in sequential chunks no larger than [chunkSize],
  // awaiting each chunk's ATT write response before sending the next. This
  // is what makes both MTU-negotiation failure and oversized single writes
  // safe: on Android, a write() larger than the negotiated MTU can silently
  // truncate or tear down the GATT connection instead of erroring cleanly.
  Future<void> _writeChunked(
    BluetoothCharacteristic char,
    List<int> bytes,
    int chunkSize,
  ) async {
    final safeChunkSize = chunkSize.clamp(20, 512);
    for (int offset = 0; offset < bytes.length; offset += safeChunkSize) {
      if (_unexpectedlyDisconnected) {
        throw Exception("BLE device disconnected mid-transfer.");
      }
      final end = (offset + safeChunkSize < bytes.length)
          ? offset + safeChunkSize
          : bytes.length;

      await char
          .write(bytes.sublist(offset, end), withoutResponse: false)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw Exception("BLE write timed out mid-transfer."),
          );

      // Brief pacing gap so the ESP32 BLE stack's internal queue isn't
      // overrun by back-to-back writes.
      await Future.delayed(const Duration(milliseconds: 30));
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
