import Foundation
import Speech
import AVFoundation

/// Continuously listens via the microphone and runs on-device speech
/// recognition for Cantonese / Mandarin. A single recogniser is used per
/// session (multi-locale parallel recognition was rejected by Apple's
/// on-device pipeline). Engine work happens on a dedicated serial queue so
/// toggling the UI button never blocks the main thread.
final class SpeechListener: NSObject {

    enum ListenerError: LocalizedError {
        case notAuthorized
        case unavailable
        case onDeviceRecognitionUnavailable
        case engineFailed(underlying: Error?)
        case recognitionFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "尚未授權語音辨識或麥克風。"
            case .unavailable:
                return "此裝置目前沒有可用的語音辨識。請確保裝置已連線以下載語音辨識模型。"
            case .onDeviceRecognitionUnavailable:
                return "此裝置目前沒有可用的裝置內語音辨識。為保護私隱，PUA Detector 不會使用雲端語音辨識。請確保裝置已下載語音辨識模型（設定 → 一般 → 鍵盤 → 啟用聽寫）。"
            case .engineFailed(let err):
                return "音訊引擎無法啟動：\(err?.localizedDescription ?? "未知錯誤")"
            case .recognitionFailed(let err):
                return "語音辨識失敗：\(err.localizedDescription)"
            }
        }
    }

    var onTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    var allowBackground: Bool = false
    var contextualHints: [String] = []
    var onStatusChange: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let queue = DispatchQueue(label: "PUADetector.SpeechListener", qos: .userInitiated)

    private var recognizers: [SFSpeechRecognizer] = []
    private var activeRecognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var restartTimer: DispatchSourceTimer?
    private var isStarted: Bool = false
    private var startInFlight: Bool = false
    private var restartScheduled: Bool = false
    /// Number of consecutive restarts where the recognition task died almost
    /// immediately after starting (a real failure, e.g. the on-device model
    /// can't run on this device). Normal silence/timeout rotations do not
    /// count. Used to break out of an otherwise-infinite restart loop.
    private var fastFailCount: Int = 0
    /// When the current task last (re)started, so scheduleRestart can tell a
    /// fast failure from a healthy long-lived rotation.
    private var lastStartAt: DispatchTime = .now()
    /// Set true while we're actively reconfiguring the audio session, so our
    /// own routeChange/interruption notifications don't loop back into another
    /// restart.
    private var suppressSessionEvents: Bool = false
    /// True if we tore down because of an interruption and should resume when
    /// it ends (separate from `isStarted`, which goes false during teardown).
    private var pendingResumeAfterInterruption: Bool = false
    /// Bumped every time we (re)start. Callbacks tagged with the old value are
    /// ignored so a cancelled task can't trigger a phantom restart.
    private var generation: UInt64 = 0

    override init() {
        super.init()
        // Order: Cantonese first (closest match to HK users), then Mandarin
        // fallbacks. `zh-HK` is iOS's actual Cantonese recogniser on most
        // builds; filter through supportedLocales so unsupported identifiers
        // do not produce simulator/runtime noise.
        var locales = [
            Locale(identifier: "zh-HK"),
            Locale(identifier: "yue-Hant-HK"),
            Locale(identifier: "yue-CN"),
            Locale(identifier: "zh-CN"),
            Locale(identifier: "zh-TW")
        ]
        // Fallback locales so the mic can still start on devices that don't
        // have the Chinese on-device dictation models installed (e.g. an
        // English-only review iPad). Chinese recognisers stay first, so HK
        // users keep Cantonese/Mandarin detection whenever those on-device
        // assets are present; we only fall through to the device language /
        // en-US when they aren't. Everything still runs on-device
        // (`requiresOnDeviceRecognition = true`), so this stays fully offline.
        for id in Locale.preferredLanguages {
            let loc = Locale(identifier: id)
            if !locales.contains(where: { $0.identifier == loc.identifier }) {
                locales.append(loc)
            }
        }
        if !locales.contains(where: { $0.identifier == "en-US" }) {
            locales.append(Locale(identifier: "en-US"))
        }
        let supported = Set(SFSpeechRecognizer.supportedLocales().map(\.identifier))
        recognizers = locales
            .filter { supported.contains($0.identifier) }
            .compactMap { SFSpeechRecognizer(locale: $0) }
        observeAudioSession()
    }

    // MARK: - Authorisation

    func requestAuthorization(_ completion: @escaping (Bool, String?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    let micResult: (Bool) -> Void = { granted in
                        DispatchQueue.main.async {
                            if granted {
                                completion(true, nil)
                            } else {
                                completion(false, "請在「設定 → PUA Detector → 麥克風」開啟權限。")
                            }
                        }
                    }
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission(completionHandler: micResult)
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission(micResult)
                    }
                case .denied, .restricted, .notDetermined:
                    completion(false, "請在「設定 → PUA Detector → 語音辨識」開啟權限。")
                @unknown default:
                    completion(false, "未知的授權狀態。")
                }
            }
        }
    }

    // MARK: - Public control

    func start(completion: ((Result<Void, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.isStarted || self.startInFlight {
                DispatchQueue.main.async { completion?(.success(())) }
                return
            }
            self.startInFlight = true
            self.fastFailCount = 0
            do {
                try self.startLocked()
                self.isStarted = true
                self.startInFlight = false
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                self.startInFlight = false
                self.teardownLocked()
                DispatchQueue.main.async {
                    completion?(.failure(error))
                    self.onError?(error)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingResumeAfterInterruption = false
            self.teardownLocked()
            self.isStarted = false
        }
    }

    // MARK: - Engine lifecycle (queue-only)

    private func startLocked() throws {
        teardownLocked()

        generation &+= 1
        let myGen = generation
        lastStartAt = .now()

        guard let recognizer = pickBestRecognizer() else {
            throw ListenerError.unavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw ListenerError.onDeviceRecognitionUnavailable
        }
        activeRecognizer = recognizer
        DispatchQueue.main.async { self.onStatusChange?(recognizer.locale.identifier) }

        try configureAudioSession()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .search
        req.requiresOnDeviceRecognition = true
        // Apple's docs cap this at ~50 phrases. Hand them the shortest /
        // highest-signal ones so the bias actually fits.
        if !contextualHints.isEmpty {
            req.contextualStrings = Array(contextualHints.prefix(50))
        }
        if #available(iOS 16.0, *) {
            req.addsPunctuation = false
        }
        request = req

        // Install the tap BEFORE starting the engine, and use the hardware
        // input format from the audio session (the bus output format can be
        // zero-channel until the engine is running, which crashes installTap).
        let input = audioEngine.inputNode
        let hwFormat = input.inputFormat(forBus: 0)
        guard hwFormat.channelCount > 0 else {
            throw ListenerError.engineFailed(underlying: nil)
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 512, format: hwFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw ListenerError.engineFailed(underlying: error)
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            // Stale callback from an older generation? Drop it.
            self.queue.async {
                guard self.generation == myGen, self.isStarted else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        DispatchQueue.main.async { self.onTranscript?(text) }
                    }
                }

                if let error = error as NSError? {
                    // 203 (kAFAssistantErrorDomain "Retry") and 1110 ("No speech")
                    // are routine; just rotate. Anything else surfaces upward.
                    let routineCodes: Set<Int> = [203, 1110, 216, 301]
                    if !routineCodes.contains(error.code) {
                        DispatchQueue.main.async {
                            self.onError?(ListenerError.recognitionFailed(underlying: error))
                        }
                    }
                    self.scheduleRestart()
                } else if result?.isFinal ?? false {
                    self.scheduleRestart()
                }
            }
        }

        // Apple caps recognition tasks at ~1 min. Pre-rotate so we never hit
        // the wall mid-conversation.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 50, repeating: 50)
        timer.setEventHandler { [weak self] in
            guard let self, self.isStarted, self.generation == myGen else { return }
            do {
                try self.startLocked()
                self.isStarted = true
            } catch {
                self.teardownLocked()
                self.isStarted = false
                DispatchQueue.main.async { self.onError?(error) }
            }
        }
        timer.resume()
        restartTimer = timer
    }

    private func scheduleRestart() {
        guard !restartScheduled else { return }
        restartScheduled = true

        // Distinguish a healthy rotation (task lived a while, then ended on
        // silence/timeout) from a device that simply can't run the recogniser
        // (task dies within ~2s of starting, over and over). Only the latter
        // increments the fast-fail counter.
        let aliveFor = DispatchTime.now().uptimeNanoseconds &- lastStartAt.uptimeNanoseconds
        if aliveFor < 2_000_000_000 {
            fastFailCount += 1
        } else {
            fastFailCount = 0
        }

        // Too many back-to-back instant failures means restarting again will
        // just loop forever (the App Store reviewer's "entered a loop" bug).
        // Stop, and surface a real error so the user/VM can react instead of
        // spinning the audio engine indefinitely.
        if fastFailCount >= 5 {
            restartScheduled = false
            fastFailCount = 0
            teardownLocked()
            isStarted = false
            DispatchQueue.main.async {
                self.onError?(ListenerError.onDeviceRecognitionUnavailable)
            }
            return
        }

        // Back off a touch more as failures stack up, so even sub-threshold
        // churn never becomes a tight spin.
        let delay = 0.3 + Double(fastFailCount) * 0.4
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.restartScheduled = false
            guard self.isStarted else { return }
            do {
                try self.startLocked()
                self.isStarted = true
            } catch {
                self.teardownLocked()
                self.isStarted = false
                DispatchQueue.main.async { self.onError?(error) }
            }
        }
    }

    private func teardownLocked() {
        restartTimer?.cancel()
        restartTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        activeRecognizer = nil
        DispatchQueue.main.async { self.onStatusChange?("未啟動") }

        // Release the audio session so the iOS mic indicator turns off and
        // other apps can record again. Failure here is non-fatal.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        suppressSessionEvents = true
        defer {
            // Allow our own activation's notifications to drain before we
            // start reacting to them again.
            queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.suppressSessionEvents = false
            }
        }

        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = [
            .mixWithOthers,
            .allowBluetooth,
            .defaultToSpeaker
        ]
        try session.setCategory(.playAndRecord, mode: .measurement, options: options)
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        // Make sure output goes to the loud speaker, not the earpiece. The
        // `.defaultToSpeaker` option only kicks in for new sessions; an
        // override is what actually forces the route.
        try? session.overrideOutputAudioPort(.speaker)

        if session.isInputGainSettable {
            try? session.setInputGain(1.0)
        }

        // Best-effort: pick the built-in omnidirectional mic. Failures here
        // must never break the start path.
        if let inputs = session.availableInputs,
           let builtIn = inputs.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtIn)
            if let omni = builtIn.dataSources?.first(where: { $0.preferredPolarPattern == .omnidirectional })
                ?? builtIn.dataSources?.first {
                try? builtIn.setPreferredDataSource(omni)
                try? omni.setPreferredPolarPattern(.omnidirectional)
            }
        }
    }

    private func pickBestRecognizer() -> SFSpeechRecognizer? {
        let available = recognizers.filter { $0.isAvailable }
        return available.first(where: { $0.supportsOnDeviceRecognition })
    }

    // MARK: - Interruption / route-change handling

    private func observeAudioSession() {
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(handleMediaServicesReset(_:)),
                       name: AVAudioSession.mediaServicesWereResetNotification,
                       object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            queue.async { [weak self] in
                guard let self else { return }
                // Remember whether we were running so we can resume after.
                self.pendingResumeAfterInterruption = self.isStarted
                self.teardownLocked()
                self.isStarted = false
            }
        case .ended:
            let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init) ?? []
            queue.async { [weak self] in
                guard let self,
                      self.pendingResumeAfterInterruption,
                      options.contains(.shouldResume) else { return }
                self.pendingResumeAfterInterruption = false
                self.start(completion: nil)
            }
        @unknown default: break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // Only react to route changes that genuinely require a tap rebuild:
        // new/old device unavailable, category change, etc. Ignore the
        // "categoryChange" we triggered ourselves.
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .override, .wakeFromSleep:
            break   // worth handling
        default:
            return  // ignore (.categoryChange, .routeConfigurationChange, .unknown, .noSuitableRouteForCategory)
        }
        queue.async { [weak self] in
            guard let self, self.isStarted, !self.suppressSessionEvents else { return }
            do {
                try self.startLocked()
                self.isStarted = true
            } catch {
                self.teardownLocked()
                self.isStarted = false
            }
        }
    }

    @objc private func handleMediaServicesReset(_ note: Notification) {
        queue.async { [weak self] in
            guard let self, self.isStarted else { return }
            self.teardownLocked()
            do {
                try self.startLocked()
                self.isStarted = true
            } catch {
                self.isStarted = false
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Status

    var hasOnDeviceSupport: Bool {
        recognizers.contains { $0.isAvailable && $0.supportsOnDeviceRecognition }
    }

    var preferredLocaleIdentifier: String? {
        recognizers.first(where: { $0.isAvailable && $0.supportsOnDeviceRecognition })?.locale.identifier
            ?? recognizers.first(where: { $0.isAvailable })?.locale.identifier
    }

    static var hasAllPermissions: Bool {
        let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
        let micOK: Bool
        if #available(iOS 17.0, *) {
            micOK = AVAudioApplication.shared.recordPermission == .granted
        } else {
            micOK = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        return speechOK && micOK
    }
}
