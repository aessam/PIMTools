# ToolsTest

A SwiftUI application demonstrating modular system service integrations for macOS. The Services directory contains standalone modules that can be integrated into other projects, MCPs, or command-line tools.

## Architecture

The project follows a modular architecture:

- **Services**: Core business logic with no UI dependencies
- **ViewModels**: SwiftUI presentation layer
- **Utils**: Shared utilities and error handling
- **Views**: SwiftUI interface components

## Services

The `ToolsTest/Services/` directory contains reusable service modules:

### LocationService
Location tracking and reverse geocoding.

```swift
let location = try await LocationService.shared.getCurrentLocation()
let address = try await LocationService.shared.reverseGeocode(
    latitude: location.latitude,
    longitude: location.longitude
)
```

### WeatherService
Weather data using Apple's WeatherKit.

```swift
let weather = try await WeatherService.shared.getCurrentWeather(
    latitude: 37.7749,
    longitude: -122.4194
)
```

### ContactsService
System address book integration.

```swift
let contacts = try await ContactsService.shared.getContacts(limit: 50)
```

### CalendarService
Calendar and event management.

```swift
let events = try await CalendarService.shared.getEvents(
    from: Date(),
    to: futureDate
)
```

### RemindersService
Task and reminder management.

```swift
let lists = try await RemindersService.shared.getReminderLists()
```

### MapsService
Location search and mapping.

```swift
let results = try await MapsService.shared.searchLocation(query: "restaurants")
```

### CaptureService
Screen capture functionality.

## Integration Examples

### MCP Server
```swift
import Foundation

class LocationMCP {
    func getCurrentLocation() async throws -> LocationData {
        return try await LocationService.shared.getCurrentLocation()
    }
}
```

### Command Line Tool
```swift
#!/usr/bin/env swift

@main
struct LocationCLI {
    static func main() async throws {
        let location = try await LocationService.shared.getCurrentLocation()
        print("Location: \(location.latitude), \(location.longitude)")
    }
}
```

### SwiftUI App
Copy the needed service files and ServiceError.swift to your project.

## Permission Management

Centralized permission handling via PermissionManager:

```swift
await PermissionManager.shared.checkAllPermissions()
try await PermissionManager.shared.requestLocationPermission()
```

## Error Handling

Standardized error handling with ServiceError:

```swift
enum ServiceError: LocalizedError {
    case permissionDenied
    case notAvailable
    case operationFailed(String)
}
```

## Requirements

- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

## Setup

```bash
git clone <repository-url>
cd ToolsTest
open ToolsTest.xcodeproj
```

## Usage

Each service can be used independently by copying the relevant files to your project. All services handle their own permissions and provide async/await interfaces.