import AppKit
import AudioToolbox
import UserNotifications

/// Reports batch progress outside the window (Dock, haptics, notifications).
protocol BatchFeedback: Sendable {
    /// Progress in 0...1, or nil when no batch is running.
    func progressDidChange(_ fraction: Double?)
    func batchDidFinish(completedCount: Int)
}

/// Dock badge percentage, a haptic tap and sound on completion, and a local
/// notification when the batch finishes while PixelDiet is in the background.
struct SystemBatchFeedback: BatchFeedback {
    func progressDidChange(_ fraction: Double?) {
        guard let fraction, fraction < 1 else {
            NSApp.dockTile.badgeLabel = nil
            return
        }
        NSApp.dockTile.badgeLabel = "\(Int(fraction * 100))%"
    }

    func batchDidFinish(completedCount: Int) {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        Self.playCompletionSound()
        guard !NSApp.isActive else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            // Ask lazily, the first time there is something worth notifying about
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "PixelDiet"
            content.body = CountText.imagesCompressed(completedCount)
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// Plays the system "Glass" sound. Loading it with NSSound on the main thread can stall
    /// the UI, so a system sound is created and played on a background task instead.
    private static func playCompletionSound() {
        Task.detached(priority: .utility) {
            var soundID: SystemSoundID = 0
            let url = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff") as CFURL
            guard AudioServicesCreateSystemSoundID(url, &soundID) == kAudioServicesNoError else { return }
            AudioServicesPlaySystemSoundWithCompletion(soundID) {
                AudioServicesDisposeSystemSoundID(soundID)
            }
        }
    }
}
