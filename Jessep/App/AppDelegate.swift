import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    private var viewModel: UsageViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var popoverWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Jessep] ========================================")
        print("[Jessep] applicationDidFinishLaunching started")
        print("[Jessep] ========================================")

        // Observe settings open request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettingsWindow,
            object: nil
        )

        // Request notification permission
        Task { @MainActor in
            await NotificationService.shared.requestPermission()
        }

        // Set up menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill",
                                   accessibilityDescription: "Jessep - Claude Usage")
        }

        // Create the menu
        setupMenu()

        // Create ViewModel on MainActor
        Task { @MainActor in
            print("[Jessep] [Task] Creating ViewModel...")
            let vm = UsageViewModel()
            self.viewModel = vm

            // Start polling
            vm.startPolling(interval: TimeInterval(AppSettings.shared.refreshInterval))

            // Observe usage changes for menu bar updates
            vm.$usageData
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateMenuBarIcon()
                    self?.updateMenuContent()
                }
                .store(in: &self.cancellables)

            print("[Jessep] [Task] ViewModel setup complete")
        }

        // Observe settings changes via UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                Task { @MainActor in
                    let interval = AppSettings.shared.refreshInterval
                    self?.viewModel?.startPolling(interval: TimeInterval(interval))
                }
            }
            .store(in: &cancellables)

        print("[Jessep] applicationDidFinishLaunching completed")
    }

    private func setupMenu() {
        statusMenu = NSMenu()
        statusMenu?.delegate = self

        // Add "Show Usage" item
        let showItem = NSMenuItem(title: "Show Usage...", action: #selector(showUsageWindow), keyEquivalent: "")
        showItem.target = self
        statusMenu?.addItem(showItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // Add quick status items (will be updated dynamically)
        let sessionItem = NSMenuItem(title: "Session: --", action: nil, keyEquivalent: "")
        sessionItem.tag = 100
        sessionItem.isEnabled = false
        statusMenu?.addItem(sessionItem)

        let weeklyItem = NSMenuItem(title: "Weekly: --", action: nil, keyEquivalent: "")
        weeklyItem.tag = 101
        weeklyItem.isEnabled = false
        statusMenu?.addItem(weeklyItem)

        let sonnetItem = NSMenuItem(title: "Sonnet: --", action: nil, keyEquivalent: "")
        sonnetItem.tag = 102
        sonnetItem.isEnabled = false
        statusMenu?.addItem(sonnetItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu?.addItem(settingsItem)

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        statusMenu?.addItem(refreshItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Jessep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusMenu?.addItem(quitItem)

        statusItem?.menu = statusMenu
        print("[Jessep] Menu configured")
    }

    @objc func showUsageWindow() {
        print("[Jessep] showUsageWindow called")

        Task { @MainActor in
            // Create window if needed
            if self.popoverWindow == nil {
                guard let vm = self.viewModel else {
                    print("[Jessep] ERROR: viewModel is nil")
                    return
                }

                let contentView = UsagePopoverView(viewModel: vm)
                    .environmentObject(AppSettings.shared)

                let hostingController = NSHostingController(rootView: contentView)

                let panel = NSPanel(contentViewController: hostingController)
                panel.styleMask = [.titled, .closable, .nonactivatingPanel]
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.isFloatingPanel = true
                panel.hidesOnDeactivate = false
                panel.isReleasedWhenClosed = false  // Prevent deallocation when closed
                panel.title = "Jessep - Claude Usage"
                panel.setContentSize(NSSize(width: 320, height: 400))

                // Position near status item
                if let button = self.statusItem?.button,
                   let buttonWindow = button.window {
                    let buttonFrame = buttonWindow.frame
                    let panelOrigin = NSPoint(
                        x: buttonFrame.midX - 160,
                        y: buttonFrame.minY - 410
                    )
                    panel.setFrameOrigin(panelOrigin)
                } else {
                    panel.center()
                }

                self.popoverWindow = panel
                print("[Jessep] Usage window created")
            }

            // Now show the window (guaranteed to exist after creation above)
            self.popoverWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            // Refresh data
            await self.viewModel?.refresh()
            print("[Jessep] Usage window shown")
        }
    }

    @objc func refreshData() {
        print("[Jessep] refreshData called")
        Task { @MainActor in
            await viewModel?.refresh()
        }
    }

    private func updateMenuContent() {
        Task { @MainActor in
            guard let menu = statusMenu else { return }

            let sessionUsage = viewModel?.usageData?.fiveHour?.utilization ?? 0
            let weeklyUsage = viewModel?.usageData?.sevenDay?.utilization ?? 0
            let sonnetUsage = viewModel?.usageData?.sonnetOnly?.utilization ?? 0

            if let item = menu.item(withTag: 100) {
                item.title = "Session: \(Int(sessionUsage))%"
            }
            if let item = menu.item(withTag: 101) {
                item.title = "Weekly: \(Int(weeklyUsage))%"
            }
            if let item = menu.item(withTag: 102) {
                item.title = "Sonnet: \(Int(sonnetUsage))%"
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            viewModel?.stopPolling()
        }
    }

    // MARK: - Menu Bar Icon

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        Task { @MainActor in
            let maxUsage = [
                self.viewModel?.usageData?.fiveHour?.utilization,
                self.viewModel?.usageData?.sevenDay?.utilization,
                self.viewModel?.usageData?.sonnetOnly?.utilization
            ].compactMap { $0 }.max() ?? 0

            self.applyMenuBarStyle(button: button, maxUsage: maxUsage)
        }
    }

    @MainActor
    private func applyMenuBarStyle(button: NSStatusBarButton, maxUsage: Double) {
        let style = MenuBarStyle(rawValue: AppSettings.shared.menuBarStyle) ?? .icon

        switch style {
        case .icon:
            button.image = NSImage(systemSymbolName: "chart.bar.fill",
                                   accessibilityDescription: "Claude Usage")
            button.title = ""

        case .percentage:
            button.image = nil
            button.title = "\(Int(maxUsage))%"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        case .dynamic:
            let color: NSColor
            if maxUsage < 50 {
                color = .systemGreen
            } else if maxUsage < 80 {
                color = .systemYellow
            } else {
                color = .systemRed
            }

            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            button.image = NSImage(systemSymbolName: "chart.bar.fill",
                                   accessibilityDescription: "Claude Usage")?
                .withSymbolConfiguration(config)
            button.title = ""
        }

        button.toolTip = "Claude usage at \(Int(maxUsage))%"
    }

    // MARK: - Settings Window

    @objc func handleOpenSettings(_ notification: Any?) {
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        print("[Jessep] showSettingsWindow called")

        popoverWindow?.close()

        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppSettings.shared)

            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Jessep Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 450, height: 600))
            window.center()
            window.isReleasedWhenClosed = false

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        print("[Jessep] Menu will open")
        // Refresh data when menu opens
        Task { @MainActor in
            await viewModel?.refresh()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettingsWindow = Notification.Name("com.jessep.openSettings")
}
