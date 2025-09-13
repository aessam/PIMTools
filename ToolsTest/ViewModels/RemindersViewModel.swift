//
//  RemindersViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import SwiftUI
import EventKit
import Combine

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var reminderLists: [ReminderListData] = []
    @Published var reminders: [ReminderInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedLists: Set<String> = []
    @Published var includeCompleted = false
    
    private let remindersService: RemindersService = RemindersService.shared
    
    init() {
        Task {
            await checkPermissionStatus()
        }
    }
    
    func requestPermission() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await remindersService.requestPermission()
            await checkPermissionStatus()
        } catch {
            errorMessage = "Failed to request permission: \(error.localizedDescription)"
            isAuthorized = false
        }
        
        isLoading = false
    }
    
    func checkPermissionStatus() async {
        isAuthorized = await remindersService.checkPermissionStatus()
        if isAuthorized {
            await loadReminderLists()
        }
    }
    
    func loadReminderLists() async {
        isLoading = true
        errorMessage = nil
        
        do {
            reminderLists = try await remindersService.getReminderLists()
        } catch {
            errorMessage = "Failed to load reminder lists: \(error.localizedDescription)"
            reminderLists = []
        }
        
        isLoading = false
    }
    
    func loadReminders() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let calendarIds = selectedLists.isEmpty ? nil : Array(selectedLists)
            reminders = try await remindersService.getReminders(
                from: calendarIds,
                includeCompleted: includeCompleted
            )
        } catch {
            errorMessage = "Failed to load reminders: \(error.localizedDescription)"
            reminders = []
        }
        
        isLoading = false
    }
    
    func searchReminders() async {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadReminders()
        } else {
            isLoading = true
            errorMessage = nil
            
            do {
                let calendarIds = selectedLists.isEmpty ? nil : Array(selectedLists)
                reminders = try await remindersService.searchReminders(
                    query: searchText,
                    calendarIdentifiers: calendarIds
                )
            } catch {
                errorMessage = "Failed to search reminders: \(error.localizedDescription)"
                reminders = []
            }
            
            isLoading = false
        }
    }
    
    func createReminder(title: String, notes: String?, dueDate: Date?, priority: ReminderPriority, listId: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await remindersService.createReminder(
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority.rawValue,
                calendarIdentifier: listId
            )
            await searchReminders()
            return true
        } catch {
            errorMessage = "Failed to create reminder: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func toggleReminderCompletion(reminderId: String) async {
        do {
            _ = try await remindersService.toggleReminderCompletion(reminderId: reminderId)
            await searchReminders()
        } catch {
            errorMessage = "Failed to update reminder: \(error.localizedDescription)"
        }
    }
    
    func deleteReminder(reminderId: String) async {
        do {
            try await remindersService.deleteReminder(reminderId: reminderId)
            await searchReminders()
        } catch {
            errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
        }
    }
    
    var remindersDisplayText: String {
        guard !reminders.isEmpty else { return "No reminders found" }
        let completedCount = reminders.filter(\.isCompleted).count
        let pendingCount = reminders.count - completedCount
        return "\(reminders.count) reminder\(reminders.count == 1 ? "" : "s") (\(pendingCount) pending, \(completedCount) completed)"
    }
    
    var statusText: String {
        if !isAuthorized {
            return "Permission required"
        } else if isLoading {
            return "Loading reminders..."
        } else if reminderLists.isEmpty {
            return "No reminder lists found"
        } else if selectedLists.isEmpty {
            return "Select reminder lists"
        } else {
            return "Ready - \(selectedLists.count) list\(selectedLists.count == 1 ? "" : "s") selected"
        }
    }
}

enum ReminderPriority: Int, CaseIterable, Identifiable {
    case none = 0
    case high = 1
    case medium = 5
    case low = 9
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .primary
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}