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
            pages: pages
        )
        controller.show()
        windowController = controller

        let server = ActivityServer(store: store)
        server.start()
        self.server = server
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // We have no standard windows; never quit just because one closed.
        false
    }
}
