from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "postgresql://aquamind_db_2l4g_user:nnQeoqaaupN9A02hRCh0Ce2tTG9Ajz4w@dpg-d7mbohapmmbs73btb720-a/aquamind_db_2l4g"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
