import '../entities/sensor_data.dart';

class ShouldWaterPlants {
  bool call(SensorData data) {
    return data.moisture < 30;
  }
}
