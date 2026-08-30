import Foundation

class ActivityTrackingService: FileSystemMonitorDelegate {
    static let shared = ActivityTrackingService()
    
    private var repository: ActivityEventRepository?
    private var appMonitor: AppActivityMonitor?
    private var fileMonitor: FileSystemMonitor?
    private(set) var fileProcessor: FileChangeProcessor?
    
    var isTrackingEnabled: Bool = true {
        didSet {
            if isTrackingEnabled {
                startTracking()
            } else {
                stopTracking()
            }
        }
    }
    
    func initialize(with repository: ActivityEventRepository) {
        self.repository = repository
        self.appMonitor = AppActivityMonitor(repository: repository)
        self.fileProcessor = FileChangeProcessor(repository: repository)
        
        let paths = [
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path,
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path,
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
        ].compactMap { $0 }
        
        self.fileMonitor = FileSystemMonitor(pathsToWatch: paths)
        self.fileMonitor?.delegate = self
        
        if isTrackingEnabled {
            startTracking()
        }
    }
    
    private func startTracking() {
        appMonitor?.start()
        fileMonitor?.start()
    }
    
    private func stopTracking() {
        appMonitor?.stop()
        fileMonitor?.stop()
    }
    
    func fileSystemMonitor(_ monitor: FileSystemMonitor, didReceiveEvent event: FSEvent) {
        fileProcessor?.process(event: event)
    }
}
