# NOVA AI

NOVA AI is an Android chat client built with Flutter and a self-hosted open-source language model. It does **not** use a commercial AI API key.

## Repository layout

- `mobile/` — Flutter Android application.
- `server/` — FastAPI bridge to Ollama.
- `docker-compose.yml` — Ollama + API services.
- `.github/workflows/build-apk.yml` — GitHub Actions APK build.

## AI model

The initial model is `qwen2.5:3b`, served by Ollama. The model is downloaded to your server when you run:

```bash
docker compose up -d --build
docker exec -it nova-ollama ollama pull qwen2.5:3b
```

Check the server:

```bash
curl http://localhost:8000/health
```

Interactive API documentation is available at `http://localhost:8000/docs`.

## Server requirements

This is self-hosted inference, not a free serverless deployment. A machine with **at least 8 GB RAM** is recommended for the 3B model and Docker services; more RAM or a supported GPU improves performance. The model download also requires disk space and internet access. A small free web host such as a static-site host or a serverless function platform cannot run Ollama itself.

For production, deploy on a VPS or machine you control, configure HTTPS with a reverse proxy, and add authentication and rate limiting before exposing the API publicly. The starter API is intended for development and must not be exposed directly to the public internet without those protections. Keep Ollama's port private.

## Connect the Android app

1. Build and install the APK from GitHub Actions.
2. Open NOVA AI and tap the settings icon.
3. Enter the public HTTPS base URL of your secured server, for example `https://ai.example.com` (no trailing slash).
4. Send a test message.

For Android emulator development, the default URL `http://10.0.2.2:8000` points to the host machine. A physical phone needs the computer's LAN address for local testing, or the public HTTPS URL for deployment.

## Build APK

Open the repository's **Actions** tab and run **Build NOVA AI APK**, or push a change under `mobile/`. The workflow generates the Android platform files, runs Flutter analysis, builds a release APK, and uploads it as the artifact `nova-ai-release-apk`.

## Important notes

- No Groq, OpenAI, or other commercial AI API key is included.
- Ollama downloads and runs the open model on your own server.
- Server hosting, bandwidth, storage, and compute may have a cost.
- Do not commit passwords, access tokens, private keys, or real `.env` files.
