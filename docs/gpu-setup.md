# GPU Acceleration (Optional)

Both services run fully on CPU out of the box. This guide covers optional GPU acceleration for NVIDIA hardware, which can significantly reduce inference latency.

> GPU acceleration is not required. Skip this entirely if you want a simpler setup or don't have an NVIDIA GPU.

---

## Expected speedups

| Service  | CPU latency (30s audio) | GPU latency (30s audio) | Speedup |
|----------|------------------------|------------------------|---------|
| speaches (large-v3) | ~3–5s | ~0.5–1s | ~5–8x |
| kokoro   | ~1–3s per sentence | ~0.2–0.5s per sentence | ~4–6x |

---

## VRAM requirements

| speaches model | VRAM needed |
|----------------|------------|
| tiny.en        | ~1 GB      |
| base / small   | ~2 GB      |
| medium         | ~4 GB      |
| large-v3       | ~8–10 GB   |

Kokoro TTS uses ~1–2 GB VRAM regardless of voice.

If your GPU has less VRAM than required for your chosen Whisper model, speaches falls back to CPU automatically.

---

## Prerequisites

- NVIDIA GPU with CUDA support (Kepler or newer)
- NVIDIA drivers installed on the host
- CUDA version compatible with the container images (CUDA 11.8+ recommended)

Verify your driver and CUDA version:

```bash
nvidia-smi
```

---

## Step 1 — Install NVIDIA Container Toolkit

The NVIDIA Container Toolkit allows Docker to pass GPU access into containers.

### Ubuntu / Debian

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

### Configure Docker runtime

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Verify GPU access in Docker

```bash
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

You should see your GPU listed in the output.

---

## Step 2 — Enable GPU in docker-compose.yml

Add `deploy.resources` to the speaches service. Edit `docker-compose.yml`:

```yaml
services:
  speaches:
    image: ghcr.io/speaches-ai/speaches:latest
    restart: unless-stopped
    environment:
      ASR_MODEL: ${ASR_MODEL:-large-v3}
      ASR_ENGINE: faster_whisper
    ports:
      - "${SPEACHES_PORT:-9000}:9000"
    volumes:
      - speaches_models:/root/.cache
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

For kokoro, check the image tags — GPU-specific images may be available from the upstream project. The CPU image (`kokoro-fastapi-cpu`) runs on CPU only. Swap the image tag if a GPU variant is released.

---

## Step 3 — Apply changes

```bash
docker compose down
docker compose up -d
```

Check that speaches detects the GPU:

```bash
docker compose logs speaches | grep -i cuda
docker compose logs speaches | grep -i gpu
```

You should see CUDA device initialization messages.

---

## CUDA compatibility notes

- The speaches image bundles its own CUDA runtime — you do not need to install CUDA on the host.
- The host only needs a compatible NVIDIA driver (typically driver version ≥ 520 for CUDA 11.8).
- Run `nvidia-smi` on the host to confirm driver version.
- If the container fails to start with a CUDA error, check that your driver version meets the minimum for the image's CUDA version.

---

## Troubleshooting

### "could not select device driver nvidia"

The NVIDIA Container Toolkit is not installed or Docker was not restarted after configuration. Re-run Step 1 and restart Docker.

### GPU detected but speaches still slow

Check that faster-whisper is actually using CUDA:

```bash
docker compose logs speaches | grep -i device
```

If it shows `cpu`, the VRAM may be insufficient for the chosen model. Try a smaller model or verify VRAM availability with `nvidia-smi`.

### Out of memory errors

Reduce model size in `.env`:

```env
ASR_MODEL=medium
```

Or free VRAM by stopping other GPU workloads.
