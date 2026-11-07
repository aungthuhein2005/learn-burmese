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

1. **App Store Connect:** create the app (My Apps → +) with your bundle ID,
   e.g. `com.yourname.kagyi`. Register the same ID under
   Certificates, IDs & Profiles → Identifiers.
2. **Apple Distribution certificate (works on Windows with OpenSSL / Git Bash):**
   ```bash
   openssl genrsa -out dist.key 2048
   openssl req -new -key dist.key -out dist.csr -subj "/emailAddress=you@example.com/CN=Your Name/C=MM"
   ```
   Upload `dist.csr` at developer.apple.com → Certificates → + → *Apple Distribution*,
   download `distribution.cer`, then:
   ```bash
   openssl x509 -inform DER -in distribution.cer -out dist.pem
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12
   ```
   (Choose an export password. If your OpenSSL doesn't know `-legacy`, drop it.)
3. **Provisioning profile:** Profiles → + → *App Store Connect* → your app ID →
   the certificate above → download the `.mobileprovision`.
4. **App Store Connect API key:** Users and Access → Integrations → App Store
   Connect API → + (role *App Manager*). Note the Key ID and Issuer ID and
   download `AuthKey_XXXX.p8`.
5. **GitHub repo secrets** (Settings → Secrets and variables → Actions):

   | Secret | Value |
   |---|---|
   | `BUILD_CERTIFICATE_BASE64` | `base64 -w0 dist.p12` |
   | `P12_PASSWORD` | the export password from step 2 |
   | `BUILD_PROVISION_PROFILE_BASE64` | `base64 -w0 KaGyi.mobileprovision` |
   | `ASC_KEY_ID` | API Key ID |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_PRIVATE_KEY` | full text of the `.p8` file |

   Bundle ID and Team ID are read from the provisioning profile automatically.

Push to `main` (or run the workflow manually): the build appears in TestFlight
after Apple finishes processing (~10–30 min). The build number is the workflow
run number.

## Scoring notes

- Drawings and reference glyphs are both cropped, centered and scaled to the
  same framing on a `#FFFCF8` background, pen width 10 px at 224×224.
- References are rendered with iOS Myanmar fonts and embedded on first launch
  (cached afterwards).
- A drawing earns 3★ only if the target letter is the model's **closest** match
  and similarity ≥ threshold; thresholds per difficulty are in
  `KaGyi/ML/Recognizer.swift`. Tune them after trying it with real kids.
