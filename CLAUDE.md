# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`touchmeplease` is a macOS menu-bar-less agent app: a translucent, always-on-top floating
`NSPanel` that lists the user's Claude **desktop app** chat sessions and flags which ones are
**waiting on the user** (🔴) vs **actively working** (🟠) vs **idle** (⚪). It exists so the user
doesn't have to scroll Claude.app's sidebar hunting for the session that asked a question. It is
read-only with respect to Claude's data (except the now-removed cleanup path) and never mutates chats.

## Build & run

```bash
swift build                       # debug build → .build/debug/touchmeplease
./bundle.sh                       # release build wrapped in touchmeplease.app (unsigned)
open touchmeplease.app
```

There are **no tests** and no lint config — it's a small SPM executable (Swift 6, macOS 14+).
Verification is done by building and running, plus inspecting live data with `python3`/`ls` against
the Claude data directories (see below).

The app runs as an `LSUIElement` accessory (no Dock icon). Quit via the ✕ button in the header,
or `pkill -f touchmeplease`. There is no `.app`-install step required for `swift build`, but
**computer-use / screenshot tooling can't target the agent app** — verify the window via
`CGWindowListCopyWindowInfo` (look for `owner=touchmeplease`, `layer=3`) instead of screenshots.

### Iteration loop used during development

```bash
pkill -f touchmeplease; ./bundle.sh && rm -rf /Applications/touchmeplease.app \
  && cp -R touchmeplease.app /Applications/ \
  && /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/touchmeplease.app \
  && open /Applications/touchmeplease.app
```

**Always bump `AppVersion.build` in `Sources/touchmeplease/Models/Version.swift` on every change**
— the `vX (build N)` badge in the window header is how the user confirms a new build actually loaded.

## Architecture

Data flow: **two on-disk Claude data sources → scan/derive → observable store → SwiftUI panel.**

- **`Core/SessionScanner`** reads chat *metadata* from
  `~/Library/Application Support/Claude/claude-code-sessions/<workspace>/<session>/local_*.json`
  (fields: `sessionId`, `cliSessionId`, `title`, `cwd`, `lastActivityAt` (epoch **ms**), `isArchived`).
- **`Core/TranscriptReader`** derives the run-state (🔴/🟠/⚪) by tailing the *transcript* at
  `~/.claude/projects/<cwd-slug>/<cliSessionId>.jsonl` — the **same file Claude Code CLI writes**;
  desktop chats write here too. It reads only the last ~64 KB and finds the last line carrying a
  `timestamp` (ignoring untitled meta lines).
- **`Core/SessionStore`** (`@MainActor ObservableObject`) merges the two, sorts, and republishes
  only on change. Refresh triggers: a **`Core/DirectoryWatcher`** (FSEvents on both directories,
  0.4 s debounce) **plus** a 5 s safety poll.
- **`UI/FloatingPanel`** / **`UI/ContentView`** / **`UI/SessionRowView`** render the panel.
- **`App.swift`** is the `@main` `NSApplication` agent entry point.

### Critical domain knowledge (non-obvious, learned by reverse-engineering Claude.app)

These are the load-bearing facts; getting them wrong silently breaks correctness:

1. **State signal** (`TranscriptReader.deriveState`): the dot is the last timestamped transcript
   event — `assistant` + `stop_reason == "end_turn"` ⇒ **waiting** (🔴, user's move);
   any other `assistant` (e.g. `tool_use`) or a trailing `user` ⇒ **working** (🟠); else **idle** (⚪).
   Time is used only for sort order and the 8 h idle filter — **never** to pick the color.

2. **Two records per chat / "shadow" dedupe** (`SessionScanner.merge`): Claude.app writes *two*
   `local_*.json` per chat sharing one `cliSessionId` — the real chat (random `sessionId`) and an
   untitled "shadow" whose `sessionId == "local_<cliSessionId>"` (a CLI-import artifact, sometimes
   with a *newer* `lastActivityAt`). Records are merged by `cliSessionId`, preferring the
   **non-shadow** record's title (so the real title wins over short auto-titles like "stealth").

3. **Tapping a row only brings Claude.app forward** (`Focuser.bringForward` via
   `NSRunningApplication(bundleIdentifier: "com.anthropic.claudefordesktop").activate`). It does
   **not** focus the specific chat. This is a hard constraint, not a missing feature: every
   `claude://` deep link either forks a duplicate (`resume`), is feature-flag-gated off
   (`code/<id>`), or is Chat-tab/cloud-only (`claude.ai/chat/<uuid>`); the clean focus primitive
   (`setFocusedSession`) is internal IPC origin-gated to Claude's own renderer. **Do not re-add a
   deep-link "jump to chat" — it was tried, it mutates/duplicates the user's real chats.**

### Sort & visibility (current product decisions)

- Order: **working (🟠) → waiting (🔴) → idle (⚪)** via `SessionState.sortRank`, then most-recent
  activity within each group. (The user prioritizes actively-running chats on top.)
- Show desktop chats only; hide sessions idle > 8 h (`SessionScanner.scan(idleCutoff:)`).
- Header badge counts **red/waiting** chats specifically (`SessionStore.waitingCount`).

### Conventions

- Models are immutable structs; mutate via copy helpers (e.g. `SessionInfo.withState`). Don't
  mutate in place.
- The panel is content-sized: `NSHostingView.sizingOptions = [.preferredContentSize]` +
  `FloatingPanel.setContentSize` keeps the **top edge anchored** so collapse/expand resizes the
  window downward rather than from the bottom-left. Changing list height logic? Preserve this.
