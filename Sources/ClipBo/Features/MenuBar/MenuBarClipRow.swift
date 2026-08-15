import SwiftUI
import AppKit

/// Compact scannable clip row for the Menu Bar Panel with full-width text expansion, floating action overlay, dynamic typography scaling, and double-click restore.
public struct MenuBarClipRow: View {
    public let clip: Clip
    public let index: Int
    public let isSelected: Bool
    public let fontScale: Double
    public let imageStorage: ImageStorage?
    public let onSelect: ((Clip) -> Void)?
    public let onRestore: (Clip) -> Void
    public let onToggleStar: (Clip) -> Void
    public var onDragCompleted: (() -> Void)?

    @State private var isHovered = false

    public init(
        clip: Clip,
        index: Int,
        isSelected: Bool = false,
        fontScale: Double = 1.0,
        imageStorage: ImageStorage? = nil,
        onSelect: ((Clip) -> Void)? = nil,
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
        HStack(spacing: 8) {
            // Index number
            Text("\(index)")
                .font(ClipBoTypography.badge(scale: fontScale))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 16, alignment: .trailing)

            // Icon or image thumbnail or color chip
            if clip.type == .image,
               let path = clip.imagePath,
               let data = imageStorage?.loadImage(filenameOrPath: path),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipped()
                    .cornerRadius(4)
            } else if let colorHex = clip.customMetadata["colorHex"], let nsColor = NSColor(hex: colorHex) {
                Circle()
                    .fill(Color(nsColor: nsColor))
                    .frame(width: 15, height: 15)
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                    .frame(width: 16)
            } else {
                Image(systemName: iconName(for: clip.type))
                    .font(ClipBoTypography.body(scale: fontScale))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 16)
            }

            // Content preview & metadata (flexible full-width container)
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.textContent ?? (clip.type == .image ? "Image clip" : ""))
                    .font(clip.type == .code ? ClipBoTypography.codeContent(scale: fontScale) : ClipBoTypography.clipContent(scale: fontScale))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.primary)

                HStack(spacing: 5) {
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
                            .background(Color.accentColor.opacity(0.1))
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.itemCornerRadius, style: .continuous)
                .fill(isSelected ? DesignTokens.Colors.selectedBackground : (isHovered ? DesignTokens.Colors.hoverBackground : Color.clear))
        }
        .overlay(alignment: .trailing) {
            if isHovered || isSelected {
                HStack(spacing: 4) {
                    Button {
                        onRestore(clip)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(ClipBoTypography.badge(scale: fontScale))
                            Text("Copy")
                                .font(ClipBoTypography.badge(scale: fontScale))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.18))
                        .cornerRadius(4)
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
                            .padding(4)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(clip.isStarred ? "Unstar" : "Star")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .cornerRadius(5)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animations.fast) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onRestore(clip)
        }
        .onTapGesture(count: 1) {
            onSelect?(clip)
        }
        .background(
            Group {
                if let imageStorage {
                    ClipDragView(
                        clip: clip,
                        imageStorage: imageStorage,
                        onDragCompleted: onDragCompleted
                    )
                }
            }
        )
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
