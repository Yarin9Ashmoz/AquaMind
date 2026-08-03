import requests
from typing import Dict, Any, Optional

class WeatherService:
    @staticmethod
    def get_outdoor_weather(lat: float = 32.0853, lon: float = 34.7818) -> Optional[Dict[str, Any]]:
        """
        Fetches current outdoor weather data using Open-Meteo API.
        Default coordinates are set to Tel Aviv (Latitude: 32.0853, Longitude: 34.7818).
        """
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,relative_humidity_2m,rain"
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                current = data.get("current", {})
                return {
                    "temperature": current.get("temperature_2m"),
                    "humidity": current.get("relative_humidity_2m"),
                    "rain": current.get("rain", 0.0)
                }
        except Exception as e:
            print(f"Error fetching weather data: {e}")
        return None