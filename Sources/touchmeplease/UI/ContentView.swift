import SwiftUI

struct ContentView: View {
    @ObservedObject var store: SessionStore
    @State private var collapsed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if !collapsed {
                Divider().opacity(0.4)
                sessionList
            }
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 8) {
            // Drag handle area — the panel itself is movable by background.
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if store.waitingCount > 0 {
                Text("\(store.waitingCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(.red))
                Text("waiting")
                    .font(.system(size: 11, weight: .medium))
                if store.unvisitedCount > 0 {
                    Text("\(store.unvisitedCount) new")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(.blue))
                }
            } else {
                Text("all clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(AppVersion.display)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)

            Button(action: { collapsed.toggle() }) {
                Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if store.sessions.isEmpty {
                    Text("No active sessions")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 16)
                } else {
                    ForEach(store.sessions) { session in
                        SessionRowView(session: session, store: store)
                    }
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 400)   // long lists scroll; short lists size to content
    }
}
