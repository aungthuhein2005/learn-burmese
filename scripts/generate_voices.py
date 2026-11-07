"""Generate the app's Burmese voice clips with Azure Neural Text-to-Speech.

Reads the key from the environment (AZURE_SPEECH_KEY, AZURE_SPEECH_REGION) or
from a `.azure-speech.env` file in the repo root (gitignored) or your home folder:
    AZURE_SPEECH_KEY=...
    AZURE_SPEECH_REGION=southeastasia

Usage:  python scripts/generate_voices.py [--env-file PATH] [--voice my-MM-NilarNeural] [--only letter_01]
Writes trimmed, loudness-matched WAV files to KaGyi/Resources/voices/ (needs `pip install miniaudio`).

Letters whose name is just the bare consonant (င မ လ ဝ သ ဟ အ) are skipped: Azure
renders a lone consonant almost silently, so the app keeps the human recordings
(letter_XX.m4a) for those.
"""
import argparse
import array
import io
import wave
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "KaGyi" / "Resources" / "voices"

# Traditional names children chant for each consonant (the "ka gyi kha gway" song).
LETTER_NAMES = [
    "ကကြီး", "ခခွေး", "ဂငယ်", "ဃကြီး", "င",
    "စလုံး", "ဆလိမ်", "ဇကွဲ", "ဈမျဉ်းဆွဲ", "ညကြီး",
    "ဋသန်လျင်းချိတ်", "ဌဝမ်းဘဲ", "ဍရင်ကောက်", "ဎရေမှုတ်", "ဏကြီး",
    "တဝမ်းပူ", "ထဆင်ထူး", "ဒထွေး", "ဓအောက်ခြိုက်", "နငယ်",
    "ပစောက်", "ဖဦးထုပ်", "ဗထက်ချိုက်", "ဘကုန်း", "မ",
    "ယပက်လက်", "ရကောက်", "လ", "ဝ", "သ",
    "ဟ", "ဠကြီး", "အ",
]

PHRASES = {
    "praise_3": "သိပ်ကောင်းတယ်!",
    "praise_2": "ကောင်းတယ်!",
    "praise_1": "နီးစပ်တယ်၊ ထပ်ကြိုးစားပါ",
    "praise_0": "ထပ်ရေးကြည့်ပါ",
}


def load_config(extra: str | None = None) -> tuple[str, str]:
    candidates = [Path(extra)] if extra else []
    candidates += [ROOT / ".azure-speech.env", Path.home() / ".azure-speech.env"]
    for env_file in candidates:
        if not env_file.exists():
            continue
        for line in env_file.read_text(encoding="utf-8-sig").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"'))
    key = os.environ.get("AZURE_SPEECH_KEY", "").strip()
    region = os.environ.get("AZURE_SPEECH_REGION", "").strip()
    if not key or not region:
        sys.exit("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION (or create .azure-speech.env).")
    return key, region


def synthesize(text: str, voice: str, key: str, region: str, rate: str) -> bytes:
    ssml = (
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="my-MM">'
        f'<voice name="{voice}"><prosody rate="{rate}">{escape(text)}</prosody></voice></speak>'
    )
    req = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"),
        headers={
            "Ocp-Apim-Subscription-Key": key,
            "Content-Type": "application/ssml+xml",
            "X-Microsoft-OutputFormat": "audio-24khz-96kbitrate-mono-mp3",
            "User-Agent": "kagyi-voice-generator",
        },
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 3:
                time.sleep(2 * (attempt + 1))
                continue
            if e.code in (401, 403):
                sys.exit(f"Azure rejected the key/region ({e.code}). Check AZURE_SPEECH_KEY and AZURE_SPEECH_REGION.")
            sys.exit(f"Azure error {e.code}: {e.read().decode(errors='replace')[:300]}")
    sys.exit("Azure kept rate-limiting; try again in a minute.")


def postprocess(mp3: bytes) -> bytes:
    """Decode, trim leading/trailing silence and match loudness; returns 16-bit mono WAV."""
    import miniaudio
    d = miniaudio.decode(mp3, output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1)
    s = array.array("h", d.samples)
    sr = d.sample_rate
    w = int(sr * 0.02)
    rms = [(sum(x * x for x in s[i:i + w]) / w) ** 0.5 for i in range(0, len(s) - w, w)]
    loud = [i for i, r in enumerate(rms) if r > 300]
    if not loud:
        raise ValueError("clip is silent")
    pad = int(sr * 0.08)
    start = max(0, loud[0] * w - pad)
    end = min(len(s), (loud[-1] + 1) * w + pad)
    s = s[start:end]
    speech = [r for r in rms if r > 300]
    speech_rms = (sum(r * r for r in speech) / len(speech)) ** 0.5
    gain = min(4000 / speech_rms, 30000 / max(map(abs, s)))   # ~-18 dBFS speech, peak < -0.8 dBFS
    s = array.array("h", (max(-32767, min(32767, int(x * gain))) for x in s))
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(sr)
        wf.writeframes(s.tobytes())
    return buf.getvalue()


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")   # Windows consoles default to a code page without Burmese
    p = argparse.ArgumentParser()
    p.add_argument("--voice", default="my-MM-NilarNeural", help="or my-MM-ThihaNeural")
    p.add_argument("--rate", default="-15%", help="speaking rate; slower is easier for kids")
    p.add_argument("--only", help="generate just this clip, e.g. letter_05 or praise_3")
    p.add_argument("--env-file", help="path to a KEY=VALUE file with the Azure settings")
    args = p.parse_args()
    key, region = load_config(args.env_file)

    clips = {f"letter_{i:02d}": name for i, name in enumerate(LETTER_NAMES, 1) if len(name) > 1}
    clips.update(PHRASES)
    if args.only:
        clips = {k: v for k, v in clips.items() if k == args.only}
        if not clips:
            sys.exit(f"Unknown clip {args.only}")

    OUT.mkdir(parents=True, exist_ok=True)
    for name, text in clips.items():
        audio = postprocess(synthesize(text, args.voice, key, region, args.rate))
        (OUT / f"{name}.wav").write_bytes(audio)
        print(f"{name}.wav  {len(audio) // 1024:>3} KB  {text}")
    print(f"Done: {len(clips)} clips in {OUT}")


if __name__ == "__main__":
    main()
