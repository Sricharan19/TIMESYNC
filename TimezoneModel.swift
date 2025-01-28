import Foundation
    import SwiftUI

    class TimezoneModel: ObservableObject {
        @Published var userTimezone: String
        @Published var teamTimezones: [String]
        
        init(userTimezone: String, teamTimezones: [String] = []) {
            self.userTimezone = userTimezone
            self.teamTimezones = teamTimezones
        }
        
        // Convert the date from the user's timezone to the given team's timezone
        func convertDate(_ date: Date, from sourceTimeZone: String, to destinationTimeZone: String) -> Date? {
            guard let sourceTimeZone = TimeZone(identifier: sourceTimeZone),
                  let destinationTimeZone = TimeZone(identifier: destinationTimeZone) else {
                return nil
            }
            
            let sourceOffset = sourceTimeZone.secondsFromGMT(for: date)
            let destinationOffset = destinationTimeZone.secondsFromGMT(for: date)
            let timeInterval = TimeInterval(destinationOffset - sourceOffset)
            return Date(timeInterval: timeInterval, since: date)
        }
        
        // Format the date to match the required time zone
        func formatDate(_ date: Date, timeZone: String) -> String? {
            guard let timeZone = TimeZone(identifier: timeZone) else { return nil }
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.timeZone = timeZone
            return formatter.string(from: date)
        }
        
        // Update the message preview when the user selects a date and time
        func updateMessagePreview(selectedDate: Date) -> String {
            var messagePreview = "Meeting Proposal:\n"
            
            // Format the time for the user's timezone
            if let userFormattedDate = formatDate(selectedDate, timeZone: userTimezone) {
                messagePreview += "User Timezone (\(userTimezone)): \(userFormattedDate)\n"
            }
            
            // Format the time for the team timezones
            for timezone in teamTimezones {
                if let convertedDate = convertDate(selectedDate, from: userTimezone, to: timezone),
                   let teamFormattedDate = formatDate(convertedDate, timeZone: timezone) {
                    messagePreview += "Teammate Timezone (\(timezone)): \(teamFormattedDate)\n"
                }
            }
            
            return messagePreview
        }
        
        // Helper method to generate a formatted message preview
        func generateMessagePreview(selectedDate: Date) -> String {
            return updateMessagePreview(selectedDate: selectedDate)
        }
        
        // Function to send message (this can be implemented to interact with a message sending service)
        func sendMessage(message: String) {
            // Logic to send message, e.g., through email or iMessage
            print("Message sent: \(message)")
        }
    }
