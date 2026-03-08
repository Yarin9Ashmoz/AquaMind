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
  }
}
