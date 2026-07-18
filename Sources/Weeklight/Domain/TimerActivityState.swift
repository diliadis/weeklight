import Foundation

enum TimerActivityState: Equatable, Sendable {
    case stopped
    case stopwatchRunning
    case countdownRunning
    case countdownFinishing
    case paused
    case completed

    var systemImage: String {
        switch self {
        case .stopped: "stop.circle"
        case .stopwatchRunning: "play.circle.fill"
        case .countdownRunning: "hourglass"
        case .countdownFinishing: "exclamationmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}
