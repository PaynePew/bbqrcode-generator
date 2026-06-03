import os
from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/qr_codes")

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Iterator[Session]:
    """Request-scoped Session provider (FastAPI dependency).

    Lives with the engine so both the HTTP router and the auth layer can depend
    on it without importing one another (avoids a router<->auth import cycle).
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
