//
//  CalendarViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import SwiftUI
import EventKit
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var calendars: [CalendarData] = []
    @Published var events: [EventData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCalendarIds: Set<String> = []
    
    private let calendarService: CalendarService = CalendarService.shared
    
    init() {
        Task {
            await checkPermissionStatus()
        }
    }
    
    func requestPermission() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await calendarService.requestPermission()
            await checkPermissionStatus()
        } catch {
            errorMessage = "Failed to request permission: \(error.localizedDescription)"
            isAuthorized = false
        }
        
        isLoading = false
    }
    
    func checkPermissionStatus() async {
        isAuthorized = await calendarService.checkPermissionStatus()
        if isAuthorized {
            await loadCalendars()
        }
    }
    
    func loadCalendars() async {
        isLoading = true
        errorMessage = nil
        
        do {
            calendars = try await calendarService.getCalendars()
        } catch {
            errorMessage = "Failed to load calendars: \(error.localizedDescription)"
            calendars = []
        }
        
        isLoading = false
    }
    
    func loadEvents(from startDate: Date, to endDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let calendarIds = selectedCalendarIds.isEmpty ? nil : Array(selectedCalendarIds)
            events = try await calendarService.getEvents(
                from: startDate,
                to: endDate,
                calendarIdentifiers: calendarIds
            )
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
            events = []
        }
        
        isLoading = false
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await calendarService.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarIdentifier: calendarId
            )
            await loadEvents(from: startDate.addingTimeInterval(-86400), to: endDate.addingTimeInterval(86400))
            return true
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    var eventsDisplayText: String {
        guard !events.isEmpty else { return "No events found" }
        return "\(events.count) event\(events.count == 1 ? "" : "s") found"
    }
    
    var statusText: String {
        if !isAuthorized {
            return "Permission required"
        } else if isLoading {
            return "Loading calendars..."
        } else if calendars.isEmpty {
            return "No calendars found"
        } else if selectedCalendarIds.isEmpty {
            return "Select calendars to view events"
        } else {
            return "Ready - \(selectedCalendarIds.count) calendar\(selectedCalendarIds.count == 1 ? "" : "s") selected"
        }
    }
}
