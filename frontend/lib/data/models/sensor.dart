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
  final DateTime? drySince;
  final double? latitude;
  final double? longitude;

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
    this.drySince,
    this.latitude,
    this.longitude,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      sensorId: json['sensor_id'] ?? json['sensorId'] ?? '',
      name: json['name'],
      plantType: json['plant_type'] ?? json['plantType'],
      locationType: json['location_type'] ?? json['locationType'],
      dryToleranceDays:
          json['dry_tolerance_days'] ?? json['dryToleranceDays'] ?? 3,
      moisture: (json['moisture'] as num?)?.toDouble() ?? 0.0,
      moistureThreshold:
          (json['moisture_threshold'] ?? json['moistureThreshold'] as num?)
              ?.toDouble() ??
          25.0,
      syncIntervalMinutes:
          json['sync_interval_minutes'] ?? json['syncIntervalMinutes'] ?? 30,
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'])
          : (json['lastUpdate'] != null
                ? DateTime.tryParse(json['lastUpdate'])
                : null),
      drySince: json['dry_since'] != null
          ? DateTime.tryParse(json['dry_since'])
          : (json['drySince'] != null
                ? DateTime.tryParse(json['drySince'])
                : null),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      'dry_since': drySince?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Sensor copyWith({
    String? sensorId,
    String? name,
    String? plantType,
    String? locationType,
    int? dryToleranceDays,
    double? moisture,
    double? moistureThreshold,
    int? syncIntervalMinutes,
    DateTime? lastUpdate,
    DateTime? drySince,
    double? latitude,
    double? longitude,
  }) {
    return Sensor(
      sensorId: sensorId ?? this.sensorId,
      name: name ?? this.name,
      plantType: plantType ?? this.plantType,
      locationType: locationType ?? this.locationType,
      dryToleranceDays: dryToleranceDays ?? this.dryToleranceDays,
      moisture: moisture ?? this.moisture,
      moistureThreshold: moistureThreshold ?? this.moistureThreshold,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      drySince: drySince ?? this.drySince,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
