#!/usr/bin/env python3
"""Generate Duet's ambient loops (rain, forest, ocean).

Every layer is built to be exactly periodic over the loop length, so the
file repeats under AVAudioPlayer numberOfLoops = -1 without a click:
noise beds are shaped in the frequency domain (an inverse FFT of a random
spectrum is periodic by construction), envelopes use whole cycles or
wrapped time, and one-shot events (drops, chirps, wave crashes) that run
past the end wrap around to the start. Reverb is a circular convolution.

Output is mono 16-bit 44.1 kHz WAV, normalized like generate-noise.py,
and deterministic (fixed seeds). Needs numpy.

Usage: python3 scripts/generate-ambience.py [output-dir]
"""

import sys
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44_100
TARGET_RMS_DB = -20.0
PEAK_LIMIT = 0.89


# --- Periodic building blocks -------------------------------------------------

def shaped_noise(n, rng, lo, hi, tilt=0.0, order=2):
    """Unit-RMS noise, periodic over n samples, band-limited to lo..hi Hz.

    tilt is the magnitude slope exponent: -0.5 is pink, -1 is brown.
    """
    f = np.fft.rfftfreq(n, 1 / SAMPLE_RATE)
    f[0] = 1.0
    mag = (f / 1000.0) ** tilt
    mag /= np.sqrt(1 + (lo / f) ** (2 * order))
    mag /= np.sqrt(1 + (f / hi) ** (2 * order))
    mag[0] = 0.0
    spectrum = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f))) * mag
    x = np.fft.irfft(spectrum, n)
    return x / np.sqrt(np.mean(x * x))


def slow_wobble(n, rng, max_cycles):
    """Smooth periodic curve in -1..1 with at most max_cycles cycles per loop."""
    spectrum = np.zeros(n // 2 + 1, dtype=complex)
    k = np.arange(1, max_cycles + 1)
    spectrum[k] = (rng.standard_normal(len(k)) + 1j * rng.standard_normal(len(k))) / k
    x = np.fft.irfft(spectrum, n)
    return x / np.max(np.abs(x))


def circular_reverb(x, rng, seconds, wet, lowpass_hz):
    m = int(seconds * SAMPLE_RATE)
    t = np.arange(m) / SAMPLE_RATE
    ir = rng.standard_normal(m) * np.exp(-6.9 * t / seconds)
    f = np.fft.rfftfreq(len(x), 1 / SAMPLE_RATE)
    lowpass = 1 / np.sqrt(1 + (f / lowpass_hz) ** 4)
    padded = np.zeros(len(x))
    padded[:m] = ir
    tail = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(padded) * lowpass, len(x))
    tail *= np.sqrt(np.mean(x * x) / max(np.mean(tail * tail), 1e-12))
    return (1 - wet) * x + wet * tail


def add_wrapped(buf, event, start):
    idx = (start + np.arange(len(event))) % len(buf)
    buf[idx] += event


def wrapped_time(n, center_s, loop_s):
    """Signed seconds from center, wrapped into -loop/2..loop/2."""
    t = np.arange(n) / SAMPLE_RATE
    return (t - center_s + loop_s / 2) % loop_s - loop_s / 2


def tone(freqs, amp, harmonics=((2, 0.12),)):
    phase = 2 * np.pi * np.cumsum(freqs) / SAMPLE_RATE
    out = np.sin(phase)
    for multiple, level in harmonics:
        out += level * np.sin(multiple * phase)
    return out * amp


def note_envelope(m, attack=0.15):
    t = np.linspace(0, 1, m)
    a = np.clip(t / attack, 0, 1)
    r = np.clip((1 - t) / (1 - attack), 0, 1)
    return np.sin(a * np.pi / 2) ** 2 * np.sin(r * np.pi / 2) ** 1.5


# --- Sounds -------------------------------------------------------------------

