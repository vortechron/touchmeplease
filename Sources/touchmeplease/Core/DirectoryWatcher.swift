import Foundation
import CoreServices

/// Recursively watches directories with FSEvents and fires a callback on any change.
final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(paths: [String], onChange: @escaping () -> Void) {
        self.onChange = onChange

        let context = UnsafeMutablePointer<FSEventStreamContext>.allocate(capacity: 1)
        context.initialize(to: FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        ))
        defer { context.deinitialize(count: 1); context.deallocate() }

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.onChange()
        }

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // latency seconds — coalesce bursts
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
        }
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
