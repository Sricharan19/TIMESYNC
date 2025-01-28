import SwiftUI
import EventKit
import UserNotifications
import CoreLocation
import MessageUI

// MARK: - SuggestedMeetingTimesView
struct SuggestedMeetingTimesView: View {
    @Binding var selectedDate: Date?
    var teamTimezones: [String]
    var userTimezone: String
    var convertDate: (Date, String, String) -> Date?
    var getTimeZoneCountry: (String) -> String
    
    private func getSuggestedTimes() -> [Date] {
        var suggestedTimes: [Date] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Get the current date components
        var dateComponents = calendar.dateComponents(in: TimeZone(identifier: userTimezone)!, from: now)
        dateComponents.hour = 9
        dateComponents.minute = 0
        dateComponents.second = 0
        
        // Create a date for 9 AM in the user's timezone
        guard let startTime = calendar.date(from: dateComponents) else {
            return []
        }
        
        // Loop through the next 8 hours to suggest times
        for hour in 0..<8 {
            let suggestedTime = calendar.date(byAdding: .hour, value: hour, to: startTime)!
            
            // Check if the suggested time is within working hours for all team timezones
            var allInWorkingHours = true
            for timezone in teamTimezones {
                if let convertedTime = convertDate(suggestedTime, userTimezone, timezone) {
                    let convertedHour = calendar.component(.hour, from: convertedTime)
                    if convertedHour < 9 || convertedHour >= 17 {
                        allInWorkingHours = false
                        break
                    }
                } else {
                    allInWorkingHours = false
                    break
                }
            }
            
            if allInWorkingHours {
                suggestedTimes.append(suggestedTime)
            }
        }
        
        return suggestedTimes
    }
    
    var body: some View {
        VStack {
            Text("Suggested Meeting Times")
                .font(.headline)
                .padding()
            
            ForEach(getSuggestedTimes(), id: \.self) { date in
                Button(action: { selectedDate = date }) {
                    Text("Meeting at \(formatDate(date))")
                        .foregroundColor(.blue)
                }
                .padding()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - TimeTranslationViewController
struct TimeTranslationViewController: View {
    @StateObject var timezoneModel: TimezoneModel
    @State private var selectedDate = Date()
    @State private var showSuggestedTimes = false
    @State private var selectedSuggestedTime: Date?
    @State private var pushNotificationGranted = false
    @Environment(\.presentationMode) var presentationMode
    @State private var calendarAccessGranted = false
    @State private var navigateToMessage = false
    
    init(userTimezone: String, teamTimezones: [String]) {
        _timezoneModel = StateObject(wrappedValue: TimezoneModel(userTimezone: userTimezone, teamTimezones: teamTimezones))
    }
    
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
        NavigationStack {
            VStack {
                // Title
                Text("Translate Timezones")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                // Display User's Timezone Country
                Text("Your Timezone: \(getTimeZoneCountry(for: timezoneModel.userTimezone))")
                    .font(.headline)
                    .padding(.bottom)
                
                // DatePicker for Date/Time Selection with 12-hour and 24-hour toggle
                HStack {
                    Spacer()
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    Spacer()
                }
                HStack {
                    Spacer()
                    DatePicker("Select Time", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.bottom)
                
                // Real-time Timezone Conversion
                List(timezoneModel.teamTimezones, id: \.self) { timezone in
                    if let convertedDate = timezoneModel.convertDate(selectedDate, from: timezoneModel.userTimezone, to: timezone),
                       let formattedDate = timezoneModel.formatDate(convertedDate, timeZone: timezone) {
                        Text("\(getTimeZoneCountry(for: timezone)): \(formattedDate) \(checkForConflict(convertedDate, timeZone: timezone) ? "Conflict" : "")")
                            .foregroundColor(checkForConflict(convertedDate, timeZone: timezone) ? .red : .primary)
                    } else {
                        Text("\(getTimeZoneCountry(for: timezone)): Conversion Error")
                    }
                }
                
                // Add to Calendar and Generate Message Buttons
                HStack {
                    // Add to Calendar Button
                    Button(action: {
                        addEventToCalendar(for: selectedDate)
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Add to Calendar")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    
                    // Button to Generate Message
                    NavigationLink(destination: MessageGenerationViewControllerRepresentable(userTimezone: timezoneModel.userTimezone, teamTimezones: timezoneModel.teamTimezones, selectedDate: selectedDate)) {
                        HStack {
                            Image(systemName: "message")
                            Text("Generate Message")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // Show Suggested Meeting Times based on overlap
                if showSuggestedTimes {
                    SuggestedMeetingTimesView(selectedDate: $selectedSuggestedTime, teamTimezones: timezoneModel.teamTimezones, userTimezone: timezoneModel.userTimezone, convertDate: timezoneModel.convertDate, getTimeZoneCountry: getTimeZoneCountry)
                }
            }
            .onAppear {
                // Request Notification permission
                requestNotificationPermission()
            }
            .onChange(of: selectedDate) { _ in
                schedulePushNotification(for: selectedDate)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Helper Functions
    private func checkForConflict(_ date: Date, timeZone: String) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour < 9 || hour >= 17
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            pushNotificationGranted = granted
        }
    }
    
    private func schedulePushNotification(for date: Date) {
        guard pushNotificationGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Meeting"
        content.body = "You have a meeting in 15 minutes!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func addEventToCalendar(for date: Date) {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { (granted, error) in
            if granted, error == nil {
                calendarAccessGranted = true
                let event = EKEvent(eventStore: eventStore)
                event.title = "Meeting"
                event.startDate = date
                event.endDate = date.addingTimeInterval(3600) // 1 hour duration
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                do {
                    try eventStore.save(event, span: .thisEvent)
                } catch let error as NSError {
                    print("Error saving event: \(error.localizedDescription)")
                }
            } else {
                print("Calendar access was not granted.")
            }
        }
    }
}

// MARK: - PreviewProvider
struct TimeTranslationViewController_Previews: PreviewProvider {
    static var previews: some View {
        // Use a default userTimezone and an empty array for teamTimezones
        NavigationStack {
            TimeTranslationViewController(userTimezone: TimeZone.current.identifier, teamTimezones: [])
        }
    }
}


