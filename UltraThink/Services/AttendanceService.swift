import Foundation
import CoreLocation

class AttendanceService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AttendanceService()
    
    @Published var isAtOffice = false
    @Published var todayAttendance: AttendanceRecord?
    @Published var isAutoClockEnabled = false
    
    private let apiService = APIService.shared
    private let locationManager = CLLocationManager()
    private var officeLocation: CLLocation?
    private let geofenceRadius: CLLocationDistance = 100.0 // 100 meters
    
    override init() {
        super.init()
        setupLocationManager()
        loadOfficeLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func loadOfficeLocation() {
        let latitude = UserDefaults.standard.double(forKey: "office_latitude")
        let longitude = UserDefaults.standard.double(forKey: "office_longitude")
        
        if latitude != 0 && longitude != 0 {
            officeLocation = CLLocation(latitude: latitude, longitude: longitude)
            setupGeofence()
        }
    }
    
    func setOfficeLocation(latitude: Double, longitude: Double) {
        officeLocation = CLLocation(latitude: latitude, longitude: longitude)
        UserDefaults.standard.set(latitude, forKey: "office_latitude")
        UserDefaults.standard.set(longitude, forKey: "office_longitude")
        setupGeofence()
    }
    
    private func setupGeofence() {
        guard let officeLocation = officeLocation else { return }
        
        locationManager.stopMonitoringSignificantLocationChanges()
        
        let geofence = CLCircularRegion(
            center: officeLocation.coordinate,
            radius: geofenceRadius,
            identifier: "office_geofence"
        )
        geofence.notifyOnEntry = true
        geofence.notifyOnExit = true
        
        locationManager.startMonitoring(for: geofence)
    }
    
    func enableAutoClocking(_ enabled: Bool) {
        isAutoClockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "auto_clock_enabled")
        
        if enabled {
            requestLocationPermission()
        }
    }
    
    private func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func manualClockIn() async {
        await performClockIn(isAutomatic: false)
    }
    
    func manualClockOut() async {
        await performClockOut(isAutomatic: false)
    }
    
    private func performClockIn(isAutomatic: Bool) async {
        guard let credentials = ConfigurationManager.shared.attendanceCredentials,
              !ConfigurationManager.shared.attendanceSystemURL.isEmpty else {
            print("Attendance system not configured")
            return
        }
        
        do {
            let clockInData = AttendanceClockData(
                action: "clock_in",
                timestamp: Date(),
                location: getCurrentLocationDescription(),
                isAutomatic: isAutomatic
            )
            
            let success = try await submitAttendance(data: clockInData, credentials: credentials)
            
            if success {
                await MainActor.run {
                    self.updateTodayAttendance(clockInTime: Date(), isAutoClocked: isAutomatic)
                }
                
                if !isAutomatic {
                    await sendNotification(title: "打卡成功", body: "已成功打上班卡")
                }
            }
            
        } catch {
            print("Clock in failed: \(error)")
            if !isAutomatic {
                await sendNotification(title: "打卡失敗", body: "上班打卡失敗，請重試")
            }
        }
    }
    
    private func performClockOut(isAutomatic: Bool) async {
        guard let credentials = ConfigurationManager.shared.attendanceCredentials,
              !ConfigurationManager.shared.attendanceSystemURL.isEmpty else {
            print("Attendance system not configured")
            return
        }
        
        do {
            let clockOutData = AttendanceClockData(
                action: "clock_out",
                timestamp: Date(),
                location: getCurrentLocationDescription(),
                isAutomatic: isAutomatic
            )
            
            let success = try await submitAttendance(data: clockOutData, credentials: credentials)
            
            if success {
                await MainActor.run {
                    self.updateTodayAttendance(clockOutTime: Date(), isAutoClocked: isAutomatic)
                }
                
                if !isAutomatic {
                    await sendNotification(title: "打卡成功", body: "已成功打下班卡")
                }
            }
            
        } catch {
            print("Clock out failed: \(error)")
            if !isAutomatic {
                await sendNotification(title: "打卡失敗", body: "下班打卡失敗，請重試")
            }
        }
    }
    
    private func submitAttendance(data: AttendanceClockData, credentials: AttendanceCredentials) async throws -> Bool {
        guard let url = URL(string: ConfigurationManager.shared.attendanceSystemURL) else {
            throw APIError.invalidURL
        }
        
        var requestBody: [String: Any] = [
            "username": credentials.username,
            "password": credentials.password,
            "action": data.action,
            "timestamp": ISO8601DateFormatter().string(from: data.timestamp),
            "location": data.location ?? "",
            "is_automatic": data.isAutomatic
        ]
        
        if let employeeId = credentials.employeeId {
            requestBody["employee_id"] = employeeId
        }
        
        if let additionalParams = credentials.additionalParams {
            for (key, value) in additionalParams {
                requestBody[key] = value
            }
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let response: AttendanceResponse = try await apiService.makeRequest(
            url: url,
            method: .POST,
            body: bodyData,
            responseType: AttendanceResponse.self
        )
        
        return response.success
    }
    
    private func getCurrentLocationDescription() -> String? {
        guard let location = locationManager.location else { return nil }
        return "Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude)"
    }
    
    private func updateTodayAttendance(clockInTime: Date? = nil, clockOutTime: Date? = nil, isAutoClocked: Bool = false) {
        if todayAttendance == nil {
            todayAttendance = AttendanceRecord(
                date: Date(),
                clockInTime: clockInTime,
                clockOutTime: clockOutTime,
                location: getCurrentLocationDescription(),
                isAutoClocked: isAutoClocked
            )
        } else {
            if let clockInTime = clockInTime {
                todayAttendance?.clockInTime = clockInTime
            }
            if let clockOutTime = clockOutTime {
                todayAttendance?.clockOutTime = clockOutTime
            }
            todayAttendance?.isAutoClocked = isAutoClocked
        }
    }
    
    private func sendNotification(title: String, body: String) async {
        await MainActor.run {
            // Here you would implement local notification
            print("Notification: \(title) - \(body)")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last,
              let officeLocation = officeLocation else { return }
        
        let distance = currentLocation.distance(from: officeLocation)
        let wasAtOffice = isAtOffice
        isAtOffice = distance <= geofenceRadius
        
        // Only trigger auto-clock if status changed and auto-clock is enabled
        if isAutoClockEnabled && wasAtOffice != isAtOffice {
            if isAtOffice && shouldAutoClockIn() {
                Task {
                    await performClockIn(isAutomatic: true)
                }
            } else if !isAtOffice && shouldAutoClockOut() {
                Task {
                    await performClockOut(isAutomatic: true)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "office_geofence" && isAutoClockEnabled && shouldAutoClockIn() {
            Task {
                await performClockIn(isAutomatic: true)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "office_geofence" && isAutoClockEnabled && shouldAutoClockOut() {
            Task {
                await performClockOut(isAutomatic: true)
            }
        }
    }
    
    private func shouldAutoClockIn() -> Bool {
        // Only auto clock-in during work hours (8 AM - 10 AM)
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 8 && hour <= 10 && (todayAttendance?.clockInTime == nil)
    }
    
    private func shouldAutoClockOut() -> Bool {
        // Only auto clock-out during work hours (5 PM - 8 PM)
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 17 && hour <= 20 && (todayAttendance?.clockOutTime == nil)
    }
}

struct AttendanceClockData {
    let action: String // "clock_in" or "clock_out"
    let timestamp: Date
    let location: String?
    let isAutomatic: Bool
}

struct AttendanceResponse: Codable {
    let success: Bool
    let message: String?
    let data: AttendanceResponseData?
}

struct AttendanceResponseData: Codable {
    let clockTime: String?
    let employeeId: String?
    
    enum CodingKeys: String, CodingKey {
        case clockTime = "clock_time"
        case employeeId = "employee_id"
    }
}

struct AttendanceRecord: Identifiable {
    let id = UUID()
    let date: Date
    var clockInTime: Date?
    var clockOutTime: Date?
    let location: String?
    var isAutoClocked: Bool
}