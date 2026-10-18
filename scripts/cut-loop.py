"""Cut a seamless, level-matched loop from a decoded 44.1 kHz stereo WAV.
usage: cut.py in.wav out.wav start_s length_s"""
import array, math, sys, wave
src, dst, start, length = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
SR, FADE, TARGET_DB, PEAK = 44100, 3.0, -21.0, 0.89
w = wave.open(src); assert w.getframerate() == SR and w.getnchannels() == 2
data = array.array('h', w.readframes(w.getnframes()))

def env_min(center_s, radius_s=3.0, step=0.05):
    """Quietest 100 ms point near center (seams land between events)."""
    best, best_e = center_s, None
    t = center_s - radius_s
    while t <= center_s + radius_s:
        i = int(t * SR) * 2; n = int(0.1 * SR) * 2
        seg = data[i:i+n]
        e = sum(x*x for x in seg[::8])
        if best_e is None or e < best_e: best, best_e = t, e
        t += step
    return best

s0 = env_min(start)
s1 = env_min(start + length)
n_loop = int((s1 - s0) * SR); n_fade = int(FADE * SR)
a = int(s0 * SR) * 2
body = array.array('d', data[a:a + n_loop * 2])
tail = data[a + n_loop * 2: a + (n_loop + n_fade) * 2]
for i in range(n_fade):
    t = (i + 0.5) / n_fade
    fi, fo = math.sin(t * math.pi / 2), math.cos(t * math.pi / 2)
    body[2*i] = body[2*i] * fi + tail[2*i] * fo
    body[2*i+1] = body[2*i+1] * fi + tail[2*i+1] * fo
rms = math.sqrt(sum(x*x for x in body[::4]) / (len(body) / 4)) / 32768
gain = 10 ** (TARGET_DB / 20) / max(rms, 1e-9)
# Smoothed peak limiter: 5 ms blocks, instant attack with one block of look-ahead, 120 ms release.
ceiling = PEAK * 32768
block = int(0.005 * SR)
frames = len(body) // 2
nblocks = frames // block + 1
need = []
for bi in range(nblocks):
    seg = body[2*bi*block: 2*(bi+1)*block]
    m = max((abs(x) for x in seg), default=0) * gain
    need.append(min(1.0, ceiling / m) if m > 0 else 1.0)
rel = math.exp(-1 / (0.120 / 0.005))
g, smooth = 1.0, []
for bi in range(nblocks):
    target = min(need[bi], need[bi+1] if bi + 1 < nblocks else 1.0)
    g = target if target < g else target + (g - target) * rel
    smooth.append(g)
out = array.array('h', [0]) * len(body)
for i in range(frames):
    bi = i // block
    gg = gain * smooth[bi]
    out[2*i] = max(-32767, min(32767, int(round(body[2*i] * gg))))
    out[2*i+1] = max(-32767, min(32767, int(round(body[2*i+1] * gg))))
gain = gain * (sum(smooth) / len(smooth))
rms = math.sqrt(sum(x*x for x in out[::4]) / (len(out) / 4)) / 32768 / gain
o = wave.open(dst, 'wb'); o.setnchannels(2); o.setsampwidth(2); o.setframerate(SR); o.writeframes(out.tobytes()); o.close()
print(f"{dst}: {s0:.2f}-{s1:.2f}s ({s1-s0:.1f}s) gain {20*math.log10(gain):+.1f} dB, out rms {20*math.log10(rms*gain):.1f} dBFS, seam jump {abs(out[0]-out[-2])}")
