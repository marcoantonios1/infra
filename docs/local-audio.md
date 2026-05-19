# Local Audio Setup Guide

Complete end-to-end guide for running speech-to-text and text-to-speech locally using the `infra` stack.

---

## Why Local Audio

| Concern | OpenAI | Local |
|---------|--------|-------|
| Privacy | Audio sent to OpenAI servers | Audio never leaves your machine |
| Cost | Per-second / per-character billing | Free after model download |
| Offline | Requires internet | Fully offline capable |
| Latency | Round-trip network + API | Local inference only |
| Data retention | Subject to provider policy | You control everything |

Audio is often sensitive (voice notes, meetings, personal messages). Running locally means it never leaves your server.

---

## Prerequisites

- Docker and Docker Compose installed
- ~10–20 GB free disk space (depends on model choice)
- Sufficient RAM (see model table below)

---

## Starting the Stack

```bash
git clone https://github.com/marcoantonios1/infra
cd infra
cp .env.example .env
# Optionally edit .env to choose a smaller model
docker compose up -d
```

Watch startup logs:

```bash
docker compose logs -f speaches
docker compose logs -f kokoro
```

Both services print a ready message when model loading completes.

---

## speaches — Whisper Model Guide

speaches uses [faster-whisper](https://github.com/SYSTRAN/faster-whisper) for efficient CPU and GPU inference.

### Model comparison

| Model    | Type           | RAM   | Disk    | CPU latency (30s audio) | Notes |
|----------|----------------|-------|---------|------------------------|-------|
| tiny.en  | English-only   | ~1 GB | ~150 MB | ~0.5–1s                | Use only for English, fast prototyping |
| base     | Multilingual   | ~1 GB | ~280 MB | ~1–2s                  | Good balance for simple use cases |
| small    | Multilingual   | ~2 GB | ~970 MB | ~2–3s                  | Solid accuracy, reasonable CPU cost |
| medium   | Multilingual   | ~5 GB | ~3 GB   | ~5–8s                  | Strong multilingual, slower |
| large-v3 | Multilingual   | ~10GB | ~6 GB   | ~3–5s                  | Best accuracy, default choice |

### First-start download

The model is downloaded once to a Docker volume (`speaches_models`). Subsequent restarts load from disk instantly.

- `large-v3` download: ~6 GB, takes 5–15 minutes depending on connection speed.
- After download: startup takes ~30–60 seconds to load model into memory.

### Changing models

Edit `.env`:

```env
ASR_MODEL=small
```

Then restart:

```bash
docker compose restart speaches
```

The new model downloads automatically if not already cached.

### API endpoint

```
POST http://<host>:9000/v1/audio/transcriptions
Content-Type: multipart/form-data

file=<audio file>
model=whisper-1
```

Response shape matches the OpenAI transcription API:

```json
{
  "text": "Hello, this is a transcribed message."
}
```

---

## Kokoro — Voice Guide

Kokoro exposes an OpenAI-compatible TTS API. Voices are pre-downloaded on first start.

### Available voices

| Voice      | Gender | Style | Notes |
|------------|--------|-------|-------|
| af_bella   | Female | Warm, natural | Recommended default — versatile |
| af_sky     | Female | Bright, energetic | Good for notifications |
| am_adam    | Male   | Neutral, clear | General-purpose male voice |
| am_michael | Male   | Deep, authoritative | Good for announcements |

### Recommended defaults

- **General use**: `af_bella` — most natural, works well for conversational replies
- **Notifications**: `af_sky`
- **Formal/assistant**: `am_michael`

### CPU performance

Kokoro runs on CPU by default:

- Short sentence (~10 words): ~0.5–1s
- Paragraph (~100 words): ~3–6s
- Streaming is not yet supported; full audio is returned when synthesis completes

### API endpoint

```
POST http://<host>:8880/v1/audio/speech
Content-Type: application/json

{
  "model": "kokoro",
  "input": "Hello, how can I help you today?",
  "voice": "af_bella",
  "response_format": "opus"
}
```

`response_format=opus` returns OGG/Opus audio, compatible with WhatsApp and Telegram voice pipelines.

---

## Costguard / Agent OS Configuration

Set these environment variables in your Costguard or Agent OS instance:

```env
# Speech-to-text
AUDIO_TRANSCRIPTION_PROVIDER=local
AUDIO_TRANSCRIPTION_URL=http://<server-ip>:9000

# Text-to-speech
AUDIO_TTS_PROVIDER=local
AUDIO_TTS_URL=http://<server-ip>:8880

# Voice selection
VOICE_TTS_VOICE=af_bella
```

Replace `<server-ip>` with:
- `localhost` or `127.0.0.1` if running on the same machine
- The LAN IP (e.g. `192.168.1.100`) if running on a separate server

No API keys needed. No other changes required.

---

## End-to-End Voice Flow

```
1. User sends voice note
        ↓
2. speaches (POST /v1/audio/transcriptions)
   — audio file → text transcript
        ↓
3. Costguard / application logic
   — text → LLM prompt
        ↓
4. Ollama / local LLM
   — prompt → text response
        ↓
5. Kokoro (POST /v1/audio/speech)
   — text → OGG/Opus audio
        ↓
6. Voice reply sent to user
```

Zero OpenAI API calls involved in this pipeline. Everything runs on local hardware.

---

## Cost Comparison

### OpenAI pricing (as of 2025)

| Service | Pricing |
|---------|---------|
| Whisper (STT) | $0.006 per minute of audio |
| TTS | $15.00 per 1M characters |

### Example monthly usage (moderate agent)

- 500 voice notes × 30s average = 250 minutes of audio
- 500 TTS replies × 200 characters average = 100,000 characters

| | OpenAI | Local |
|--|--------|-------|
| STT cost | $1.50/month | $0 |
| TTS cost | $1.50/month | $0 |
| **Total** | **$3.00/month** | **$0** |

For heavier usage (thousands of messages), savings scale linearly.

**Local cost:** electricity for the host machine + hardware depreciation. No per-request cost after model download.

---

## Reverting to OpenAI

To switch back to OpenAI at any time, update your project's env vars:

```env
AUDIO_TRANSCRIPTION_PROVIDER=openai
AUDIO_TRANSCRIPTION_URL=

AUDIO_TTS_PROVIDER=openai
AUDIO_TTS_URL=
```

No changes needed in this infra repo. The stack can remain running unused or be stopped with:

```bash
docker compose down
```

---

## Troubleshooting

### speaches not responding after startup

The large-v3 model takes time to load into RAM. Wait 30–60 seconds and check:

```bash
docker compose logs speaches --tail=20
```

### Kokoro audio sounds choppy

This is normal on low-spec CPU hardware for longer synthesis. Consider:
- Using a shorter TTS voice (shorter sentences)
- Switching to a smaller voice model
- Adding GPU acceleration (see [gpu-setup.md](gpu-setup.md))

### Port conflicts

Edit `.env` to change default ports:

```env
SPEACHES_PORT=9001
KOKORO_PORT=8881
```

Then restart: `docker compose up -d`
