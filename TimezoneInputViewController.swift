import SwiftUI
    import CoreLocation
    import UserNotifications

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
        @State private var selectedTeamTimezone = TimeZone.current.identifier
        @State private var showingTimezoneSheet = false
        @StateObject private var locationManager = LocationManager()
        @State private var showOnboarding = true
        @State private var is24HourToggle = false
        
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
                VStack(spacing: 20) {
                    // Title
                    Text("Set Your Timezones")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding()

                    // 24-Hour Toggle
                    Toggle("24-Hour Format", isOn: $is24HourToggle)
                        .padding()
                        .font(.title3)

                    // User Timezone Display
                    userTimezoneDisplay

                    // Team Timezones Section
                    teamTimezonesSectionView

                    Spacer()

                    // Save and Next Buttons
                    saveAndNextButtonsView
                }
                .sheet(isPresented: $showingTimezoneSheet) {
                    TimezoneSelectionView(selectedTimezone: $selectedTeamTimezone) { selected in
                        if selected != userTimezone {
                            if selected == selectedTeamTimezone {
                                selectedTeamTimezone = selected
                            } else if !teamTimezones.contains(selected) {
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
                    requestNotificationPermission()
                    updateUserTimezone()
                }
                .alert(isPresented: $showOnboarding) {
                    Alert(title: Text("Welcome to TimeSync"), message: Text("Set your timezone and add team timezones to get started."), dismissButton: .default(Text("Got it!")))
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }

        // MARK: - Subviews
        private var userTimezoneDisplay: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Timezone")
                    .font(.title3)
                
                Text(getTimeZoneCountry(for: userTimezone))
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                    .padding(.vertical, 5)
            }
            .padding(.horizontal)
        }

        private var teamTimezonesSectionView: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Team Timezones")
                    .font(.title3)

                ForEach(teamTimezones, id: \.self) { timezone in
                    HStack {
                        Text(getTimeZoneCountry(for: timezone))
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
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
                                .scaleEffect(1.2)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }

                Button(action: { showingTimezoneSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Another")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 5)
            }
            .padding(.horizontal)
        }

        private var saveAndNextButtonsView: some View {
            HStack {
                // Save as Favorite Button
                Button(action: {
                    saveTimezones()
                    triggerNotification(title: "Timezones Saved", body: "Your timezones have been saved.")
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.white)
                        Text("Save as Favorite")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                // Next Button
                NavigationLink(destination: TimeTranslationViewController(userTimezone: userTimezone, teamTimezones: teamTimezones)) {
                    Text("Next")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(teamTimezones.isEmpty ? AnyView(Color.gray) : AnyView(Color.blue))
                        .cornerRadius(10)
                        .shadow(color: teamTimezones.isEmpty ? Color.clear : Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .disabled(teamTimezones.isEmpty)
            }
            .padding(.horizontal)
        }

        // MARK: - Supporting Methods
        private func saveTimezones() {
            print("Timezones saved: \(teamTimezones)")
        }

        private func saveToUserDefaults() {
            UserDefaults.standard.set(teamTimezones, forKey: "savedTimezones")
        }

        private func loadFromUserDefaults() {
            if let saved = UserDefaults.standard.array(forKey: "savedTimezones") as? [String] {
                teamTimezones = saved
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

    // MARK: - PreviewProvider
    struct TimezoneInputViewController_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                TimezoneInputViewController()
            }
        }
    }
