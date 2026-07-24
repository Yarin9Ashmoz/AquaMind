import '../models/sensor.dart';
import '../services/api_service.dart';

class SensorRepository {
  final ApiService api;

  SensorRepository(this.api);

  Future<List<Sensor>> getSensors() async {
    final data = await api.getSensors();
    // Converts raw JSON list into a list of Sensor objects
    return data.map<Sensor>((json) => Sensor.fromJson(json)).toList();
  }

  /// Updates threshold and sync interval configuration on remote server
  Future<void> updateSensorConfig({
    required String sensorId,
    required double threshold,
    required int syncInterval,
  }) async {
    await api.updateSensorConfig(
      sensorId: sensorId,
      threshold: threshold,
      syncInterval: syncInterval,
    );
  }

  Future<void> requestManualSample(String sensorId) async {
    await api.requestManualSample(sensorId);
  }

  Future<void> renameSensor(String sensorId, String newName) async {
    await api.renameSensor(sensorId, newName);
  }

  Future<void> deleteAllSensors() async {
    await api.deleteAllSensors();
  }

  Future<void> deleteSensor({String? sensorId, String? name}) async {
    await api.deleteSensor(sensorId: sensorId, name: name);
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays, // Added to match ApiService
  }) async {
    // Forwarding the call to the API layer
    await api.createSensor(
      sensorId: sensorId,
      name: name,
      plantType: plantType,
      locationType: locationType,
      moisture: moisture,
      dryToleranceDays: dryToleranceDays, // Pass it through
    );
  }
}