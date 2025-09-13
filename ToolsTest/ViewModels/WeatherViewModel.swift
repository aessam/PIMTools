//
//  WeatherViewModel.swift
//  ToolsTest
//
//  Created by Ahmed Essam on 9/12/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - ViewModel (SwiftUI Bridge Layer)

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var dailyForecast: [DailyWeatherData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let weatherService: WeatherService = WeatherService.shared
    
    // MARK: - Actions
    
    func getCurrentWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil
        
        do {
            currentWeather = try await weatherService.getCurrentWeather(latitude: latitude, longitude: longitude)
        } catch {
            errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
            currentWeather = nil
        }
        
        isLoading = false
    }
    
    func getHourlyForecast(latitude: Double, longitude: Double, hours: Int = 24) async {
        isLoading = true
        errorMessage = nil
        
        do {
            hourlyForecast = try await weatherService.getHourlyForecast(latitude: latitude, longitude: longitude, hours: hours)
        } catch {
            errorMessage = "Failed to fetch hourly forecast: \(error.localizedDescription)"
            hourlyForecast = []
        }
        
        isLoading = false
    }
    
    func getDailyForecast(latitude: Double, longitude: Double, days: Int = 7) async {
        isLoading = true
        errorMessage = nil
        
        do {
            dailyForecast = try await weatherService.getDailyForecast(latitude: latitude, longitude: longitude, days: days)
        } catch {
            errorMessage = "Failed to fetch daily forecast: \(error.localizedDescription)"
            dailyForecast = []
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties for UI
    
    var currentWeatherDisplayText: String {
        guard let weather = currentWeather else { return "" }
        
        return """
        Temperature: \(Int(weather.temperature))°C
        Feels like: \(Int(weather.apparentTemperature))°C
        Condition: \(weather.condition)
        Humidity: \(Int(weather.humidity * 100))%
        Wind Speed: \(Int(weather.windSpeed)) m/s
        UV Index: \(weather.uvIndex)
        """
    }
}