def rain(loop_s, rng):
    n = int(loop_s * SAMPLE_RATE)
    hiss = shaped_noise(n, rng, 500, 9000, tilt=-0.25)
    body = shaped_noise(n, rng, 120, 1200, tilt=-0.6)
    swell = 1 + 0.12 * slow_wobble(n, rng, 4)
    bed = (hiss + 0.35 * body) * swell

    drops = np.zeros(n)
    # Small, fast drops: decaying, slightly rising bubble tones.
    for _ in range(int(90 * loop_s)):
        dur = rng.uniform(0.004, 0.012)
        m = int(dur * 5 * SAMPLE_RATE)
        t = np.arange(m) / SAMPLE_RATE
        f0 = rng.uniform(1800, 5200)
        freqs = f0 * (1 + 0.5 * t / (dur * 5))
        ev = tone(freqs, rng.lognormal(-1.2, 0.5), harmonics=()) * np.exp(-t / dur)
        add_wrapped(drops, ev, rng.integers(n))
    # A few nearer, heavier drops.
    for _ in range(int(4 * loop_s)):
        dur = rng.uniform(0.012, 0.025)
        m = int(dur * 5 * SAMPLE_RATE)
        t = np.arange(m) / SAMPLE_RATE
        f0 = rng.uniform(900, 2200)
        freqs = f0 * (1 + 0.3 * t / (dur * 5))
        ev = tone(freqs, rng.lognormal(-0.6, 0.4), harmonics=()) * np.exp(-t / dur)
        add_wrapped(drops, ev, rng.integers(n))
    drops = circular_reverb(drops, rng, 0.25, 0.4, 7000)
    drops *= 0.45 / np.sqrt(np.mean(drops * drops))

    return circular_reverb(bed + drops, rng, 0.6, 0.15, 6000)


def bird_whistle(rng):
    notes = []
    base = rng.uniform(2400, 3400)
    for _ in range(rng.integers(3, 6)):
        dur = rng.uniform(0.09, 0.22)
        m = int(dur * SAMPLE_RATE)
        t = np.linspace(0, 1, m)
        f0 = base * rng.uniform(0.85, 1.2)
        f1 = f0 * rng.uniform(0.75, 1.3)
        vibrato = 1 + 0.015 * np.sin(2 * np.pi * rng.uniform(25, 40) * t * dur)
        notes.append(tone((f0 + (f1 - f0) * t) * vibrato, 1.0) * note_envelope(m))
        notes.append(np.zeros(int(rng.uniform(0.05, 0.14) * SAMPLE_RATE)))
    return np.concatenate(notes)


def bird_chips(rng):
    notes = []
    top = rng.uniform(4600, 6000)
    for _ in range(rng.integers(5, 11)):
        dur = rng.uniform(0.02, 0.035)
        m = int(dur * SAMPLE_RATE)
        t = np.linspace(0, 1, m)
        freqs = top - (top * 0.4) * t ** 0.7
        notes.append(tone(freqs, 1.0, harmonics=((2, 0.05),)) * note_envelope(m, 0.2))
        notes.append(np.zeros(int(rng.uniform(0.05, 0.08) * SAMPLE_RATE)))
    return np.concatenate(notes)


def bird_coo(rng):
    notes = []
    base = rng.uniform(480, 620)
    for i in range(rng.integers(2, 4)):
        dur = rng.uniform(0.3, 0.5) if i else 0.22
        m = int(dur * SAMPLE_RATE)
        t = np.linspace(0, 1, m)
        freqs = base * (1 + 0.06 * np.sin(np.pi * t))
        notes.append(tone(freqs, 1.0, harmonics=((2, 0.25), (3, 0.08))) * note_envelope(m, 0.3))
        notes.append(np.zeros(int(0.18 * SAMPLE_RATE)))
    return np.concatenate(notes)


