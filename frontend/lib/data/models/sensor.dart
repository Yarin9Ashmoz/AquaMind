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
      sensorId: json["sensorId"],
      name: json["name"],
      moisture: json["moisture"],
      plantType: json["plantType"],
      locationType: json["locationType"] ?? "indoor",
      lastUpdate: DateTime.parse(json["lastUpdate"]),
    );
  }
}
