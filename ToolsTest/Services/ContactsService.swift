//
//  ContactsService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import Contacts

// MARK: - Data Models

struct ContactInfo: Identifiable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let postalAddresses: [String]
    
    var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Contacts Service (No UI Dependencies)

final class ContactsService {
    @MainActor static let shared = ContactsService()
    
    private let contactStore = CNContactStore()
    
    private init() {}
    
    func requestPermission() async throws {
        do {
            try await contactStore.requestAccess(for: .contacts)
        } catch {
            throw ServiceError.permissionDenied
        }
    }
    
    func checkPermissionStatus() async -> Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    func getContacts(limit: Int = 100) async throws -> [ContactInfo] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) { @MainActor in
                let keys = [
                    CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactOrganizationNameKey,
                    CNContactPhoneNumbersKey,
                    CNContactEmailAddressesKey,
                    CNContactPostalAddressesKey
                ] as [CNKeyDescriptor]
                
                let request = CNContactFetchRequest(keysToFetch: keys)
                request.sortOrder = .givenName
                
                var fetchedContacts: [ContactInfo] = []
                
                do {
                    try self.contactStore.enumerateContacts(with: request) { contact, stop in
                        let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                        let emailAddresses = contact.emailAddresses.map { $0.value as String }
                        let postalAddresses = contact.postalAddresses.map { 
                            CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)
                        }
                        
                        let contactInfo = ContactInfo(
                            id: contact.identifier,
                            givenName: contact.givenName,
                            familyName: contact.familyName,
                            organizationName: contact.organizationName,
                            phoneNumbers: phoneNumbers,
                            emailAddresses: emailAddresses,
                            postalAddresses: postalAddresses
                        )
                        
                        fetchedContacts.append(contactInfo)
                        
                        if fetchedContacts.count >= limit {
                            stop.pointee = true
                        }
                    }
                    
                    continuation.resume(returning: fetchedContacts)
                    
                } catch {
                    continuation.resume(throwing: ServiceError.operationFailed("Failed to load contacts: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    func searchContacts(query: String, limit: Int = 50) async throws -> [ContactInfo] {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactPostalAddressesKey
        ] as [CNKeyDescriptor]
        
        let predicate = CNContact.predicateForContacts(matchingName: query)
        
        do {
            let fetchedContacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
            
            return Array(fetchedContacts.prefix(limit).map { contact in
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                let emailAddresses = contact.emailAddresses.map { $0.value as String }
                let postalAddresses = contact.postalAddresses.map { 
                    CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)
                }
                
                return ContactInfo(
                    id: contact.identifier,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    organizationName: contact.organizationName,
                    phoneNumbers: phoneNumbers,
                    emailAddresses: emailAddresses,
                    postalAddresses: postalAddresses
                )
            })
            
        } catch {
            throw ServiceError.operationFailed("Failed to search contacts: \(error.localizedDescription)")
        }
    }
    
    func createContact(givenName: String, familyName: String, phoneNumber: String? = nil, emailAddress: String? = nil) async throws -> String {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        
        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
            let phone = CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phoneNumber))
            contact.phoneNumbers = [phone]
        }
        
        if let emailAddress = emailAddress, !emailAddress.isEmpty {
            let email = CNLabeledValue(label: CNLabelHome, value: emailAddress as NSString)
            contact.emailAddresses = [email]
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        do {
            try contactStore.execute(saveRequest)
            return contact.identifier
        } catch {
            throw ServiceError.operationFailed("Failed to create contact: \(error.localizedDescription)")
        }
    }
}