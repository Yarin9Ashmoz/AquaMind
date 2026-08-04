import httpx
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

DEFAULT_LAT = 32.0853
DEFAULT_LON = 34.7818

class WeatherService:
    _cache: Dict[str, Any] = {}
    _cache_time: Optional[datetime] = None
    _CACHE_DURATION = timedelta(minutes=15)

    @classmethod
    async def get_current_weather(cls, lat: float = None, lon: float = None) -> Dict[str, Any]:
        """
        Fetches real-time weather parameters from Open-Meteo with local caching
        to prevent hitting API rate limits (HTTP 429).
        """
        target_lat = lat if lat is not None else DEFAULT_LAT
        target_lon = lon if lon is not None else DEFAULT_LON
        now = datetime.now()

        # Return cached response if valid
        if cls._cache and cls._cache_time and (now - cls._cache_time < cls._CACHE_DURATION):
            return cls._cache

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
                
                cls._cache = {
                    "temperature": current.get("temperature", 22.0),
                    "windspeed": current.get("windspeed", 0.0),
                    "weathercode": current.get("weathercode", 0),
                    "is_day": current.get("is_day", 1),
                    "latitude_used": target_lat,
                    "longitude_used": target_lon,
                }
                cls._cache_time = now
                return cls._cache

        except Exception as e:
            print(f"❌ Error fetching weather data for ({target_lat}, {target_lon}): {e}")
            if cls._cache:
                return cls._cache

            return {
                "temperature": 22.0,
                "windspeed": 0.0,
                "weathercode": 0,
                "is_day": 1,
                "latitude_used": target_lat,
                "longitude_used": target_lon,
            }