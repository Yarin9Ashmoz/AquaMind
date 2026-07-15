import os
import json
import traceback
from google import genai
from google.genai import types

API_KEY = os.getenv("GEMINI_API_KEY", "AQ.Ab8RN6KMip2Gz8fYttjpf5Dm1wXlOCpZB4lhUobLlTEz08HT5Q")

# Keep using 'v1' for model availability, but we will fix the config fields below
client = genai.Client(
    api_key=API_KEY,
    http_options={'api_version': 'v1'}
)

def analyze_plant_image(image_bytes: bytes) -> dict:
    """
    Sends the raw plant image bytes to Gemini 1.5 Flash and returns 
    structured JSON configuration details entirely in English.
    """
    
    prompt = """
    Analyze this plant image and provide configuration details for a smart irrigation system.
    You must return a valid JSON object matching the requested schema.
    All text values inside the JSON must be strictly in English.
    """

    image_part = types.Part.from_bytes(
        data=image_bytes,
        mime_type="image/jpeg",
    )

    try:
        response = client.models.generate_content(
            model='gemini-1.5-flash',
            contents=[prompt, image_part],
            config=types.GenerateContentConfig(
                # Using exact snake_case strings to prevent SDK/API mapping issues
                response_mime_type="application/json",
                response_schema={
                    "type": "OBJECT",
                    "properties": {
                        "plant_name": {"type": "STRING"},
                        "watering_frequency_days": {"type": "INTEGER"},
                        "optimal_moisture_percentage": {"type": "INTEGER"},
                        "light_requirement": {"type": "STRING"},
                        "short_info": {"type": "STRING"},
                    },
                    "required": [
                        "plant_name", 
                        "watering_frequency_days", 
                        "optimal_moisture_percentage", 
                        "light_requirement", 
                        "short_info"
                    ],
                },
            ),
        )
        
        print(f"DEBUG: Gemini raw response text: {response.text}")
        return json.loads(response.text)
        
    except Exception as e:
        print("❌ ERROR inside analyze_plant_image:")
        traceback.print_exc()
        
        return {
            "error": "Failed to analyze image or parse AI data",
            "details": str(e)
        }