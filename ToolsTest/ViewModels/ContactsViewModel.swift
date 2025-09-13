//
//  ContactsViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var contacts: [ContactInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    
    private let contactsService: ContactsService = ContactsService.shared
    
    init() {
        Task {
            await checkPermissionStatus()
        }
    }
    
    func requestPermission() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await contactsService.requestPermission()
            await checkPermissionStatus()
        } catch {
            errorMessage = "Failed to request permission: \(error.localizedDescription)"
            isAuthorized = false
        }
        
        isLoading = false
    }
    
    func checkPermissionStatus() async {
        isAuthorized = await contactsService.checkPermissionStatus()
        if isAuthorized {
            await loadContacts()
        }
    }
    
    func loadContacts(limit: Int = 100) async {
        isLoading = true
        errorMessage = nil
        
        do {
            contacts = try await contactsService.getContacts(limit: limit)
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            contacts = []
        }
        
        isLoading = false
    }
    
    func searchContacts() async {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadContacts()
        } else {
            isLoading = true
            errorMessage = nil
            
            do {
                contacts = try await contactsService.searchContacts(query: searchText)
            } catch {
                errorMessage = "Failed to search contacts: \(error.localizedDescription)"
                contacts = []
            }
            
            isLoading = false
        }
    }
    
    func createContact(givenName: String, familyName: String, phoneNumber: String?, emailAddress: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await contactsService.createContact(
                givenName: givenName,
                familyName: familyName,
                phoneNumber: phoneNumber,
                emailAddress: emailAddress
            )
            await searchContacts()
            return true
        } catch {
            errorMessage = "Failed to create contact: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    var contactsDisplayText: String {
        guard !contacts.isEmpty else { return "No contacts found" }
        return "\(contacts.count) contact\(contacts.count == 1 ? "" : "s") found"
    }
    
    var statusText: String {
        if !isAuthorized {
            return "Permission required"
        } else if isLoading {
            return "Loading contacts..."
        } else if contacts.isEmpty {
            return "No contacts loaded"
        } else {
            return "Ready - \(contacts.count) contact\(contacts.count == 1 ? "" : "s")"
        }
    }
}