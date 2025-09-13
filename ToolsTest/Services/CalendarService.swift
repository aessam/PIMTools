//
//  CalendarService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import EventKit

// MARK: - Data Models

struct CalendarData: Sendable, Codable {
    let identifier: String
    let title: String
    let type: String
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let colorData: Data?
    
    init(from calendar: EKCalendar) {
        self.identifier = calendar.calendarIdentifier
        self.title = calendar.title
        self.type = calendar.type.description
        self.allowsContentModifications = calendar.allowsContentModifications
        self.isSubscribed = calendar.isSubscribed
        
        // Store color as Data since CGColor is not Codable
        if let cgColor = calendar.cgColor {
            self.colorData = try? NSKeyedArchiver.archivedData(withRootObject: cgColor, requiringSecureCoding: false)
        } else {
            self.colorData = nil
        }
    }
    
    var color: Color {
        guard let colorData = colorData,
              let cgColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? CGColor else {
            return Color.blue
        }
        return Color(cgColor)
    }
}

struct EventData: Sendable, Codable {
    let identifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarIdentifier: String
    
    init(from event: EKEvent) {
        self.identifier = event.eventIdentifier ?? ""
        self.title = event.title ?? ""
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location
        self.notes = event.notes
        self.calendarIdentifier = event.calendar?.calendarIdentifier ?? ""
    }
}

// MARK: - Calendar Service (No UI Dependencies)

final class CalendarService {
    @MainActor static let shared = CalendarService()
    
    let name = "Calendar"
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestPermission() async throws {
        do {
            try await eventStore.requestFullAccessToEvents()
        } catch {
            throw ServiceError.permissionDenied
        }
    }
    
    func checkPermissionStatus() async -> Bool {
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    func getCalendars() async throws -> [CalendarData] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let calendars = eventStore.calendars(for: .event)
        return calendars.map { CalendarData(from: $0) }
    }
    
    func getEvents(from startDate: Date, to endDate: Date, calendarIdentifiers: [String]? = nil) async throws -> [EventData] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let calendars: [EKCalendar]?
        if let identifiers = calendarIdentifiers {
            calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
        } else {
            calendars = nil
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        return events.map { EventData(from: $0) }
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date, calendarIdentifier: String? = nil) async throws -> String {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        
        if let calendarIdentifier = calendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) {
            event.calendar = calendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier ?? ""
        } catch {
            throw ServiceError.operationFailed("Failed to create event: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensions

extension EKCalendarType {
    var description: String {
        switch self {
        case .local: return "Local"
        case .calDAV: return "CalDAV"
        case .exchange: return "Exchange"
        case .subscription: return "Subscription"
        case .birthday: return "Birthday"
        @unknown default: return "Unknown"
        }
    }
}
