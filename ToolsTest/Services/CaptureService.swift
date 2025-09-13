//
//  CaptureService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import ScreenCaptureKit
import AppKit

// MARK: - Data Models

struct CaptureSource: Identifiable, Sendable {
    let id: String
    let name: String
    let type: CaptureSourceType
}

enum CaptureSourceType: String, CaseIterable, Sendable {
    case display = "Display"
    case application = "Application"
    case window = "Window"
}

struct CaptureResult: Sendable {
    let imagePath: String
    let image: NSImage
    let timestamp: Date
    let sourceId: String
    
    init(imagePath: String, image: NSImage, sourceId: String) {
        self.imagePath = imagePath
        self.image = image
        self.sourceId = sourceId
        self.timestamp = Date()
    }
}

// MARK: - Capture Service (No UI Dependencies)

final class CaptureService {
    @MainActor static let shared = CaptureService()
    
    private init() {}
    
    // MARK: - Permission Management
    
    func checkPermissionStatus() async -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    func requestPermission() async throws {
        let granted = CGRequestScreenCaptureAccess()
        
        if !granted {
            throw ServiceError.permissionDenied
        }
    }
    
    // MARK: - Content Discovery
    
    func getAvailableSources() async throws -> [CaptureSource] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        var sources: [CaptureSource] = []
        
        // Add displays
        for display in content.displays {
            sources.append(CaptureSource(
                id: "display-\(display.displayID)",
                name: "Display \(display.displayID)",
                type: .display
            ))
        }
        
        // Add applications
        for app in content.applications {
            let bundleID = app.bundleIdentifier
            sources.append(CaptureSource(
                id: "app-\(bundleID)",
                name: app.applicationName,
                type: .application
            ))
        }
        
        // Add windows (top 10 most relevant)
        for window in content.windows.prefix(10) {
            if let title = window.title, !title.isEmpty {
                sources.append(CaptureSource(
                    id: "window-\(window.windowID)",
                    name: title,
                    type: .window
                ))
            }
        }
        
        return sources
    }
    
    // MARK: - Screenshot Capture
    
    func captureScreenshot(sourceId: String) async throws -> CaptureResult {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let filter = try createContentFilter(for: sourceId, content: content)
        let configuration = SCStreamConfiguration()
        
        // Configure for screenshot
        configuration.width = 1920
        configuration.height = 1080
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true
        configuration.scalesToFit = true
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory
        let filename = "ToolsTest-Screenshot-\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = tempURL.appendingPathComponent(filename)
        
        let imageRep = NSBitmapImageRep(cgImage: image)
        
        guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
            throw ServiceError.operationFailed("Failed to create PNG data")
        }
        
        try pngData.write(to: fileURL)
        
        // Create NSImage for preview
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        return CaptureResult(imagePath: fileURL.path, image: nsImage, sourceId: sourceId)
    }
    
    // MARK: - Helper Methods
    
    private func createContentFilter(for sourceId: String, content: SCShareableContent) throws -> SCContentFilter {
        let components = sourceId.split(separator: "-", maxSplits: 1)
        guard components.count == 2 else {
            throw ServiceError.operationFailed("Invalid source ID format")
        }
        
        let type = String(components[0])
        let identifier = String(components[1])
        
        switch type {
        case "display":
            guard let displayID = UInt32(identifier),
                  let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw ServiceError.operationFailed("Display not found")
            }
            return SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
        case "app":
            guard let app = content.applications.first(where: { $0.bundleIdentifier == identifier }) else {
                throw ServiceError.operationFailed("Application not found")
            }
            // For applications, capture all their windows
            let appWindows = content.windows.filter { $0.owningApplication == app }
            if let firstWindow = appWindows.first {
                return SCContentFilter(desktopIndependentWindow: firstWindow)
            } else {
                // Fallback to display with app included
                guard let display = content.displays.first else {
                    throw ServiceError.operationFailed("No display available")
                }
                return SCContentFilter(display: display, including: [app], exceptingWindows: [])
            }
            
        case "window":
            guard let windowID = UInt32(identifier),
                  let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw ServiceError.operationFailed("Window not found")
            }
            return SCContentFilter(desktopIndependentWindow: window)
            
        default:
            throw ServiceError.operationFailed("Unknown source type")
        }
    }
}
