from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "postgresql://aquamind_db_user:sacIscY7YjGbMZINkLAoLCliWCp8Volu@dpg-d6k18dh4tr6s73bef8o0-a.oregon-postgres.render.com/aquamind_db"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
