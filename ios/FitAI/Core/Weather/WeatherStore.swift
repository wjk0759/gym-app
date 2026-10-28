import CoreLocation
import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class WeatherStore {
    enum LoadState: Equatable {
        case idle
        case locating
        case loading
        case ready
        case permissionDenied
        case failed(String)
    }

    private(set) var snapshot: WeatherSnapshot?
    private(set) var state: LoadState = .idle
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isRefreshing = false
    private(set) var alertsEnabled = true
    private(set) var alertsAuthorized = false
    private(set) var lastError: String?
    private(set) var lastRefreshAttempt: Date?

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let locationProvider: WeatherLocationProvider
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var didActivate = false

    private let cacheKey = "fitai.weather.cache.v1"
    private let alertsEnabledKey = "fitai.weather.alerts.enabled.v1"
    private let lastAlertDayKey = "fitai.weather.alert.day.v1"

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)

        locationProvider = WeatherLocationProvider()
        alertsEnabled = defaults.object(forKey: alertsEnabledKey) as? Bool ?? true

        if let data = defaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) {
            snapshot = cached
            state = .ready
        }

        authorizationStatus = locationProvider.authorizationStatus
        locationProvider.onAuthorizationChange = { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleAuthorization(status)
            }
        }
        locationProvider.onLocation = { [weak self] location in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleLocation(location)
            }
        }
        locationProvider.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleLocationError(error)
            }
        }
    }

    // MARK: - 提供给界面

    var isStale: Bool {
        guard let snapshot else { return false }
        return Date().timeIntervalSince(snapshot.updatedAt) > 60 * 60
    }

    var authorizationLabel: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "定位已开启"
        case .denied:
            return "定位未开启"
        case .restricted:
            return "定位受限"
        case .notDetermined:
            return "等待定位权限"
        @unknown default:
            return "定位状态未知"
        }
    }

    var needsLocationPermission: Bool {
        authorizationStatus == .notDetermined
    }

    var locationBlocked: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 夜间不主动弹天气提醒，避免在用户休息时打扰。
    private var isWeatherAlertWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return (7..<22).contains(hour)
    }

    // MARK: - 生命周期

    func activate() {
        didActivate = true
        authorizationStatus = locationProvider.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            state = snapshot == nil ? .locating : .ready
            locationProvider.requestAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            refreshIfNeeded()
        case .denied, .restricted:
            state = snapshot == nil ? .permissionDenied : .ready
        @unknown default:
            state = snapshot == nil ? .permissionDenied : .ready
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.refreshNotificationAuthorization()
        }
    }

    func refreshIfNeeded(maxAge: TimeInterval = 15 * 60) {
        guard didActivate else { return }
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        guard !isRefreshing else { return }
        if let updatedAt = snapshot?.updatedAt,
           Date().timeIntervalSince(updatedAt) < maxAge {
            return
        }
        refresh()
    }

    func refresh() {
        authorizationStatus = locationProvider.authorizationStatus
        guard !isRefreshing else { return }

        switch authorizationStatus {
        case .notDetermined:
            state = snapshot == nil ? .locating : .ready
            locationProvider.requestAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isRefreshing = true
            lastError = nil
            lastRefreshAttempt = Date()
            if snapshot == nil {
                state = .locating
            }
            locationProvider.requestLocation()
            startTimeout()
        case .denied, .restricted:
            isRefreshing = false
            state = snapshot == nil ? .permissionDenied : .ready
            lastError = "请在系统设置中允许定位，才能获取当地天气。"
        @unknown default:
            isRefreshing = false
            state = snapshot == nil ? .permissionDenied : .ready
        }
    }

    // MARK: - 权限回调

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .notDetermined:
            state = snapshot == nil ? .locating : .ready
        case .authorizedAlways, .authorizedWhenInUse:
            if !isRefreshing {
                refresh()
            }
        case .denied, .restricted:
            isRefreshing = false
            timeoutTask?.cancel()
            loadTask?.cancel()
            state = snapshot == nil ? .permissionDenied : .ready
            lastError = "定位权限未开启，天气和出行提醒暂时不可用。"
        @unknown default:
            isRefreshing = false
            state = snapshot == nil ? .permissionDenied : .ready
        }
    }

    private func handleLocationError(_ error: Error) {
        isRefreshing = false
        timeoutTask?.cancel()
        lastError = "定位失败：\(error.localizedDescription)"

        if let locationError = error as? CLError, locationError.code == .denied {
            state = snapshot == nil ? .permissionDenied : .ready
        } else if snapshot == nil {
            state = .failed("定位失败，请检查定位服务和网络后重试。")
        } else {
            state = .ready
        }
    }

    // MARK: - 请求天气

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled, let self, self.isRefreshing else { return }
            self.isRefreshing = false
            self.lastError = "天气刷新超时，先显示上次数据。"
            if self.snapshot == nil {
                self.state = .failed("天气刷新超时，请稍后重试。")
            }
        }
    }

    private func handleLocation(_ location: CLLocation) {
        timeoutTask?.cancel()
        loadTask?.cancel()
        isRefreshing = true
        state = snapshot == nil ? .loading : .ready
        lastError = nil
        lastRefreshAttempt = Date()

        let previousPlace = cachedPlaceName(for: location)
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                var value = try await self.fetchSnapshot(for: location)
                guard !Task.isCancelled else { return }
                value.placeName = previousPlace
                self.snapshot = value
                self.state = .ready
                self.lastError = nil
                self.isRefreshing = false
                self.cache(value)
                await self.evaluateWeatherAlert(for: value)
                await self.resolvePlaceName(for: location, previous: previousPlace)
            } catch {
                guard !Task.isCancelled else { return }
                self.isRefreshing = false
                self.lastError = "天气加载失败，请稍后重试。"
                self.state = self.snapshot == nil
                    ? .failed("天气加载失败，请检查网络后重试。")
                    : .ready
            }
        }
    }

    private func cache(_ value: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    private func cachedPlaceName(for location: CLLocation) -> String? {
        guard let snapshot, let placeName = snapshot.placeName, !placeName.isEmpty else {
            return nil
        }
        let cachedLocation = CLLocation(
            latitude: snapshot.latitude,
            longitude: snapshot.longitude
        )
        return cachedLocation.distance(from: location) < 50_000 ? placeName : nil
    }

    private func resolvePlaceName(for location: CLLocation, previous: String?) async {
        if let previous, !previous.isEmpty {
            return
        }

        let name = await reverseGeocode(location)
        guard let name, !name.isEmpty else { return }
        guard var latest = snapshot else { return }
        let latestLocation = CLLocation(latitude: latest.latitude, longitude: latest.longitude)
        guard latestLocation.distance(from: location) < 10_000 else { return }
        latest.placeName = name
        snapshot = latest
        cache(latest)
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "zh_Hans_CN")
            ) { placemarks, _ in
                let placemark = placemarks?.first
                let name = placemark?.locality
                    ?? placemark?.subLocality
                    ?? placemark?.administrativeArea
                    ?? placemark?.name
                continuation.resume(returning: name)
            }
        }
    }

    private func fetchSnapshot(for location: CLLocation) async throws -> WeatherSnapshot {
        let latitude = (location.coordinate.latitude * 100).rounded() / 100
        let longitude = (location.coordinate.longitude * 100).rounded() / 100

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,wind_speed_10m"
            ),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm")
        ]

        guard let url = components.url else {
            throw WeatherFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("FitAI/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherFetchError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherFetchError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        guard let current = decoded.current else {
            throw WeatherFetchError.missingCurrentWeather
        }

        let daily = decoded.daily
        let high: Double? = daily?.temperature2mMax?.first ?? nil
        let low: Double? = daily?.temperature2mMin?.first ?? nil
        let probability: Int? = daily?.precipitationProbabilityMax?.first ?? nil
        return WeatherSnapshot(
            temperatureC: current.temperature2m,
            apparentTemperatureC: current.apparentTemperature,
            humidity: current.relativeHumidity2m,
            windKPH: current.windSpeed10m,
            weatherCode: current.weatherCode,
            isDay: current.isDay == 1,
            precipitationMM: current.precipitation ?? 0,
            rainMM: current.rain ?? 0,
            showersMM: current.showers ?? 0,
            snowfallCM: current.snowfall ?? 0,
            cloudCover: current.cloudCover,
            highC: high,
            lowC: low,
            precipitationProbability: probability,
            timezone: decoded.timezone,
            placeName: nil,
            latitude: latitude,
            longitude: longitude,
            updatedAt: Date()
        )
    }

    // MARK: - 通知

    @discardableResult
    func refreshNotificationAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        alertsAuthorized = authorized
        return authorized
    }

    func setWeatherAlerts(_ enabled: Bool) {
        alertsEnabled = enabled
        defaults.set(enabled, forKey: alertsEnabledKey)
        guard enabled else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await NotificationScheduler.shared.requestAuthorization()
            _ = await self.refreshNotificationAuthorization()
            if let snapshot = self.snapshot {
                await self.evaluateWeatherAlert(for: snapshot)
            }
        }
    }

    func requestWeatherAlertPermission() async -> Bool {
        _ = await NotificationScheduler.shared.requestAuthorization()
        let authorized = await refreshNotificationAuthorization()
        if authorized && alertsEnabled, let snapshot = snapshot {
            await evaluateWeatherAlert(for: snapshot)
        }
        return authorized && alertsEnabled
    }

    /// 供页面定时器调用：当天气没有重新请求、但进入可提醒时段时，补发当天提醒。
    func evaluateCurrentAlertIfNeeded() async {
        guard let snapshot,
              Date().timeIntervalSince(snapshot.updatedAt) < 2 * 60 * 60 else {
            return
        }
        await evaluateWeatherAlert(for: snapshot)
    }

    private func evaluateWeatherAlert(for snapshot: WeatherSnapshot) async {
        guard alertsEnabled, let alertKind = snapshot.alertKind else { return }
        guard isWeatherAlertWindow else { return }
        let dayKey = snapshot.dayKey
        guard defaults.string(forKey: lastAlertDayKey) != dayKey else { return }
        guard await refreshNotificationAuthorization() else { return }

        let sent = await NotificationScheduler.shared.notifyWeather(
            title: alertKind.title(for: snapshot),
            body: alertKind.body(for: snapshot),
            identifier: "weather-\(dayKey)-\(alertKind.rawValue)"
        )
        if sent {
            defaults.set(dayKey, forKey: lastAlertDayKey)
        }
    }
}

// MARK: - Location provider

final class WeatherLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocation: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1_000
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()
        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }
}

// MARK: - Open-Meteo response

private struct OpenMeteoResponse: Decodable {
    let current: Current?
    let daily: Daily?
    let timezone: String?

    struct Current: Decodable {
        let temperature2m: Double
        let relativeHumidity2m: Int?
        let apparentTemperature: Double?
        let isDay: Int
        let precipitation: Double?
        let rain: Double?
        let showers: Double?
        let snowfall: Double?
        let weatherCode: Int
        let cloudCover: Int?
        let windSpeed10m: Double?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case precipitation
            case rain
            case showers
            case snowfall
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed10m = "wind_speed_10m"
        }
    }

    struct Daily: Decodable {
        let temperature2mMax: [Double?]?
        let temperature2mMin: [Double?]?
        let precipitationProbabilityMax: [Int?]?

        enum CodingKeys: String, CodingKey {
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }
}

private enum WeatherFetchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case missingCurrentWeather

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "天气地址无效"
        case .invalidResponse:
            return "天气服务返回异常"
        case .httpStatus(let status):
            return "天气服务返回 \(status)"
        case .missingCurrentWeather:
            return "天气数据不完整"
        }
    }
}
