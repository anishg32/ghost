import Foundation
import AppKit

class AppUsageMonitor {
    private let repository: ActivityEventRepository
    private var isTracking = false
    
    private var currentAppName: String?
    private var currentBundleId: String?
    private var currentSessionStartTime: Date?
    
    init(repository: ActivityEventRepository) {
        self.repository = repository
    }
    
    func start() {
        guard !isTracking else { return }
        isTracking = true
        
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidDeactivate(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        
        // Track initially active app
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            startSession(for: frontmostApp)
        }
    }
    
    func stop() {
        guard isTracking else { return }
        isTracking = false
        
        let nc = NSWorkspace.shared.notificationCenter
        nc.removeObserver(self)
        
        // End any ongoing session
        endCurrentSession()
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        // Ignore background processes
        if app.activationPolicy != .regular { return }
        
        // If we switch to a new app, end the old session
        endCurrentSession()
        
        // Start the new session
        startSession(for: app)
    }
    
    @objc private func appDidDeactivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        // Only end session if it's the one we're currently tracking
        if app.localizedName == currentAppName {
            endCurrentSession()
        }
    }
    
    private func startSession(for app: NSRunningApplication) {
        // Exclude our own app if we don't want to track Ghost
        guard let appName = app.localizedName else { return }
        
        currentAppName = appName
        currentBundleId = app.bundleIdentifier
        currentSessionStartTime = Date()
    }
    
    private func endCurrentSession() {
        guard let appName = currentAppName,
              let startTime = currentSessionStartTime else {
            return
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let bundleId = currentBundleId
        
        // Discard micro-sessions (e.g. command-tabbing through apps quickly)
        if duration >= 2.0 {
            Task {
                await repository.insertAppUsageSession(
                    appName: appName,
                    bundleId: bundleId,
                    startTime: startTime,
                    endTime: endTime
                )
            }
        }
        
        currentAppName = nil
        currentBundleId = nil
        currentSessionStartTime = nil
    }
}
