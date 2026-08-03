class Sensor {
  final String sensorId;
  final String? name;
  final String? plantType;
  final String? locationType;
  final int dryToleranceDays;
  final double moisture;
  final double moistureThreshold;
  final int syncIntervalMinutes;
  final DateTime? lastUpdate;

  Sensor({
    required this.sensorId,
    this.name,
    this.plantType,
    this.locationType,
    this.dryToleranceDays = 3,
    required this.moisture,
    this.moistureThreshold = 25.0,
    this.syncIntervalMinutes = 30,
    this.lastUpdate,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      sensorId: json['sensor_id'] ?? json['sensorId'] ?? '',
      name: json['name'],
      plantType: json['plant_type'],
      locationType: json['location_type'],
      dryToleranceDays: json['dry_tolerance_days'] ?? 3,
      moisture: (json['moisture'] as num?)?.toDouble() ?? 0.0,
      moistureThreshold:
          (json['moisture_threshold'] as num?)?.toDouble() ?? 25.0,
      syncIntervalMinutes: json['sync_interval_minutes'] ?? 30,
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sensor_id': sensorId,
      'name': name,
      'plant_type': plantType,
      'location_type': locationType,
      'dry_tolerance_days': dryToleranceDays,
      'moisture': moisture,
      'moisture_threshold': moistureThreshold,
      'sync_interval_minutes': syncIntervalMinutes,
      'last_update': lastUpdate?.toIso8601String(),
    };
  }
}
