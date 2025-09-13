//
//  MapsViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
final class MapsViewModel: ObservableObject {
    @Published var searchResults: [MapSearchResult] = []
    @Published var directionsResult: DirectionsResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedTransportType: MKDirectionsTransportType = .automobile
    @Published var fromAddress = ""
    @Published var toAddress = ""
    @Published var selectedCategory: MKPointOfInterestCategory = .restaurant
    
    private let mapsService: MapsService = MapsService.shared
    
    func searchPlaces() async {
        isLoading = true
        errorMessage = nil
        
        do {
            searchResults = try await mapsService.searchPlaces(query: searchText)
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isLoading = false
    }
    
    func searchNearby() async {
        isLoading = true
        errorMessage = nil
        
        do {
            searchResults = try await mapsService.searchNearby(category: selectedCategory)
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isLoading = false
    }
    
    func getDirections() async {
        guard !fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !toAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter both from and to addresses"
            return
        }
        
        isLoading = true
        errorMessage = nil
        directionsResult = nil
        
        do {
            let fromResult = try await mapsService.geocodeAddress(address: fromAddress)
            let toResult = try await mapsService.geocodeAddress(address: toAddress)
            
            directionsResult = try await mapsService.getDirections(
                from: fromResult.coordinate,
                to: toResult.coordinate,
                transportType: selectedTransportType
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        do {
            let placemark = try await mapsService.reverseGeocode(coordinate: coordinate)
            return formatPlacemark(placemark)
        } catch {
            return nil
        }
    }
    
    var searchResultsDisplayText: String {
        guard !searchResults.isEmpty else { return "No results found" }
        return "\(searchResults.count) result\(searchResults.count == 1 ? "" : "s") found"
    }
    
    var directionsDisplayText: String? {
        guard let directions = directionsResult else { return nil }
        
        let distanceText = formatDistance(directions.distance)
        let timeText = formatTime(directions.expectedTravelTime)
        let transportText = formatTransportType(directions.transportType)
        
        return "Distance: \(distanceText)\nEstimated time: \(timeText)\nTransport: \(transportText)"
    }
    
    private func formatPlacemark(_ placemark: CLPlacemark?) -> String? {
        guard let placemark = placemark else { return nil }
        
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        return formatter.string(fromDistance: distance)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? "\(Int(timeInterval / 60)) min"
    }
    
    private func formatTransportType(_ transportType: MKDirectionsTransportType) -> String {
        switch transportType {
        case .automobile:
            return "Driving"
        case .walking:
            return "Walking"
        case .transit:
            return "Transit"
        default:
            return "Unknown"
        }
    }
}

extension MKDirectionsTransportType: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension MKPointOfInterestCategory {
    static let availableCategories: [MKPointOfInterestCategory] = [
        .restaurant,
        .gasStation,
        .hospital,
        .hotel,
        .pharmacy,
        .store,
        .bakery,
        .bank,
        .cafe,
        .carRental,
        .evCharger,
        .fireStation,
        .library,
        .museum,
        .nightlife,
        .park,
        .parking,
        .police,
        .postOffice,
        .school,
        .stadium,
        .theater,
        .university
    ]
    
    var displayName: String {
        switch self {
        case .restaurant: return "Restaurants"
        case .gasStation: return "Gas Stations"
        case .hospital: return "Hospitals"
        case .hotel: return "Hotels"
        case .pharmacy: return "Pharmacies"
        case .store: return "Stores"
        case .bakery: return "Bakeries"
        case .bank: return "Banks"
        case .cafe: return "Cafes"
        case .carRental: return "Car Rentals"
        case .evCharger: return "EV Chargers"
        case .fireStation: return "Fire Stations"
        case .library: return "Libraries"
        case .museum: return "Museums"
        case .nightlife: return "Nightlife"
        case .park: return "Parks"
        case .parking: return "Parking"
        case .police: return "Police Stations"
        case .postOffice: return "Post Offices"
        case .school: return "Schools"
        case .stadium: return "Stadiums"
        case .theater: return "Theaters"
        case .university: return "Universities"
        default: return rawValue.capitalized
        }
    }
}
