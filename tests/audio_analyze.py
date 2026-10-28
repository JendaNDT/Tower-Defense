#!/usr/bin/env python3
"""Rozbor vygenerovaných WAV (nástroj scripts/tools/audio_dump.gd).
Poslech nahradit nelze, proto kontroluje měřitelné vlastnosti: ticho, přebuzení, stejnosměrná složka,
cvaknutí na začátku/konci, švy smyček, výšku tónů (hudba v d moll), tempo a rozdíl klidné/bojové hudby.
Použití: python3 tests/audio_analyze.py CESTA_K_WAV [--png vystup.png]"""
import sys, os, wave, json
import numpy as np
import importlib.util


def importlib_util_find(name):
    return importlib.util.find_spec(name) is not None

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
D_MINOR = {"D", "E", "F", "G", "A", "A#", "C"}          # d moll přirozená (B♭ = A#)


def load(path):
    with wave.open(path) as w:
        n, rate, ch = w.getnframes(), w.getframerate(), w.getnchannels()
        raw = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64) / 32768.0
    if ch > 1:
        raw = raw.reshape(-1, ch).mean(axis=1)
    return raw, rate


def envelope(x, rate, win=0.01):
    k = max(int(rate * win), 1)
    m = len(x) // k
    return np.sqrt((x[: m * k].reshape(m, k) ** 2).mean(axis=1)), k / rate


def dom_freq(x, rate):
    n = len(x)
    if n < 64:
        return 0.0
    sp = np.abs(np.fft.rfft(x * np.hanning(n)))
    f = np.fft.rfftfreq(n, 1.0 / rate)
    return float(f[1 + np.argmax(sp[1:])])


def centroid(x, rate):
    sp = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    return float((sp * f).sum() / max(sp.sum(), 1e-12))


def chroma(x, rate):
    sp = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    sel = (f > 60) & (f < 2000)
    midi = 69 + 12 * np.log2(f[sel] / 440.0)
    pc = np.round(midi).astype(int) % 12
    c = np.zeros(12)
    np.add.at(c, pc, sp[sel])
    return c / max(c.sum(), 1e-12)


def tempo(x, rate):
    """Odhad tempa z autokorelace obálky (úderů za minutu)."""
    env, dt = envelope(x, rate, 0.02)
    d = np.maximum(np.diff(env), 0)
    d -= d.mean()
    ac = np.correlate(d, d, mode="full")[len(d) - 1:]
    lo, hi = int(60 / 200 / dt), int(60 / 60 / dt)
    lag = lo + int(np.argmax(ac[lo:hi]))
    return 60.0 / (lag * dt)


def analyze(path):
    x, rate = load(path)
    name = os.path.splitext(os.path.basename(path))[0]
    peak = float(np.abs(x).max())
    rms = float(np.sqrt((x ** 2).mean()))
    env, dt = envelope(x, rate)
    emax = float(env.max())
    loud = np.where(env > emax * 0.1)[0]
    r = {
        "name": name, "sec": len(x) / rate, "rate": rate, "peak": peak,
        "rms_db": 20 * np.log10(max(rms, 1e-9)), "dc": float(x.mean()),
        "clipped": int((np.abs(x) > 0.999).sum()),
        "sound_sec": float((loud[-1] - loud[0] + 1) * dt) if len(loud) else 0.0,
        "attack_ms": float(np.argmax(env >= emax * 0.9) * dt * 1000),
        "dom_hz": dom_freq(x, rate), "centroid_hz": centroid(x, rate),
        "edge": float(max(abs(x[0]), abs(x[-1]))),
    }
    # švy smyčky: skok na přechodu konec -> začátek vs. běžný skok mezi vzorky
    typ = float(np.percentile(np.abs(np.diff(x)), 99))
    r["seam_jump"] = float(abs(x[0] - x[-1]))
    r["seam_ratio"] = r["seam_jump"] / max(typ, 1e-9)
    if name.startswith("music_"):
        c = chroma(x, rate)
        r["chroma"] = {NOTE[i]: round(float(c[i]), 3) for i in np.argsort(-c)[:8]}
        r["in_key"] = float(sum(c[i] for i in range(12) if NOTE[i] in D_MINOR))
        r["tempo_bpm"] = tempo(x, rate)
    return r, x, rate


