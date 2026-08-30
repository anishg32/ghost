import Foundation

enum RecoveryOperationState: Equatable {
    case ready
    case conflict(existingFileName: String)
    case fileMissing
    case destinationMissing
    case unsupported
}

struct RecoveryOperation {
    let event: RecallResult
    let state: RecoveryOperationState
    let targetPath: String
    let destinationPath: String
}
