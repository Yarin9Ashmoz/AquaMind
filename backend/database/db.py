import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Load the database URL from the environment variable set in Render.
# Fallback to local PostgreSQL instance if the environment variable is not defined.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/aquamind"
)

# Render provides connection strings starting with 'postgres://',
# but SQLAlchemy 1.4+ strictly requires 'postgresql://'.
if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """
    FastAPI dependency that yields a database session per-request
    and guarantees it's closed afterwards, even if an error occurs.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()