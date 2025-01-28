import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

// MARK: - LocationManager (ObservableObject)
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = CLLocationManager().authorizationStatus
    }
}

// MARK: - TimezoneInputViewController (SwiftUI View)
struct TimezoneInputViewController: View {
    @State private var userTimezone = TimeZone.current.identifier
    @State private var teamTimezones: [String] = []
    @State private var selectedTeamTimezone = ""
    @State private var showingTimezoneSheet = false
    @StateObject private var locationManager = LocationManager()
    @State private var showOnboarding = true
    @State private var is24HourToggle = false
    @State private var showingSaveConfigAlert = false
    @State private var configName = ""
    @State private var savedConfigurations: [TimezoneConfiguration] = []
    
    // Helper function to get country name from timezone identifier
    private func getTimeZoneCountry(for timeZoneIdentifier: String) -> String {
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            let locale = Locale.current
            if let countryCode = timeZone.identifier.components(separatedBy: "/").first {
                return locale.localizedString(forRegionCode: countryCode) ?? timeZoneIdentifier
            }
        }
        return timeZoneIdentifier
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Settings").font(.title2).textCase(nil)) {
                    // 24-Hour Toggle
                    Toggle("24-Hour Format", isOn: $is24HourToggle)
                        .font(.headline)
                        .padding(.vertical, 3)
                    
                    // User Timezone Display
                    HStack {
                        Text("Your Timezone")
                            .font(.headline)
                        Spacer()
                        Text(getTimeZoneCountry(for: userTimezone))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                
                Section(header: Text("Team Timezones").font(.title2).textCase(nil)) {
                    ForEach(teamTimezones, id: \.self) { timezone in
                        HStack {
                            Text(getTimeZoneCountry(for: timezone))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    if let index = teamTimezones.firstIndex(of: timezone) {
                                        teamTimezones.remove(at: index)
                                        saveToUserDefaults()
                                    }
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .scaleEffect(1.0)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    
                    Button(action: { showingTimezoneSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Another")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 3)
                    }
                }
                
                Section {
                    Button(action: {
                        showingSaveConfigAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                            Text("Save as Favorite")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    NavigationLink(destination: TimeTranslationViewController(userTimezone: userTimezone, teamTimezones: teamTimezones)) {
                        HStack {
                            Spacer()
                            Text("Next")
                            Spacer()
                        }
                    }
                    .disabled(teamTimezones.isEmpty)
                }
            }
            .sheet(isPresented: $showingTimezoneSheet) {
                TimezoneSelectionView(selectedTimezone: $selectedTeamTimezone) { selected in
                    if selected != userTimezone {
                        if !teamTimezones.contains(selected) {
                            teamTimezones.append(selected)
                            saveToUserDefaults()
                        }
                    }
                    else {
                        userTimezone = selected
                    }
                }
            }
            .onAppear {
                locationManager.requestLocation()
                loadFromUserDefaults()
                loadConfigurations()
                requestNotificationPermission()
                updateUserTimezone()
            }
            .alert(isPresented: $showOnboarding) {
                Alert(title: Text("Welcome to TimeSync"), message: Text("Set your timezone and add team timezones to get started."), dismissButton: .default(Text("Got it!")))
            }
            .navigationTitle("Timezone Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Timezone Settings")
                        .font(.system(size: 34, weight: .bold))
                }
            }
        }
        .background(
            SaveConfigAlert(isPresented: $showingSaveConfigAlert, configName: $configName) {
                saveTimezones(configName: configName)
            }
        )
    }
    
    // MARK: - Supporting Methods
    private func saveTimezones(configName: String) {
        let newConfig = TimezoneConfiguration(name: configName, userTimezone: userTimezone, teamTimezones: teamTimezones)
        savedConfigurations.append(newConfig)
        saveConfigurations()
        print("Timezones saved with config name: \(configName), timezones: \(teamTimezones)")
        triggerNotification(title: "Timezones Saved", body: "Your timezones have been saved with configuration name: \(configName).")
    }
    
    private func loadConfiguration(config: TimezoneConfiguration) {
        userTimezone = config.userTimezone
        teamTimezones = config.teamTimezones
        saveToUserDefaults()
    }
    
    private func deleteConfiguration(config: TimezoneConfiguration) {
        savedConfigurations.removeAll { $0.id == config.id }
        saveConfigurations()
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(teamTimezones, forKey: "savedTimezones")
    }
    
    private func loadFromUserDefaults() {
        if let saved = UserDefaults.standard.array(forKey: "savedTimezones") as? [String] {
            teamTimezones = saved
        }
    }
    
    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(savedConfigurations) {
            UserDefaults.standard.set(encoded, forKey: "savedTimezoneConfigurations")
        }
    }
    
    private func loadConfigurations() {
        if let saved = UserDefaults.standard.data(forKey: "savedTimezoneConfigurations") {
            if let decoded = try? JSONDecoder().decode([TimezoneConfiguration].self, from: saved) {
                savedConfigurations = decoded
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func triggerNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateUserTimezone() {
        if let location = locationManager.location {
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first, let timezone = placemark.timeZone {
                    userTimezone = timezone.identifier
                }
            }
        }
    }
}

// MARK: - TimezoneSelectionView
struct TimezoneSelectionView: View {
    @Binding var selectedTimezone: String
    var onSelect: (String) -> Void
    
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    let timezones = TimeZone.knownTimeZoneIdentifiers
    
    var filteredTimezones: [String] {
        if searchText.isEmpty {
            return timezones
        } else {
            return timezones.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                List {
                    ForEach(filteredTimezones, id: \.self) { timezone in
                        Button(action: {
                            selectedTimezone = timezone
                            onSelect(timezone)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(timezone)
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                if timezone == selectedTimezone {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Timezone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search by country"
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
}

// MARK: - SaveConfigAlert
struct SaveConfigAlert: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var configName: String
    var onSave: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let alert = UIAlertController(title: "Save Configuration", message: "Enter a name for this timezone configuration", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "Configuration Name"
                textField.text = configName
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                isPresented = false
                configName = ""
            }
            
            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                if let textField = alert.textFields?.first {
                    configName = textField.text ?? ""
                    onSave()
                }
                isPresented = false
            }
            
            alert.addAction(cancelAction)
            alert.addAction(saveAction)
            
            uiViewController.present(alert, animated: true) {
                isPresented = false
            }
        }
    }
}

// MARK: - TimezoneConfiguration
struct TimezoneConfiguration: Codable, Identifiable {
    var id = UUID()
    var name: String
    var userTimezone: String
    var teamTimezones: [String]
}

// MARK: - CustomButtonStyle
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.gray.opacity(0.3) : Color.clear)
            .cornerRadius(10)
    }
}

// MARK: - PreviewProvider
struct TimezoneInputViewController_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TimezoneInputViewController()
        }
    }
}

