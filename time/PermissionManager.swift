import Foundation
import CoreLocation
import EventKit
import Contacts

class PermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var locationPermissionGranted = false
    @Published var calendarPermissionGranted = false
    @Published var contactsPermissionGranted = false
    
    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestCalendarPermission() {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                self.calendarPermissionGranted = granted
            }
        }
    }
    
    func requestContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                self.contactsPermissionGranted = granted
            }
        }
    }
    
    // CLLocationManagerDelegate method
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationPermissionGranted = (manager.authorizationStatus == .authorizedWhenInUse)
        }
    }
}
