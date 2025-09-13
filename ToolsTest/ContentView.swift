//
//  ContentView.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import SwiftUI
import EventKit
import MapKit

enum ServiceCategory: String, CaseIterable, Identifiable {
    case permissions = "Permissions"
    case calendar = "Calendar"
    case capture = "Capture"
    case contacts = "Contacts"
    case location = "Location"
    case maps = "Maps"
    case reminders = "Reminders"
    case weather = "Weather"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .permissions: return "checkmark.shield"
        case .calendar: return "calendar"
        case .capture: return "camera.viewfinder"
        case .contacts: return "person.crop.circle"
        case .location: return "location"
        case .maps: return "map"
        case .reminders: return "checklist"
        case .weather: return "cloud.sun"
        }
    }
}

struct ContentView: View {
    @State private var selectedCategory: ServiceCategory? = .permissions
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
        } detail: {
            DetailView(category: selectedCategory)
        }
        .navigationTitle("Service Tester")
    }
}

struct SidebarView: View {
    @Binding var selectedCategory: ServiceCategory?
    
    var body: some View {
        List(ServiceCategory.allCases, selection: $selectedCategory) { category in
            NavigationLink(value: category) {
                Label(category.rawValue, systemImage: category.systemImage)
            }
        }
        .navigationTitle("Services")
    }
}

struct DetailView: View {
    let category: ServiceCategory?
    
