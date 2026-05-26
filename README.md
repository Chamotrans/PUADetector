# PUA Detector

iOS app (SwiftUI, iOS 16+) that listens to nearby conversations and warns you when manipulative ("PUA") speech is detected. Speech recognition is performed **entirely on-device** via Apple's Speech framework. If iOS cannot provide an on-device recogniser for the supported locales, detection refuses to start instead of falling back to cloud recognition.

## What you get

- **UI** — Tiffany-blue "PUA DETECTOR" title, semicircular gauge (20–130) with `MIN 65` / `PEAK 115` markers, animated red needle, and a red radar-ripple effect under the dial.
- **Listening** — `AVAudioEngine` mic tap → `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`. Prioritises supported Cantonese recognisers (`zh-HK`, then available Yue variants), then `zh-CN` / `zh-TW` (Mandarin).
- **Classifier** — `PUAClassifier.swift` scores the rolling transcript using a category-aware weighted phrase list covering gaslighting, negging, guilt-tripping, isolation, ownership, threats, financial control, and related tropes in Cantonese, Mandarin, and English.
- **Alert** — Sensitivity is configurable. The default medium threshold is 85, and the default alert mode is vibration. Voice, voice+vibration, and silent modes are available.
- **Privacy controls** — Privacy mode is on by default, so the main UI shows risk summaries and categories instead of the live transcript. Background detection is off by default and opt-in.
- **Risk levels** — Scores are mapped into low risk, watch, warning, and high risk so the user does not have to interpret raw numbers alone.
- **Category controls** — Detection categories can be switched off individually for personal calibration; disabled categories are removed from scoring, ASR contextual hints, and noted in reports.
- **Category presets** — Use full, balanced, or safety-first category presets before making manual tweaks.
- **Local calibration** — Mark a detection as useful or a false positive from the main screen. The app stores aggregate counts only, not transcripts.
- **Settings backup** — Export/import a versioned JSON settings snapshot for sensitivity, alert mode, category filters, privacy mode, and background preference. Transcripts and detections are never included.
- **Privacy reset** — Restore conservative defaults in one tap: privacy mode on, background detection off, vibration alerts, medium sensitivity, and all categories enabled.
- **Settings / debug** — The settings sheet exposes sensitivity, background detection, privacy mode, alert mode, alert voice language, active locale, threshold, score, score trend, recent hits, emergency stop, system permission settings, safety resources, and a manual text tester for classifier tuning.
- **Reports** — Users can share a diagnosis report containing score, risk level, categories, and classifier signals without including the live transcript.
- **Pro LLM deep scan** — Optional manual text analysis can call a configured DeepSeek relay. The app redacts phone numbers, emails, and account-like identifiers before sending text. Live listening remains local-only.
- **Release hygiene** — Includes an Apple privacy manifest declaring no tracking and no collected data types.

## Open the project

```bash
brew install xcodegen   # already done on this machine
cd ~/Developer/PUADetector
xcodegen generate
open PUADetector.xcodeproj
```

(`xcodegen generate` was run once during scaffolding — re-run it any time you edit `project.yml` or add files.)

## Layout

```
PUADetector/
├── project.yml                # XcodeGen spec
└── PUADetector/
    ├── Info.plist             # mic + speech-recognition usage strings
    ├── Resources/
    │   └── Assets.xcassets/   # AccentColor, AppIcon placeholder
    └── Sources/
        ├── PUADetectorApp.swift          # @main
        ├── ContentView.swift             # screen layout
        ├── SettingsView.swift            # settings + manual classifier test
        ├── Palette.swift                 # shared colours
        ├── DetectionPreferences.swift    # sensitivity + alert mode enums
        ├── DetectionReport.swift         # transcript-free report text
        ├── ShareSheet.swift              # system share sheet wrapper
        ├── SafetyResourcesView.swift     # crisis/safety resource links
        ├── ScoreTrendView.swift          # compact score history chart
        ├── DebugDetailsView.swift        # recent hits + classifier metadata
        ├── GaugeView.swift               # semicircular dial + needle
        ├── RadarRippleView.swift         # red radar arcs
        ├── PUADetectorViewModel.swift    # state + decay timer
        ├── SpeechListener.swift          # on-device ASR (zh-HK / zh-CN)
        ├── PUAClassifier.swift           # weighted phrase scoring
        ├── LLMDeepScan.swift             # optional relay-backed Pro analysis
        └── VoiceAlert.swift              # "PUA detected" TTS
PUADetectorTests/
└── PUAClassifierTests.swift              # golden classifier tests
```

## Tuning

- Add/adjust phrases in `PUAClassifier.phrases` — `weight` is roughly "points added to the gauge per hit".
- Thresholds live in `SensitivityLevel.alertThreshold`: low `100`, medium `85`, high `72`.
- Score decay rate is in `startDecayTimer()` (default `1.5/0.5 s`).
- Use the Settings text tester to try transcripts without speaking into the mic.
- Use category presets or individual toggles in Settings to disable categories that are too noisy for a specific user's context. Changing a category immediately recalculates the current in-memory transcript and updates the ASR contextual hint list.
- Use the "有幫助" / "誤報" buttons after detections to track local calibration quality. Settings shows only counts and useful-rate percentage.
- Export/import Settings JSON when copying a tuned profile to another device. The snapshot is intentionally configuration-only and documented in `docs/settings-schema.json`.
- Reported-speech markers such as "佢話" / "有人說" dampen scores so examples and quotes are less likely to over-alert.
- LLM deep scan expects a PUA-specific relay contract, not the Amazing Tutor `/v1/generate-questions` endpoint. See `docs/llm-relay-contract.md`.

## Privacy

`SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition` is always set to `true`. The app only starts with a recogniser that reports `supportsOnDeviceRecognition`; otherwise it shows an error and keeps the microphone off. The rolling transcript is held in memory only, trimmed to the most recent slice, and cleared on stop/emergency stop. `PrivacyInfo.xcprivacy` declares no tracking and no collected data types.

LLM deep scan is manual opt-in only. If a relay endpoint is configured, the submitted text is redacted locally before upload and the DeepSeek API key must stay on the relay/backend, never in the app.

PUA Detector is a safety aid, not a verdict. Its output should be treated as a prompt to pay attention, seek context, and prioritise personal safety.

## Roadmap

`docs/SUGGESTIONS.md` tracks the original 50 suggestions plus the next backlog and explicitly deferred ideas.

## TestFlight / App Store checklist

- Confirm `PrivacyInfo.xcprivacy` still declares no tracking and no collected data types before archive.
- In App Privacy, disclose that audio is processed on-device and not collected by the developer.
- Use `RELEASE_NOTES.md` for TestFlight notes, App Privacy answers, and App Review notes.
- Use TestFlight notes that describe PUA Detector as a safety aid, not a diagnostic or legal decision tool.
- Test first launch permissions, denied-permission recovery, emergency stop, settings export/import, and safety resources on a real device.
- Keep background detection opt-in and verify iOS background audio behaviour on device before release.

## Verification

```bash
scripts/verify.sh
```

The verification script runs Swift parse, privacy manifest lint, and the Xcode test scheme. By default, it uses the checked-in `PUADetector.xcodeproj`; set `REGENERATE_PROJECT=1` when `project.yml` changed. The test scheme runs both `PUADetectorTests` and `PUADetectorUITests` unless `INCLUDE_UI_TESTS=0` is set for CI-friendly unit tests only.

Override defaults when needed:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5' \
scripts/verify.sh
```
