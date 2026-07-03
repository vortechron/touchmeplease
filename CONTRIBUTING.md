# Contributing to touchmeplease

Thanks for looking under the hood. This doc covers everything you need to build, run, and safely
modify the app — including the reverse-engineered domain knowledge that isn't obvious from the code.

## Prerequisites

- macOS 14 (Sonoma) or later
- Swift 6 toolchain (Xcode 16+ or a matching Swift toolchain)
- The [Claude desktop app](https://claude.ai/download) installed and used at least once (so there
  is real session data on disk to read)

No third-party dependencies — it's a pure Swift Package Manager executable.

## Build & run

```bash
swift build                 # debug build → .build/debug/touchmeplease
swift run                   # build and run the debug binary directly
./bundle.sh                 # release build wrapped in touchmeplease.app (unsigned)
open touchmeplease.app
```

The app runs as an `LSUIElement` accessory — **no Dock icon, no menu bar item**. Quit it via the
✕ button in the panel header, or:

```bash
pkill -f touchmeplease
```

### Iteration loop

The tight loop used during development (rebuild, reinstall to `/Applications`, re-register with
Launch Services, relaunch):

```bash
pkill -f touchmeplease; ./bundle.sh && rm -rf /Applications/touchmeplease.app \
  && cp -R touchmeplease.app /Applications/ \
  && /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/touchmeplease.app \
  && open /Applications/touchmeplease.app
```

**Bump `AppVersion.build` in [`Sources/touchmeplease/Models/Version.swift`](Sources/touchmeplease/Models/Version.swift)
on every change.** The `vX (build N)` badge in the header is how you confirm a new build actually
loaded.

### Verifying the window

Screenshot/computer-use tooling can't reliably target an `LSUIElement` agent app. To confirm the
window is up, inspect the window list instead of screenshotting:

```bash
# look for owner=touchmeplease, layer=3
python3 -c "from Quartz import CGWindowListCopyWindowInfo, kCGWindowListOptionAll, kCGNullWindowID; \
print([w for w in CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID) \
if 'touchmeplease' in str(w.get('kCGWindowOwnerName',''))])"
```

Inspect live data directly with `python3` / `ls` against the two Claude data directories (below).

## Architecture at a glance

Data flow: **two on-disk Claude data sources → scan/derive → observable store → SwiftUI panel.**

| Layer | File | Responsibility |
| ----- | ---- | -------------- |
| Metadata scan | `Core/SessionScanner.swift` | Read `local_*.json`, dedupe, filter, sort |
| State derive | `Core/TranscriptReader.swift` | Tail transcript `.jsonl`, derive 🔴/🟠/⚪ |
| Store | `Core/SessionStore.swift` | `@MainActor` merge + refresh; publishes on change |
| Watch | `Core/DirectoryWatcher.swift` | FSEvents on both directories (0.4s debounce) |
| Focus | `Core/Focuser.swift` | Bring Claude.app forward (see constraint below) |
| Hotkey | `Core/HotKey.swift` | Carbon `RegisterEventHotKey` for ⌘⌥H |
| UI | `UI/FloatingPanel.swift`, `UI/ContentView.swift`, `UI/SessionRowView.swift` | Panel, header, rows |
| Entry | `App.swift` | `@main` `NSApplication` agent |

### Data sources

1. **Session metadata**
   `~/Library/Application Support/Claude/claude-code-sessions/<workspace>/<session>/local_*.json`
   Fields: `sessionId`, `cliSessionId`, `title`, `cwd`, `lastActivityAt` (epoch **ms**), `isArchived`.

2. **Transcript (run state)**
   `~/.claude/projects/<cwd-slug>/<cliSessionId>.jsonl` — the same file Claude Code CLI writes;
   desktop chats write here too. Only the last ~64&nbsp;KB is read.

## Critical domain knowledge (non-obvious)

These are load-bearing facts learned by reverse-engineering the Claude desktop app. Getting them
wrong silently breaks correctness.

1. **State signal** (`TranscriptReader.deriveState`) — the dot is the **last timestamped**
   transcript event:
   - `assistant` + `stop_reason == "end_turn"` → **waiting** (🔴, user's move)
   - any other `assistant` (e.g. `tool_use`) or a trailing `user` → **working** (🟠)
   - otherwise → **idle** (⚪)

   Time is used **only** for sort order and the 8-hour idle filter — **never** to pick the color.

2. **Two records per chat / "shadow" dedupe** (`SessionScanner.merge`) — Claude writes *two*
   `local_*.json` per chat sharing one `cliSessionId`: the real chat (random `sessionId`) and an
   untitled "shadow" whose `sessionId == "local_<cliSessionId>"` (a CLI-import artifact, sometimes
   with a *newer* `lastActivityAt`). Merge by `cliSessionId`, preferring the **non-shadow** record's
   title so the real title wins over short auto-titles.

3. **Tapping a row only brings Claude.app forward** (`Focuser.bringForward`). It does **not** focus
   the specific chat, and that's a hard constraint, not a missing feature. Every `claude://` deep
   link either forks a duplicate (`resume`), is feature-flag-gated off (`code/<id>`), or is
   Chat-tab/cloud-only (`claude.ai/chat/<uuid>`); the clean focus primitive (`setFocusedSession`) is
   internal IPC origin-gated to Claude's own renderer.
   **Do not re-add a deep-link "jump to chat" — it was tried, and it mutates/duplicates real chats.**

## Product decisions (current)

- **Sort order:** working (🟠) → waiting (🔴) → idle (⚪) via `SessionState.sortRank`, then
  most-recent activity within each group.
- **Visibility:** desktop chats only; hide sessions idle > 8h (`SessionScanner.scan(idleCutoff:)`).
- **Header badge** counts red/waiting chats (`SessionStore.waitingCount`); the blue "new" badge
  counts waiting chats not yet visited (`unvisitedCount`).

## Coding conventions

- **Immutability:** models are immutable structs. Mutate via copy helpers (e.g.
  `SessionInfo.withState`) — never mutate in place.
- **Many small files:** keep files focused and cohesive.
- **Panel sizing:** the panel is content-sized —
  `NSHostingView.sizingOptions = [.preferredContentSize]` + `FloatingPanel.setContentSize` keeps
  the **top edge anchored** so collapse/expand resizes downward. If you change list-height logic,
  preserve this.

## Making a change

1. Make the change; keep it minimal and immutable.
2. Bump `AppVersion.build`.
3. `./bundle.sh` and run — confirm the new build number in the header.
4. Verify the window via `CGWindowListCopyWindowInfo` (not screenshots).
5. Sanity-check live state against the on-disk data with `python3` / `ls`.
6. Open a PR with a clear description of the behavior change.

## Reporting bugs

Open a [GitHub issue](https://github.com/vortechron/touchmeplease/issues) with your macOS version,
Claude desktop app build number, and what you saw vs. expected. If the state dots look wrong,
including a redacted snippet of the relevant `.jsonl` transcript tail helps a lot.
