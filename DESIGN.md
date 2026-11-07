# KaGyi (ကကြီး) — Design Draft v1

An iPhone / iPad app where beginners and kids (ages 4–10) learn to **write** the
33 Myanmar consonants by drawing them with a finger or Apple Pencil. All scoring
runs on-device with the `aungthuhein-dev/myanmar-handwriting` embedding model —
no account, no internet, no ads, no analytics (App Store Kids-category friendly).

---

## 1. Screen list

| # | Screen | Purpose | Main actions |
|---|--------|---------|--------------|
| 1 | **Loading** | Load model, prepare letter references (first launch only, ~3 s) | — (auto-advances) |
| 2 | **Home** | Big, picture-first menu | Learn · Practice · Quiz · My Stars · Parents (small, corner) |
| 3 | **Letter Grid** | All 33 consonants in their 7 traditional groups (ကဝဂ်, စဝဂ်, …) with stars earned | Tap a letter → Practice it; tap 🔊 to hear it |
| 4 | **Learn Card** | Look & listen: huge letter, romanization, audio, "Next/Prev" swipe | 🔊 Play · ✏️ Try writing → Practice |
| 5 | **Practice (Trace)** | Core screen. Write the target letter on a canvas. Faint guide letter behind (can be turned off) | Draw · ↺ Clear · ✓ Check · 👁 Guide on/off · 🔊 · ◀ ▶ |
| 6 | **Result sheet** | Stars (0–3), friendly Myanmar + English message, confetti on 3★; if child wrote a *different* letter, show "That looks like ဂ!" | Try again · Next letter |
| 7 | **Quiz** | 10 rounds: hear a letter (audio) → write it from memory, no guide | Draw · Check · Skip; end screen with total stars |
| 8 | **My Stars** | Sticker-board progress: each letter shows best stars; streak & total | Tap letter → Practice |
| 9 | **Parents' Corner** | Behind a simple adult gate (e.g. "What is 7 × 3?") | Difficulty (Easy/Normal/Hard thresholds) · Left-handed toggle · Sound on/off · Reset progress · About/Privacy |

### Navigation flow

```
Loading ─▶ Home ─┬─▶ Letter Grid ─▶ Practice ─▶ Result ─┐
                 │        ▲                              │ next / again
                 │        └──────────────────────────────┘
                 ├─▶ Learn Card ─▶ Practice
                 ├─▶ Quiz ─▶ (Practice canvas, no guide) ─▶ Quiz Summary
                 ├─▶ My Stars ─▶ Practice
                 └─▶ [adult gate] ─▶ Parents' Corner
```

---

## 2. Wireframes (iPhone portrait)

**Home**
```
┌──────────────────────────────┐
│                         ⚙︎ 🔒 │  ← Parents (small, needs gate)
│        ကကြီး  KaGyi           │
│     ⭐ 42 stars collected      │
│ ┌────────────┐┌────────────┐ │
│ │   📖  က     ││   ✏️        │ │
│ │   Learn    ││  Practice  │ │
│ └────────────┘└────────────┘ │
│ ┌────────────┐┌────────────┐ │
│ │   🎯        ││   ⭐        │ │
│ │   Quiz     ││  My Stars  │ │
│ └────────────┘└────────────┘ │
└──────────────────────────────┘
```

**Practice**
```
┌──────────────────────────────┐
│ ‹ Back        က  ka     🔊   │
│ ┌──────────────────────────┐ │
│ │                          │ │
│ │        (faint က)         │ │  ← cream canvas, kid draws here
│ │                          │ │
│ └──────────────────────────┘ │
│  ◀    ↺ Clear   👁 Guide   ▶  │
│ ┌──────────────────────────┐ │
│ │        ✓  Check           │ │  ← big green button
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

**Result sheet** (slides up)
```
│        ⭐  ⭐  ⭐               │
│   သိပ်ကောင်းတယ်!  Great job!     │
│   [ Try again ]  [ Next ▶ ]   │
```

---

## 3. Visual design

| Token | Value | Use |
|-------|-------|-----|
| Canvas / background | `#FFFCF8` cream | Matches the model's training/reference background — **must stay this color** |
| Ink | `#3D3D3D` | Child's strokes and reference glyphs |
| Primary | `#FF8A3D` warm orange | Main buttons, highlights |
| Success | `#3DBE7A` green | Check button, 3★ |
| Accent | `#4AA8FF` sky blue | Learn, audio |
| Star | `#FFC83D` | Stars |
| Card | white, 24 pt corner radius, soft shadow | Tiles |

- Font: SF Rounded (system `.rounded`) for Latin; system Myanmar font for script.
- Tap targets ≥ 64 pt, buttons labeled with icon **and** word (pre-readers use icons).
- Group colors on the Letter Grid: each of the 7 groups gets its own pastel.
- Haptic tap on Check; confetti + chime on 3★. Never a "wrong" buzzer — only
  "Try again" encouragement.
- Dynamic Type & VoiceOver labels on all buttons; supports iPad with Apple Pencil.

---

## 4. Scoring (how ✓ Check works)

1. Strokes are captured as vectors. On Check, the drawing is **cropped to its
   bounding box, centered and scaled** onto a 224×224 cream square, then
   re-rendered with a fixed pen width. Reference glyphs go through the exact same
   normalization, so position/size of the child's drawing doesn't matter.
2. Model → 256-d embedding. Compare with cosine similarity against the
   reference embeddings of **all 33 letters** (several fonts each, best match kept).
3. Stars:
   - target is **top-1** and similarity ≥ high threshold → ⭐⭐⭐
   - target in **top-3** and similarity ≥ mid threshold → ⭐⭐
   - similarity ≥ low threshold → ⭐ ("Almost! Try again")
   - otherwise 0 ★, and if another letter clearly won: "That looks like ဂ!"
4. Reference embeddings are computed on-device on first launch (with iOS fonts,
   so they match on-device rendering exactly) and cached.

Thresholds live in one place (`Scoring.swift`) and Parents' Corner shifts them
for Easy / Hard.

---

## 5. Out of scope for v1 (later)

- Vowel signs, medials, numbers (model supports any glyph, but needs per-symbol
  tuning and combined-glyph rendering)
- Animated stroke-order guides (needs stroke-order data per letter)
- Word writing, multiple child profiles, iCloud sync

---

## 6. Tech

- SwiftUI, iOS 16+, iPhone + iPad, portrait.
- ONNX Runtime (Swift Package) with Core ML execution provider; model converted
  to a single-file **float32** model (~114 MB) at build time (fp16 was slow and crashed on iPhone CPUs).
- Project generated by **XcodeGen** (`project.yml`) so it can be built entirely
  on GitHub Actions macOS runners → archived → uploaded to **TestFlight**.
- Letter audio: the 33 `.m4a` recordings from the learn-myanmar-script repo.
