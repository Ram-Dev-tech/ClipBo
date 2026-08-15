import SwiftUI
import AppKit

/// Spotlight-styled list item row for the Quick Overlay with full-width text expansion, floating action overlay,
/// dynamic typography scaling, double-click restore, and native AppKit drag-and-drop.
public struct QuickOverlayClipRow: View {
    public let clip: Clip
    public let index: Int
    public let isSelected: Bool
    public let fontScale: Double
    public let imageStorage: ImageStorage
    public let onSelect: (Clip) -> Void
    public let onRestore: (Clip) -> Void
    public let onToggleStar: (Clip) -> Void
    /// Called when a drag completes successfully so the overlay can close.
    public var onDragCompleted: (() -> Void)?

    @State private var isHovered = false

    public init(
        clip: Clip,
        index: Int,
        isSelected: Bool,
        fontScale: Double = 1.0,
        imageStorage: ImageStorage,
        onSelect: @escaping (Clip) -> Void,
        onRestore: @escaping (Clip) -> Void,
        onToggleStar: @escaping (Clip) -> Void,
        onDragCompleted: (() -> Void)? = nil
    ) {
        self.clip = clip
        self.index = index
        self.isSelected = isSelected
        self.fontScale = fontScale
        self.imageStorage = imageStorage
        self.onSelect = onSelect
        self.onRestore = onRestore
        self.onToggleStar = onToggleStar
        self.onDragCompleted = onDragCompleted
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Index number
            Text("\(index)")
                .font(ClipBoTypography.badge(scale: fontScale))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 18, alignment: .trailing)

            // Thumbnail, Color Chip, or Type Icon
            if clip.type == .image,
               let path = clip.imagePath,
               let data = imageStorage.loadImage(filenameOrPath: path),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipped()
                    .cornerRadius(4)
            } else if let colorHex = clip.customMetadata["colorHex"], let nsColor = NSColor(hex: colorHex) {
                Circle()
                    .fill(Color(nsColor: nsColor))
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                    .frame(width: 24)
            } else {
                Image(systemName: iconName(for: clip.type))
                    .font(ClipBoTypography.body(scale: fontScale))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24)
            }

            // Main Content Preview & Subtitle (full-width flexible container)
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.textContent ?? (clip.type == .image ? "Image clip" : ""))
                    // Use centralized clipContent / codeContent — larger and bolder than bodyMedium
                    .font(clip.type == .code ? ClipBoTypography.codeContent(scale: fontScale) : ClipBoTypography.clipContent(scale: fontScale))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))

                HStack(spacing: 6) {
                    Text(RelativeTimestamp.format(date: clip.createdAt))
                        .font(ClipBoTypography.caption(scale: fontScale))
                        .foregroundStyle(DesignTokens.Colors.secondaryText)

                    if let appName = clip.sourceAppName, !appName.isEmpty {
                        Text("• \(appName)")
                            .font(ClipBoTypography.caption(scale: fontScale))
                            .foregroundStyle(DesignTokens.Colors.tertiaryText)
                    }

                    // Prompt Badge
                    if clip.type == .prompt {
                        Text("✦ Prompt")
                            .font(ClipBoTypography.badge(scale: fontScale))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(3)
                            .foregroundStyle(Color.purple)
                    }

                    // Code / Prompt Language Badge
                    if let lang = clip.customMetadata["detectedLanguage"] {
                        Text(lang)
                            .font(ClipBoTypography.badge(scale: fontScale))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(3)
                            .foregroundStyle(Color.secondary)
                    }

                    // URL Domain Badge
                    if let domain = clip.customMetadata["urlDomain"] {
                        Text(domain)
                            .font(ClipBoTypography.badge(scale: fontScale))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(3)
                            .foregroundStyle(Color.accentColor)
                    }

                    if clip.isStarred {
                        Image(systemName: "star.fill")
                            .font(ClipBoTypography.badge(scale: fontScale))
                            .foregroundStyle(DesignTokens.Colors.starGold)
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.itemCornerRadius, style: .continuous)
                    .fill(DesignTokens.Colors.selectedBackground)
            } else if isHovered {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.itemCornerRadius, style: .continuous)
                    .fill(DesignTokens.Colors.hoverBackground)
            }
        }
        .overlay(alignment: .trailing) {
            if isHovered || isSelected {
                HStack(spacing: 6) {
                    Button {
                        onRestore(clip)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(ClipBoTypography.badge(scale: fontScale))
                            Text("Copy")
                                .font(ClipBoTypography.caption(scale: fontScale))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.18))
                        .cornerRadius(5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")

                    Button {
                        onToggleStar(clip)
                    } label: {
                        Image(systemName: clip.isStarred ? "star.fill" : "star")
                            .font(ClipBoTypography.caption(scale: fontScale))
                            .foregroundStyle(clip.isStarred ? DesignTokens.Colors.starGold : Color.secondary)
                            .padding(5)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(clip.isStarred ? "Unstar" : "Star")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                .padding(.trailing, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animations.fast) {
                isHovered = hovering
            }
        }
        // Double-click copies. Single-click selects. Order matters: double first.
        .onTapGesture(count: 2) {
            onRestore(clip)
        }
        .onTapGesture(count: 1) {
            onSelect(clip)
        }
        // Native AppKit drag-and-drop overlay — threshold prevents accidental drags during clicks
        .background(
            ClipDragView(
                clip: clip,
                imageStorage: imageStorage,
                onDragCompleted: onDragCompleted
            )
        )
        // Draggable cursor hint on hover
        .cursor(isHovered ? .openHand : .arrow)
    }

    private func iconName(for type: ClipType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .prompt: return "sparkles"
        }
    }
}

// MARK: - Cursor Modifier

private extension View {
    @ViewBuilder
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - NSColor Hex

private extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
