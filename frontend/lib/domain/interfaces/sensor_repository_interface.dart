import '../entities/sensor_data.dart';

abstract class SensorRepositoryInterface {
  Future<SensorData> getSensorData();
}
