# PUA Detector 50 Suggestions Tracker

This tracker turns the original "50 suggestions" request into a concrete backlog. Items marked done have been implemented in the current workspace.

## Done

1. Locate and document the project path.
2. Add a `.gitignore` suitable for Xcode projects.
3. Convert project configuration to XcodeGen.
4. Add a unit test target.
5. Add classifier golden tests.
6. Require on-device speech recognition only.
7. Refuse cloud speech-recognition fallback.
8. Filter unsupported speech locales before use.
9. Prefer Cantonese-capable recognisers before Mandarin fallbacks.
10. Keep microphone off until the user explicitly starts detection.
11. Make background detection opt-in.
12. Make privacy mode on by default.
13. Keep live transcript hidden while privacy mode is enabled.
14. Clear transient transcript state on stop.
15. Add emergency stop that clears current transcript state.
16. Add score decay to avoid stale high-risk states.
17. Add category-aware scoring to reduce duplicate spikes.
18. Add weighted phrase metadata.
19. Add severity metadata.
20. Add phrase locale metadata.
21. Add Cantonese / Mandarin / English phrase coverage.
22. Damp reported-speech examples and quotations.
23. Add risk levels above the raw gauge score.
24. Add category chips to the main UI.
25. Add per-category enable/disable controls.
26. Exclude disabled categories from scoring.
27. Exclude disabled categories from speech contextual hints.
28. Re-evaluate current in-memory transcript after category changes.
29. Add category presets.
30. Add a safety-first preset.
31. Add a balanced preset.
32. Mark manually changed presets as custom.
33. Add configurable sensitivity.
34. Add configurable alert mode.
35. Add configurable alert voice language.
36. Add vibration-only default alerts.
37. Add debug details view.
38. Add score trend view.
39. Add safety resources view.
40. Show safety resources when threat signals appear.
41. Add transcript-free share reports.
42. Include disabled categories and preset in reports.
43. Include explicit privacy status in reports.
44. Add local useful / false-positive calibration counters.
45. Add settings export/import as configuration-only JSON.
46. Add a settings schema document.
47. Add conservative privacy defaults reset.
48. Add Apple privacy manifest.
49. Add UI tests for key settings entry points.
50. Add a reusable verification script and CI workflow draft.

## Next Backlog

1. Add true localization files for English, Traditional Chinese, and Hong Kong Chinese.
2. Add UI tests for manual text tester and category preset picker.
3. Add more false-positive fixtures from neutral relationship conversations.
4. Add more coercive-control safety fixtures from English and Chinese examples.
5. Add an in-app "why this alerted" explanation panel.
6. Add optional haptic confirmation when calibration feedback is recorded.
7. Add a real-device QA checklist for microphone route changes.
8. Add a release build archive script.
9. Add screenshot capture workflow for App Store assets.
10. Add a design pass for Dynamic Type and VoiceOver reading order.

## Deferred

1. Any cloud model or server-side detection.
2. Storing raw audio.
3. Storing full transcripts.
4. Uploading calibration feedback.
5. Background detection as a default-on feature.
