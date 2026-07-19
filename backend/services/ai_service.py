import os
import json
import traceback
import importlib.metadata
from google import genai
from google.genai import types

print(
    "google-genai version:",
    importlib.metadata.version("google-genai")
)

API_KEY = os.getenv("GEMINI_API_KEY")

client = genai.Client(
    api_key=API_KEY,
    http_options={'api_version': 'v1'}
)

print("=== Available Gemini models ===")
for model in client.models.list():
    print(model.name)
print("===============================")


def analyze_plant_image(image_bytes: bytes) -> dict:
    """
    Sends the raw plant image bytes to Gemini 2.0 Flash Lite
    and returns structured JSON configuration details.
    """

    prompt = """
    Analyze this plant image and provide configuration details for a smart irrigation system.

    You must return ONLY a raw JSON object matching this structure:

    {
        "plant_name": "Common English name of the plant",
        "watering_frequency_days": 3,
        "optimal_moisture_percentage": 60,
        "light_requirement": "High / Medium / Low",
        "short_info": "A short 2-sentence description in English."
    }

    Rules:
    - Do not wrap the JSON in markdown.
    - Return only valid JSON.
    - All text values must be strictly in English.
    """

    image_part = types.Part.from_bytes(
        data=image_bytes,
        mime_type="image/jpeg",
    )

    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash-lite",
            contents=[prompt, image_part]
        )

        print(f"DEBUG: Gemini raw response text: {response.text}")

        clean_text = response.text.strip()

        # Remove markdown if Gemini returns it anyway
        if clean_text.startswith("```json"):
            clean_text = clean_text[7:]

        if clean_text.endswith("```"):
            clean_text = clean_text[:-3]

        clean_text = clean_text.strip()

        return json.loads(clean_text)

    except Exception as e:
        print("❌ ERROR inside analyze_plant_image:")
        traceback.print_exc()

        return {
            "error": "Failed to analyze image or parse AI data",
            "details": str(e)
        }