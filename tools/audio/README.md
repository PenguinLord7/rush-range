# Procedural Audio Generator

Generates all game SFX and the menu music bed from scratch using only the
Python standard library. No samples, no external assets, no copyrighted audio.

## Regenerate

```bash
python3 tools/audio/gen_sounds.py
```

The script is idempotent (seeded PRNG) — re-running produces byte-identical
files. Output format is always **44100 Hz, 16-bit PCM, mono**.

## Output

Written under `audio/`:

| Folder        | Files |
|---------------|-------|
| `weapons/`    | `rifle_shot`, `handgun_shot`, `dry_fire`, `reload`, `grenade_throw` |
| `environment/`| `explosion`, `impact`, `target_hit`, `target_destroy` |
| `player/`     | `footstep_1..4`, `jump`, `land`, `slide`, `punch` |
| `ui/`         | `click`, `hover`, `score`, `menu_music` |

Each file is peak-normalized (0.4–0.95 depending on type) with 4–5 ms
fade-in/out to avoid clicks. `menu_music.wav` is a 10 s original A-minor
arpeggio/chord bed with a short echo tail for seamless looping.

## Tweaking

Constants live at the top of `gen_sounds.py`. The synthesis helpers
(`tone`, `voice`, `sweep`, `noise`, `lp1`/`hp1`, `sweep_lp`, envelopes,
`echo`) can be reused to add new sounds in the same style; call the new
generator from `main()`.
