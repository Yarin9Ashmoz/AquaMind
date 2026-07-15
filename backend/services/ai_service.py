import os
import json
from google import genai
from google.genai import types

# Load the verified Gemini API key dynamically from Render's environment variables.
# Fallback to the hardcoded one only if the environment variable is not set.
API_KEY = os.getenv("GEMINI_API_KEY", "AQ.Ab8RN6KMip2Gz8fYttjpf5Dm1wXlOCpZB4lhUobLlTEz08HT5Q")

# Initialize the Gemini Client using the official google-genai SDK
client = genai.Client(api_key=API_KEY)

def analyze_plant_image(image_bytes: bytes) -> dict:
    """
    Sends the raw plant image bytes to Gemini 1.5 Flash and returns 
    structured JSON configuration details entirely in English.
    """
    
    prompt = """
    Analyze this plant image and provide configuration details for a smart irrigation system.
    Provide the common English name of the plant, recommended watering interval in days, 
    optimal moisture percentage, light requirements, and a short 2-sentence description in English.
    """

    # Properly construct the image part using the correct google-genai types structure
    image_part = types.Part.from_bytes(
        data=image_bytes,
        mime_type="image/jpeg",
    )

    try:
        # Request generation using JSON Schema to guarantee a strict JSON response
        response = client.models.generate_content(
            model='gemini-1.5-flash',
            contents=[prompt, image_part],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=types.Schema(
                    type=types.Type.OBJECT,
                    properties={
                        "plant_name": types.Schema(type=types.Type.STRING),
                        "watering_frequency_days": types.Schema(type=types.Type.INTEGER),
                        "optimal_moisture_percentage": types.Schema(type=types.Type.INTEGER),
                        "light_requirement": types.Schema(type=types.Type.STRING),
                        "short_info": types.Schema(type=types.Type.STRING),
                    },
                    required=[
                        "plant_name", 
                        "watering_frequency_days", 
                        "optimal_moisture_percentage", 
                        "light_requirement", 
                        "short_info"
                    ],
                ),
            ),
        )
        
        # Since we enforced schema validation, response.text is guaranteed to be clean JSON
        return json.loads(response.text)
        
    except Exception as e:
        # Fallback error response if parsing or generation fails
        return {
            "error": "Failed to analyze image or parse AI data",
            "details": str(e)
        }