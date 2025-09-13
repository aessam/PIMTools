//
//  RemindersService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import EventKit

// MARK: - Data Models

struct ReminderInfo: Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int
    let creationDate: Date?
    let completionDate: Date?
    let dueDate: Date?
    let calendarTitle: String
    let calendarColor: CGColor?
}

struct ReminderListData: Identifiable, Sendable {
    let id: String
    let title: String
    let type: String
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let colorData: Data?
    
    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
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
            return Color.orange
        }
        return Color(cgColor)
    }
}

// MARK: - Reminders Service (No UI Dependencies)

final class RemindersService {
    @MainActor static let shared = RemindersService()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestPermission() async throws {
        do {
            try await eventStore.requestFullAccessToReminders()
        } catch {
            throw ServiceError.permissionDenied
        }
    }
    
    func checkPermissionStatus() async -> Bool {
        return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }
    
    func getReminderLists() async throws -> [ReminderListData] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let calendars = eventStore.calendars(for: .reminder)
        return calendars.map { ReminderListData(from: $0) }
    }
    
    func getReminders(from calendarIdentifiers: [String]? = nil, includeCompleted: Bool = false) async throws -> [ReminderInfo] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let calendars: [EKCalendar]?
        if let identifiers = calendarIdentifiers {
            calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
        } else {
            calendars = nil
        }
        
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let loadedReminders = (ekReminders ?? []).compactMap { reminder -> ReminderInfo? in
                    // Filter completed reminders if not requested
                    if !includeCompleted && reminder.isCompleted {
                        return nil
                    }
                    
                    return ReminderInfo(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        notes: reminder.notes,
                        isCompleted: reminder.isCompleted,
                        priority: reminder.priority,
                        creationDate: reminder.creationDate,
                        completionDate: reminder.completionDate,
                        dueDate: reminder.dueDateComponents?.date,
                        calendarTitle: reminder.calendar.title,
                        calendarColor: reminder.calendar.cgColor
                    )
                }
                
                continuation.resume(returning: loadedReminders)
            }
        }
    }
    
    func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil, priority: Int = 0, calendarIdentifier: String? = nil) async throws -> String {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        
        if let calendarIdentifier = calendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) {
            reminder.calendar = calendar
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }
        
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            throw ServiceError.operationFailed("Failed to create reminder: \(error.localizedDescription)")
        }
    }
    
    func toggleReminderCompletion(reminderId: String) async throws -> Bool {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw ServiceError.operationFailed("Reminder not found")
        }
        
        let newCompletionState = !reminder.isCompleted
        reminder.isCompleted = newCompletionState
        reminder.completionDate = newCompletionState ? Date() : nil
        
        do {
            try eventStore.save(reminder, commit: true)
            return newCompletionState
        } catch {
            throw ServiceError.operationFailed("Failed to update reminder: \(error.localizedDescription)")
        }
    }
    
    func deleteReminder(reminderId: String) async throws {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw ServiceError.operationFailed("Reminder not found")
        }
        
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            throw ServiceError.operationFailed("Failed to delete reminder: \(error.localizedDescription)")
        }
    }
    
    func searchReminders(query: String, calendarIdentifiers: [String]? = nil) async throws -> [ReminderInfo] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try await getReminders(from: calendarIdentifiers)
        }
        
        let calendars: [EKCalendar]?
        if let identifiers = calendarIdentifiers {
            calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
        } else {
            calendars = nil
        }
        
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let searchResults = (ekReminders ?? []).compactMap { reminder -> ReminderInfo? in
                    let title = reminder.title ?? ""
                    let notes = reminder.notes ?? ""
                    
                    // Simple text search in title and notes
                    if title.localizedCaseInsensitiveContains(query) || notes.localizedCaseInsensitiveContains(query) {
                        return ReminderInfo(
                            id: reminder.calendarItemIdentifier,
                            title: reminder.title ?? "Untitled",
                            notes: reminder.notes,
                            isCompleted: reminder.isCompleted,
                            priority: reminder.priority,
                            creationDate: reminder.creationDate,
                            completionDate: reminder.completionDate,
                            dueDate: reminder.dueDateComponents?.date,
                            calendarTitle: reminder.calendar.title,
                            calendarColor: reminder.calendar.cgColor
                        )
                    }
                    return nil
                }
                
                continuation.resume(returning: searchResults)
            }
        }
    }
}