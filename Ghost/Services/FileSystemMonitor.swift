import Foundation
import CoreServices

protocol FileSystemMonitorDelegate: AnyObject {
    func fileSystemMonitor(_ monitor: FileSystemMonitor, didReceiveEvent event: FSEvent)
}

struct FSEvent {
    let id: FSEventStreamEventId
    let path: String
    let flags: FSEventStreamEventFlags
    let timestamp: Date
}

class FileSystemMonitor {
    weak var delegate: FileSystemMonitorDelegate?
    
    private var stream: FSEventStreamRef?
    private let pathsToWatch: [String]
    private var isTracking = false
    
    init(pathsToWatch: [String]) {
        self.pathsToWatch = pathsToWatch
    }
    
    func start() {
        guard !isTracking else { return }
        guard !pathsToWatch.isEmpty else { return }
        isTracking = true
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, // latency
            flags
        )
        
        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .background))
            FSEventStreamStart(stream)
        }
    }
    
    func stop() {
        guard isTracking else { return }
        isTracking = false
        
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
}

private let fsEventsCallback: FSEventStreamCallback = { (
    streamRef,
    clientCallBackInfo,
    numEvents,
    eventPaths,
    eventFlags,
    eventIds
) in
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(info).takeUnretainedValue()
    
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
    let flags = eventFlags
    let ids = eventIds
    let timestamp = Date()
    
    for i in 0..<numEvents {
        let event = FSEvent(
            id: ids[i],
            path: paths[i],
            flags: flags[i],
            timestamp: timestamp
        )
        monitor.delegate?.fileSystemMonitor(monitor, didReceiveEvent: event)
    }
}
