class Sensor {
  final String sensorId;
  String name;
  final int moisture;
  final String plantType; // pot / garden
  final String locationType; // indoor / outdoor
  final DateTime lastUpdate;

  Sensor({
    required this.sensorId,
    required this.name,
    required this.moisture,
    required this.plantType,
    required this.locationType,
    required this.lastUpdate,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      sensorId: json["sensor_id"] ?? "",
      name: json["name"] ?? "",
      moisture: (json["moisture"] as num?)?.toInt() ?? 0,
      plantType: json["plant_type"] ?? "",
      locationType: json["location_type"] ?? "indoor",
      lastUpdate:
          DateTime.tryParse(json["last_update"] ?? "") ?? DateTime.now(),
    );
  }
}
