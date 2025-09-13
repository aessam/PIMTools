//
//  CaptureViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - ViewModel (SwiftUI Bridge Layer)

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var availableSources: [CaptureSource] = []
    @Published var selectedSources: Set<String> = []
    @Published var isCapturing = false
    @Published var lastCapturedImagePath: String?
    @Published var lastCapturedImage: NSImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let captureService: CaptureService = CaptureService.shared
    
    init() {
        Task {
            await checkPermissionStatus()
        }
    }
    
    // MARK: - Actions
    
    func requestPermission() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await captureService.requestPermission()
            await checkPermissionStatus()
        } catch {
            errorMessage = "Failed to request permission: \(error.localizedDescription)"
            isAuthorized = false
        }
        
        isLoading = false
    }
    
    func checkPermissionStatus() async {
        isAuthorized = await captureService.checkPermissionStatus()
        if isAuthorized {
            await loadAvailableSources()
        }
    }
    
    func loadAvailableSources() async {
        isLoading = true
        errorMessage = nil
        
        do {
            availableSources = try await captureService.getAvailableSources()
        } catch {
            errorMessage = "Failed to load sources: \(error.localizedDescription)"
            availableSources = []
        }
        
        isLoading = false
    }
    
    func captureScreenshot(sourceId: String) async {
        isCapturing = true
        errorMessage = nil
        
        do {
            let result = try await captureService.captureScreenshot(sourceId: sourceId)
            lastCapturedImagePath = result.imagePath
            lastCapturedImage = result.image
        } catch {
            errorMessage = "Screenshot failed: \(error.localizedDescription)"
        }
        
        isCapturing = false
    }
    
    func captureSelectedSources() async {
        guard !selectedSources.isEmpty else {
            errorMessage = "Please select at least one source to capture"
            return
        }
        
        for sourceId in selectedSources {
            await captureScreenshot(sourceId: sourceId)
            if errorMessage != nil {
                break // Stop on first error
            }
        }
    }
    
    // MARK: - Computed Properties for UI
    
    var sourcesDisplayText: String {
        guard !availableSources.isEmpty else { return "No sources available" }
        
        let displays = availableSources.filter { $0.type == .display }
        let apps = availableSources.filter { $0.type == .application }
        let windows = availableSources.filter { $0.type == .window }
        
        var text = ""
        
        if !displays.isEmpty {
            text += "Displays: \(displays.count)\n"
        }
        
        if !apps.isEmpty {
            text += "Applications: \(apps.count)\n"
        }
        
        if !windows.isEmpty {
            text += "Windows: \(windows.count)"
        }
        
        return text.isEmpty ? "No sources available" : text
    }
    
    var canCapture: Bool {
        return isAuthorized && !availableSources.isEmpty && !selectedSources.isEmpty
    }
    
    var statusText: String {
        if !isAuthorized {
            return "Permission required"
        } else if availableSources.isEmpty {
            return "No sources loaded"
        } else if selectedSources.isEmpty {
            return "Select sources to capture"
        } else {
            return "Ready to capture \(selectedSources.count) source\(selectedSources.count == 1 ? "" : "s")"
        }
    }
}