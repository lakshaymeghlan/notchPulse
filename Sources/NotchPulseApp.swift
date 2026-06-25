import SwiftUI

@main
struct NotchPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only presence. The notch UI itself lives in a borderless
        // NSPanel managed by AppDelegate; this extra is just the control surface.
        MenuBarExtra("NotchPulse", systemImage: "waveform") {
            MenuBarContent(store: appDelegate.store)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.widgetSettings)
                .environmentObject(appDelegate.shelf)
                .environmentObject(appDelegate.pages)
        }
    }
}

/// Contents of the menu-bar dropdown.
struct MenuBarContent: View {
    let store: ActivityStore

    var body: some View {
        SettingsLink {
            Text("Widgets & Settings…")
        }
        .keyboardShortcut(",")
        Button("Clear All Activity") {
            store.clearAll()
        }
        Divider()
        Button("Quit NotchPulse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Per-page widget editor: pick a page, then check/uncheck and drag-reorder the
/// widgets that appear on it. This is the "edit / add any widget" surface.
struct SettingsView: View {
    @EnvironmentObject var pages: PagesModel
    @EnvironmentObject var shelf: ShelfStore
    @State private var pageIndex = 0

    private var page: NotchPage { pages.pages[min(pageIndex, pages.pages.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit widgets").font(.headline)
                Text("Choose which widgets show on each page. Drag to reorder; they appear left-to-right.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Picker("Page", selection: $pageIndex) {
                ForEach(Array(pages.pages.enumerated()), id: \.element.id) { i, p in
                    Label(p.title, systemImage: p.icon).tag(i)
                }
            }
            .pickerStyle(.segmented)

            // Widgets currently on this page — reorderable & removable.
            List {
                Section("On this page") {
                    ForEach(page.widgets, id: \.self) { kind in
                        HStack(spacing: 10) {
                            Image(systemName: kind.systemImage).frame(width: 20).foregroundStyle(.tint)
                            Text(kind.title)
                            Spacer()
                            Button {
                                pages.setWidget(kind, onPage: page.id, included: false)
                            } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { pages.moveWidgets(onPage: page.id, from: $0, to: $1) }

                    if page.widgets.isEmpty {
                        Text("No widgets yet — add some below.").foregroundStyle(.secondary).font(.caption)
                    }
                }

                Section("Available widgets") {
                    ForEach(WidgetKind.allCases.filter { !page.widgets.contains($0) }) { kind in
                        Button {
                            pages.setWidget(kind, onPage: page.id, included: true)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: kind.systemImage).frame(width: 20).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title).foregroundStyle(.primary)
                                    Text(kind.blurb).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 280)

            HStack {
                Button("Reset Pages") { pages.resetToDefaults(); pageIndex = 0 }
                Button("Clear Shelf") { shelf.clear() }.disabled(shelf.items.isEmpty)
                Spacer()
                Text("Tip: hover the notch to open it.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460, height: 520)
    }
}
