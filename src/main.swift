import Foundation
import CoreGraphics
import IOKit.pwr_mgt
import Darwin

// Hold a display-sleep assertion only while this user's console is locked.
// No synthetic input, password changes, or changes to the screen-saver timer.
final class LockedDisplayKeeper {
    private var assertion: IOPMAssertionID = 0
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private var timer: Timer?
    private var lastState: String?
    private var lockNotificationAt: Date?

    private func log(_ text: String) {
        let line = ISO8601DateFormatter().string(from: Date()) + " " + text + "\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    private func setAssertion(_ enabled: Bool) {
        if enabled && assertion == 0 {
            var created: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Keep display on while screen is locked" as CFString,
                &created
            )
            if result == kIOReturnSuccess {
                assertion = created
                log("display_assertion=on")
            } else {
                log("display_assertion=failed code=\(result)")
            }
        } else if !enabled && assertion != 0 {
            let result = IOPMAssertionRelease(assertion)
            if result == kIOReturnSuccess {
                assertion = 0
                log("display_assertion=off")
            } else {
                log("display_assertion_release=failed code=\(result)")
            }
        }
    }

    private func reconcile() {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            if lastState != "unavailable" { log("session=unavailable"); lastState = "unavailable" }
            setAssertion(false)
            return
        }
        let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool ?? false
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        // The lock notification can precede the session dictionary update.
        let justLocked = lockNotificationAt.map { Date().timeIntervalSince($0) < 2 } ?? false
        let state = "locked=\(locked) on_console=\(onConsole)"
        if state != lastState { log(state); lastState = state }
        setAssertion(onConsole && (locked || justLocked))
    }

    func start(duration: TimeInterval?) {
        let center = DistributedNotificationCenter.default()
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if let user = notification.object as? String, let uid = UInt32(user), uid != getuid() { return }
                self.lockNotificationAt = locked ? Date() : nil
                self.log("notification=" + (locked ? "locked" : "unlocked"))
                if !locked { self.setAssertion(false) }
                self.reconcile()
            }
            observers.append(token)
        }
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { [weak self] in self?.stop() }
            source.resume()
            signals.append(source)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.reconcile() }
        timer?.tolerance = 0.2
        if let duration = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in self?.stop() }
        }
        log("started pid=\(getpid())")
        reconcile()
        RunLoop.main.run()
    }

    private func stop() {
        setAssertion(false)
        log("stopped")
        exit(0)
    }
}

let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "--version" {
    print("LockedDisplayKeeper 0.1.0")
    exit(0)
}
if arguments.count == 2 && ["--help", "-h"].contains(arguments[1]) {
    print("""
    Usage: LockedDisplayKeeper [--duration seconds | --version | --help]
    Keeps the display awake only while the current console session is locked.
    --duration: stop and release the assertion after the specified time.
    """)
    exit(0)
}
let duration: TimeInterval?
if arguments.count == 3, arguments[1] == "--duration", let seconds = Double(arguments[2]), seconds.isFinite, seconds > 0, seconds <= 86400 {
    duration = seconds
} else if arguments.count == 1 {
    duration = nil
} else {
    fputs("Usage: LockedDisplayKeeper [--duration seconds (0 < seconds <= 86400) | --help | --version]\n", stderr)
    exit(64)
}
let keeper = LockedDisplayKeeper()
keeper.start(duration: duration)
