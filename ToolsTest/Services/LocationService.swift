//
//  LocationService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import CoreLocation

// MARK: - Data Models

struct LocationData: Sendable, Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let timestamp: Date
}

struct AddressData: Sendable, Codable {
    let formattedAddress: String
    let streetNumber: String?
    let streetName: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let timeZone: String?
}

// MARK: - Location Service (No UI Dependencies)

final class LocationService: NSObject {
    @MainActor static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<LocationData, Error>?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() async throws {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedAlways:
            return
        case .denied, .restricted:
            throw ServiceError.permissionDenied
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                locationManager.requestAlwaysAuthorization()
            }
        @unknown default:
            throw ServiceError.notAvailable
        }
    }
    
    func checkPermissionStatus() async -> Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedAlways
    }
    
    func getCurrentLocation() async throws -> LocationData {
        guard await checkPermissionStatus() else {
            throw ServiceError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> AddressData {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw ServiceError.operationFailed("No placemark found")
        }
        
        let addressComponents = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ].compactMap { $0 }
        
        return AddressData(
            formattedAddress: addressComponents.joined(separator: ", "),
            streetNumber: placemark.subThoroughfare,
            streetName: placemark.thoroughfare,
            city: placemark.locality,
            state: placemark.administrativeArea,
            postalCode: placemark.postalCode,
            country: placemark.country,
            timeZone: placemark.timeZone?.identifier
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
        
        locationContinuation?.resume(returning: locationData)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            authorizationContinuation?.resume(returning: ())
        case .denied, .restricted:
            authorizationContinuation?.resume(throwing: ServiceError.permissionDenied)
        case .notDetermined:
            return // Still waiting for user response
        @unknown default:
            authorizationContinuation?.resume(throwing: ServiceError.notAvailable)
        }
        authorizationContinuation = nil
    }
}