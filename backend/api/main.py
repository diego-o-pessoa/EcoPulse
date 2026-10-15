from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from shared.config import settings
from api.routers import auth, users, occurrences, websockets

app = FastAPI(
    title="EcoPulse API",
    description="API for EcoPulse Distributed System",
    version="1.0.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(occurrences.router, prefix="/api/v1/occurrences", tags=["Occurrences"])
app.include_router(websockets.router, tags=["WebSockets"])

@app.get("/health", tags=["Health"])
async def health_check():
    """Endpoint for basic health check"""
    return {"status": "ok", "service": "api"}

@app.get("/ready", tags=["Health"])
async def readiness_check():
    """Endpoint to check if API is ready to accept traffic and connected to dependencies"""
    # TODO: Add checks for DB, Redis, RabbitMQ
    return {"status": "ready"}
