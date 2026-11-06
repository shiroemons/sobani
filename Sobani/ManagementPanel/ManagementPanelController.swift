import AppKit
import SwiftUI
import os.log

@MainActor
final class ManagementPanelController: NSObject, NSWindowDelegate {
    private let logger = Logger(category: "ManagementPanelController")
    private var panel: NSPanel?
    private let viewModel: ManagementPanelViewModel
    nonisolated(unsafe) private var languageObserver: Any?

    init(appDelegate: AppDelegate) {
        self.viewModel = ManagementPanelViewModel(appDelegate: appDelegate)
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel?.title = L("management.title")
            }
        }
    }

    deinit {
        if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
    }

    func show() {
        if let panel {
            viewModel.setPanelVisible(true)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        setupPanel()
    }

    func close() {
        panel?.orderOut(nil)
        viewModel.setPanelVisible(false)
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
        // 一覧は表示に切り替わったときに構築されるため、ビューを作る前に済ませる（初回描画を空の一覧にしない）
        viewModel.setPanelVisible(true)
        let contentView = ManagementPanelView(viewModel: viewModel)
        let hosting = NSHostingController(rootView: contentView)

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
        let panelLevel = NSWindow.Level.floating.rawValue + AppConstants.managementPanelLevelOffset
        panel.level = NSWindow.Level(rawValue: panelLevel)
        panel.configureForFloating()
        panel.isMovableByWindowBackground = true
        panel.center()
        viewModel.presentingWindow = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        self.panel = panel
        logger.info("Management panel opened")
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Return false to prevent the panel from being deallocated.
        // Instead, hide it via close() so it can be reused on next show().
        close()
        return false
    }
}
