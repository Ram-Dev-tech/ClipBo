import SwiftUI

/// Temporary verification interface for Phase 1 testing.
/// Note: This is strictly a functional verification view, not the final Phase 2 UI.
public struct TemporaryHistoryView: View {
    @ObservedObject public var coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Circle()
                    .fill(coordinator.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text("ClipBo (Phase 1)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(coordinator.recentClips.count) clips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()

            // Status message banner if any
            if let status = coordinator.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                Divider()
            }

            // Clips list
            if coordinator.recentClips.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Clipboard history is empty")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Copy some text or an image to test.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                List {
                    ForEach(Array(coordinator.recentClips), id: \.id) { (clip: Clip) in
                        HStack(spacing: 10) {
                            // Type icon
                            typeIcon(for: clip.type)
                                .frame(width: 16)
                            
                            // Clip preview
                            VStack(alignment: .leading, spacing: 2) {
                                if clip.type == .image {
                                    imagePreview(for: clip)
                                } else {
                                    Text(clip.textContent ?? "")
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                }
                                
                                HStack(spacing: 6) {
                                    Text(clip.createdAt, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    if let appName = clip.sourceAppName {
                                        Text("• \(appName)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Copy back button
                            Button {
                                coordinator.restoreClip(clip)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy to Clipboard")

                            // Delete button
                            Button {
                                Task {
                                    await coordinator.deleteClip(clip)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete clip")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer controls
            HStack {
                Button("Clear History") {
                    Task {
                        await coordinator.clearAll()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Spacer()

                Toggle("Launch at Login", isOn: Binding(
                    get: { coordinator.launchAtLoginEnabled },
                    set: { _ in coordinator.toggleLaunchAtLogin() }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 380, height: 440)
    }

    @ViewBuilder
    private func typeIcon(for type: ClipType) -> some View {
        switch type {
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.blue)
        case .image:
            Image(systemName: "photo")
                .foregroundStyle(.green)
        case .url:
            Image(systemName: "link")
                .foregroundStyle(.purple)
        case .code:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.orange)
        case .prompt:
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
        }
    }

    @ViewBuilder
    private func imagePreview(for clip: Clip) -> some View {
        if let path = clip.imagePath,
           let data = coordinator.imageStorage.loadImage(filenameOrPath: path),
           let nsImage = NSImage(data: data) {
            HStack(spacing: 8) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 80, maxHeight: 40)
                    .cornerRadius(4)
                
                VStack(alignment: .leading) {
                    Text("Image clip")
                        .font(.caption)
                        .bold()
                    if let w = clip.imageWidth, let h = clip.imageHeight {
                        Text("\(Int(w)) × \(Int(h)) px")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text("[Image payload unavailable]")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
