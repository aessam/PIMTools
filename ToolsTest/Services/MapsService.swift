//
//  MapsService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/13/25.
//

import Foundation
import MapKit
import CoreLocation
import os.log

// MARK: - Data Models

struct MapSearchResult: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let placemark: CLPlacemark?
    let phoneNumber: String?
    let url: URL?
}

struct DirectionsResult: Sendable {
    let route: MKRoute
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let transportType: MKDirectionsTransportType
}

struct GeocodeResult: Sendable {
    let coordinate: CLLocationCoordinate2D
    let placemark: CLPlacemark?
}

// MARK: - Maps Service (No UI Dependencies)

final class MapsService {
    @MainActor static let shared = MapsService()
    
    private let logger = Logger(subsystem: "com.toolstest.maps", category: "MapsService")
    
    private init() {}
    
    func searchPlaces(query: String, region: MKCoordinateRegion? = nil) async throws -> [MapSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let region = region {
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            return response.mapItems.map { mapItem in
                MapSearchResult(
                    name: mapItem.name ?? "Unknown",
                    subtitle: mapItem.placemark.title ?? "",
                    coordinate: mapItem.placemark.coordinate,
                    placemark: mapItem.placemark,
                    phoneNumber: mapItem.phoneNumber,
                    url: mapItem.url
                )
            }
            
        } catch {
            throw ServiceError.operationFailed("Search failed: \(error.localizedDescription)")
        }
    }
    
    func searchNearby(category: MKPointOfInterestCategory, radius: CLLocationDistance = 5000) async throws -> [MapSearchResult] {
        logger.info("Starting nearby search for category: \(category.rawValue)")
        
        // Get current location
        let locationService = LocationService.shared
        
        let isAuthorized = await locationService.checkPermissionStatus()
        logger.info("Location authorization status: \(isAuthorized)")
        
        guard isAuthorized else {
            logger.error("Location permission not granted")
            throw ServiceError.permissionDenied
        }
        
        logger.info("Requesting current location...")
        let locationData = try await locationService.getCurrentLocation()
        
        let coordinate = CLLocationCoordinate2D(
            latitude: locationData.latitude,
            longitude: locationData.longitude
        )
        logger.info("Current location: \(coordinate.latitude), \(coordinate.longitude)")
        
        // Try POI-based search first
        var response: MKLocalSearch.Response?
        var searchError: Error?
        
        do {
            let request = MKLocalSearch.Request()
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
            
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radius * 2,
                longitudinalMeters: radius * 2
            )
            request.region = region
            logger.info("Search region: center(\(region.center.latitude), \(region.center.longitude)), span(\(region.span.latitudeDelta), \(region.span.longitudeDelta))")
            logger.info("Trying POI filter for category: \(category.rawValue)")
            
            let search = MKLocalSearch(request: request)
            response = try await search.start()
            logger.info("POI search completed. Found \(response?.mapItems.count ?? 0) items")
            
        } catch {
            searchError = error
            logger.warning("POI search failed: \(error.localizedDescription). Trying natural language fallback...")
            
            // Fallback to natural language search
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = categoryToSearchTerm(category)
            
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radius * 2,
                longitudinalMeters: radius * 2
            )
            request.region = region
            logger.info("Using natural language query: \(request.naturalLanguageQuery ?? "nil")")
            
            let search = MKLocalSearch(request: request)
            response = try await search.start()
            logger.info("Natural language search completed. Found \(response?.mapItems.count ?? 0) items")
        }
        
        guard let finalResponse = response else {
            // Check for specific MKError codes
            if let mkError = searchError as? MKError {
                logger.error("MKError code: \(mkError.code.rawValue)")
                switch mkError.code {
                case .placemarkNotFound:
                    throw ServiceError.operationFailed("No places found in this area for \(category.rawValue)")
                case .directionsNotFound:
                    throw ServiceError.operationFailed("Search service unavailable")
                case .serverFailure:
                    throw ServiceError.operationFailed("Maps server error - try again later")
                default:
                    throw ServiceError.operationFailed("Search failed: \(mkError.localizedDescription) (Code: \(mkError.code.rawValue))")
                }
            } else {
                throw searchError ?? ServiceError.operationFailed("No search response")
            }
        }
        
        let results = finalResponse.mapItems.map { mapItem in
            logger.debug("Found place: \(mapItem.name ?? "Unknown") at \(mapItem.placemark.coordinate.latitude), \(mapItem.placemark.coordinate.longitude)")
            return MapSearchResult(
                name: mapItem.name ?? "Unknown",
                subtitle: mapItem.placemark.title ?? "",
                coordinate: mapItem.placemark.coordinate,
                placemark: mapItem.placemark,
                phoneNumber: mapItem.phoneNumber,
                url: mapItem.url
            )
        }
        
        logger.info("Nearby search completed")
        return results
    }
    
    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) async throws -> DirectionsResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        
        // For transit, request multiple route options
        if transportType == .transit {
            request.requestsAlternateRoutes = true
        }
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                if transportType == .transit {
                    throw ServiceError.operationFailed("No transit routes found. Transit directions may not be available in this area.")
                } else {
                    throw ServiceError.operationFailed("No routes found for \(formatTransportType(transportType))")
                }
            }
            
            return DirectionsResult(
                route: route,
                distance: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                transportType: transportType
            )
            
        } catch let error as ServiceError {
            throw error
        } catch {
            if transportType == .transit {
                throw ServiceError.operationFailed("Transit directions failed: \(error.localizedDescription). Transit may not be available in this area.")
            } else {
                throw ServiceError.operationFailed("\(formatTransportType(transportType)) directions failed: \(error.localizedDescription)")
            }
        }
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                throw ServiceError.operationFailed("No placemark found for this location")
            }
            return placemark
        } catch {
            throw ServiceError.operationFailed("Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
    
    func geocodeAddress(address: String) async throws -> GeocodeResult {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let placemark = placemarks.first,
                  let coordinate = placemark.location?.coordinate else {
                throw ServiceError.operationFailed("Could not find location for this address")
            }
            
            return GeocodeResult(coordinate: coordinate, placemark: placemark)
        } catch {
            throw ServiceError.operationFailed("Geocoding failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTransportType(_ transportType: MKDirectionsTransportType) -> String {
        switch transportType {
        case .automobile:
            return "driving"
        case .walking:
            return "walking"
        case .transit:
            return "transit"
        default:
            return "unknown"
        }
    }
    
    private func categoryToSearchTerm(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant:
            return "restaurants"
        case .gasStation:
            return "gas stations"
        case .hospital:
            return "hospitals"
        case .hotel:
            return "hotels"
        case .pharmacy:
            return "pharmacies"
        case .store:
            return "stores"
        case .bakery:
            return "bakeries"
        case .bank:
            return "banks"
        case .cafe:
            return "cafes"
        case .carRental:
            return "car rental"
        case .evCharger:
            return "EV charging stations"
        case .fireStation:
            return "fire stations"
        case .library:
            return "libraries"
        case .museum:
            return "museums"
        case .nightlife:
            return "bars nightlife"
        case .park:
            return "parks"
        case .parking:
            return "parking"
        case .police:
            return "police stations"
        case .postOffice:
            return "post offices"
        case .school:
            return "schools"
        case .stadium:
            return "stadiums"
        case .theater:
            return "theaters"
        case .university:
            return "universities"
        default:
            return category.rawValue
        }
    }
}
