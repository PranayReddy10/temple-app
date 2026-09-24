# Usage: python3 tool/make_temple_bell.py assets/sounds/temple_bell.wav
# The bell is synthesised here, not recorded, so it carries no licence.
# Synthesises a small brass temple bell (ghanta): inharmonic bell partials
# with individual decays, a slight beating shimmer, and a strike transient.
import math, random, struct, wave, sys
sr = 22050
dur = 3.6
base = 640.0
partials = [  # ratio, amplitude, decay time constant (s)
    (0.50, 0.22, 1.60), (1.00, 0.50, 1.20), (1.19, 0.30, 0.95), (1.50, 0.16, 0.70),
    (2.00, 0.38, 0.85), (2.52, 0.16, 0.50), (2.67, 0.13, 0.45), (3.01, 0.10, 0.38),
    (4.10, 0.08, 0.25), (5.43, 0.05, 0.16),
]
strikes = [(0.0, 1.0), (0.95, 0.75)]
n = int(sr * dur)
out = [0.0] * n
random.seed(3)
for t0, gain in strikes:
    s0 = int(t0 * sr)
    for i in range(s0, n):
        t = (i - s0) / sr
        v = 0.0
        for r, a, d in partials:
            f = base * r
            env = math.exp(-t / d)
            if env < 1e-4:
                continue
            ph = 2 * math.pi * f * t
            # Detuned twin for the shimmer of a real casting.
            v += a * env * (math.sin(ph) + 0.35 * math.sin(ph + 2 * math.pi * 1.3 * t))
        # The clapper's click.
        if t < 0.012:
            v += (random.random() * 2 - 1) * 0.5 * (1 - t / 0.012)
        out[i] += gain * v
peak = max(abs(x) for x in out)
fade = int(0.25 * sr)
frames = bytearray()
for i, x in enumerate(out):
    y = x / peak * 0.85
    if i > n - fade:
        y *= (n - i) / fade
    frames += struct.pack('<h', int(max(-1, min(1, y)) * 32767))
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(bytes(frames))
