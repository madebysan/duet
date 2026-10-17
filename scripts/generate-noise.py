#!/usr/bin/env python3
"""Generate Duet's built-in noise loops (white, pink, brown).

Each file is a mono 16-bit WAV that loops seamlessly: the extra tail is
equal-power crossfaded into the head, so AVAudioPlayer can repeat it with
numberOfLoops = -1 without a click. Output is deterministic (fixed seed).

Usage: python3 scripts/generate-noise.py [output-dir]
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
LOOP_SECONDS = 20
FADE_SECONDS = 1.5
TARGET_RMS_DB = -20.0
PEAK_LIMIT = 0.89


def white(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def pink(n, rng):
    # Paul Kellet's refined pink filter.
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(n):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append(b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362)
        b6 = w * 0.115926
    return out


def brown(n, rng):
    # Leaky integrator keeps the walk centred so the loop seam has no DC jump.
    last = 0.0
    out = []
    for _ in range(n):
        last = (last + 0.02 * rng.uniform(-1.0, 1.0)) * 0.998
        out.append(last)
    return out


def make_loop(samples, loop_len, fade_len):
    body = samples[:loop_len]
    tail = samples[loop_len:loop_len + fade_len]
    for i in range(fade_len):
        t = (i + 0.5) / fade_len
        fade_in = math.sin(t * math.pi / 2)
        fade_out = math.cos(t * math.pi / 2)
        body[i] = body[i] * fade_in + tail[i] * fade_out
    return body


def normalize(samples):
    mean = sum(samples) / len(samples)
    centred = [s - mean for s in samples]
    rms = math.sqrt(sum(s * s for s in centred) / len(centred)) or 1.0
    gain = (10 ** (TARGET_RMS_DB / 20)) / rms
    peak = max(abs(s) for s in centred) * gain
    if peak > PEAK_LIMIT:
        gain *= PEAK_LIMIT / peak
    return [s * gain for s in centred]


def write_wav(path, samples):
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(round(s * 32767)))))
            for s in samples
        )
        wav.writeframes(frames)


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "MixLayer" / "Resources" / "Sounds"
    out_dir.mkdir(parents=True, exist_ok=True)

    loop_len = SAMPLE_RATE * LOOP_SECONDS
    fade_len = int(SAMPLE_RATE * FADE_SECONDS)
    total = loop_len + fade_len

    for index, (name, generator) in enumerate([("white-noise", white), ("pink-noise", pink), ("brown-noise", brown)]):
        rng = random.Random(20261017 + index)
        samples = normalize(make_loop(generator(total, rng), loop_len, fade_len))
        path = out_dir / f"{name}.wav"
        write_wav(path, samples)
        print(f"wrote {path} ({LOOP_SECONDS}s)")


if __name__ == "__main__":
    main()
