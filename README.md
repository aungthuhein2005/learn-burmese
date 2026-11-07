# KaGyi (ကကြီး)

iOS app that teaches kids and beginners to write the 33 Myanmar consonants.
Children draw a letter; the on-device model
[`aungthuhein-dev/myanmar-handwriting`](https://huggingface.co/aungthuhein-dev/myanmar-handwriting)
scores it with 0–3 stars. See [DESIGN.md](DESIGN.md) for screens and design.

No Mac needed: GitHub Actions generates the Xcode project, builds, signs and
uploads to TestFlight.

## Layout

```
project.yml                 XcodeGen spec (Xcode project is generated in CI)
scripts/prepare_model.py    Downloads the HF model, fixes the export, converts to fp16
.github/workflows/ios.yml   build job (every push/PR) + testflight job (main)
KaGyi/App                   App entry, letter data
KaGyi/ML                    ONNX Runtime wrapper, image normalization, scoring
KaGyi/Services              App state, progress, audio
KaGyi/Views                 SwiftUI screens
KaGyi/Resources             Icon, letter voices (model is added in CI)
```

## One-time TestFlight setup

Signing is cloud-managed with an App Store Connect API key (same as palm-note):
no certificate or provisioning profile files are needed.

1. Register the bundle ID `com.aungthuhein.kagyi` at developer.apple.com →
   Identifiers, then create the app in App Store Connect → Apps → + with it.
   (To use another ID, set a repository **variable** `BUNDLE_ID`.)
2. Add these repository secrets (Settings → Secrets and variables → Actions) —
   the same values you use for palm-note:

   | Secret | Value |
   |---|---|
   | `APPLE_TEAM_ID` | 10-character Team ID |
   | `APPSTORE_KEY_ID` | API key ID |
   | `APPSTORE_ISSUER_ID` | Issuer ID |
   | `APPSTORE_PRIVATE_KEY` | full text of `AuthKey_XXXXXXXXXX.p8` |

3. Actions → **iOS build & TestFlight** → **Run workflow**. The build appears in
   TestFlight after Apple finishes processing (~10–30 min). The build number is
   the workflow run number. Pushes and PRs only run the compile check.

## Voices

`KaGyi/Resources/voices/` holds:
- `letter_01.m4a` … `letter_33.m4a`: human recordings of the 33 consonants.
- `praise_0.wav` … `praise_3.wav`: encouragement after each check, generated with
  Azure Neural TTS (`my-MM-NilarNeural`).

The app plays a `.wav` clip if one exists, otherwise the `.m4a`. To replace a
sound with a new recording, drop an `.m4a` with the same name into the folder.

```bash
pip install miniaudio
python scripts/generate_voices.py --env-file path/to/azure.env           # praise clips
```

The env file holds `AZURE_SPEECH_KEY=` and `AZURE_SPEECH_REGION=`. Keep it out of git.

## Scoring notes

- Drawings and reference glyphs are both cropped, centered and scaled to the
  same framing on a `#FFFCF8` background, pen width 10 px at 224×224.
- References are rendered with iOS Myanmar fonts and embedded on first launch
  (cached afterwards).
- A drawing earns 3★ only if the target letter is the model's **closest** match
  and similarity ≥ threshold; thresholds per difficulty are in
  `KaGyi/ML/Recognizer.swift`. Tune them after trying it with real kids.
