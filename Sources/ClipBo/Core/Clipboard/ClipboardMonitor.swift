import Foundation
import AppKit
import OSLog

/// Monitors the system pasteboard for changes and notifies subscribers of new content.
public final class ClipboardMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "ClipboardMonitor")
    
    private let pasteboard: NSPasteboard
    private let reader: ClipboardReader
    private let writer: ClipboardWriter?
    private var pollingInterval: TimeInterval
    
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastPayload: PasteboardPayload?
    
    private let lock = NSLock()
    private var isRunningInternal = false
    
    /// Handler invoked whenever new unique clipboard content is detected.
    public var onNewPayload: (@Sendable (PasteboardPayload) async -> Void)?

    public init(
        pasteboard: NSPasteboard = .general,
        reader: ClipboardReader = ClipboardReader(),
        writer: ClipboardWriter? = nil,
        pollingInterval: TimeInterval = 0.5
    ) {
        self.pasteboard = pasteboard
        self.reader = reader
        self.writer = writer
        self.pollingInterval = pollingInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunningInternal
    }

    public var currentPollingInterval: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return pollingInterval
    }

    /// Starts observing the pasteboard on the main run loop.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunningInternal else { return }
        
        isRunningInternal = true
        lastChangeCount = pasteboard.changeCount
        let interval = self.pollingInterval
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkForChanges()
            }
            self.timer?.tolerance = 0.05
        }
        logger.info("ClipboardMonitor started (interval: \(interval)s, changeCount: \(self.lastChangeCount))")
    }

    /// Dynamically updates the polling interval live while running or stopped.
    public func updatePollingInterval(_ newInterval: TimeInterval) {
        lock.lock()
        let clampedInterval = max(0.1, min(5.0, newInterval))
        self.pollingInterval = clampedInterval
        let running = isRunningInternal
        lock.unlock()

        if running {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: clampedInterval, repeats: true) { [weak self] _ in
                    self?.checkForChanges()
                }
                self.timer?.tolerance = 0.05
                self.logger.info("ClipboardMonitor polling interval updated live to \(clampedInterval)s")
            }
        }
    }

    /// Stops observing the pasteboard.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunningInternal else { return }
        
        isRunningInternal = false
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
        logger.info("ClipboardMonitor stopped")
    }

    /// Checks for pasteboard changes synchronously (can be called by timer or manual poll in tests).
    public func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        lock.lock()
        guard isRunningInternal else {
            lock.unlock()
            return
        }
        
        // Skip if change count hasn't incremented
        guard currentChangeCount != lastChangeCount else {
            lock.unlock()
            return
        }
        
        lastChangeCount = currentChangeCount
        
        // Ignore self-writes originating from ClipBo
        if let writer = writer, writer.isSelfWrite(changeCount: currentChangeCount) {
            logger.debug("Ignoring pasteboard change from ClipBo self-write (changeCount: \(currentChangeCount))")
            lock.unlock()
            return
        }
        lock.unlock()

        // Read payload safely
        guard let payload = reader.read(from: pasteboard) else {
            return
        }

        // Deduplicate consecutive identical content
        lock.lock()
        if let last = lastPayload, last == payload {
            logger.debug("Deduplicated identical consecutive clipboard content")
            lock.unlock()
            return
        }
        lastPayload = payload
        let handler = onNewPayload
        lock.unlock()

        if let handler = handler {
            Task {
                await handler(payload)
            }
        }
    }

    /// Resets the cached change count and last payload (useful for tests or app reload).
    public func resetTracking() {
        lock.lock()
        defer { lock.unlock() }
        lastChangeCount = pasteboard.changeCount
        lastPayload = nil
    }
}
