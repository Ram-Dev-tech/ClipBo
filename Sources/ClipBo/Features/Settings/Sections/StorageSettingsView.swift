import SwiftUI

public struct StorageSettingsView: View {
    public let clipCount: Int
    public let starredCount: Int
    public let imageCount: Int
    public let databaseSizeBytes: Int64
    public let sqliteSizeBytes: Int64
    public let walSizeBytes: Int64
    public let imagesSizeBytes: Int64
    public let onClearHistory: () -> Void
    public let onClearImages: () -> Void

    @State private var showingClearHistoryAlert: Bool = false
    @State private var showingClearImagesAlert: Bool = false

    public init(
        clipCount: Int,
        starredCount: Int,
        imageCount: Int,
        databaseSizeBytes: Int64,
        sqliteSizeBytes: Int64 = 0,
        walSizeBytes: Int64 = 0,
        imagesSizeBytes: Int64,
        onClearHistory: @escaping () -> Void,
        onClearImages: @escaping () -> Void
    ) {
        self.clipCount = clipCount
        self.starredCount = starredCount
        self.imageCount = imageCount
        self.databaseSizeBytes = databaseSizeBytes
        self.sqliteSizeBytes = sqliteSizeBytes
        self.walSizeBytes = walSizeBytes
        self.imagesSizeBytes = imagesSizeBytes
        self.onClearHistory = onClearHistory
        self.onClearImages = onClearImages
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    Text("Total Saved Clips")
                        .font(ClipBoTypography.body)
                    Spacer()
                    Text("\(clipCount)")
                        .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                HStack {
                    Text("Starred Clips (Preserved)")
                        .font(ClipBoTypography.body)
                    Spacer()
                    Text("\(starredCount)")
                        .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                HStack {
                    Text("Stored Images")
                        .font(ClipBoTypography.body)
                    Spacer()
                    Text("\(imageCount)")
                        .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
            } header: {
                Text("Item Counts")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            }

            Section {
                HStack {
                    Text("CoreData Database (ClipBo.sqlite)")
                        .font(ClipBoTypography.body)
                    Spacer()
                    Text(formatBytes(sqliteSizeBytes > 0 ? sqliteSizeBytes : databaseSizeBytes))
                        .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                if walSizeBytes > 0 {
                    HStack {
                        Text("WAL Journal (ClipBo.sqlite-wal)")
                            .font(ClipBoTypography.body)
                        Spacer()
                        Text(formatBytes(walSizeBytes))
                            .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }

                HStack {
                    Text("Image Storage Directory")
                        .font(ClipBoTypography.body)
                    Spacer()
                    Text(formatBytes(imagesSizeBytes))
                        .font(ClipBoTypography.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                Divider()

                HStack {
                    Text("Total Disk Usage")
                        .font(ClipBoTypography.bodyMedium)
                    Spacer()
                    Text(formatBytes(databaseSizeBytes + imagesSizeBytes))
                        .font(ClipBoTypography.mono(size: 12, weight: .bold))
                        .foregroundStyle(Color.primary)
                }
            } header: {
                Text("Disk Footprint Breakdown")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            } footer: {
                Text("All clipboard history and image payloads are saved locally in ~/Library/Application Support/ClipBo.")
                    .font(ClipBoTypography.secondary)
                    .foregroundStyle(Color.secondary)
            }

            Section {
                HStack {
                    Button(role: .destructive) {
                        showingClearHistoryAlert = true
                    } label: {
                        Text("Clear Clipboard History…")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(ClipBoTypography.caption)

                    Spacer()

                    Button(role: .destructive) {
                        showingClearImagesAlert = true
                    } label: {
                        Text("Clear Stored Images…")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(ClipBoTypography.caption)
                }
            } header: {
                Text("Maintenance")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .alert("Clear Clipboard History?", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All History", role: .destructive) {
                onClearHistory()
            }
        } message: {
            Text("This will permanently delete all saved clipboard history from your Mac.")
        }
        .alert("Clear Stored Images?", isPresented: $showingClearImagesAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Images", role: .destructive) {
                onClearImages()
            }
        } message: {
            Text("This will remove all locally stored image files from disk.")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
