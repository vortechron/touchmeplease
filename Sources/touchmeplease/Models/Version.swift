import Foundation

/// Single source of truth for the displayed version. Bump `build` on every change
/// so you can confirm a new build actually loaded (shown in the window header).
enum AppVersion {
    static let version = "0.3"
    static let build = 13

    static var display: String { "v\(version) (\(build))" }
}