    var body: some View {
        Group {
            if let category = category {
                switch category {
                case .permissions:
                    PermissionsView()
                case .calendar:
                    CalendarView()
                case .capture:
                    CaptureView()
                case .contacts:
                    ContactsView()
                case .location:
                    LocationView()
                case .maps:
                    MapsView()
                case .reminders:
                    RemindersView()
                case .weather:
                    WeatherView()
                }
            } else {
                Text("Select a service from the sidebar")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder Views

struct PermissionsView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Service Permissions")
                .font(.largeTitle)
                .padding(.bottom)
            
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Calendar",
                    icon: "calendar",
                    isAuthorized: permissionManager.calendarAuthorized,
                    onGrant: {
                        Task {
                            try? await permissionManager.requestCalendarPermission()
                        }
                    }
                )
                
                PermissionRow(
                    title: "Reminders",
                    icon: "checklist",
                    isAuthorized: permissionManager.remindersAuthorized,
                    onGrant: {
                        Task {
                            try? await permissionManager.requestRemindersPermission()
                        }
                    }
                )
                
                PermissionRow(
                    title: "Contacts",
                    icon: "person.crop.circle",
                    isAuthorized: permissionManager.contactsAuthorized,
                    onGrant: {
                        Task {
                            try? await permissionManager.requestContactsPermission()
                        }
                    }
                )
                
                PermissionRow(
                    title: "Location",
                    icon: "location",
                    isAuthorized: permissionManager.locationAuthorized,
                    onGrant: {
                        Task {
                            try? await permissionManager.requestLocationPermission()
                        }
                    }
                )
                
                PermissionRow(
                    title: "Capture",
                    icon: "camera.viewfinder",
                    isAuthorized: permissionManager.captureAuthorized,
                    onGrant: {
                        Task {
                            try? await permissionManager.requestCapturePermission()
                        }
                    }
                )
            }
            
            Spacer()
            
            Button("Refresh All") {
                Task {
                    await permissionManager.checkAllPermissions()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await permissionManager.checkAllPermissions()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isAuthorized: Bool
    let onGrant: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    onGrant()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct CalendarView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var eventTitle: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    @State private var selectedCalendarId: String?
    @State private var selectedCalendarsForEvents: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Calendar Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            if !calendarViewModel.isAuthorized {
                VStack(spacing: 12) {
                    Text("Calendar access required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Grant Calendar Access") {
                        Task {
                            await calendarViewModel.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Create Event Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create New Event")
                                .font(.headline)
                            
                            TextField("Event Title", text: $eventTitle)
                                .textFieldStyle(.roundedBorder)
                            
                            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            
                            DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            
                            if !calendarViewModel.calendars.isEmpty {
                                Picker("Calendar", selection: $selectedCalendarId) {
                                    Text("Default").tag(nil as String?)
                                    ForEach(calendarViewModel.calendars, id: \.identifier) { calendar in
                                        Text(calendar.title).tag(calendar.identifier as String?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Button("Create Event") {
                                Task {
                                    let success = await calendarViewModel.createEvent(
                                        title: eventTitle,
                                        startDate: startDate,
                                        endDate: endDate,
                                        calendarId: selectedCalendarId
                                    )
                                    if success {
                                        eventTitle = ""
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(eventTitle.isEmpty || calendarViewModel.isLoading)
                        }
                        
                        Divider()
                        
                        // Load Events Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Events")
                                .font(.headline)
                            
                            if !calendarViewModel.calendars.isEmpty {
                                Text("Select Calendars for Events:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(calendarViewModel.calendars, id: \.identifier) { calendar in
                                        Toggle(isOn: Binding(
                                            get: { selectedCalendarsForEvents.contains(calendar.identifier) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedCalendarsForEvents.insert(calendar.identifier)
                                                } else {
                                                    selectedCalendarsForEvents.remove(calendar.identifier)
                                                }
                                            }
                                        )) {
                                            HStack {
                                                Circle()
                                                    .fill(calendar.color)
                                                    .frame(width: 12, height: 12)
                                                Text(calendar.title)
                                                    .font(.body)
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            
                            Button("Load This Week's Events") {
                                Task {
                                    let now = Date()
                                    let weekFromNow = now.addingTimeInterval(7 * 24 * 60 * 60)
                                    calendarViewModel.selectedCalendarIds = selectedCalendarsForEvents
                                    await calendarViewModel.loadEvents(from: now, to: weekFromNow)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedCalendarsForEvents.isEmpty)
                            
                            if calendarViewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading...")
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = calendarViewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !selectedCalendarsForEvents.isEmpty && !calendarViewModel.events.isEmpty {
                                        let selectedCalendars = calendarViewModel.calendars.filter { 
                                            selectedCalendarsForEvents.contains($0.identifier) 
                                        }
                                        
                                        HStack {
                                            HStack(spacing: 4) {
                                                ForEach(selectedCalendars.prefix(3), id: \.identifier) { calendar in
                                                    Circle()
                                                        .fill(calendar.color)
                                                        .frame(width: 12, height: 12)
                                                }
                                            }
                                            Text("Events from \(selectedCalendars.count) calendar\(selectedCalendars.count == 1 ? "" : "s")")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.bottom, 4)
                                    }
                                    
                                    ForEach(calendarViewModel.events, id: \.identifier) { event in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(event.title)
                                                    .font(.headline)
                                                Text(event.startDate, style: .date)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 12, height: 12)
                                        }
                                        .padding()
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(8)
                                    }
                                    
                                    if calendarViewModel.events.isEmpty && !selectedCalendarsForEvents.isEmpty {
                                        Text("No events found in selected calendar\(selectedCalendarsForEvents.count == 1 ? "" : "s") for this week")
                                            .foregroundStyle(.secondary)
                                            .padding()
                                    } else if calendarViewModel.events.isEmpty {
                                        Text("Select calendars and tap 'Load This Week's Events' to see results")
                                            .foregroundStyle(.secondary)
                                            .padding()
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Calendars Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Calendars")
                                .font(.headline)
                            
                            ForEach(calendarViewModel.calendars, id: \.identifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(calendar.color)
                                        .frame(width: 16, height: 16)
                                    Text(calendar.title)
                                    Spacer()
                                    Text(calendar.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CaptureView: View {
    @StateObject private var viewModel = CaptureViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Screen Capture Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            if !viewModel.isAuthorized {
                VStack(spacing: 12) {
                    Text("Screen capture access required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Grant Screen Capture Access") {
                        Task {
                            await viewModel.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Load Sources Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Sources")
                                .font(.headline)
                            
                            Button("Refresh Sources") {
                                Task {
                                    await viewModel.loadAvailableSources()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading)
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading sources...")
                                        .foregroundStyle(.secondary)
                                }
                            } else if !viewModel.sourcesDisplayText.isEmpty {
                                Text(viewModel.sourcesDisplayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding()
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Divider()
                        
                        // Source Selection Section
                        if !viewModel.availableSources.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Sources to Capture:")
                                    .font(.headline)
                                
                                // Group by type
                                ForEach(CaptureSourceType.allCases, id: \.rawValue) { sourceType in
                                    let sourcesOfType = viewModel.availableSources.filter { $0.type == sourceType }
                                    
                                    if !sourcesOfType.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(sourceType.rawValue + "s")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                            
                                            ForEach(sourcesOfType) { source in
                                                Toggle(isOn: Binding(
                                                    get: { viewModel.selectedSources.contains(source.id) },
                                                    set: { isSelected in
                                                        if isSelected {
                                                            viewModel.selectedSources.insert(source.id)
                                                        } else {
                                                            viewModel.selectedSources.remove(source.id)
                                                        }
                                                    }
                                                )) {
                                                    HStack {
                                                        Image(systemName: iconName(for: sourceType))
                                                            .frame(width: 16)
                                                            .foregroundColor(.primary)
                                                        Text(source.name)
                                                            .font(.body)
                                                    }
                                                }
                                                .toggleStyle(.checkbox)
                                            }
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Capture Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Capture")
                                .font(.headline)
                            
                            Text(viewModel.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button("Capture Screenshots") {
                                Task {
                                    await viewModel.captureSelectedSources()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canCapture || viewModel.isLoading)
                        }
                        
                        Divider()
                        
                        // Results Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.headline)
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            } else if let capturedImage = viewModel.lastCapturedImage, let imagePath = viewModel.lastCapturedImagePath {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Screenshot captured:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    // Image preview
                                    Image(nsImage: capturedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 300)
                                        .border(Color.secondary.opacity(0.3), width: 1)
                                        .cornerRadius(8)
                                    
                                    // File path info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Saved to:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(imagePath)
                                            .font(.monospaced(.caption)())
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.selectFile(imagePath, inFileViewerRootedAtPath: "")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Text("No screenshots captured yet")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await viewModel.checkPermissionStatus()
        }
    }
    
    private func iconName(for sourceType: CaptureSourceType) -> String {
        switch sourceType {
        case .display:
            return "display"
        case .application:
            return "app.badge"
        case .window:
            return "macwindow"
        }
    }
}

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var newGivenName: String = ""
    @State private var newFamilyName: String = ""
    @State private var newPhoneNumber: String = ""
    @State private var newEmailAddress: String = ""
    @State private var showingCreateForm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Contacts Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            if !viewModel.isAuthorized {
                VStack(spacing: 12) {
                    Text("Contacts access required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Grant Contacts Access") {
                        Task {
                            await viewModel.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Search Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Contacts")
                                .font(.headline)
                            
                            HStack {
                                TextField("Search by name...", text: $viewModel.searchText)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        Task {
                                            await viewModel.searchContacts()
                                        }
                                    }
                                
                                Button("Search") {
                                    Task {
                                        await viewModel.searchContacts()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isLoading)
                                
                                Button("Load All") {
                                    Task {
                                        await viewModel.loadContacts()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isLoading)
                            }
                            
                            Text(viewModel.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        // Create Contact Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Create New Contact")
                                    .font(.headline)
                                Spacer()
                                Button(showingCreateForm ? "Hide Form" : "Show Form") {
                                    showingCreateForm.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if showingCreateForm {
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("First Name", text: $newGivenName)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("Last Name", text: $newFamilyName)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    HStack {
                                        TextField("Phone Number", text: $newPhoneNumber)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("Email Address", text: $newEmailAddress)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    Button("Create Contact") {
                                        Task {
                                            let success = await viewModel.createContact(
                                                givenName: newGivenName,
                                                familyName: newFamilyName,
                                                phoneNumber: newPhoneNumber.isEmpty ? nil : newPhoneNumber,
                                                emailAddress: newEmailAddress.isEmpty ? nil : newEmailAddress
                                            )
                                            if success {
                                                newGivenName = ""
                                                newFamilyName = ""
                                                newPhoneNumber = ""
                                                newEmailAddress = ""
                                                showingCreateForm = false
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newGivenName.isEmpty || viewModel.isLoading)
                                }
                                .padding()
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                        
                        Divider()
                        
                        // Results Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.headline)
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading contacts...")
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            } else if !viewModel.contacts.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(viewModel.contactsDisplayText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(viewModel.contacts) { contact in
                                        ContactRowView(contact: contact)
                                    }
                                }
                            } else {
                                Text("No contacts found. Try searching or loading all contacts.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await viewModel.checkPermissionStatus()
        }
    }
}

struct ContactRowView: View {
    let contact: ContactInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(contact.givenName)
                            .font(.headline)
                        Text(contact.familyName)
                            .font(.headline)
                    }
                    
                    if !contact.organizationName.isEmpty {
                        Text(contact.organizationName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            
            if !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(contact.phoneNumbers.prefix(2), id: \.self) { phone in
                        HStack {
                            Image(systemName: "phone")
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            Text(phone)
                                .font(.caption)
                        }
                    }
                    
                    ForEach(contact.emailAddresses.prefix(2), id: \.self) { email in
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.green)
                                .frame(width: 16)
                            Text(email)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}


struct RemindersView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @State private var newReminderTitle: String = ""
    @State private var newReminderNotes: String = ""
    @State private var newReminderDueDate: Date = Date()
    @State private var newReminderHasDueDate: Bool = false
    @State private var newReminderPriority: ReminderPriority = .none
    @State private var newReminderListId: String? = nil
    @State private var showingCreateForm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Reminders Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            if !viewModel.isAuthorized {
                VStack(spacing: 12) {
                    Text("Reminders access required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Grant Reminders Access") {
                        Task {
                            await viewModel.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Search and Filter Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search & Filter")
                                .font(.headline)
                            
                            HStack {
                                TextField("Search reminders...", text: $viewModel.searchText)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        Task {
                                            await viewModel.searchReminders()
                                        }
                                    }
                                
                                Button("Search") {
                                    Task {
                                        await viewModel.searchReminders()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isLoading)
                            }
                            
                            Toggle("Include completed", isOn: $viewModel.includeCompleted)
                                .onChange(of: viewModel.includeCompleted) {
                                    Task {
                                        await viewModel.searchReminders()
                                    }
                                }
                            
                            Text(viewModel.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        // Reminder Lists Selection
                        if !viewModel.reminderLists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Reminder Lists:")
                                    .font(.headline)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.reminderLists, id: \.id) { list in
                                        Toggle(isOn: Binding(
                                            get: { viewModel.selectedLists.contains(list.id) },
                                            set: { isSelected in
                                                if isSelected {
                                                    viewModel.selectedLists.insert(list.id)
                                                } else {
                                                    viewModel.selectedLists.remove(list.id)
                                                }
                                                Task {
                                                    await viewModel.searchReminders()
                                                }
                                            }
                                        )) {
                                            HStack {
                                                Circle()
                                                    .fill(list.color)
                                                    .frame(width: 12, height: 12)
                                                Text(list.title)
                                                    .font(.body)
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            
                            Divider()
                        }
                        
                        // Create Reminder Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Create New Reminder")
                                    .font(.headline)
                                Spacer()
                                Button(showingCreateForm ? "Hide Form" : "Show Form") {
                                    showingCreateForm.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if showingCreateForm {
                                VStack(spacing: 12) {
                                    TextField("Reminder title", text: $newReminderTitle)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    TextField("Notes (optional)", text: $newReminderNotes, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3)
                                    
                                    HStack {
                                        Toggle("Due date:", isOn: $newReminderHasDueDate)
                                        if newReminderHasDueDate {
                                            DatePicker("", selection: $newReminderDueDate, displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                        }
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Text("Priority:")
                                        Picker("Priority", selection: $newReminderPriority) {
                                            ForEach(ReminderPriority.allCases) { priority in
                                                Text(priority.displayName)
                                                    .foregroundColor(priority.color)
                                                    .tag(priority)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        Spacer()
                                    }
                                    
                                    if !viewModel.reminderLists.isEmpty {
                                        HStack {
                                            Text("List:")
                                            Picker("List", selection: $newReminderListId) {
                                                Text("Default").tag(nil as String?)
                                                ForEach(viewModel.reminderLists, id: \.id) { list in
                                                    Text(list.title).tag(list.id as String?)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            Spacer()
                                        }
                                    }
                                    
                                    Button("Create Reminder") {
                                        Task {
                                            let success = await viewModel.createReminder(
                                                title: newReminderTitle,
                                                notes: newReminderNotes.isEmpty ? nil : newReminderNotes,
                                                dueDate: newReminderHasDueDate ? newReminderDueDate : nil,
                                                priority: newReminderPriority,
                                                listId: newReminderListId
                                            )
                                            if success {
                                                newReminderTitle = ""
                                                newReminderNotes = ""
                                                newReminderHasDueDate = false
                                                newReminderPriority = .none
                                                newReminderListId = nil
                                                showingCreateForm = false
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newReminderTitle.isEmpty || viewModel.isLoading)
                                }
                                .padding()
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                        
                        Divider()
                        
                        // Results Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.headline)
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading reminders...")
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            } else if !viewModel.reminders.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(viewModel.remindersDisplayText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(viewModel.reminders) { reminder in
                                        ReminderRowView(reminder: reminder, viewModel: viewModel)
                                    }
                                }
                            } else {
                                Text("No reminders found. Select lists and search or create a new reminder.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await viewModel.checkPermissionStatus()
        }
    }
}

struct ReminderRowView: View {
    let reminder: ReminderInfo
    let viewModel: RemindersViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    Task {
                        await viewModel.toggleReminderCompletion(reminderId: reminder.id)
                    }
                }) {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.isCompleted ? .green : .primary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(reminder.title)
                            .font(.headline)
                            .strikethrough(reminder.isCompleted)
                            .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                        
                        if reminder.priority > 0 {
                            priorityIndicator(for: reminder.priority)
                        }
                        
                        Spacer()
                        
                        Button("Delete") {
                            Task {
                                await viewModel.deleteReminder(reminderId: reminder.id)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                    
                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color(reminder.calendarColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)))
                            .frame(width: 8, height: 8)
                        Text(reminder.calendarTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let dueDate = reminder.dueDate {
                            Spacer()
                            Text("Due: \(dueDate, style: .date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func priorityIndicator(for priority: Int) -> some View {
        let color: Color
        let text: String
        
        switch priority {
        case 1:
            color = .red
            text = "!!!"
        case 5:
            color = .orange
            text = "!!"
        case 9:
            color = .blue
            text = "!"
        default:
            color = .primary
            text = ""
        }
        
        return Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(color)
    }
}

struct LocationView: View {
    @StateObject private var viewModel = LocationViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Location Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            if !viewModel.isAuthorized {
                VStack(spacing: 12) {
                    Text("Location access required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Grant Location Access") {
                        Task {
                            await viewModel.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Current Location Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Location")
                            .font(.headline)
                        
                        Button("Get Current Location") {
                            Task {
                                await viewModel.getCurrentLocationWithAddress()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                    }
                    
                    Divider()
                    
                    // Results Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                        
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Getting location...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        } else if !viewModel.locationDisplayText.isEmpty {
                            Text(viewModel.locationDisplayText)
                                .font(.monospaced(.body)())
                                .padding()
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        } else {
                            Text("Tap 'Get Current Location' to see results")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MapsView: View {
    @StateObject private var viewModel = MapsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Maps Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            Picker("Feature", selection: $selectedTab) {
                Text("Search Places").tag(0)
                Text("Nearby Search").tag(1)
                Text("Directions").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.bottom)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case 0:
                        PlaceSearchView(viewModel: viewModel)
                    case 1:
                        NearbySearchView(viewModel: viewModel)
                    case 2:
                        DirectionsView(viewModel: viewModel)
                    default:
                        EmptyView()
                    }
                    
                    Divider()
                    
                    // Results Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                        
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            // Show search results or directions based on selected tab
                            if selectedTab == 2 {
                                DirectionsResultsView(viewModel: viewModel)
                            } else {
                                SearchResultsView(viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlaceSearchView: View {
    @ObservedObject var viewModel: MapsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Places")
                .font(.headline)
            
            HStack {
                TextField("Search for places...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.searchPlaces()
                        }
                    }
                
                Button("Search") {
                    Task {
                        await viewModel.searchPlaces()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading || viewModel.searchText.isEmpty)
            }
        }
    }
}

struct NearbySearchView: View {
    @ObservedObject var viewModel: MapsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Nearby (Current Location)")
                .font(.headline)
            
            Text("Find places near your current location. Location permission will be requested if needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Category:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(MKPointOfInterestCategory.availableCategories, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button("Search Nearby") {
                Task {
                    await viewModel.searchNearby()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
    }
}

struct DirectionsView: View {
    @ObservedObject var viewModel: MapsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get Directions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("From:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("Starting location", text: $viewModel.fromAddress)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("To:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("Destination", text: $viewModel.toAddress)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Transport Type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Transport", selection: $viewModel.selectedTransportType) {
                    Text("Driving").tag(MKDirectionsTransportType.automobile)
                    Text("Walking").tag(MKDirectionsTransportType.walking)
                    Text("Transit").tag(MKDirectionsTransportType.transit)
                }
                .pickerStyle(.segmented)
            }
            
            Button("Get Directions") {
                Task {
                    await viewModel.getDirections()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading || viewModel.fromAddress.isEmpty || viewModel.toAddress.isEmpty)
        }
    }
}

struct SearchResultsView: View {
    @ObservedObject var viewModel: MapsViewModel
    
    var body: some View {
        if !viewModel.searchResults.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.searchResultsDisplayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                ForEach(viewModel.searchResults) { result in
                    SearchResultRowView(result: result)
                }
            }
        } else {
            Text("No results to display. Try searching for places or nearby locations.")
                .foregroundStyle(.secondary)
        }
    }
}

struct DirectionsResultsView: View {
    @ObservedObject var viewModel: MapsViewModel
    
    var body: some View {
        if let directionsText = viewModel.directionsDisplayText {
            VStack(alignment: .leading, spacing: 8) {
                Text("Route Information:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(directionsText)
                    .font(.monospaced(.body)())
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
        } else {
            Text("No directions to display. Enter addresses and get directions.")
                .foregroundStyle(.secondary)
        }
    }
}

struct SearchResultRowView: View {
    let result: MapSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.headline)
                    
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    Text("\(result.coordinate.latitude, specifier: "%.4f"), \(result.coordinate.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let phoneNumber = result.phoneNumber {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.green)
                            .frame(width: 16)
                        Text(phoneNumber)
                            .font(.caption)
                    }
                }
                
                if let url = result.url {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Text(url.absoluteString)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WeatherView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var latitude: String = "37.7749"
    @State private var longitude: String = "-122.4194"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weather Testing")
                .font(.largeTitle)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Location Coordinates")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Latitude")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("37.7749", text: $latitude)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Longitude")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("-122.4194", text: $longitude)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Button("Get Weather") {
                    if let lat = Double(latitude), let lon = Double(longitude) {
                        Task {
                            await viewModel.getCurrentWeather(latitude: lat, longitude: lon)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Results")
                    .font(.headline)
                
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading weather data...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                } else if !viewModel.currentWeatherDisplayText.isEmpty {
                    Text(viewModel.currentWeatherDisplayText)
                        .font(.monospaced(.body)())
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                } else {
                    Text("Enter coordinates and tap 'Get Weather' to see results")
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MKDirectionsTransportType: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

#Preview {
    ContentView()
}
