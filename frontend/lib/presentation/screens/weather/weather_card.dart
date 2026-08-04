import 'package:flutter/material.dart';

class WeatherCard extends StatelessWidget {
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final String locationName;

  const WeatherCard({
    super.key,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    this.locationName = "Local Conditions",
  });

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code >= 1 && code <= 3) return Icons.wb_cloudy_rounded;
    if (code >= 51 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 80 && code <= 82) return Icons.thunderstorm_rounded;
    return Icons.wb_sunny_rounded;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return "Clear Sky";
    if (code >= 1 && code <= 3) return "Partly Cloudy";
    if (code >= 51 && code <= 67) return "Rainy";
    if (code >= 80 && code <= 82) return "Showers";
    return "Sunny";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    locationName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${temperature.toStringAsFixed(1)}°C",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getWeatherDescription(weatherCode),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Icon(
                _getWeatherIcon(weatherCode),
                size: 48,
                color: Colors.amberAccent,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.air, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "${windSpeed.toStringAsFixed(1)} km/h",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8), 
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}