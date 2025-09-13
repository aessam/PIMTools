//
//  LocationViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - ViewModel (SwiftUI Bridge Layer)

@MainActor
final class LocationViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var currentLocation: LocationData?
    @Published var currentAddress: AddressData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationService: LocationService = LocationService.shared
    
    init() {
        Task {
            await checkPermissionStatus()
        }
    }
    
    // MARK: - Actions
    
    func requestPermission() async {
        errorMessage = nil
        
        do {
            try await locationService.requestPermission()
            await checkPermissionStatus()
        } catch {
            errorMessage = "Failed to request permission: \(error.localizedDescription)"
        }
    }
    
    func checkPermissionStatus() async {
        isAuthorized = await locationService.checkPermissionStatus()
    }
    
    func getCurrentLocation() async {
        guard isAuthorized else {
            errorMessage = "Location permission not granted"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            currentLocation = try await locationService.getCurrentLocation()
        } catch {
            errorMessage = "Failed to get location: \(error.localizedDescription)"
            currentLocation = nil
        }
        
        isLoading = false
    }
    
    func reverseGeocodeCurrentLocation() async {
        guard let location = currentLocation else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            currentAddress = try await locationService.reverseGeocode(
                latitude: location.latitude,
                longitude: location.longitude
            )
        } catch {
            errorMessage = "Geocoding failed: \(error.localizedDescription)"
            currentAddress = nil
        }
        
        isLoading = false
    }
    
    func getCurrentLocationWithAddress() async {
        await getCurrentLocation()
        if currentLocation != nil {
            await reverseGeocodeCurrentLocation()
        }
    }
    
    // MARK: - Computed Properties for UI
    
    var locationDisplayText: String {
        guard let location = currentLocation else { return "" }
        
        var text = """
        Latitude: \(location.latitude)
        Longitude: \(location.longitude)
        Altitude: \(location.altitude) m
        Accuracy: ±\(location.horizontalAccuracy) m
        Timestamp: \(location.timestamp)
        """
        
        if let address = currentAddress {
            text += "\n\nAddress: \(address.formattedAddress)"
        }
        
        return text
    }
}
