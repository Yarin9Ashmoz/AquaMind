import httpx
from typing import Dict, Any

DEFAULT_LAT = 32.0853
DEFAULT_LON = 34.7818

class WeatherService:
    @staticmethod
    async def get_current_weather(lat: float = None, lon: float = None) -> Dict[str, Any]:
        """
        Fetches real-time weather parameters from Open-Meteo for a specific sensor location.
        Fallbacks to Tel Aviv default coordinates if lat/lon are missing.
        """
        target_lat = lat if lat is not None else DEFAULT_LAT
        target_lon = lon if lon is not None else DEFAULT_LON

        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={target_lat}&longitude={target_lon}"
            f"&current_weather=true&hourly=precipitation"
        )

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()

                current = data.get("current_weather", {})
                
                return {
                    "temperature": current.get("temperature"),
                    "windspeed": current.get("windspeed"),
                    "weathercode": current.get("weathercode"),
                    "is_day": current.get("is_day"),
                    "latitude_used": target_lat,
                    "longitude_used": target_lon,
                }
        except Exception as e:
            print(f"❌ Error fetching weather data for ({target_lat}, {target_lon}): {e}")
            return {
                "temperature": 22.0,
                "windspeed": 0.0,
                "weathercode": 0,
                "is_day": 1,
                "latitude_used": target_lat,
                "longitude_used": target_lon,
            }