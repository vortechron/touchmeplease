import SwiftUI

struct SessionRowView: View {
    let session: SessionInfo
    @ObservedObject var store: SessionStore
    @State private var hovering = false
    @State private var blinkCount = 0   // >0 while the post-tap blink sequence runs

    /// Blue highlight: shown while unvisited, or mid-blink right after a tap.
    private var unvisited: Bool { store.isUnvisited(session) }
    private var showBlue: Bool { unvisited || blinkCount > 0 }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 10) {
                StatusDot(state: session.state)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(session.projectName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                dismissButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    /// Small X to temporarily remove the row. Appears on hover; the chat
    /// reappears if it continues, or on app restart. Not a delete.
    @ViewBuilder
    private var dismissButton: some View {
        Button(action: { store.hide(session) }) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hovering ? 1 : 0)
        .help("Remove from list (reappears if the chat continues)")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if blinkCount > 0 {
            // Distinct on/off blinks: even = lit, odd = clear.
            return blinkCount % 2 == 1 ? Color.blue.opacity(0.45) : .clear
        }
        if unvisited { return Color.blue.opacity(0.18) }
        return hovering ? Color.primary.opacity(0.08) : .clear
    }

    private func handleTap() {
        let wasUnvisited = unvisited
        store.acknowledge(session)   // clears blue immediately
        Focuser.bringForward()
        if wasUnvisited { runBlink() }
    }

    /// Flash blue a few distinct times over ~5s as tap feedback, then settle.
    private func runBlink() {
        let blinks = 5                 // number of "lit" flashes
        let steps = blinks * 2         // on/off transitions
        let interval = 5.0 / Double(steps)
        blinkCount = steps
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step + 1)) {
                withAnimation(.easeInOut(duration: interval * 0.6)) {
                    blinkCount = steps - step - 1
                }
            }
        }
    }
}

private struct StatusDot: View {
    let state: SessionState
    @State private var pulse = false

    private var color: Color {
        switch state {
        case .waiting: return .red
        case .working: return .orange
        case .idle:    return .gray
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: state == .waiting ? color.opacity(0.8) : .clear, radius: pulse ? 4 : 0)
            .scaleEffect(state == .waiting && pulse ? 1.25 : 1.0)
            .animation(
                state == .waiting
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { if state == .waiting { pulse = true } }
    }
}
