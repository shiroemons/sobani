import AppKit
import SwiftUI
import os.log

@MainActor
final class ManagementPanelController: NSObject, NSWindowDelegate {
    private static let panelLevelOffset: Int = 2
    private let logger = Logger(category: "ManagementPanelController")
    private var panel: NSPanel?
    private var hostingController: NSHostingController<ManagementPanelView>?
    private let viewModel: ManagementPanelViewModel

    init(appDelegate: AppDelegate) {
        self.viewModel = ManagementPanelViewModel(appDelegate: appDelegate)
        super.init()
    }

    func show() {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        setupPanel()
    }

    func close() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private func setupPanel() {
        let contentView = ManagementPanelView(viewModel: viewModel)
        let hosting = NSHostingController(rootView: contentView)
        hostingController = hosting

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0, y: 0,
                width: AppConstants.managementPanelWidth,
                height: AppConstants.managementPanelHeight
            ),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L("management.title")
        panel.contentViewController = hosting
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + Self.panelLevelOffset)
        panel.configureForFloating()
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
        logger.info("Management panel opened")
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }
}
