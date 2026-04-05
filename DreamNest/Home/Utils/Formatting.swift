import Foundation

public extension TimeInterval {
    func formattedMMSS() -> String {
        let totalSeconds = Int(max(0, self.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

