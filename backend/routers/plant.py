from fastapi import APIRouter, UploadFile, File, HTTPException
from services.ai_service import analyze_plant_image

router = APIRouter(prefix="/plants", tags=["Plants AI Identification"])

@router.post("/identify")
async def identify_plant(file: UploadFile = File(...)):
    """
    HTTP POST Endpoint that accepts an image file, validates it, 
    and returns AI-generated care instructions.
    """
    # Validate that the uploaded file is indeed an image
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image")
        
    # Read the file contents asynchronously into bytes
    image_bytes = await file.read()
    
    # Process the image via the Gemini service
    result = analyze_plant_image(image_bytes)
    
    # Raise a server error if the AI service failed to parse or execute
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
        
    # NOTE: You can add logic here to save these settings directly to your DB 
    # under the current user's profile or connected ESP32 device.
    
    return result