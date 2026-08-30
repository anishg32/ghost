import Foundation
import AppKit

class AppActivityMonitor {
    private let repository: ActivityEventRepository
    private var isTracking = false
    
    init(repository: ActivityEventRepository) {
        self.repository = repository
    }
    
    func start() {
        guard !isTracking else { return }
        isTracking = true
        
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }
    
    func stop() {
        guard isTracking else { return }
        isTracking = false
        
        let nc = NSWorkspace.shared.notificationCenter
        nc.removeObserver(self)
    }
    
    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName,
              // Ignore background processes, only track normal UI apps
              app.activationPolicy == .regular else {
            return
        }
        
        Task {
            await repository.insertEvent(
                eventType: .appLaunched,
                title: "Opened \(appName)",
                appName: appName
            )
        }
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName,
              app.activationPolicy == .regular else {
            return
        }
        
        Task {
            await repository.insertEvent(
                eventType: .appQuit,
                title: "Closed \(appName)",
                appName: appName
            )
        }
    }
}
