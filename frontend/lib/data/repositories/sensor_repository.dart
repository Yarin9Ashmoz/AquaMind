import '../models/sensor.dart';
import '../services/api_service.dart';

class SensorRepository {
  final ApiService api;

  SensorRepository(this.api);

  Future<List<Sensor>> getSensors() async {
    final data = await api.getSensors();
    return data.map<Sensor>((json) => Sensor.fromJson(json)).toList();
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
  }) async {
    await api.createSensor(
      sensorId: sensorId,
      name: name,
      plantType: plantType,
      locationType: locationType,
      moisture: moisture,
    );
  }
}
