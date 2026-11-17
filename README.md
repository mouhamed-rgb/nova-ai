# NOVA AI

NOVA AI is an Android AI assistant built with Flutter and a fully on-device open-source language model.

## How it works

- Flutter + Dart mobile application.
- `llamadart` with `llama.cpp` runs the model directly on Android.
- Qwen2.5 1.5B Instruct in GGUF Q4_K_M format.
- No FastAPI backend, no Ollama server, no Groq/OpenAI API key, and no inference server.

The model is downloaded from Hugging Face the first time the app is used and cached on the phone. Internet is needed for that initial download; after it finishes, text generation works offline. The model file is about 1.1 GB, so use Wi-Fi and make sure the phone has enough free storage.

## Repository layout

- `mobile/` — Flutter Android application and local inference service.
- `.github/workflows/build-apk.yml` — GitHub Actions APK build.

## Model details

- Model: Qwen2.5-1.5B-Instruct
- Format: GGUF
- Quantization: Q4_K_M
- Source: [Qwen2.5-1.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF)
- Runtime: [llamadart](https://pub.dev/packages/llamadart), powered by llama.cpp.

The model is a compact on-device assistant, not a cloud-scale model. Response speed depends on the Android device's processor, available memory, and thermal state.

## Build APK

Open the repository's **Actions** tab and run **Build NOVA AI APK**, or push a change under `mobile/`. The workflow:

1. Creates the Android project files.
2. Adds Android internet permission for the one-time model download.
3. Fetches Flutter dependencies and native llama.cpp runtime assets.
4. Runs Flutter analysis and builds a release APK.
5. Uploads `nova-ai-release-apk` as a workflow artifact.

## Privacy and connectivity

- Prompts are processed locally by the model after it is downloaded.
- No chat messages are sent to an inference server.
- Internet is only required to download the model initially (and for future app/model updates).
- The downloaded model occupies around 1.1 GB of storage.
