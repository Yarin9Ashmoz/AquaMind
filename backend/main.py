from fastapi import FastAPI
from backend.database.db import Base, engine
# 1. IMPORTANT: Import all models here so SQLAlchemy detects them
# This ensures that Base.metadata.create_all actually finds your tables
from backend.models.sensor import Sensor 
from backend.routers import sensors

# 2. Create tables in the database (if they don't exist)
# This command runs every time the server starts
try:
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully or already exist.")
except Exception as e:
    print(f"❌ Error creating database tables: {e}")

app = FastAPI(title="AquaMind API")

# 3. Include the sensors router
app.include_router(sensors.router)

# 4. Root endpoint for health check
@app.get("/")
def root():
    return {
        "status": "online",
        "message": "AquaMind Backend is running!",
        "version": "1.0.0"
    }

# 5. Debug endpoint to check DB connectivity
@app.get("/health")
def health_check():
    try:
        # Simple check to see if we can reach the DB
        engine.connect()
        return {"database": "connected"}
    except Exception as e:
        return {"database": "error", "details": str(e)}