//
//  ServiceError.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation

enum ServiceError: LocalizedError {
    case permissionDenied
    case notAvailable
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied. Please grant access in System Settings."
        case .notAvailable:
            return "Service not available on this system."
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}