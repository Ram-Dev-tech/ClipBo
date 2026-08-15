import SwiftUI

/// Management view for built-in and user-defined custom categories in Settings.
public struct CategorySettingsView: View {
    @ObservedObject var settingsService: SettingsService

    @State private var showingAddSheet: Bool = false
    @State private var newCategoryTitle: String = ""
    @State private var selectedIconName: String = "tag"
    @State private var editingCategoryId: String? = nil
    @State private var editingTitle: String = ""
    @State private var categoryToDelete: CustomCategoryItem? = nil

    private let availableIcons = [
        "tag", "folder", "briefcase", "book", "graduationcap",
        "star", "heart", "bookmark", "doc", "terminal",
        "laptopcomputer", "lightbulb", "wrench.and.screwdriver", "music.note", "cart"
    ]

    public init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    private var fontScale: Double {
        settingsService.settings.fontScale.scaleFactor
    }

    private var categories: [CustomCategoryItem] {
        settingsService.allCategories()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categories")
                    .font(ClipBoTypography.sectionTitle(scale: fontScale))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Button {
                    newCategoryTitle = ""
                    selectedIconName = "tag"
                    showingAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(ClipBoTypography.caption(scale: fontScale))
                        Text("Add Category")
                            .font(ClipBoTypography.caption(scale: fontScale))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(spacing: 3) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    categoryRow(category: category, index: index)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }

            Text("Reorder, enable, or disable categories. The 'All' category and built-in filters are permanently protected.")
                .font(ClipBoTypography.caption(scale: fontScale))
                .foregroundStyle(Color.secondary)
        }
        .sheet(isPresented: $showingAddSheet) {
            addCategorySheet
        }
        .alert("Delete Category?", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    settingsService.deleteCustomCategory(id: cat.id)
                    categoryToDelete = nil
                }
            }
        } message: {
            if let cat = categoryToDelete {
                Text("Are you sure you want to delete \"\(cat.title)\"? Your saved clipboard clips will remain intact.")
            }
        }
    }

    @ViewBuilder
    private func categoryRow(category: CustomCategoryItem, index: Int) -> some View {
        HStack(spacing: 8) {
            // Reorder controls
            HStack(spacing: 2) {
                Button {
                    settingsService.moveCategory(id: category.id, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(ClipBoTypography.badge(scale: fontScale))
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.3 : 0.8)

                Button {
                    settingsService.moveCategory(id: category.id, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(ClipBoTypography.badge(scale: fontScale))
                }
                .buttonStyle(.plain)
                .disabled(index == categories.count - 1)
                .opacity(index == categories.count - 1 ? 0.3 : 0.8)
            }
            .frame(width: 28)

            // Category Icon
            Image(systemName: category.iconName)
                .font(ClipBoTypography.body(scale: fontScale))
                .foregroundStyle(category.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            // Name or Inline Rename Field
            if editingCategoryId == category.id {
                TextField("Category Name", text: $editingTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(ClipBoTypography.body(scale: fontScale))
                    .onSubmit {
                        if !editingTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            settingsService.renameCategory(id: category.id, newTitle: editingTitle.trimmingCharacters(in: .whitespaces))
                        }
                        editingCategoryId = nil
                    }

                Button("Save") {
                    if !editingTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        settingsService.renameCategory(id: category.id, newTitle: editingTitle.trimmingCharacters(in: .whitespaces))
                    }
                    editingCategoryId = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .font(ClipBoTypography.caption(scale: fontScale))
            } else {
                Text(category.title)
                    .font(ClipBoTypography.body(scale: fontScale))
                    .foregroundStyle(category.isEnabled ? Color.primary : Color.secondary)

                if category.isBuiltIn {
                    Text("Built-in")
                        .font(ClipBoTypography.badge(scale: fontScale))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions for custom categories
                if !category.isBuiltIn {
                    Button {
                        editingCategoryId = category.id
                        editingTitle = category.title
                    } label: {
                        Image(systemName: "pencil")
                            .font(ClipBoTypography.caption(scale: fontScale))
                    }
                    .buttonStyle(.plain)
                    .help("Rename category")

                    Button {
                        categoryToDelete = category
                    } label: {
                        Image(systemName: "trash")
                            .font(ClipBoTypography.caption(scale: fontScale))
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete category")
                }

                // Visibility Toggle
                Toggle("", isOn: Binding(
                    get: { category.isEnabled },
                    set: { _ in
                        settingsService.toggleCategoryEnabled(id: category.id)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(category.id == "all")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var addCategorySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Custom Category")
                .font(ClipBoTypography.title(scale: fontScale))

            VStack(alignment: .leading, spacing: 4) {
                Text("Category Name")
                    .font(ClipBoTypography.caption(scale: fontScale))
                    .foregroundStyle(Color.secondary)

                TextField("e.g. Work, Research, Study", text: $newCategoryTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(ClipBoTypography.body(scale: fontScale))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Icon")
                    .font(ClipBoTypography.caption(scale: fontScale))
                    .foregroundStyle(Color.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(ClipBoTypography.body(scale: fontScale))
                                .frame(width: 32, height: 32)
                                .background(selectedIconName == icon ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                .cornerRadius(6)
                                .overlay {
                                    if selectedIconName == icon {
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showingAddSheet = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Category") {
                    let trimmed = newCategoryTitle.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    settingsService.addCustomCategory(title: trimmed, iconName: selectedIconName)
                    showingAddSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(width: 320)
    }
}
