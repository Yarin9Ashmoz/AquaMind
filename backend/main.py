from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database.db import Base, engine
from dotenv import load_dotenv
load_dotenv()

# 1. IMPORTANT: Import all models here so SQLAlchemy detects them
from models.sensor import Sensor 

# Import routers
from routers import sensors, plant

# 2. Create tables in the database (if they don't exist)
try:
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully or already exist.")
except Exception as e:
    print(f"❌ Error creating database tables: {e}")

app = FastAPI(
    title="AquaMind API",
    description="Backend API powering the AquaMind Smart Irrigation Network",
    version="1.0.0"
)

# 3. Configure CORS Middleware (Crucial for Flutter & Web clients)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins for local dev / mobile clients
    allow_credentials=True,
    allow_methods=["*"],  # Allows GET, POST, PUT, DELETE, etc.
    allow_headers=["*"],
)

# 4. Include routers
app.include_router(sensors.router)
app.include_router(plant.router)

# 5. Root endpoint for health check
@app.get("/")
def root():
    return {
        "status": "online",
        "message": "AquaMind Backend is running!",
        "version": "1.0.0"
    }

# 6. Debug endpoint to check DB connectivity
@app.get("/health")
def health_check():
    try:
        # Verify active connection pool
        with engine.connect() as connection:
            return {"database": "connected", "status": "healthy"}
    except Exception as e:
        return {"database": "error", "details": str(e)}