def main():
    root = sys.argv[1]
    files = sorted(f for f in os.listdir(root) if f.endswith(".wav"))
    res, problems = {}, []
    for f in files:
        r, x, rate = analyze(os.path.join(root, f))
        res[r["name"]] = r
        n = r["name"]
        loop = n.startswith("music_") or n.startswith("amb_")
        if r["peak"] < 0.3:
            problems.append(f"{n}: příliš tichý (peak {r['peak']:.2f})")
        if r["peak"] > 0.95 or r["clipped"] > 0:
            problems.append(f"{n}: přebuzení (peak {r['peak']:.3f}, ořezaných {r['clipped']})")
        if abs(r["dc"]) > 0.02:
            problems.append(f"{n}: stejnosměrná složka {r['dc']:.3f}")
        if not loop and r["edge"] > 0.01:
            problems.append(f"{n}: nenulový začátek/konec (cvaknutí) {r['edge']:.3f}")
        if loop and r["seam_ratio"] > 6:
            problems.append(f"{n}: šev smyčky skáče {r['seam_jump']:.3f} (×{r['seam_ratio']:.1f} běžného kroku)")
        if r["sound_sec"] < 0.03:
            problems.append(f"{n}: téměř ticho (znělých {r['sound_sec']:.2f} s)")
        if n.startswith("music_") and r["in_key"] < 0.8:
            problems.append(f"{n}: jen {r['in_key']*100:.0f} % energie v tónině d moll")
    print(f"{'zvuk':14s} {'s':>5s} {'peak':>5s} {'RMS dB':>7s} {'znělé s':>7s} {'náběh ms':>8s} {'dom Hz':>7s} {'těžiště Hz':>10s} {'šev×':>5s}")
    for n, r in res.items():
        print(f"{n:14s} {r['sec']:5.2f} {r['peak']:5.2f} {r['rms_db']:7.1f} {r['sound_sec']:7.2f} {r['attack_ms']:8.0f} "
              f"{r['dom_hz']:7.0f} {r['centroid_hz']:10.0f} {r['seam_ratio']:5.1f}")
    for n in ("music_calm", "music_battle"):
        if n in res:
            r = res[n]
            print(f"{n}: tempo≈{r['tempo_bpm']:.0f} BPM, v tónině d moll {r['in_key']*100:.0f} %, nejčastější tóny {r['chroma']}")
    if "music_calm" in res and "music_battle" in res:
        a, b = res["music_calm"], res["music_battle"]
        print(f"bojová vs. klidná: těžiště {b['centroid_hz']:.0f} vs {a['centroid_hz']:.0f} Hz, tempo {b['tempo_bpm']:.0f} vs {a['tempo_bpm']:.0f}")
        if b["centroid_hz"] <= a["centroid_hz"]:
            problems.append("bojová hudba není jasnější než klidná")
    # PNG se spektrogramy (volitelně)
    if "--png" in sys.argv and importlib_util_find("matplotlib"):
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        names = [f for f in files if not f.startswith(("music_", "amb_"))]
        cols = 6
        rows = (len(names) + cols - 1) // cols
        fig, axs = plt.subplots(rows, cols, figsize=(cols * 3.2, rows * 2.2))
        for ax in axs.flat:
            ax.axis("off")
        for ax, f in zip(axs.flat, names):
            x, rate = load(os.path.join(root, f))
            ax.axis("on")
            ax.specgram(x, NFFT=512, Fs=rate, noverlap=384, cmap="magma")
            ax.set_title(f[:-4], fontsize=8)
            ax.tick_params(labelsize=6)
        fig.tight_layout()
        fig.savefig(sys.argv[sys.argv.index("--png") + 1], dpi=80)
    print("\nPROBLÉMY:" if problems else "\nBez nalezených problémů.")
    for p in problems:
        print(" -", p)
    json.dump(res, open(os.path.join(root, "analyza.json"), "w"), ensure_ascii=False, indent=1, default=float)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
