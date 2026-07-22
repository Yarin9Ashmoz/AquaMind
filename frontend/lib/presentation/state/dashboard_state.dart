import 'package:flutter/material.dart';
import '../../data/models/sensor.dart';
import '../../data/repositories/sensor_repository.dart';

class DashboardState extends ChangeNotifier {
  final SensorRepository repo;

  List<Sensor> sensors = [];
  Sensor? selectedSensor;

  bool isLoading = false; // Primary full-screen view state fetch manager
  bool isActionLoading = false; // Micro-interaction background loading toggle
  String? error;

  DashboardState(this.repo) {
    loadSensors();
  }

  /// Fetches the latest sensor configuration array from remote database
  Future<void> loadSensors() async {
    // Prevent overlapping synchronization pipelines
    if (isLoading) return;

    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final fetchedSensors = await repo.getSensors();

      // DE-DUPLICATION: Safely filter out any duplicate IDs returned by faulty network cycles
      final seenIds = <String>{};
      sensors = fetchedSensors.where((s) => seenIds.add(s.sensorId)).toList();

      // Synchronize currently active screen target with fresh network metrics
      if (selectedSensor != null) {
        final index = sensors.indexWhere(
          (s) => s.sensorId == selectedSensor!.sensorId,
        );
        selectedSensor = index != -1
            ? sensors[index]
            : (sensors.isNotEmpty ? sensors.first : null);
      } else if (sensors.isNotEmpty) {
        selectedSensor = sensors.first;
      }

      error = null;
    } catch (e) {
      error = "Sync Failure: Check your connection or cloud status.";
      print("❌ Error loading sensors: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Requests the remote ESP32 unit to execute an instantaneous analog moisture measurement
  Future<void> requestMeasurement(String sensorId) async {
    try {
      error = null;
      // Triggers manual polling downstream via backend router
      await repo.requestManualSample(sensorId);
      print("📡 Telemetry operational command transmitted: $sensorId");
    } catch (e) {
      error = "Hardware polling request failed. Node may be offline.";
      print("❌ Error requesting measurement: $e");
      notifyListeners();
      rethrow;
    }
  }

  /// Alias for pull-to-refresh architecture components
  Future<void> fetchSensors() => loadSensors();

  /// Completely purges all structural nodes linked with the user profile
  Future<void> deleteAllSensors() async {
    if (isActionLoading) return;

    try {
      isActionLoading = true;
      error = null;
      notifyListeners();

      await repo.deleteAllSensors();

      sensors = [];
      selectedSensor = null;
    } catch (e) {
      error = "Full ecosystem wipe rejected: $e";
      print("❌ Error dropping entire table: $e");
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Removes an individual tracking node utilizing its unique identifier string
  Future<void> deleteSensorById(String sensorId) async {
    try {
      error = null;
      await repo.deleteSensor(sensorId: sensorId);

      sensors.removeWhere((s) => s.sensorId == sensorId);

      if (selectedSensor?.sensorId == sensorId) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }

      notifyListeners();
    } catch (e) {
      error = "Target node deletion failed: $e";
      notifyListeners();
    }
  }

  /// Removes an individual tracking node utilizing its user-defined name token
  Future<void> deleteSensorByName(String name) async {
    try {
      error = null;
      await repo.deleteSensor(name: name);

      sensors.removeWhere((s) => s.name == name);

      if (selectedSensor?.name == name) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }

      notifyListeners();
    } catch (e) {
      error = "Target node asset deletion failed: $e";
      notifyListeners();
    }
  }

  /// Updates a device identification label across infrastructure layers
  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      error = null;
      await repo.renameSensor(sensorId, newName);
      await loadSensors();
    } catch (e) {
      error = "Label modification dropped by server: $e";
      notifyListeners();
    }
  }

  /// Provisions a fresh operational hardware metadata node onto the platform map
  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays,
  }) async {
    // BLOCK DOUBLE TRIGGER: Prevent rapid twin taps or race conditions from executing twice
    if (isActionLoading) return;

    try {
      isActionLoading = true;
      error = null;
      notifyListeners();

      await repo.createSensor(
        sensorId: sensorId,
        name: name,
        plantType: plantType,
        locationType: locationType,
        moisture: moisture,
        dryToleranceDays: dryToleranceDays,
      );

      // Force high-priority clean sync immediately after successful pipeline creation
      await loadSensors();
    } catch (e) {
      error = "Infrastructure asset registration failure: $e";
      print("❌ Error creating sensor: $e");
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Shifts active view targeting mechanics to a selected physical telemetry entity
  void selectSensor(Sensor sensor) {
    selectedSensor = sensor;
    notifyListeners();
  }

  /// Explicitly flushes the error banner buffer state to clear user interface real-estate
  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  /// Interprets raw soil metrics into dynamic, action-oriented natural descriptions
  String get statusText {
    if (selectedSensor == null) return "No active nodes monitored";
    final m = selectedSensor!.moisture;
    if (m < 30) return "Dry – critical watering needed";
    if (m < 60) return "Optimal hydration equilibrium";
    return "Saturation threshold exceeded";
  }

  String get lastUpdateText {
    if (selectedSensor == null) return "";
    return selectedSensor!.lastUpdate.toString();
  }
}
