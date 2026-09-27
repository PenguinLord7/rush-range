#!/usr/bin/env python3
"""Procedurally synthesize all SFX/music for the arcade FPS.

Pure Python standard library only (wave, struct, math, random).
Re-runnable / idempotent: identical output every run (seeded RNG).

Output format: 44100 Hz, 16-bit PCM, MONO.
Destination:   <repo>/audio/{weapons,environment,player,ui}/*.wav

Usage:
    python3 tools/audio/gen_sounds.py
"""

import math
import os
import random
import struct
import wave

SR = 44100

# tools/audio/gen_sounds.py -> repo root is three levels up.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, "audio")

TAU = 2.0 * math.pi


# ----------------------------------------------------------------------------
# Core helpers
# ----------------------------------------------------------------------------
def n_of(seconds):
    return max(1, int(round(seconds * SR)))


def tone(freq, n, amp=1.0):
    w = TAU * freq / SR
    return [amp * math.sin(w * i) for i in range(n)]


def voice(freq, n, amp=1.0, harmonics=(1.0,), phases=None):
    """Additive voice: harmonics is gain per harmonic (index 0 -> fundamental)."""
    out = [0.0] * n
    for idx, gain in enumerate(harmonics):
        if gain == 0.0:
            continue
        h = idx + 1
        w = TAU * freq * h / SR
        ph = 0.0 if phases is None else phases[idx % len(phases)]
        for i in range(n):
            out[i] += gain * amp * math.sin(w * i + ph)
    return out


def sweep(f0, f1, n, amp=1.0, exponential=True):
    """Phase-continuous sine sweep from f0 to f1."""
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        frac = i / (n - 1) if n > 1 else 0.0
        if exponential and f0 > 0 and f1 > 0:
            f = f0 * (f1 / f0) ** frac
        else:
            f = f0 + (f1 - f0) * frac
        phase += TAU * f / SR
        out[i] = amp * math.sin(phase)
    return out


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lp1(sig, fc):
    """One-pole low-pass."""
    a = math.exp(-TAU * fc / SR)
    y = 0.0
    out = [0.0] * len(sig)
    for i, x in enumerate(sig):
        y = a * y + (1.0 - a) * x
        out[i] = y
    return out


def hp1(sig, fc):
    """One-pole high-pass (signal minus its low-passed part)."""
    low = lp1(sig, fc)
    return [x - y for x, y in zip(sig, low)]


def sweep_lp(sig, fc0, fc1):
    """Low-pass whose cutoff glides from fc0 to fc1."""
    n = len(sig)
    out = [0.0] * n
    y = 0.0
    for i, x in enumerate(sig):
        frac = i / (n - 1) if n > 1 else 0.0
        fc = fc0 * (fc1 / fc0) ** frac
        a = math.exp(-TAU * fc / SR)
        y = a * y + (1.0 - a) * x
        out[i] = y
    return out


def decay_env(n, tau):
    return [math.exp(-i / (tau * SR)) for i in range(n)]


def ad_env(n, attack_s, tau):
    """Fast linear attack followed by exponential decay (tau seconds)."""
    na = max(1, int(attack_s * SR))
    out = [0.0] * n
    for i in range(n):
        atk = i / na if i < na else 1.0
        out[i] = atk * math.exp(-i / (tau * SR))
    return out


def apply_env(sig, env):
    return [s * e for s, e in zip(sig, env)]


def scale(sig, g):
    return [s * g for s in sig]


def mix(*sigs):
    n = max((len(s) for s in sigs), default=0)
    out = [0.0] * n
    for s in sigs:
        for i, x in enumerate(s):
            out[i] += x
    return out


def place(buf, sig, at_seconds):
    o = n_of(at_seconds)
    lim = len(buf)
    for i, x in enumerate(sig):
        j = o + i
        if j >= lim:
            break
        buf[j] += x
    return buf


