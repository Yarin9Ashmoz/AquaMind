from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from services.ai_service import analyze_plant_image
from security import verify_api_key

router = APIRouter(prefix="/plants", tags=["Plants AI Identification"])

@router.post("/identify", dependencies=[Depends(verify_api_key)])
async def identify_plant(file: UploadFile = File(...)):
    """
    HTTP POST Endpoint that accepts an image file, validates it,
    and returns AI-generated care instructions for smart irrigation setup.
    Requires API key - this endpoint calls the paid Gemini API.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image")

    try:
        image_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read image stream: {str(e)}")

    result = analyze_plant_image(image_bytes)

    if "error" in result:
        detail_msg = result.get("details", result["error"])
        raise HTTPException(status_code=500, detail=f"AI Identification Failed: {detail_msg}")

    return result