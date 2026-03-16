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
    // Support both snake_case and camelCase payloads (backend can change)
    final sensorId = json["sensor_id"] ?? json["sensorId"] ?? "";
    final plantType = json["plant_type"] ?? json["plantType"] ?? "";
    final locationType =
        json["location_type"] ?? json["locationType"] ?? "indoor";
    final lastUpdateRaw = json["last_update"] ?? json["lastUpdate"] ?? "";

    return Sensor(
      sensorId: sensorId,
      name: json["name"] ?? "",
      moisture: (json["moisture"] as num?)?.toInt() ?? 0,
      plantType: plantType,
      locationType: locationType,
      lastUpdate: DateTime.tryParse(lastUpdateRaw) ?? DateTime.now(),
    );
  }
}
