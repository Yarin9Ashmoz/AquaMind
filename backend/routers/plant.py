from fastapi import APIRouter, UploadFile, File, HTTPException
from services.ai_service import analyze_plant_image

router = APIRouter(prefix="/plants", tags=["Plants AI Identification"])

@router.post("/identify")
async def identify_plant(file: UploadFile = File(...)):
    """
    HTTP POST Endpoint that accepts an image file, validates it, 
    and returns AI-generated care instructions for smart irrigation setup.
    """
    # Validate that the uploaded file is indeed an image
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image")
        
    try:
        # Read the file contents asynchronously into bytes
        image_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read image stream: {str(e)}")
    
    # Process the image via the Gemini service
    result = analyze_plant_image(image_bytes)
    
    # Raise a server error if the AI service failed to parse or execute
    if "error" in result:
        detail_msg = result.get("details", result["error"])
        raise HTTPException(status_code=500, detail=f"AI Identification Failed: {detail_msg}")
        
    return result