import os
from typing import Literal

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", "180"))

app = FastAPI(
    title="NOVA AI Server",
    description="Private API bridge to an open-source Ollama model.",
    version="1.0.0",
)

allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if allowed_origins == ["*"] else allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


class Message(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(min_length=1, max_length=20000)


class ChatRequest(BaseModel):
    messages: list[Message] = Field(min_length=1, max_length=40)


@app.get("/")
async def root():
    return {"name": "NOVA AI Server", "status": "running", "docs": "/docs"}


@app.get("/health")
async def health():
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(f"{OLLAMA_URL}/api/tags")
            response.raise_for_status()
        return {"status": "ok", "model": OLLAMA_MODEL, "ollama": "connected"}
    except (httpx.HTTPError, httpx.TimeoutException):
        raise HTTPException(status_code=503, detail="Ollama is not reachable")


@app.post("/api/chat")
async def chat(payload: ChatRequest):
    messages = [
        {
            "role": item.role,
            "content": item.content,
        }
        for item in payload.messages
    ]

    # Add a consistent assistant instruction unless the client supplied one.
    if not messages or messages[0]["role"] != "system":
        messages.insert(
            0,
            {
                "role": "system",
                "content": (
                    "You are NOVA, a helpful, accurate AI assistant. "
                    "Reply in the user's language. Use clear formatting."
                ),
            },
        )

    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
                    "messages": messages,
                    "stream": False,
                    "options": {"temperature": 0.7},
                },
            )
            response.raise_for_status()
            data = response.json()
            reply = data.get("message", {}).get("content", "").strip()
            if not reply:
                raise HTTPException(status_code=502, detail="The model returned an empty reply")
            return {"reply": reply, "model": OLLAMA_MODEL}
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="The model took too long to respond")
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Ollama returned HTTP {exc.response.status_code}",
        )
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="Could not connect to the AI model")
