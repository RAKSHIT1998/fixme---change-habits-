import AVFoundation
import UIKit
import Observation

/// Makes an alarm actually loud.
///
/// A notification sound is capped, respects the ringer switch, and stops after 30
/// seconds. Real audio playback does not: with the session set to `.playback`, iOS plays
/// at full app volume **through the silent switch**, loops indefinitely, and can be
/// paired with continuous haptics. That's the difference between a chime and an alarm.
///
/// The catch is that audio only plays while the process is alive. `startKeepAlive()`
/// addresses that by holding an active audio session open — the same technique third-party
/// alarm apps use — at a real battery cost, which is why it's opt-in rather than default.
@MainActor
@Observable
final class AlarmAudioEngine {

    private(set) var isRinging = false
    private(set) var isKeepAliveRunning = false
    private(set) var lastError: String?

    private var ringPlayer: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer?
    private var hapticTimer: Timer?
    private var scheduledRingTimers: [Timer] = []

    /// Persisted opt-in for keeping the app awake so alarms can sound while backgrounded.
    var loudModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "fixme.alarm.loudMode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "fixme.alarm.loudMode")
            if newValue { startKeepAlive() } else { stopKeepAlive() }
        }
    }

    // MARK: - Session

    /// `.playback` is the category that ignores the ringer switch. `duckOthers` lowers
    /// music rather than killing it, so an alarm doesn't silently end someone's podcast.
    private func activateSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            lastError = "Couldn't take over audio: \(error.localizedDescription)"
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func player(named name: String, ext: String = "wav") -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            lastError = "Missing sound file \(name).\(ext)"
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }

    // MARK: - Ringing

    /// Starts the alarm: full-volume looping tone plus a heavy haptic pulse, until stopped.
    func ring() {
        guard !isRinging else { return }
        activateSession()

        guard let player = player(named: "fixme_alarm") else { return }
        player.numberOfLoops = -1        // until the user acts
        player.volume = 1.0
        player.prepareToPlay()
        player.play()
        ringPlayer = player
        isRinging = true

        // Haptics keep working when the phone is face-down or in a pocket.
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            Task { @MainActor in UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func stop() {
        ringPlayer?.stop()
        ringPlayer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
        isRinging = false

        // Drop back to the quiet keep-alive loop if loud mode is still armed.
        if loudModeEnabled {
            startKeepAlive()
        } else {
            deactivateSession()
        }
    }

    // MARK: - Keep-alive

    /// Holds an audio session open with a near-silent loop so iOS keeps the process
    /// alive, letting `ring()` fire later even when the app isn't in the foreground.
    func startKeepAlive() {
        guard !isKeepAliveRunning else { return }
        activateSession()

        guard let player = player(named: "fixme_keepalive") else { return }
        player.numberOfLoops = -1
        player.volume = 0.008        // inaudible, but genuinely playing
        player.prepareToPlay()
        player.play()
        keepAlivePlayer = player
        isKeepAliveRunning = true
    }

    func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        isKeepAliveRunning = false
        if !isRinging { deactivateSession() }
    }

    // MARK: - In-process firing

    /// Arms in-process timers for the given fire times. Only meaningful while the app is
    /// alive — which is exactly what keep-alive buys. Notifications remain the fallback
    /// for when it isn't.
    func armRingTimers(at dates: [Date]) {
        cancelRingTimers()
        let now = Date.now
        for date in dates where date > now {
            let interval = date.timeIntervalSince(now)
            // Timers this far out won't survive anyway; notifications cover them.
            guard interval < 60 * 60 * 24 else { continue }
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                Task { @MainActor in self.ring() }
            }
            scheduledRingTimers.append(timer)
        }
    }

    func cancelRingTimers() {
        scheduledRingTimers.forEach { $0.invalidate() }
        scheduledRingTimers = []
    }
}