def fade(sig, ms=4.0):
    n = min(n_of(ms / 1000.0), len(sig) // 2)
    if n <= 0:
        return sig
    for i in range(n):
        g = i / float(n)
        sig[i] *= g
        sig[-1 - i] *= g
    return sig


def echo(sig, delay_s, decay, repeats=4):
    d = n_of(delay_s)
    out = list(sig) + [0.0] * (d * repeats)
    for r in range(1, repeats + 1):
        g = decay ** r
        off = d * r
        for i, x in enumerate(sig):
            out[off + i] += x * g
    return out


def write_wav(relpath, sig, peak=0.8, fade_ms=4.0):
    if not sig:
        raise ValueError("empty signal for " + relpath)
    fade(sig, fade_ms)
    m = max(abs(x) for x in sig) or 1.0
    g = peak / m
    path = os.path.join(AUDIO, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = bytearray()
    for x in sig:
        v = x * g
        if v > 1.0:
            v = 1.0
        elif v < -1.0:
            v = -1.0
        frames += struct.pack("<h", int(round(v * 32767)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("  %-38s %6.3fs  %7.1f KB" % (relpath, len(sig) / SR, os.path.getsize(path) / 1024.0))


# ----------------------------------------------------------------------------
# Weapons
# ----------------------------------------------------------------------------
def gen_rifle_shot():
    rng = random.Random(1001)
    n = n_of(0.15)

    body = apply_env(noise(n, rng), ad_env(n, 0.0008, 0.026))
    body = lp1(body, 6800)

    thump = apply_env(sweep(175.0, 52.0, n), decay_env(n, 0.040))

    tail = [0.0] * n
    for f, a, tau in ((1750.0, 0.45, 0.055), (2600.0, 0.30, 0.048), (3450.0, 0.20, 0.040)):
        p = apply_env(tone(f, n), decay_env(n, tau))
        tail = mix(tail, scale(p, a))

    sig = mix(scale(body, 1.0), scale(thump, 0.95), scale(tail, 0.32))
    sig = hp1(sig, 38.0)
    write_wav("weapons/rifle_shot.wav", sig, peak=0.88)


def gen_handgun_shot():
    rng = random.Random(1002)
    n = n_of(0.12)

    body = apply_env(noise(n, rng), ad_env(n, 0.0006, 0.018))
    body = hp1(lp1(body, 9000), 180.0)

    thump = apply_env(sweep(245.0, 78.0, n), decay_env(n, 0.026))

    tail = [0.0] * n
    for f, a, tau in ((2700.0, 0.40, 0.030), (3900.0, 0.26, 0.024), (5100.0, 0.16, 0.020)):
        p = apply_env(tone(f, n), decay_env(n, tau))
        tail = mix(tail, scale(p, a))

    sig = mix(scale(body, 1.0), scale(thump, 0.70), scale(tail, 0.30))
    write_wav("weapons/handgun_shot.wav", sig, peak=0.85)


def gen_dry_fire():
    rng = random.Random(1003)
    n = n_of(0.08)

    click = hp1(apply_env(noise(n, rng), decay_env(n, 0.004)), 900.0)
    body = apply_env(tone(2100.0, n), decay_env(n, 0.008))
    body2 = apply_env(tone(3300.0, n, amp=0.5), decay_env(n, 0.005))
    sig = mix(scale(click, 0.8), body, body2)
    write_wav("weapons/dry_fire.wav", sig, peak=0.70)


def gen_reload():
    rng = random.Random(1004)
    n = n_of(0.6)
    buf = [0.0] * n

    events = [
        (0.00, 900.0, 0.55, 0.010),
        (0.09, 1450.0, 0.70, 0.008),
        (0.19, 1150.0, 0.60, 0.009),
        (0.31, 1750.0, 0.75, 0.007),
        (0.44, 1250.0, 0.65, 0.010),
    ]
    for t, f, amp, cl in events:
        m = n_of(0.07)
        click = hp1(apply_env(noise(m, rng), decay_env(m, cl)), 1200.0)
        ring = apply_env(tone(f, m), decay_env(m, 0.020))
        ring2 = apply_env(tone(f * 1.63, m, amp=0.4), decay_env(m, 0.014))
        ev = mix(scale(click, 0.9), ring, ring2)
        place(buf, scale(ev, amp), t)

    buf = hp1(lp1(buf, 6000), 90.0)
    write_wav("weapons/reload.wav", buf, peak=0.72)


def gen_grenade_throw():
    rng = random.Random(1005)
    n = n_of(0.2)

    nz = noise(n, rng)
    hump = [math.sin(math.pi * (i / (n - 1))) ** 1.4 for i in range(n)]
    air = apply_env(sweep_lp(nz, 350.0, 5200.0), hump)
    low = apply_env(sweep(430.0, 150.0, n), hump)
    sig = mix(scale(air, 0.85), scale(low, 0.45))
    sig = hp1(sig, 60.0)
    write_wav("weapons/grenade_throw.wav", sig, peak=0.78)


# ----------------------------------------------------------------------------
# Environment
# ----------------------------------------------------------------------------
def gen_explosion():
    rng = random.Random(2001)
    n = n_of(0.9)

    crack = hp1(apply_env(noise(n, rng), decay_env(n, 0.030)), 1400.0)
    burst = apply_env(noise(n, rng), decay_env(n, 0.18))
    burst = lp1(burst, 4500.0)
    rumble = apply_env(lp1(noise(n, rng), 130.0), decay_env(n, 0.55))
    boom = apply_env(sweep(115.0, 27.0, n), decay_env(n, 0.42))

    sig = mix(scale(crack, 0.55), scale(burst, 0.9), scale(rumble, 0.9), scale(boom, 1.0))
    sig = lp1(sig, 8500.0)
    write_wav("environment/explosion.wav", sig, peak=0.95)


def gen_impact():
    rng = random.Random(2002)
    n = n_of(0.1)

    tick = hp1(apply_env(noise(n, rng), decay_env(n, 0.018)), 1500.0)
    ring = apply_env(tone(1650.0, n), decay_env(n, 0.010))
    thump = apply_env(sweep(210.0, 88.0, n), decay_env(n, 0.014))
    sig = mix(scale(tick, 0.8), scale(ring, 0.35), scale(thump, 0.5))
    write_wav("environment/impact.wav", sig, peak=0.75)


def gen_target_hit():
    n = n_of(0.12)
    base = 1180.0
    sig = voice(
        base,
        n,
        harmonics=(1.0, 0.45, 0.22, 0.10),
        phases=(0.0, 0.0, 0.0, 0.0),
    )
    sig = apply_env(sig, ad_env(n, 0.002, 0.055))
    shimmer = apply_env(tone(base * 2.02, n, amp=0.25), decay_env(n, 0.030))
    sig = mix(sig, shimmer)
    write_wav("environment/target_hit.wav", sig, peak=0.80)


def gen_target_destroy():
    rng = random.Random(2003)
    n = n_of(0.5)

    pop = apply_env(noise(n, rng), ad_env(n, 0.001, 0.035))
    pop = lp1(pop, 5000.0)
    thump = apply_env(sweep(190.0, 58.0, n), decay_env(n, 0.075))
    fall = apply_env(sweep(950.0, 300.0, n), decay_env(n, 0.30))
    sparkle = apply_env(tone(2500.0, n, amp=0.3), decay_env(n, 0.055))

    sig = mix(scale(pop, 0.85), scale(thump, 0.8), scale(fall, 0.55), sparkle)
    write_wav("environment/target_destroy.wav", sig, peak=0.85)


# ----------------------------------------------------------------------------
# Player
# ----------------------------------------------------------------------------
def gen_footstep(idx):
    rng = random.Random(3000 + idx)
    n = n_of(0.12)

    thump = apply_env(sweep(105.0 + idx * 9.0, 58.0, n), decay_env(n, 0.030))
    scuff = apply_env(lp1(noise(n, rng), 900.0 + idx * 130.0), ad_env(n, 0.002, 0.024))
    sig = mix(scale(thump, 0.95), scale(scuff, 0.6))
    write_wav("player/footstep_%d.wav" % idx, sig, peak=0.55)


def gen_jump():
    rng = random.Random(3100)
    n = n_of(0.15)

    lift = apply_env(sweep(220.0, 690.0, n), ad_env(n, 0.004, 0.075))
    air = apply_env(sweep_lp(noise(n, rng), 500.0, 3800.0), decay_env(n, 0.06))
    sig = mix(lift, scale(air, 0.35))
    write_wav("player/jump.wav", sig, peak=0.70)


def gen_land():
    rng = random.Random(3101)
    n = n_of(0.15)

    thud = apply_env(sweep(150.0, 52.0, n), decay_env(n, 0.048))
    dirt = apply_env(lp1(noise(n, rng), 1300.0), ad_env(n, 0.002, 0.030))
    sig = mix(scale(thud, 1.0), scale(dirt, 0.5))
    write_wav("player/land.wav", sig, peak=0.68)


def gen_slide():
    rng = random.Random(3102)
    n = n_of(0.4)

    band = hp1(lp1(noise(n, rng), 3800.0), 500.0)
    flicker = lp1(noise(n, rng), 28.0)
    fm = max((abs(x) for x in flicker), default=1.0) or 1.0
    env = []
    for i in range(n):
        frac = i / (n - 1)
        hump = math.sin(math.pi * frac) ** 0.6
        env.append(hump * (0.55 + 0.45 * abs(flicker[i]) / fm))
    sig = apply_env(band, env)
    write_wav("player/slide.wav", sig, peak=0.60)


def gen_punch():
    rng = random.Random(3103)
    n = n_of(0.12)

    thump = apply_env(sweep(175.0, 58.0, n), decay_env(n, 0.036))
    smack = apply_env(lp1(noise(n, rng), 1600.0), ad_env(n, 0.001, 0.020))
    sig = mix(scale(thump, 1.0), scale(smack, 0.6))
    write_wav("player/punch.wav", sig, peak=0.80)


# ----------------------------------------------------------------------------
# UI
# ----------------------------------------------------------------------------
def gen_ui_click():
    rng = random.Random(4001)
    n = n_of(0.06)
    body = apply_env(tone(1500.0, n), ad_env(n, 0.0008, 0.006))
    tick = hp1(apply_env(noise(n, rng), decay_env(n, 0.0025)), 2200.0)
    sig = mix(body, scale(tick, 0.35))
    write_wav("ui/click.wav", sig, peak=0.60)


def gen_ui_hover():
    n = n_of(0.04)
    sig = apply_env(tone(960.0, n, amp=1.0), ad_env(n, 0.001, 0.006))
    write_wav("ui/hover.wav", sig, peak=0.40)


def gen_ui_score():
    n = n_of(0.25)
    buf = [0.0] * n

    a = apply_env(voice(659.25, n_of(0.11), harmonics=(1.0, 0.3, 0.08)), ad_env(n_of(0.11), 0.004, 0.070))
    b = apply_env(voice(987.77, n_of(0.17), harmonics=(1.0, 0.3, 0.08)), ad_env(n_of(0.17), 0.004, 0.100))
    place(buf, a, 0.0)
    place(buf, b, 0.08)
    write_wav("ui/score.wav", buf, peak=0.75)


# ----------------------------------------------------------------------------
# Music bed (original, loop-friendly arpeggio + chords)
# ----------------------------------------------------------------------------
SONG_CHORDS = [
    (110.00, (220.00, 261.63, 329.63)),  # A minor
    (87.31, (174.61, 220.00, 261.63)),   # F major
    (65.41, (130.81, 164.81, 196.00)),   # C major
    (98.00, (196.00, 246.94, 293.66)),   # G major
]
ARP_PATTERN = (0, 1, 2, 1, 2, 0, 1, 2)


def music_note(freq, dur, amp, rng, harmonics=(1.0, 0.22, 0.07)):
    n = n_of(dur)
    out = [0.0] * n
    for idx, gain in enumerate(harmonics):
        if gain == 0.0:
            continue
        w = TAU * freq * (idx + 1) / SR
        ph = rng.uniform(0.0, TAU)
        for i in range(n):
            out[i] += gain * math.sin(w * i + ph)
    a = max(1, int(0.025 * SR))
    r = max(1, int(0.18 * SR))
    for i in range(n):
        if i < a:
            e = i / a
        elif i > n - r:
            e = (n - i) / r
        else:
            e = 1.0
        out[i] *= amp * e
    return out


def gen_menu_music():
    rng = random.Random(4242)
    total = n_of(10.0)
    dry_dur = 9.2
    dry = [0.0] * n_of(dry_dur)

    bar = dry_dur / len(SONG_CHORDS)
    eighth = bar / 8.0

    for bi, (bass, chord) in enumerate(SONG_CHORDS):
        t0 = bi * bar

        # Sustained pad chord.
        for f in chord:
            note = music_note(f, bar + 0.45, 0.13, rng, harmonics=(1.0, 0.18, 0.06))
            place(dry, note, t0)

        # Soft bass root.
        place(dry, music_note(bass, bar + 0.2, 0.30, rng, harmonics=(1.0, 0.28, 0.05)), t0)

        # Arpeggio, gently rising octave.
        for step, ci in enumerate(ARP_PATTERN):
            f = chord[ci] * 2.0
            if step % 4 == 3:
                f *= 1.5
            note = music_note(f, eighth * 1.7, 0.17, rng, harmonics=(1.0, 0.20, 0.05))
            place(dry, note, t0 + step * eighth)

    full = echo(dry, 0.26, 0.48, repeats=4)
    if len(full) < total:
        full += [0.0] * (total - len(full))
    full = full[:total]
    full = lp1(full, 7000.0)
    write_wav("ui/menu_music.wav", full, peak=0.70, fade_ms=5.0)


# ----------------------------------------------------------------------------
def main():
    print("Generating audio into: %s" % AUDIO)
    gen_rifle_shot()
    gen_handgun_shot()
    gen_dry_fire()
    gen_reload()
    gen_grenade_throw()
    gen_explosion()
    gen_impact()
    gen_target_hit()
    gen_target_destroy()
    for i in range(1, 5):
        gen_footstep(i)
    gen_jump()
    gen_land()
    gen_slide()
    gen_punch()
    gen_ui_click()
    gen_ui_hover()
    gen_ui_score()
    gen_menu_music()
    print("Done.")


if __name__ == "__main__":
    main()
