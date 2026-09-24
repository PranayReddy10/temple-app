# Usage: python3 tool/make_temple_sounds.py assets/sounds
# Synthesises the Om heard as a temple's doors open, and the page turn of
# the passport book. Nothing is recorded, so nothing carries a licence.
import math, random, struct, sys, wave

SR = 22050


def write(path, samples, peak=0.85):
    top = max(abs(x) for x in samples) or 1.0
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x / top * peak)) * 32767)) for x in samples))


def lerp(a, b, t):
    return a + (b - a) * t


def om(dur=2.4):
    """A-U-M, sung low: a voiced tone shaped by vowel formants that glide
    from 'a' through 'u' into the closed-mouth hum of 'm'."""
    f0 = 128.0
    n = int(SR * dur)
    # (time fraction, F1, F2, F3, brightness): the mouth closing over the syllable.
    shape = [(0.00, 720, 1150, 2500, 1.0), (0.30, 650, 1050, 2450, 1.0), (0.50, 420, 820, 2350, 0.8),
             (0.68, 320, 700, 2300, 0.6), (0.80, 260, 1300, 2200, 0.25), (1.00, 250, 1350, 2200, 0.2)]

    def params(t):
        for (t0, *a), (t1, *b) in zip(shape, shape[1:]):
            if t <= t1:
                u = (t - t0) / (t1 - t0)
                return [lerp(x, y, u) for x, y in zip(a, b)]
        return shape[-1][1:]

    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (1 + 0.004 * math.sin(2 * math.pi * 5.2 * i / SR))  # gentle vibrato
        phase += 2 * math.pi * f / SR
        F1, F2, F3, bright = params(t)
        v = 0.0
        for k in range(1, 36):
            fk = f * k
            if fk > 5000:
                break
            g = 1 / (1 + ((fk - F1) / 90) ** 2) + 0.5 / (1 + ((fk - F2) / 120) ** 2) + 0.18 * bright / (1 + ((fk - F3) / 160) ** 2)
            v += g / k ** (0.7 if bright > 0.5 else 1.2) * math.sin(k * phase)
        # Swell in, hold, and let the hum fade as the doors finish opening.
        env = min(1.0, t / 0.08) * (1.0 if t < 0.72 else max(0.0, (1 - t) / 0.28) ** 1.4)
        out[i] = v * env
    # A soft drone an octave down, like a tanpura's lowest string.
    for i in range(n):
        t = i / n
        env = min(1.0, t / 0.15) * max(0.0, 1 - t) ** 0.8
        out[i] += 0.35 * env * math.sin(2 * math.pi * (f0 / 2) * i / SR)
    return out


def page_turn(dur=0.42):
    """A stiff page lifted and laid over: a band of noise that swells as the
    page moves through the air, then a soft flap as it lands."""
    random.seed(5)
    n = int(SR * dur)
    out = [0.0] * n
    lp = hp = 0.0
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        lp += 0.35 * (x - lp)          # low-pass: take the hiss off
        hp = lp - (hp + 0.02 * (lp - hp))  # crude high-pass: take the rumble off
        swish = math.exp(-((t - 0.13) / 0.075) ** 2)  # the page sweeping through
        flap = math.exp(-max(0.0, t - 0.30) / 0.03) if t >= 0.30 else 0.0  # landing
        crackle = 1 + 0.6 * (random.random() < 0.02)
        out[i] = hp * (0.9 * swish + 0.7 * flap) * crackle
    return out


if __name__ == '__main__':
    d = sys.argv[1]
    write(f'{d}/om.wav', om(), 0.8)
    write(f'{d}/page_turn.wav', page_turn(), 0.7)
