import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let notchState = NotchState()
    let store = ActivityStore()
    let widgetSettings = WidgetSettings()
    let battery = BatteryMonitor()
    let shelf = ShelfStore()
    let openApps = OpenAppsMonitor()
    let windows = WindowsMonitor()
    let camera = CameraController()
    let calendar = CalendarMonitor()
    let music = NowPlayingMonitor()
    let teleprompter = TeleprompterModel()
    let stats = SystemStatsMonitor()
    let pomodoro = PomodoroModel()
    let theme = ThemeModel()
    let ask = AskModel()
    let clipboard = ClipboardMonitor()
    let approvals = ApprovalStore()
    let todo = TodoModel()
    let notes = NotesModel()
    let shortcuts = ShortcutsModel()
    let bluetooth = BluetoothMonitor()
    let pages = PagesModel()
    let userActivity = UserActivityMonitor()
    private var windowController: NotchWindowController?
    private var server: ActivityServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon, no main window. LSUIElement in Info.plist
        // plus .accessory policy keep us out of the Dock and app switcher.
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController(
            notchState: notchState,
            store: store,
            widgetSettings: widgetSettings,
            battery: battery,
            shelf: shelf,
            openApps: openApps,
            windows: windows,
            camera: camera,
            calendar: calendar,
            music: music,
            teleprompter: teleprompter,
            stats: stats,
            pomodoro: pomodoro,
            theme: theme,
            ask: ask,
            clipboard: clipboard,
            approvals: approvals,
            todo: todo,
            notes: notes,
            shortcuts: shortcuts,
            bluetooth: bluetooth,
            pages: pages,
            userActivity: userActivity
        )
        controller.show()
        windowController = controller

        // Mirror what the user is doing (foreground app + typing pace) so the
        // mascot works alongside them.
        userActivity.start()

        let server = ActivityServer(store: store, approvals: approvals)
        server.start()
        self.server = server

        // Poll now-playing globally so the collapsed mascot can "vibe" to music
        // even when the Music widget isn't open. Cheap and prompt-free unless a
        // supported player is actually running (only then is any AppleScript run).
        music.startPolling()

        // Global shortcut (⌥⌘N) to open settings from any app.
        GlobalHotKey.shared.register { [weak self] in
            self?.openSettings()
        }
    }

    /// Open Settings and bring it to the very front (an .accessory app's
    /// Settings window otherwise opens behind other apps / unfocused).
    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Next runloop: the Settings window exists — front + center it.
        DispatchQueue.main.async {
            guard let w = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) else { return }
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        userActivity.stop()
        GlobalHotKey.shared.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // We have no standard windows; never quit just because one closed.
        false
    }
}
