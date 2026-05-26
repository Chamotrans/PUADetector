# PUA Detector Release Notes

## TestFlight Beta Notes

PUA Detector is an on-device safety aid that listens for manipulative or coercive speech patterns and shows a local risk score. Speech recognition is required, but audio and transcripts are processed on the device and are not collected by the developer.

Please test:

- First launch permission flow for microphone and speech recognition.
- Start/stop detection and emergency stop.
- Privacy mode on/off.
- Background detection opt-in behaviour on a real device.
- Settings export/import.
- Safety resources links.
- False-positive and useful-detection feedback counters.

Known limitation: PUA Detector is not a legal, medical, psychological, or relationship verdict. It is a prompt to pay attention, seek context, and prioritise personal safety.

## App Privacy Answers

- Tracking: No.
- Data collected by developer: None.
- Audio data: Not collected. Audio is streamed into Apple's on-device speech recognition while detection is active.
- Transcripts: Not collected. Recent transcript text is held in memory only, trimmed to the latest slice, and cleared on stop or emergency stop.
- Diagnostics / analytics: None currently collected.
- User content: Not uploaded or stored by the developer.

## Review Notes

PUA Detector uses the microphone and Apple's Speech framework to detect manipulative speech patterns in real time. The app requires on-device speech recognition and refuses to start if no supported on-device recogniser is available. Reports intentionally omit live transcripts and include only score, risk level, categories, classifier signals, and privacy status.

The app includes safety resources and an emergency stop control. It should be reviewed as a privacy-preserving personal safety aid, not as a diagnostic, legal, or professional counselling tool.

## Archive Checklist

- Run `xcodegen generate`.
- Run `swiftc -parse PUADetector/Sources/*.swift`.
- Run `plutil -lint PUADetector/Resources/PrivacyInfo.xcprivacy`.
- Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PUADetector.xcodeproj -scheme PUADetector -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`.
- Test on a real iPhone with microphone and speech recognition permissions reset.
- Confirm `PrivacyInfo.xcprivacy` still declares no tracking and no collected data types.
