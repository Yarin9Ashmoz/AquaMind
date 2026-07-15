import json
from google import genai
from google.genai import types

# Verified Gemini API key from Google AI Studio
GEMINI_API_KEY = "AQ.Ab8RN6KMip2Gz8fYttjpf5Dm1wXlOCpZB4lhUobLlTEz08HT5Q"

# Initialize the Gemini Client using the official google-genai SDK
client = genai.Client(api_key=GEMINI_API_KEY)

def analyze_plant_image(image_bytes: bytes) -> dict:
    """
    Sends the raw plant image bytes to Gemini 1.5 Flash and returns 
    structured JSON configuration details entirely in English.
    """
    
    # Strict prompt forcing the model to reply ONLY with a valid JSON payload in English
    prompt = """
    Analyze this plant image and provide configuration details for a smart irrigation system.
    You must return the response strictly as a valid JSON object with the following keys, and nothing else (no markdown, no backticks).
    All text values inside the JSON must be strictly in English:
    {
      "plant_name": "Common English name of the plant",
      "watering_frequency_days": "integer, recommended interval between waterings in days",
      "optimal_moisture_percentage": "integer, target soil moisture percentage (0-100)",
      "light_requirement": "English description of light needs (e.g., Full Sun, Partial Shade, Low Light)",
      "short_info": "A short, 2-sentence description of the plant and care tips in English"
    }
    """

    # Convert raw bytes into the format required by the Google GenAI SDK
    image_part = types.Part.from_bytes(
        data=image_bytes,
        mime_type="image/jpeg",
    )

    try:
        # Request generation from Gemini 1.5 Flash (multimodal, highly efficient)
        response = client.models.generate_content(
            model='gemini-1.5-flash',
            contents=[prompt, image_part]
        )
        
        # Clean potential markdown block formatting from the text response
        clean_text = response.text.strip().replace("```json", "").replace("```", "")
        
        # Parse the string into a Python dictionary
        return json.loads(clean_text)
        
    except Exception as e:
        # Fallback error response if parsing or generation fails
        return {
            "error": "Failed to analyze image or parse AI data",
            "details": str(e)
        }