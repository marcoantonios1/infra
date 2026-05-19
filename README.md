# infra

Shared self-hosted audio infrastructure for local speech-to-text and text-to-speech services.

This repository is project-agnostic. It runs independently and can serve multiple projects simultaneously without coupling to any single application.

---

## Purpose

Provide OpenAI-compatible STT and TTS endpoints using only local compute — no API keys, no usage costs, no data leaving your server.

| Service  | Role | API endpoint |
|----------|------|-------------|
| speaches | Speech-to-text (Whisper via faster-whisper) | `POST /v1/audio/transcriptions` |
| kokoro   | Text-to-speech (Kokoro TTS) | `POST /v1/audio/speech` |

Both services expose the same request/response shapes as the OpenAI Audio API, so any client that already supports OpenAI can point at these instead with a single URL change.

---

## Why OpenAI-compatible APIs

Keeping the API surface identical to OpenAI means:

- **No code changes** in consuming applications — only environment variables change.
- **Instant switchback** to OpenAI if you need cloud capacity.
- **Standard tooling** works out of the box (LangChain, LlamaIndex, Costguard, custom clients).

---

## Quick start

```bash
cp .env.example .env
docker compose up -d
```

On first start, speaches downloads the Whisper model (~6 GB for `large-v3`). Kokoro downloads its voice models (~1–2 GB). Both are persisted in named Docker volumes so subsequent restarts are instant.

---

## First-start model downloads

| Service  | Default model | Download size |
|----------|--------------|--------------|
| speaches | large-v3     | ~6 GB        |
| kokoro   | all voices   | ~1–2 GB      |

Downloads happen once. After that, `docker compose up -d` starts in seconds.

---

## CPU vs GPU

Both services run fully on CPU out of the box. Performance on CPU:

- **speaches** (large-v3): ~3–5 seconds to transcribe 30 seconds of audio.
- **kokoro**: ~1–3 seconds to synthesize a short sentence.

GPU acceleration is optional and significantly reduces latency. See [docs/gpu-setup.md](docs/gpu-setup.md) for NVIDIA setup instructions.

---

## Integrating with a project

Any project that speaks the OpenAI Audio API can use these services. Set the provider and URL in that project's environment:

```env
# Transcription
AUDIO_TRANSCRIPTION_PROVIDER=local
AUDIO_TRANSCRIPTION_URL=http://<server-ip>:9000

# TTS
AUDIO_TTS_PROVIDER=local
AUDIO_TTS_URL=http://<server-ip>:8880
VOICE_TTS_VOICE=af_bella
```

### Agent OS / Costguard example

Costguard routes audio through whichever provider is configured. Point it at this infra stack:

```env
AUDIO_TRANSCRIPTION_PROVIDER=local
AUDIO_TRANSCRIPTION_URL=http://192.168.1.100:9000

AUDIO_TTS_PROVIDER=local
AUDIO_TTS_URL=http://192.168.1.100:8880
VOICE_TTS_VOICE=af_bella
```

No other changes needed. The full voice pipeline runs locally:

```
Voice note → speaches → Costguard → Ollama/LLM → Kokoro → voice reply
```

Zero OpenAI API calls.

---

## Multiple projects sharing the same services

Because both services are stateless HTTP APIs, any number of projects can call them concurrently. Each project just sets its own URL env vars pointing at this host. There is no per-project configuration inside this repo.

---

## Zero recurring costs

After the one-time model download:

- No API keys required.
- No per-request charges.
- Running cost: electricity + hardware depreciation only.

See [docs/local-audio.md](docs/local-audio.md) for a detailed cost comparison with OpenAI pricing.

---

## Documentation

- [docs/local-audio.md](docs/local-audio.md) — complete setup guide, model selection, voice guide, cost comparison
- [docs/gpu-setup.md](docs/gpu-setup.md) — optional GPU acceleration with NVIDIA