def forest(loop_s, rng):
    n = int(loop_s * SAMPLE_RATE)
    gusts = 0.5 + 0.5 * slow_wobble(n, rng, 6)
    flutter = 1 + 0.25 * slow_wobble(n, rng, int(loop_s * 7))
    leaves = shaped_noise(n, rng, 350, 6000, tilt=-0.5) * (0.3 + 0.7 * gusts ** 1.5) * flutter
    wind = shaped_noise(n, rng, 40, 350, tilt=-0.8) * (0.6 + 0.4 * gusts)
    bed = leaves + 0.5 * wind

    birds = np.zeros(n)
    callers = [bird_whistle, bird_chips, bird_whistle, bird_coo, bird_chips, bird_whistle,
               bird_coo, bird_whistle, bird_chips, bird_whistle, bird_chips]
    slots = np.linspace(0, n, len(callers), endpoint=False)
    for caller, slot in zip(callers, slots):
        start = int(slot + rng.uniform(0, 0.7) * n / len(callers))
        level = rng.uniform(0.25, 1.0)
        add_wrapped(birds, caller(rng) * level, start)
    birds = circular_reverb(birds, rng, 1.2, 0.45, 5000)
    birds *= 0.4 / np.sqrt(np.mean(birds * birds))

    return bed + birds


def ocean(loop_s, rng):
    n = int(loop_s * SAMPLE_RATE)
    rumble = shaped_noise(n, rng, 30, 260, tilt=-1.0)
    crash = shaped_noise(n, rng, 150, 6000, tilt=-0.5)
    fizz = shaped_noise(n, rng, 1500, 11000, tilt=-0.3)
    bed = shaped_noise(n, rng, 40, 1200, tilt=-1.0)

    rumble_env = np.full(n, 0.3)
    crash_env = np.zeros(n)
    fizz_env = np.zeros(n)
    crashes = [1.5, 10.0, 20.0, 28.5]
    strengths = [0.9, 1.0, 0.75, 0.95]
    for center, strength in zip(crashes, strengths):
        d = wrapped_time(n, center, loop_s)
        rumble_env += strength * 0.8 * np.exp(-0.5 * ((d + 0.6) / 1.4) ** 2)
        attack = np.clip((d + 1.2) / 1.5, 0, 1)
        crash_env += strength * np.where(d < 0.3, np.sin(attack * np.pi / 2) ** 2,
                                         np.exp(-(d - 0.3) / 1.6))
        fizz_attack = np.clip((d + 0.4) / 1.4, 0, 1)
        fizz_env += strength * np.where(d < 1.0, np.sin(fizz_attack * np.pi / 2) ** 2,
                                        np.exp(-(d - 1.0) / 2.8))

    fizz_flutter = 1 + 0.3 * slow_wobble(n, rng, int(loop_s * 3))
    breathing = 1 + 0.15 * slow_wobble(n, rng, 3)
    mix = (0.8 * rumble * rumble_env + crash * crash_env
           + 0.45 * fizz * fizz_env * fizz_flutter + 0.5 * bed * breathing)
    return circular_reverb(mix, rng, 1.5, 0.2, 4000)


# --- Output -------------------------------------------------------------------

def normalize(x):
    x = x - np.mean(x)
    gain = 10 ** (TARGET_RMS_DB / 20) / np.sqrt(np.mean(x * x))
    peak = np.max(np.abs(x)) * gain
    if peak > PEAK_LIMIT:
        gain *= PEAK_LIMIT / peak
    return x * gain


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767), -32767, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())


SOUNDS = [
    ("rain", rain, 20),
    ("forest", forest, 30),
    ("ocean", ocean, 36),
]


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "MixLayer" / "Resources" / "Sounds"
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, (name, generator, seconds) in enumerate(SOUNDS):
        rng = np.random.default_rng(20261017 + 100 + index)
        path = out_dir / f"{name}.wav"
        write_wav(path, normalize(generator(seconds, rng)))
        print(f"wrote {path} ({seconds}s)")


if __name__ == "__main__":
    main()
