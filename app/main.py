import os
import time
import logging
import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Standard SRE Structured Logging
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        if record.exc_info:
            log_record["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(log_record)

logger = logging.getLogger("service_flow_app")
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
logger.setLevel(logging.INFO)

app = FastAPI(
    title="test13",
    description="Microservice created by ServiceFlow developer portal.",
    version="1.0.0"
)

class HealthStatus(BaseModel):
    status: str
    database: str
    uptime_seconds: float

START_TIME = time.time()

@app.get("/")
def read_root():
    logger.info("Handling root endpoint request")
    return {
        "message": "Welcome to test13",
        "service": "test13",
        "environment": "dev",
        "version": "1.0.0"
    }

@app.get("/health")
def health_check():
    db_configured = os.getenv("DATABASE_URL") is not None
    # For a real RDS integration, check database connection status here.
    db_status = "connected" if db_configured else "not_configured"
    
    logger.info(f"Health check executed. Database: {db_status}")
    
    return HealthStatus(
        status="healthy",
        database=db_status,
        uptime_seconds=time.time() - START_TIME
    )
