from fastapi import FastAPI
from database.db import Base, engine
from routers import sensors

Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(sensors.router)

@app.get("/")
def root():
    return {"message": "AquaMind Backend is running!"}