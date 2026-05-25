class Sensor {
  final String sensorId;
  String name;
  final double moisture;
  final String plantType; // pot / garden
  final String locationType; // indoor / outdoor
  final DateTime lastUpdate;
  final int dryToleranceDays; 

  Sensor({
    required this.sensorId,
    required this.name,
    required this.moisture,
    required this.plantType,
    required this.locationType,
    required this.lastUpdate,
    this.dryToleranceDays = 3, 
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    
    final sensorId = json["sensor_id"] ?? json["sensorId"] ?? "";
    final plantType = json["plant_type"] ?? json["plantType"] ?? "";
    final locationType =
        json["location_type"] ?? json["locationType"] ?? "indoor";
    final lastUpdateRaw = json["last_update"] ?? json["lastUpdate"] ?? "";
    
    final dryTolerance = json["dry_tolerance_days"] ?? json["dryToleranceDays"] ?? 3;

    return Sensor(
      sensorId: sensorId,
      name: json["name"] ?? "",
      moisture: (json["moisture"] as num?)?.toDouble() ?? 0,
      plantType: plantType,
      locationType: locationType,
      lastUpdate: DateTime.tryParse(lastUpdateRaw) ?? DateTime.now(),
      dryToleranceDays: dryTolerance is int ? dryTolerance : int.parse(dryTolerance.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sensor_id": sensorId,
      "name": name,
      "moisture": moisture,
      "plant_type": plantType,
      "location_type": locationType,
      "last_update": lastUpdate.toIso8601String(),
      "dry_tolerance_days": dryToleranceDays,
    };
  }
}