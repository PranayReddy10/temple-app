# Usage: python3 tool/make_temple_sounds.py assets/sounds
# Synthesises the page turn of the passport book. Nothing is recorded, so nothing carries a licence.
import math, random, struct, sys, wave

SR = 22050


def write(path, samples, peak=0.85):
    top = max(abs(x) for x in samples) or 1.0
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x / top * peak)) * 32767)) for x in samples))


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
    write(f'{d}/page_turn.wav', page_turn(), 0.7)
