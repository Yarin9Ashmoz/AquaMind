from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "postgresql://aquamind_db_rxo4_user:dtpEDKAdZIimFvUhDF1z0BS9vxcOBFrx@dpg-d8hc1hddt1ts7389homg-a/aquamind_db_rxo4"


engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
