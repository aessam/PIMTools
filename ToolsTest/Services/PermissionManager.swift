//
//  PermissionManager.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import EventKit
import CoreLocation
import Contacts
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var calendarAuthorized = false
    @Published var remindersAuthorized = false
    @Published var contactsAuthorized = false
    @Published var locationAuthorized = false
    @Published var captureAuthorized = false
    
    private init() {
        Task {
            await checkAllPermissions()
        }
    }
    
    func checkAllPermissions() async {
        await checkCalendarPermission()
        await checkRemindersPermission()
        await checkContactsPermission()
        await checkLocationPermission()
        await checkCapturePermission()
    }
    
    // MARK: - Calendar
    func checkCalendarPermission() async {
        calendarAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    func requestCalendarPermission() async throws {
        let eventStore = EKEventStore()
        try await eventStore.requestFullAccessToEvents()
        await checkCalendarPermission()
    }
    
    // MARK: - Reminders
    func checkRemindersPermission() async {
        remindersAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }
    
    func requestRemindersPermission() async throws {
        let eventStore = EKEventStore()
        try await eventStore.requestFullAccessToReminders()
        await checkRemindersPermission()
    }
    
    // MARK: - Contacts
    func checkContactsPermission() async {
        contactsAuthorized = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    func requestContactsPermission() async throws {
        let store = CNContactStore()
        try await store.requestAccess(for: .contacts)
        await checkContactsPermission()
    }
    
    // MARK: - Location
    func checkLocationPermission() async {
        locationAuthorized = await LocationService.shared.checkPermissionStatus()
    }
    
    func requestLocationPermission() async throws {
        try await LocationService.shared.requestPermission()
        await checkLocationPermission()
    }
    
    // MARK: - Capture (Screen Recording)
    func checkCapturePermission() async {
        // Screen recording permission check - simplified for now
        captureAuthorized = true // Will be implemented when we add screen capture
    }
    
    func requestCapturePermission() async throws {
        await checkCapturePermission()
    }
}
