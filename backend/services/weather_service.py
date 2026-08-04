import httpx
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

DEFAULT_LAT = 32.0853
DEFAULT_LON = 34.7818

# Global cache variables to ensure persistence across process execution
_WEATHER_CACHE: Dict[str, Any] = {}
_LAST_FETCH_TIME: Optional[datetime] = None
CACHE_TTL = timedelta(minutes=15)


class WeatherService:
    @classmethod
    async def get_current_weather(cls, lat: float = None, lon: float = None) -> Dict[str, Any]:
        """
        Fetches real-time weather parameters from Open-Meteo with global caching
        to completely eliminate HTTP 429 Rate Limit errors.
        """
        global _WEATHER_CACHE, _LAST_FETCH_TIME
        
        target_lat = lat if lat is not None else DEFAULT_LAT
        target_lon = lon if lon is not None else DEFAULT_LON
        now = datetime.now()

        # 1. Return cached weather data if it's still fresh (< 15 minutes)
        if _WEATHER_CACHE and _LAST_FETCH_TIME and (now - _LAST_FETCH_TIME < CACHE_TTL):
            return _WEATHER_CACHE

        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={target_lat}&longitude={target_lon}"
            f"&current_weather=true&hourly=precipitation"
        )

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url)
                
                # If rate limited (429), return cached or fallback data immediately
                if response.status_code == 429:
                    print(f"⚠️ Open-Meteo Rate Limit (429) hit. Returning cached/fallback data.")
                    return cls._get_fallback_or_cache(target_lat, target_lon)

                response.raise_for_status()
                data = response.json()

                current = data.get("current_weather", {})
                
                # Update global cache
                _WEATHER_CACHE = {
                    "temperature": current.get("temperature", 22.0),
                    "windspeed": current.get("windspeed", 0.0),
                    "weathercode": current.get("weathercode", 0),
                    "is_day": current.get("is_day", 1),
                    "latitude_used": target_lat,
                    "longitude_used": target_lon,
                }
                _LAST_FETCH_TIME = now
                return _WEATHER_CACHE

        except Exception as e:
            print(f"❌ Error fetching weather data for ({target_lat}, {target_lon}): {e}")
            return cls._get_fallback_or_cache(target_lat, target_lon)

    @classmethod
    def _get_fallback_or_cache(cls, lat: float, lon: float) -> Dict[str, Any]:
        """Returns existing cache if available, otherwise safe default metrics."""
        if _WEATHER_CACHE:
            return _WEATHER_CACHE
        
        return {
            "temperature": 22.0,
            "windspeed": 0.0,
            "weathercode": 0,
            "is_day": 1,
            "latitude_used": lat,
            "longitude_used": lon,
        }