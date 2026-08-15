import SwiftUI
import AppKit

/// Blip-inspired compact macOS utility panel for browsing, searching, and managing clipboard history.
public struct MenuBarPanelView: View {
    @ObservedObject public var coordinator: AppCoordinator
    public var onDismiss: (() -> Void)?
    
    @State private var selectedCategory: ClipCategory = .all
    @State private var searchQuery: String = ""
    @State private var selectedClipId: UUID? = nil
    @State private var isSettingsHovered: Bool = false
    @State private var isCategoryFocused: Bool = false
    @FocusState private var isSearchFocused: Bool

    public init(coordinator: AppCoordinator, onDismiss: (() -> Void)? = nil) {
        self.coordinator = coordinator
        self.onDismiss = onDismiss
    }

    private var fontScale: Double {
        coordinator.settingsService.settings.fontScale.scaleFactor
    }

    private var filteredClips: [Clip] {
        coordinator.filteredClips(category: selectedCategory, searchQuery: searchQuery)
    }

    private var activeCategories: [CustomCategoryItem] {
        coordinator.settingsService.activeCategories()
    }

    private var activeClipCategories: [ClipCategory] {
        let list = activeCategories.compactMap { ClipCategory(rawValue: $0.id) }
        return list.isEmpty ? ClipCategory.allCases : list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Row: Settings (Top Left), App Title, and Active Clips Count
            HStack(spacing: 8) {
                Button {
                    coordinator.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(ClipBoTypography.body(scale: fontScale))
                        .foregroundStyle(isSettingsHovered ? Color.primary : Color.secondary)
                        .padding(6)
                        .background {
                            if isSettingsHovered {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Settings")
                .contentShape(Rectangle())
                .onHover { isSettingsHovered = $0 }

                Spacer()

                Text("ClipBo")
                    .font(ClipBoTypography.appTitle(scale: fontScale))
                    .foregroundStyle(Color.primary)

                Spacer()

                Text("\(filteredClips.count)")
                    .font(ClipBoTypography.badge(scale: fontScale))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider()

            // 2. Horizontal Category Navigation Bar with animated pill
            MenuBarCategoryRow(
                selectedCategory: $selectedCategory,
                categories: activeCategories,
                isCategoryFocused: isCategoryFocused,
                fontScale: fontScale
            )

            Divider()

            // 3. Pill-shaped Rounded Search Field immediately below Category Row
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(ClipBoTypography.body(scale: fontScale))
                    .foregroundStyle(isSearchFocused ? Color.primary : Color.secondary)

                TextField("Search your clips...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(ClipBoTypography.body(scale: fontScale))
                    .focused($isSearchFocused)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(ClipBoTypography.body(scale: fontScale))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            // 4. Results Content Area with smooth category transitions
            ZStack {
                if filteredClips.isEmpty {
                    emptyStateView
                } else if selectedCategory == .images {
                    MenuBarImageGallery(
                        clips: filteredClips,
                        fontScale: fontScale,
                        imageStorage: coordinator.imageStorage,
                        onRestore: { clip in
                            if coordinator.restoreClip(clip) {
                                onDismiss?()
                            }
                        },
                        onToggleStar: { clip in Task { await coordinator.toggleStar(for: clip) } }
                    )
                } else if selectedCategory == .collections {
                    collectionsPlaceholderView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredClips.enumerated()), id: \.element.id) { index, clip in
                                MenuBarClipRow(
                                    clip: clip,
                                    index: index + 1,
                                    isSelected: selectedClipId == clip.id,
                                    fontScale: fontScale,
                                    imageStorage: coordinator.imageStorage,
                                    onSelect: { selected in
                                        selectedClipId = selected.id
                                    },
                                    onRestore: { c in
                                        if coordinator.restoreClip(c) {
                                            onDismiss?()
                                        }
                                    },
                                    onToggleStar: { c in Task { await coordinator.toggleStar(for: c) } },
                                    onDragCompleted: { onDismiss?() }
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                    }
                }
            }
            .animation(DesignTokens.Animations.fast, value: selectedCategory)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 5. Clean Footer Utility Bar (Removed Launch at Login — belongs only in Settings)
            HStack(spacing: 8) {
                Text("\(filteredClips.count) \(filteredClips.count == 1 ? "clip" : "clips")")
                    .font(ClipBoTypography.caption(scale: fontScale))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    Task {
                        await coordinator.clearAll()
                    }
                }
                .font(ClipBoTypography.caption(scale: fontScale))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Text("•")
                    .font(ClipBoTypography.badge(scale: fontScale))
                    .foregroundStyle(.tertiary)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(ClipBoTypography.caption(scale: fontScale))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        }
        .frame(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight)
        .background(.ultraThinMaterial)
        .onAppear {
            isSearchFocused = true
            isCategoryFocused = false
        }
        .background(MenuBarKeyboardHandler(
            isSearchFocused: { self.isSearchFocused },
            onLeftArrow: { handleLeftArrow() },
            onRightArrow: { handleRightArrow() },
            onUpArrow: { handleUpArrow() },
            onDownArrow: { handleDownArrow() }
        ))
    }

    private func handleRightArrow() {
        let available = activeClipCategories
        guard !available.isEmpty else { return }
        isSearchFocused = false
        isCategoryFocused = true
        withAnimation(DesignTokens.Animations.pillSpring) {
            selectedCategory = selectedCategory.next(in: available)
            selectedClipId = nil
        }
    }

    private func handleLeftArrow() {
        let available = activeClipCategories
        guard !available.isEmpty else { return }
        isSearchFocused = false
        isCategoryFocused = true
        withAnimation(DesignTokens.Animations.pillSpring) {
            selectedCategory = selectedCategory.previous(in: available)
            selectedClipId = nil
        }
    }

    private func handleUpArrow() {
        isCategoryFocused = false
        isSearchFocused = true
    }

    private func handleDownArrow() {
        isCategoryFocused = false
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: selectedCategory.iconName)
                .font(ClipBoTypography.system(size: 26, scale: fontScale))
                .foregroundStyle(.secondary.opacity(0.6))
            
            Text(searchQuery.isEmpty ? "No \(selectedCategory.title) clips" : "No results for \"\(searchQuery)\"")
                .font(ClipBoTypography.bodyMedium(scale: fontScale))
                .foregroundStyle(.secondary)

            Text(searchQuery.isEmpty ? "Copied items will appear here automatically." : "Try a different search term or category.")
                .font(ClipBoTypography.secondary(scale: fontScale))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var collectionsPlaceholderView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(ClipBoTypography.system(size: 28, scale: fontScale))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("Collections")
                .font(ClipBoTypography.sectionTitle(scale: fontScale))
                .foregroundStyle(.secondary)

            Text("Organize clips into smart lists and pinned tags in Phase 4.")
                .font(ClipBoTypography.secondary(scale: fontScale))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(16)
    }
}

/// Local key event monitor for Menu Bar Panel navigation.
/// isSearchFocused is a closure so the monitor always reads current focus state at event time,
/// not the stale value captured at layout time.
private struct MenuBarKeyboardHandler: NSViewRepresentable {
    var isSearchFocused: () -> Bool
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.isSearchFocused = isSearchFocused
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.isSearchFocused = isSearchFocused
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onUpArrow = onUpArrow
        nsView.onDownArrow = onDownArrow
    }

    class KeyView: NSView {
        /// Closure read at event time — never stale.
        var isSearchFocused: (() -> Bool) = { false }
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self else { return event }
                    let searchHasFocus = self.isSearchFocused()
                    switch event.keyCode {
                    case 124: // Right Arrow
                        // Pass through if search has focus and text cursor isn't at end
                        if searchHasFocus,
                           let tv = self.window?.firstResponder as? NSTextView,
                           let range = tv.selectedRanges.first as? NSRange,
                           range.location < tv.string.count {
                            return event
                        }
                        self.onRightArrow?()
                        return nil
                    case 123: // Left Arrow
                        // Pass through if search has focus and text cursor isn't at start
                        if searchHasFocus,
                           let tv = self.window?.firstResponder as? NSTextView,
                           let range = tv.selectedRanges.first as? NSRange,
                           range.location > 0 {
                            return event
                        }
                        self.onLeftArrow?()
                        return nil
                    case 126: // Up Arrow
                        self.onUpArrow?()
                        return nil
                    case 125: // Down Arrow
                        self.onDownArrow?()
                        return nil
                    default:
                        return event
                    }
                }
            } else if window == nil, let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }
    }
}
