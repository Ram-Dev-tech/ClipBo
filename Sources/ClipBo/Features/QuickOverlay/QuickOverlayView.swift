import SwiftUI
import AppKit

/// Spotlight-inspired floating overlay for instant keyboard-first clipboard retrieval.
/// Category circles are ALWAYS visible in the header regardless of navigation state.
/// Arrow navigation, Enter-to-copy, and drag-and-drop are all handled reliably via AppKit local monitors.
public struct QuickOverlayView: View {
    @ObservedObject public var coordinator: AppCoordinator
    public var onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @StateObject private var navController = QuickOverlayNavigationController()
    @FocusState private var isSearchFocused: Bool
    @State private var copyErrorMessage: String? = nil

    public init(
        coordinator: AppCoordinator,
        initialState: QuickOverlayNavigationState = .search,
        initialCategory: ClipCategory = .all,
        onDismiss: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self._navController = StateObject(wrappedValue: QuickOverlayNavigationController(initialState: initialState, initialCategory: initialCategory))
        self.onDismiss = onDismiss
    }

    private var fontScale: Double {
        coordinator.settingsService.settings.fontScale.scaleFactor
    }

    private var filteredClips: [Clip] {
        coordinator.filteredClips(category: navController.selectedCategory, searchQuery: searchQuery)
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
            // ── Spotlight Header ──────────────────────────────────────────────
            // Search field + category circles are ALWAYS both visible.
            // GeometryReader drives compact mode when window width < 500pt.
            GeometryReader { geo in
                let isCompact = geo.size.width < 500
                HStack(spacing: 8) {
                    // Search Icon & Input
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(ClipBoTypography.system(size: 15, weight: .medium, scale: fontScale))
                            .foregroundStyle(.secondary)

                        TextField("Search your clips...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(ClipBoTypography.system(size: 15, weight: .regular, scale: fontScale))
                            .focused($isSearchFocused)
                            .onSubmit {
                                handleEnter()
                            }
                            .onChange(of: searchQuery) { _, _ in
                                navController.selectedResultIndex = 0
                                copyErrorMessage = nil
                            }

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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ── Category circles — ALWAYS VISIBLE ──
                    HStack(spacing: 0) {
                        // Active-category badge shown when filtering (non-all) + categories not expanded
                        if navController.selectedCategory != .all && navController.state == QuickOverlayNavigationState.search {
                            HStack(spacing: 4) {
                                Image(systemName: navController.selectedCategory.iconName)
                                    .font(ClipBoTypography.badge(scale: fontScale))
                                Text(navController.selectedCategory.title
                                    .replacingOccurrences(of: "★ ", with: "")
                                    .replacingOccurrences(of: "✦ ", with: "")
                                    .replacingOccurrences(of: "<> ", with: ""))
                                    .font(ClipBoTypography.badge(scale: fontScale))
                                    .fontWeight(.medium)

                                Button {
                                    withAnimation(DesignTokens.Animations.pillSpring) {
                                        navController.selectedCategory = .all
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(ClipBoTypography.badge(scale: fontScale))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundStyle(Color.accentColor)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(DesignTokens.Animations.pillSpring) {
                                    navController.state = QuickOverlayNavigationState.categories
                                }
                            }
                            .padding(.trailing, 4)
                        }

                        // Circular category row — always rendered
                        ScrollView(.horizontal, showsIndicators: false) {
                            QuickOverlayCategoryRow(
                                selectedCategory: $navController.selectedCategory,
                                categories: activeCategories,
                                fontScale: fontScale,
                                isCompact: isCompact,
                                isCategoryFocused: navController.state == QuickOverlayNavigationState.categories,
                                onCategorySelected: { _ in
                                    navController.selectedResultIndex = 0
                                    navController.state = QuickOverlayNavigationState.search
                                    copyErrorMessage = nil
                                }
                            )
                            .padding(.vertical, 2)
                        }
                        .frame(maxWidth: isCompact ? 200 : .infinity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(WindowDragHandle())
                .frame(width: geo.size.width)
            }
            .frame(height: 48)

            // Copy error banner — non-destructive, inline
            if let errorMsg = copyErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(ClipBoTypography.caption(scale: fontScale))
                    Text(errorMsg)
                        .font(ClipBoTypography.caption(scale: fontScale))
                    Spacer()
                    Button {
                        withAnimation(DesignTokens.Animations.fast) {
                            copyErrorMessage = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(ClipBoTypography.caption(scale: fontScale))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(Color.orange)
                .background(Color.orange.opacity(0.10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            // Results List
            if filteredClips.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredClips.enumerated()), id: \.element.id) { index, clip in
                                QuickOverlayClipRow(
                                    clip: clip,
                                    index: index + 1,
                                    isSelected: index == navController.selectedResultIndex,
                                    fontScale: fontScale,
                                    imageStorage: coordinator.imageStorage,
                                    onSelect: { _ in
                                        navController.selectedResultIndex = index
                                        copyErrorMessage = nil
                                    },
                                    onRestore: { selectedClip in
                                        selectAndRestore(clip: selectedClip)
                                    },
                                    onToggleStar: { selectedClip in
                                        Task {
                                            await coordinator.toggleStar(for: selectedClip)
                                        }
                                    },
                                    onDragCompleted: {
                                        onDismiss()
                                    }
                                )
                                .id(clip.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: navController.selectedResultIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < filteredClips.count {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(filteredClips[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: OverlayGeometry.minWidth, maxWidth: .infinity, minHeight: OverlayGeometry.minHeight, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignTokens.Dimensions.panelCornerRadius)
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.panelCornerRadius, style: .continuous)
                .strokeBorder(DesignTokens.Colors.panelBorder, lineWidth: 1)
        }
        .onAppear {
            isSearchFocused = true
            navController.selectedResultIndex = 0
            navController.clampSelection(totalResults: filteredClips.count)
        }
        .onChange(of: filteredClips.count) { _, newCount in
            navController.clampSelection(totalResults: newCount)
        }
        .onChange(of: navController.selectedCategory) { _, _ in
            navController.selectedResultIndex = 0
            copyErrorMessage = nil
        }
        .background(KeyboardEventHandler(
            isCategoryFocused: navController.state == QuickOverlayNavigationState.categories,
            onUpArrow: {
                navController.handleUpArrow(totalResults: filteredClips.count)
                copyErrorMessage = nil
            },
            onDownArrow: {
                navController.handleDownArrow(totalResults: filteredClips.count)
                copyErrorMessage = nil
            },
            onLeftArrow: {
                withAnimation(DesignTokens.Animations.pillSpring) {
                    navController.handleLeftArrow(activeCategories: activeCategories)
                }
            },
            onRightArrow: {
                withAnimation(DesignTokens.Animations.pillSpring) {
                    navController.handleRightArrow(activeCategories: activeCategories)
                }
            },
            onEnter: {
                handleEnter()
            },
            onEscape: {
                onDismiss()
            }
        ))
        .animation(DesignTokens.Animations.fast, value: copyErrorMessage != nil)
    }

    // MARK: - Private

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: navController.selectedCategory.iconName)
                .font(ClipBoTypography.system(size: 26, scale: fontScale))
                .foregroundStyle(.secondary.opacity(0.6))

            Text(searchQuery.isEmpty ? "No \(navController.selectedCategory.title) clips" : "No results for \"\(searchQuery)\"")
                .font(ClipBoTypography.bodyMedium(scale: fontScale))
                .foregroundStyle(.secondary)

            Text("Press Esc to close")
                .font(ClipBoTypography.secondary(scale: fontScale))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragHandle())
    }

    private func handleEnter() {
        if navController.state == QuickOverlayNavigationState.categories {
            withAnimation(DesignTokens.Animations.pillSpring) {
                _ = navController.handleEnter()
            }
            return
        }

        guard !filteredClips.isEmpty,
              navController.selectedResultIndex >= 0 && navController.selectedResultIndex < filteredClips.count else { return }
        let clip = filteredClips[navController.selectedResultIndex]
        selectAndRestore(clip: clip)
    }

    private func selectAndRestore(clip: Clip) {
        let success = coordinator.restoreClip(clip)
        if success {
            // Clear any previous error
            copyErrorMessage = nil
            if coordinator.settingsService.settings.closeOverlayAfterCopy {
                onDismiss()
            }
        } else {
            // Non-destructive inline error — do NOT close
            withAnimation(DesignTokens.Animations.fast) {
                copyErrorMessage = "Copy failed — please try again"
            }
        }
    }
}

// MARK: - Window Drag Handle

/// Native window drag handle that triggers native AppKit window dragging on mouse down without intercepting controls.
public struct WindowDragHandle: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragView {
        DragView()
    }

    public func updateNSView(_ nsView: DragView, context: Context) {}

    public final class DragView: NSView {
        public override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Keyboard Event Handler

/// AppKit local event monitor for reliable keyboard navigation in the Quick Overlay.
/// Consumes arrow keys, Enter, and Escape to prevent routing conflicts with SwiftUI text field cursor.
/// Left/Right arrows pass through when the search field has a non-empty text cursor position mid-text
/// so normal text editing remains fully functional.
private struct KeyboardEventHandler: NSViewRepresentable {
    var isCategoryFocused: Bool
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onEnter: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.isCategoryFocused = isCategoryFocused
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.isCategoryFocused = isCategoryFocused
        nsView.onUpArrow = onUpArrow
        nsView.onDownArrow = onDownArrow
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
    }

    class KeyView: NSView {
        var isCategoryFocused: Bool = false
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onEnter: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self, self.window != nil else { return event }
                    switch event.keyCode {
                    case 126: // Up arrow
                        self.onUpArrow?()
                        return nil
                    case 125: // Down arrow
                        self.onDownArrow?()
                        return nil
                    case 124: // Right arrow
                        if self.isCategoryFocused {
                            self.onRightArrow?()
                            return nil
                        }
                        // In search mode, check if text cursor is at the end of the text
                        if let firstResponder = self.window?.firstResponder as? NSTextView {
                            let selection = firstResponder.selectedRange()
                            let textLen = (firstResponder.string as NSString).length
                            if selection.location < textLen {
                                return event // cursor in middle -> allow normal text cursor movement
                            }
                        }
                        self.onRightArrow?()
                        return nil
                    case 123: // Left arrow
                        if self.isCategoryFocused {
                            self.onLeftArrow?()
                            return nil
                        }
                        // In search mode, check if text cursor is after start
                        if let firstResponder = self.window?.firstResponder as? NSTextView {
                            let selection = firstResponder.selectedRange()
                            if selection.location > 0 {
                                return event // cursor not at start -> allow normal text cursor movement
                            }
                        }
                        self.onLeftArrow?()
                        return nil
                    case 36, 76: // Enter / Return
                        self.onEnter?()
                        return nil
                    case 53: // Escape
                        self.onEscape?()
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
