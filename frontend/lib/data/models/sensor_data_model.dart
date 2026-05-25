class SensorDataModel {
  final double moisture;
  final double temperature;
  final double light;

  SensorDataModel({
    required this.moisture,
    required this.temperature,
    required this.light,
  });

  factory SensorDataModel.fromJson(Map<String, dynamic> json) {
    return SensorDataModel(
      moisture: json['moisture']?.toDouble() ?? 0,
      temperature: json['temperature']?.toDouble() ?? 0,
      light: json['light']?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
    };
  }
}
