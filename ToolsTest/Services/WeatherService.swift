//
//  WeatherService.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Data Models

struct WeatherData: Sendable, Codable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Double
    let pressure: Double
    let windSpeed: Double
    let windDirection: Double
    let uvIndex: Int
    let cloudCover: Double
    let condition: String
    let symbolName: String
    let isDaylight: Bool
    let timestamp: Date
}

struct HourlyWeatherData: Sendable, Codable {
    let date: Date
    let temperature: Double
    let apparentTemperature: Double
    let precipitationChance: Double
    let precipitationAmount: Double
    let windSpeed: Double
    let condition: String
    let symbolName: String
}

struct DailyWeatherData: Sendable, Codable {
    let date: Date
    let highTemperature: Double
    let lowTemperature: Double
    let precipitationChance: Double
    let precipitationAmount: Double
    let condition: String
    let symbolName: String
    let sunrise: Date?
    let sunset: Date?
}

// MARK: - Weather Service (No UI Dependencies)

final class WeatherService {
    @MainActor static let shared = WeatherService()
    
    private let weatherService = WeatherKit.WeatherService.shared
    
    private init() {}
    
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        // Add debug logging
        print("🌤️ Requesting weather for location: \(location)")
        
        let weather: WeatherKit.CurrentWeather
        do {
            weather = try await weatherService.weather(for: location, including: .current)
            print("✅ Weather request successful")
        } catch {
            print("❌ Weather request failed: \(error)")
            throw error
        }
        
        return WeatherData(
            temperature: weather.temperature.value,
            apparentTemperature: weather.apparentTemperature.value,
            humidity: weather.humidity,
            pressure: weather.pressure.value,
            windSpeed: weather.wind.speed.value,
            windDirection: weather.wind.direction.value,
            uvIndex: weather.uvIndex.value,
            cloudCover: weather.cloudCover,
            condition: weather.condition.description,
            symbolName: weather.symbolName,
            isDaylight: weather.isDaylight,
            timestamp: Date()
        )
    }
    
    func getHourlyForecast(latitude: Double, longitude: Double, hours: Int = 24) async throws -> [HourlyWeatherData] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let weather = try await weatherService.weather(for: location, including: .hourly)
        
        return weather.forecast.prefix(hours).map { hourWeather in
            HourlyWeatherData(
                date: hourWeather.date,
                temperature: hourWeather.temperature.value,
                apparentTemperature: hourWeather.apparentTemperature.value,
                precipitationChance: hourWeather.precipitationChance,
                precipitationAmount: hourWeather.precipitationAmount.value,
                windSpeed: hourWeather.wind.speed.value,
                condition: hourWeather.condition.description,
                symbolName: hourWeather.symbolName
            )
        }
    }
    
    func getDailyForecast(latitude: Double, longitude: Double, days: Int = 7) async throws -> [DailyWeatherData] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let weather = try await weatherService.weather(for: location, including: .daily)
        
        return weather.forecast.prefix(days).map { dayWeather in
            return DailyWeatherData(
                date: dayWeather.date,
                highTemperature: dayWeather.highTemperature.value,
                lowTemperature: dayWeather.lowTemperature.value,
                precipitationChance: dayWeather.precipitationChance,
                precipitationAmount: dayWeather.precipitationAmountByType.mixed.value,
                condition: dayWeather.condition.description,
                symbolName: dayWeather.symbolName,
                sunrise: dayWeather.sun.sunrise,
                sunset: dayWeather.sun.sunset
            )
        }
    }
}

