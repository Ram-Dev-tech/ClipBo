import Foundation
import SwiftUI
import Combine
import OSLog

/// Central coordinator that connects the clipboard engine, persistence, image storage, classifier, settings, and UI state.
@MainActor
public final class AppCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "AppCoordinator")
    private var cancellables = Set<AnyCancellable>()

    public let repository: any ClipRepositoryProtocol
    public let imageStorage: ImageStorage
    public let clipboardReader: ClipboardReader
    public let clipboardWriter: ClipboardWriter
    public let clipboardMonitor: ClipboardMonitor
    public let launchAtLoginManager: LaunchAtLoginManager
    public let classifier: any ContentClassifierProtocol
    public let selectionCaptureService: SelectionCaptureService
    public let settingsService: SettingsService

    @Published public private(set) var recentClips: [Clip] = []
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var launchAtLoginEnabled: Bool = false
    @Published public var statusMessage: String? = nil

    /// HUD manager for the Quick Capture background capture flow.
    private let captureHUD = QuickCaptureHUDManager()

    /// Background monitor for modifier-assisted selection capture (e.g. ⌘ + Drag/Select).
    public let selectionModifierCaptureManager: SelectionModifierCaptureManager = .shared

    public init(
        repository: any ClipRepositoryProtocol,
        imageStorage: ImageStorage = ImageStorage(),
        launchAtLoginManager: LaunchAtLoginManager = .shared,
        classifier: any ContentClassifierProtocol = DefaultContentClassifier(),
        selectionCaptureService: SelectionCaptureService = .shared,
        settingsService: SettingsService? = nil
    ) {
        self.repository = repository
        self.imageStorage = imageStorage
        self.launchAtLoginManager = launchAtLoginManager
        self.classifier = classifier
        self.selectionCaptureService = selectionCaptureService
        let resolvedSettingsService = settingsService ?? SettingsService()
        self.settingsService = resolvedSettingsService
        
        let reader = ClipboardReader()
        let writer = ClipboardWriter(imageStorage: imageStorage)
        let initialPolling = resolvedSettingsService.settings.pollingInterval
        let monitor = ClipboardMonitor(reader: reader, writer: writer, pollingInterval: initialPolling)

        self.clipboardReader = reader
        self.clipboardWriter = writer
        self.clipboardMonitor = monitor
        self.launchAtLoginEnabled = launchAtLoginManager.isEnabled

        setupMonitorSubscription()
        setupSelectionModifierCapture()
        setupSettingsObservation()
    }

    private func setupSelectionModifierCapture() {
        selectionModifierCaptureManager.onSelectionCaptureTriggered = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.captureSelection()
            }
        }
    }

    private func setupMonitorSubscription() {
        clipboardMonitor.onNewPayload = { [weak self] payload in
            guard let self = self else { return }
            await self.handleNewPayload(payload)
        }
    }

    private func setupSettingsObservation() {
        settingsService.$settings
            .dropFirst()
            .sink { [weak self] newSettings in
                guard let self = self else { return }
                self.clipboardMonitor.updatePollingInterval(newSettings.pollingInterval)
                if newSettings.quickSelectionCaptureEnabled {
                    self.selectionModifierCaptureManager.start(modifier: newSettings.selectionCaptureModifier)
                } else {
                    self.selectionModifierCaptureManager.stop()
                }
                Task {
                    await self.enforceRetention()
                }
            }
            .store(in: &cancellables)
    }

    /// Starts monitoring the clipboard and loads recent clips.
    public func start() async {
        await enforceRetention()
        await reloadRecentClips()
        clipboardMonitor.start()
        isMonitoring = clipboardMonitor.isRunning
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
        if settingsService.settings.quickSelectionCaptureEnabled {
            selectionModifierCaptureManager.start(modifier: settingsService.settings.selectionCaptureModifier)
        }
        logger.info("AppCoordinator started successfully")
    }

    /// Stops clipboard monitoring.
    public func stop() {
        clipboardMonitor.stop()
        selectionModifierCaptureManager.stop()
        isMonitoring = clipboardMonitor.isRunning
        logger.info("AppCoordinator stopped")
    }

    /// Enforces simultaneous count and age retention limits.
    public func enforceRetention() async {
        if let coreDataRepo = repository as? CoreDataClipRepository {
            let settings = settingsService.settings
            try? await coreDataRepo.enforceRetentionLimit(
                maxNonStarred: settings.maxClipCount,
                maxAgeDays: settings.maxHistoryAgeDays
            )
        }
    }

    /// Reloads the most recent clips from the repository.
    public func reloadRecentClips(limit: Int = 1000) async {
        do {
            let maxLimit = max(limit, settingsService.settings.maxClipCount)
            let clips = try await repository.fetchRecent(limit: maxLimit)
            self.recentClips = clips
        } catch {
            logger.error("Failed to load recent clips: \(error.localizedDescription)")
            statusMessage = "Error loading clips: \(error.localizedDescription)"
        }
    }

    /// Ingests a new payload, classifies it, and persists the clip.
    public func handleNewPayload(_ payload: PasteboardPayload) async {
        // Respect Clipboard Monitoring toggle from Settings
        guard settingsService.settings.isMonitoring else {
            logger.debug("Clipboard capture paused by settings")
            return
        }

        let classification = classifier.classify(payload: payload)

        // Consecutive duplicate prevention
        if let topClip = recentClips.first,
           topClip.type == classification.type,
           topClip.textContent == payload.textContent,
           classification.type != .image {
            logger.info("Ignoring consecutive duplicate clip")
            return
        }

        let clipId = UUID()
        let clip: Clip

        switch classification.type {
        case .image:
            guard let imageData = payload.imageData else { return }
            do {
                let filename = try imageStorage.saveImage(data: imageData, id: clipId)
                clip = Clip(
                    id: clipId,
                    type: .image,
                    imagePath: filename,
                    createdAt: Date(),
                    sourceAppBundleId: payload.sourceAppBundleId,
                    sourceAppName: payload.sourceAppName,
                    imageWidth: payload.imageWidth,
                    imageHeight: payload.imageHeight,
                    customMetadata: classification.customMetadata
                )
            } catch {
                logger.error("Failed to save clipboard image: \(error.localizedDescription)")
                return
            }

        case .text, .url, .code, .prompt:
            clip = Clip(
                id: clipId,
                type: classification.type,
                textContent: payload.textContent,
                createdAt: Date(),
                sourceAppBundleId: payload.sourceAppBundleId,
                sourceAppName: payload.sourceAppName,
                charCount: payload.textContent?.count,
                wordCount: payload.textContent.map { $0.split(whereSeparator: \.isWhitespace).count },
                customMetadata: classification.customMetadata
            )
        }

        do {
            try await repository.insert(clip)
            // Prepend to observable recent clips list
            recentClips.insert(clip, at: 0)
            if recentClips.count > settingsService.settings.maxClipCount {
                recentClips.removeLast()
            }

            // Enforce simultaneous count and age retention limits
            await enforceRetention()

            logger.info("Successfully persisted clip: \(clip.id) (classified as: \(clip.type.rawValue))")
        } catch {
            logger.error("Failed to persist clip: \(error.localizedDescription)")
        }
    }

    /// Performs background Quick Capture via Accessibility APIs without touching NSPasteboard.
    /// Shows a subtle HUD near the menu bar while operating. Safe failure on all error paths.
    public func captureSelection() async {
        let shortcutDisplay = settingsService.settings.quickCaptureShortcut.displayString

        // Show arming HUD immediately — does not activate or block the user's app
        captureHUD.show(state: .arming(shortcut: shortcutDisplay))

        guard selectionCaptureService.isAccessibilityGranted else {
            captureHUD.transition(to: .accessibilityRequired, autoDismissAfter: 3.0)
            logger.warning("Quick Capture: Accessibility permission not granted")
            return
        }

        let result = selectionCaptureService.captureSelection()
        let frontApp = NSWorkspace.shared.frontmostApplication

        switch result {
        case .text(let text):
            let payload = PasteboardPayload.text(
                text,
                sourceAppBundleId: frontApp?.bundleIdentifier,
                sourceAppName: frontApp?.localizedName
            )
            await handleNewPayload(payload)
            let preview = String(text.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
            captureHUD.transition(to: .captured(preview), autoDismissAfter: 1.5)
            logger.info("Quick Capture: text clip saved (\(text.count) chars)")

        case .image(let imageData):
            let clipId = UUID()
            do {
                let filename = try imageStorage.saveImage(data: imageData, id: clipId)
                let clip = Clip(
                    id: clipId,
                    type: .image,
                    imagePath: filename,
                    createdAt: Date(),
                    sourceAppBundleId: frontApp?.bundleIdentifier,
                    sourceAppName: frontApp?.localizedName
                )
                try await repository.insert(clip)
                recentClips.insert(clip, at: 0)
                if recentClips.count > settingsService.settings.maxClipCount { recentClips.removeLast() }
                await enforceRetention()
                captureHUD.transition(to: .captured("Image clip"), autoDismissAfter: 1.5)
                logger.info("Quick Capture: image clip saved (\(imageData.count) bytes)")
            } catch {
                captureHUD.transition(to: .failed("Could not save image"), autoDismissAfter: 3.0)
                logger.error("Quick Capture: failed to save image clip — \(error.localizedDescription)")
            }

        case .notFound:
            captureHUD.transition(to: .failed("Nothing selected — select text and try again"), autoDismissAfter: 2.5)
            logger.warning("Quick Capture: no content found in focused element")

        case .accessibilityDenied:
            captureHUD.transition(to: .accessibilityRequired, autoDismissAfter: 4.0)
            logger.warning("Quick Capture: Accessibility permission denied")
        }
    }

    /// Restores a clip back to NSPasteboard and returns whether the restoration succeeded.
    @discardableResult
    public func restoreClip(_ clip: Clip) -> Bool {
        do {
            try clipboardWriter.restoreClip(clip)
            logger.info("Restored clip to clipboard: \(clip.id)")
            return true
        } catch {
            logger.error("Failed to restore clip to clipboard: \(error.localizedDescription)")
            statusMessage = "Could not restore clip: \(error.localizedDescription)"
            return false
        }
    }

    /// Toggles launch at login state.
    public func toggleLaunchAtLogin() {
        let newState = !launchAtLoginEnabled
        do {
            try launchAtLoginManager.setEnabled(newState)
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            settingsService.settings.launchAtLogin = launchAtLoginEnabled
        } catch {
            logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
            statusMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }

    /// Returns clips filtered by category and search text query using the universal ClipSearchEngine,
    /// with centralized display limits (30 for All, 20 for individual categories) applied AFTER filtering and ranking.
    public func filteredClips(category: ClipCategory, searchQuery: String = "") -> [Clip] {
        let results = ClipSearchEngine.shared.filterAndRank(
            clips: recentClips,
            query: searchQuery,
            activeTabCategory: category,
            customCategories: settingsService.settings.customCategories
        )
        let limit = ClipDisplayLimits.limit(for: category)
        return Array(results.prefix(limit))
    }

    /// Opens the native Settings window.
    public func openSettings() {
        SettingsWindowController.shared.show(settingsService: settingsService, coordinator: self)
    }

    /// Toggles the starred state of a clip and persists the change.
    public func toggleStar(for clip: Clip) async {
        var updated = clip
        updated.isStarred.toggle()
        
        do {
            try await repository.update(updated)
            if let index = recentClips.firstIndex(where: { $0.id == clip.id }) {
                recentClips[index] = updated
            }
        } catch {
            logger.error("Failed to toggle star for clip \(clip.id): \(error.localizedDescription)")
        }
    }

    /// Deletes an individual clip from persistence and memory.
    public func deleteClip(_ clip: Clip) async {
        do {
            try await repository.delete(byId: clip.id)
            if let imagePath = clip.imagePath {
                try? imageStorage.deleteImage(filenameOrPath: imagePath)
            }
            recentClips.removeAll(where: { $0.id == clip.id })
            logger.info("Deleted clip: \(clip.id)")
        } catch {
            logger.error("Failed to delete clip \(clip.id): \(error.localizedDescription)")
        }
    }

    /// Clears all clipboard history from persistence.
    public func clearAll() async {
        do {
            try await repository.clearAll()
            try imageStorage.clearAllImages()
            recentClips.removeAll()
            logger.info("Cleared all clipboard history")
        } catch {
            logger.error("Failed to clear history: \(error.localizedDescription)")
        }
    }

    /// Clears all stored images from disk.
    public func clearAllImages() async {
        do {
            try imageStorage.clearAllImages()
            await reloadRecentClips()
            logger.info("Cleared all stored image payloads")
        } catch {
            logger.error("Failed to clear images: \(error.localizedDescription)")
        }
    }

    /// Returns the total database file size on disk.
    public nonisolated func databaseFileSize() -> Int64 {
        if let coreDataRepo = repository as? CoreDataClipRepository {
            return coreDataRepo.databaseFileSize()
        }
        return 0
    }

    /// Returns the main .sqlite file size on disk.
    public nonisolated func sqliteFileSize() -> Int64 {
        if let coreDataRepo = repository as? CoreDataClipRepository {
            return coreDataRepo.sqliteFileSize()
        }
        return 0
    }

    /// Returns the .sqlite-wal write-ahead log size on disk.
    public nonisolated func walFileSize() -> Int64 {
        if let coreDataRepo = repository as? CoreDataClipRepository {
            return coreDataRepo.walFileSize()
        }
        return 0
    }

    /// Returns the total size of stored image payloads.
    public nonisolated func imagesDirectorySize() -> Int64 {
        return imageStorage.imagesDirectorySize()
    }

    /// Cleans up orphaned images on disk.
    public func cleanupOrphanImages() async {
        if let coreDataRepo = repository as? CoreDataClipRepository {
            if let validPaths = try? await coreDataRepo.fetchAllImagePaths() {
                imageStorage.cleanupOrphanImages(validFilenames: Set(validPaths))
            }
        }
    }
}
