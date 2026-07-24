import os
import json
import traceback
import importlib.metadata
from google import genai
from google.genai import types
from google.genai.errors import ServerError

print(
    "google-genai version:",
    importlib.metadata.version("google-genai")
)

API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise Exception("Missing GEMINI_API_KEY environment variable")

client = genai.Client(
    api_key=API_KEY
)

print("=== Available Gemini models ===")
try:
    for model in client.models.list():
        print(model.name)
except Exception as e:
    print("Failed to list models:", e)

print("===============================")


def analyze_plant_image(image_bytes: bytes) -> dict:
    """
    Analyze a plant image using Gemini and return irrigation configuration.
    """

    prompt = """
    Analyze this plant image and provide configuration details for a smart irrigation system.

    Return ONLY a valid JSON object matching this schema:

    {
        "plant_name": "Common English name of the plant",
        "watering_frequency_days": 3,
        "optimal_moisture_percentage": 60,
        "light_requirement": "High / Medium / Low",
        "short_info": "Short description in English."
    }

    Rules:
    - All text values must be in English.
    """

    image_part = types.Part.from_bytes(
        data=image_bytes,
        mime_type="image/jpeg"
    )

    try:
        # שימוש במודל נתמך והגדרת פלט JSON מובנה
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                prompt,
                image_part
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json"
            )
        )

        print("DEBUG Gemini response:")
        print(response.text)

        clean_text = response.text.strip()
        return json.loads(clean_text)

    except ServerError as e:
        print("⚠️ Gemini Server Error (503 / High demand or temporarily unavailable):")
        traceback.print_exc()
        return {
            "error": "Gemini service busy or temporarily unavailable",
            "details": str(e)
        }

    except Exception as e:
        print("❌ ERROR inside analyze_plant_image:")
        traceback.print_exc()

        return {
            "error": "Failed to analyze image or parse AI data",
            "details": str(e)
        }