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

}
