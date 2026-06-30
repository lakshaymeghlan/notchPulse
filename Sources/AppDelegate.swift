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
            pages: pages
        )
        controller.show()
        windowController = controller

        let server = ActivityServer(store: store, approvals: approvals)
        server.start()
        self.server = server

        // Global shortcut (⌥⌘N) to open settings from any app.
        GlobalHotKey.shared.register {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        GlobalHotKey.shared.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // We have no standard windows; never quit just because one closed.
        false
    }
}
