import 'package:flutter/material.dart';
import '../../data/models/sensor.dart';
import '../../data/repositories/sensor_repository.dart';

class DashboardState extends ChangeNotifier {
  final SensorRepository repo;

  List<Sensor> sensors = [];
  Sensor? selectedSensor;
  bool isLoading = false;
  String? error;

  DashboardState(this.repo);

  Future<void> loadSensors() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      sensors = await repo.getSensors();

      if (sensors.isNotEmpty) {
        selectedSensor = sensors.first;
      } else {
        selectedSensor = null;
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      error = e.toString();
      notifyListeners();
    }
  }

  String get statusText {
    if (selectedSensor == null) return "";
    final m = selectedSensor!.moisture;

    if (m < 30) return "Dry – needs watering";
    if (m < 60) return "Moisture level is normal";
    return "Too wet";
  }

  String get lastUpdateText {
    if (selectedSensor == null) return "";
    return selectedSensor!.lastUpdate.toString();
  }

  Future<void> renameSensor(String sensorId, String newName) async {
    await repo.renameSensor(sensorId, newName);

    final index = sensors.indexWhere((s) => s.sensorId == sensorId);
    if (index != -1) {
      sensors[index].name = newName;
    }

    if (selectedSensor?.sensorId == sensorId) {
      selectedSensor!.name = newName;
    }

    notifyListeners();
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required int moisture,
  }) async {
    await repo.createSensor(
      sensorId: sensorId,
      name: name,
      plantType: plantType,
      locationType: locationType,
      moisture: moisture,
    );
    await loadSensors();
  }

  Future<void> deleteAllSensors() async {
    await repo.deleteAllSensors();

    sensors = [];
    selectedSensor = null;
    notifyListeners();
  }

  Future<void> deleteSensorById(String sensorId) async {
    await repo.deleteSensor(sensorId: sensorId);

    sensors.removeWhere((s) => s.sensorId == sensorId);
    if (selectedSensor?.sensorId == sensorId) {
      selectedSensor = sensors.isNotEmpty ? sensors.first : null;
    }
    notifyListeners();
  }

  Future<void> deleteSensorByName(String name) async {
    await repo.deleteSensor(name: name);

    sensors.removeWhere((s) => s.name == name);
    if (selectedSensor?.name == name) {
      selectedSensor = sensors.isNotEmpty ? sensors.first : null;
    }
    notifyListeners();
  }
}
