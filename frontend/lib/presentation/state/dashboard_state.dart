import 'package:flutter/material.dart';
import '../../data/models/sensor.dart';
import '../../data/repositories/sensor_repository.dart';

class DashboardState extends ChangeNotifier {
  final SensorRepository repo;

  List<Sensor> sensors = [];
  Sensor? selectedSensor;
  bool isLoading = false;
  String? error;

  DashboardState(this.repo) {
    loadSensors(); 
  }

  Future<void> loadSensors() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      sensors = await repo.getSensors();

      if (selectedSensor != null) {
        try {
          selectedSensor = sensors.firstWhere(
            (s) => s.sensorId == selectedSensor!.sensorId,
          );
        } catch (_) {
          selectedSensor = sensors.isNotEmpty ? sensors.first : null;
        }
      } else if (sensors.isNotEmpty) {
        selectedSensor = sensors.first;
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      error = e.toString();
      notifyListeners();
      print("❌ Error loading sensors: $e");
    }
  }

  Future<void> fetchSensors() => loadSensors();

  Future<void> deleteAllSensors() async {
    try {
      isLoading = true;
      notifyListeners();

      await repo.deleteAllSensors();

      sensors = [];
      selectedSensor = null;

      isLoading = false;
      notifyListeners();
      print("✅ All sensors deleted successfully");
    } catch (e) {
      isLoading = false;
      error = "Failed to delete all sensors: $e";
      notifyListeners();
      print("❌ Error deleting all sensors: $e");
    }
  }

  Future<void> deleteSensorById(String sensorId) async {
    try {
      await repo.deleteSensor(sensorId: sensorId);
      sensors.removeWhere((s) => s.sensorId == sensorId);
      if (selectedSensor?.sensorId == sensorId) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }
      notifyListeners();
    } catch (e) {
      error = "Delete failed: $e";
      notifyListeners();
    }
  }

  Future<void> deleteSensorByName(String name) async {
    try {
      await repo.deleteSensor(name: name);
      sensors.removeWhere((s) => s.name == name);
      if (selectedSensor?.name == name) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }
      notifyListeners();
    } catch (e) {
      error = "Delete failed: $e";
      notifyListeners();
    }
  }

  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      await repo.renameSensor(sensorId, newName);
      await loadSensors(); // רענון נתונים
    } catch (e) {
      error = "Rename failed: $e";
      notifyListeners();
    }
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays,
  }) async {
    try {
      await repo.createSensor(
        sensorId: sensorId,
        name: name,
        plantType: plantType,
        locationType: locationType,
        moisture: moisture,
        dryToleranceDays: dryToleranceDays,
        
      );
      await loadSensors();
    } catch (e) {
      error = "Creation failed: $e";
      notifyListeners();
    }
  }

  void selectSensor(Sensor sensor) {
    selectedSensor = sensor;
    notifyListeners();
  }

  String get statusText {
    if (selectedSensor == null) return "No data";
    final m = selectedSensor!.moisture;
    if (m < 30) return "Dry – needs watering";
    if (m < 60) return "Moisture level is normal";
    return "Too wet";
  }

  String get lastUpdateText {
    if (selectedSensor == null) return "";
    return selectedSensor!.lastUpdate.toString();
  }
}
