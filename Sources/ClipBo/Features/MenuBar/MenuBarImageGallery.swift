import SwiftUI
import AppKit

/// Three-column image gallery for browsing image clips in the Menu Bar Panel with dynamic typography scaling.
public struct MenuBarImageGallery: View {
    public let clips: [Clip]
    public let fontScale: Double
    public let imageStorage: ImageStorage
    public let onRestore: (Clip) -> Void
    public let onToggleStar: (Clip) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    public init(
        clips: [Clip],
        fontScale: Double = 1.0,
        imageStorage: ImageStorage,
        onRestore: @escaping (Clip) -> Void,
        onToggleStar: @escaping (Clip) -> Void
    ) {
        self.clips = clips
        self.fontScale = fontScale
        self.imageStorage = imageStorage
        self.onRestore = onRestore
        self.onToggleStar = onToggleStar
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    MenuBarImageCell(
                        clip: clip,
                        index: index + 1,
                        fontScale: fontScale,
                        imageStorage: imageStorage,
                        onRestore: onRestore,
                        onToggleStar: onToggleStar
                    )
                }
            }
            .padding(8)
        }
    }
}

private struct MenuBarImageCell: View {
    let clip: Clip
    let index: Int
    let fontScale: Double
    let imageStorage: ImageStorage
    let onRestore: (Clip) -> Void
    let onToggleStar: (Clip) -> Void

    @State private var isHovered = false
    @State private var isCopiedFeedback = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail image
                if let path = clip.imagePath,
                   let data = imageStorage.loadImage(filenameOrPath: path),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 105, height: 80)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 105, height: 80)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }

                // Index badge
                VStack {
                    HStack {
                        Text("\(index)")
                            .font(ClipBoTypography.badge(scale: fontScale))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)

                // Hover Actions
                if isHovered {
                    VStack(spacing: 4) {
                        Button {
                            triggerCopy()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(ClipBoTypography.badge(scale: fontScale))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onToggleStar(clip)
                        } label: {
                            Image(systemName: clip.isStarred ? "star.fill" : "star")
                                .font(ClipBoTypography.badge(scale: fontScale))
                                .foregroundStyle(clip.isStarred ? DesignTokens.Colors.starGold : .white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .transition(.opacity)
                }

                // Copied feedback banner
                if isCopiedFeedback {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 105, height: 80)
                        .overlay {
                            VStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(ClipBoTypography.system(size: 14, scale: fontScale))
                                Text("Copied")
                                    .font(ClipBoTypography.badge(scale: fontScale))
                                    .foregroundStyle(.white)
                            }
                        }
                        .transition(.opacity)
                }
            }

            // Timestamp subtitle
            Text(RelativeTimestamp.format(date: clip.createdAt))
                .font(ClipBoTypography.caption(scale: fontScale))
                .foregroundStyle(DesignTokens.Colors.secondaryText)
                .lineLimit(1)
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.itemCornerRadius, style: .continuous)
                .fill(isHovered ? DesignTokens.Colors.hoverBackground : Color.clear)
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Animations.fast) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            triggerCopy()
        }
    }

    private func triggerCopy() {
        onRestore(clip)
        withAnimation(DesignTokens.Animations.fast) {
            isCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(DesignTokens.Animations.fast) {
                isCopiedFeedback = false
            }
        }
    }
}
