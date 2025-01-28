import SwiftUI
    import EventKit
    import UserNotifications
    import MessageUI
    import Contacts

    class MessageGenerationViewController: ObservableObject {
        var userTimezone: String
        var teamTimezones: [String]
        var selectedDate: Date
        @Published var messagePreview = ""
        @Published var isShowingMailView = false
        @Published var isShowingSMSView = false
        @Published var mailResult: Result<MFMailComposeResult, Error>? = nil
        @Published var smsResult: Result<MessageComposeResult, Error>? = nil
        
        init(userTimezone: String, teamTimezones: [String], selectedDate: Date) {
            self.userTimezone = userTimezone
            self.teamTimezones = teamTimezones
            self.selectedDate = selectedDate
        }
        
        func updateMessagePreview() {
            let userTimeZone = TimeZone(identifier: userTimezone)
            messagePreview = "Meeting Proposal:\n"
            messagePreview += "User Timezone (\(getTimeZoneCountry(for: userTimezone))): \(formatDate(selectedDate, timeZone: userTimeZone))\n"
            
            for timezone in teamTimezones {
                if let teamTimeZone = TimeZone(identifier: timezone) {
                    let convertedDate = convertDate(selectedDate, from: userTimeZone, to: teamTimeZone)
                    messagePreview += "Teammate Timezone (\(getTimeZoneCountry(for: timezone))): \(formatDate(convertedDate, timeZone: teamTimeZone))\n"
                }
            }
        }
        
        private func convertDate(_ date: Date, from sourceTimeZone: TimeZone?, to destinationTimeZone: TimeZone?) -> Date {
            let sourceOffset = sourceTimeZone?.secondsFromGMT(for: date) ?? 0
            let destinationOffset = destinationTimeZone?.secondsFromGMT(for: date) ?? 0
            let timeInterval = TimeInterval(destinationOffset - sourceOffset)
            return Date(timeInterval: timeInterval, since: date)
        }
        
        private func formatDate(_ date: Date, timeZone: TimeZone?) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.timeZone = timeZone
            return formatter.string(from: date)
        }
        
        private func getTimeZoneCountry(for timeZoneIdentifier: String) -> String {
            if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
                let locale = Locale.current
                if let countryCode = timeZone.identifier.components(separatedBy: "/").first {
                    return locale.localizedString(forRegionCode: countryCode) ?? timeZoneIdentifier
                }
            }
            return timeZoneIdentifier
        }
        
        func sendEmail() {
            if MFMailComposeViewController.canSendMail() {
                isShowingMailView = true
            } else {
                print("Cannot send email")
            }
        }
        
        func sendSMS() {
            if MFMessageComposeViewController.canSendText() {
                isShowingSMSView = true
            } else {
                print("Cannot send SMS")
            }
        }
    }

    struct MessageGenerationViewControllerRepresentable: View {
        @Environment(\.presentationMode) var presentationMode
        @StateObject var messageGenerator: MessageGenerationViewController
        @State private var isShowingReminderAlert = false
        @State private var reminderMessage = ""
        
        init(userTimezone: String, teamTimezones: [String], selectedDate: Date) {
            _messageGenerator = StateObject(wrappedValue: MessageGenerationViewController(userTimezone: userTimezone, teamTimezones: teamTimezones, selectedDate: selectedDate))
        }

        var body: some View {
            VStack {
                // Back Button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.backward")
                        Text("Back")
                    }
                    .padding(.leading)
                    Spacer()
                }
                
                Text("Message Generation")
                    .font(.largeTitle)
                    .padding()

                Text("Preview:")
                    .font(.headline)
                ScrollView {
                    Text(messageGenerator.messagePreview)
                        .padding()
                        .font(.system(size: 16))
                }
                
                HStack {
                    Button(action: {
                        messageGenerator.sendEmail()
                    }) {
                        Text("Send Email")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        messageGenerator.sendSMS()
                    }) {
                        Text("Send SMS")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                Button(action: {
                    addReminder()
                }) {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("Add Reminder")
                    }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                .padding()
            }
            .onAppear {
                messageGenerator.updateMessagePreview()
            }
            .sheet(isPresented: $messageGenerator.isShowingMailView) {
                MailView(result: $messageGenerator.mailResult, message: messageGenerator.messagePreview)
            }
            .sheet(isPresented: $messageGenerator.isShowingSMSView) {
                SMSView(result: $messageGenerator.smsResult, message: messageGenerator.messagePreview)
            }
            .alert(isPresented: $isShowingReminderAlert) {
                Alert(title: Text("Reminder Set"), message: Text(reminderMessage), dismissButton: .default(Text("OK")))
            }
        }
        
        private func addReminder() {
            let eventStore = EKEventStore()
            eventStore.requestFullAccessToEvents { (granted, error) in
                if granted, error == nil {
                    let reminder = EKReminder(eventStore: eventStore)
                    reminder.title = "Meeting Reminder"
                    reminder.notes = messageGenerator.messagePreview
                    
                    let alarm = EKAlarm(absoluteDate: messageGenerator.selectedDate.addingTimeInterval(-900))
                    reminder.addAlarm(alarm)
                    
                    do {
                        try eventStore.save(reminder, commit: true)
                        reminderMessage = "Reminder set for 15 minutes before the meeting."
                    } catch {
                        reminderMessage = "Failed to set reminder."
                    }
                    isShowingReminderAlert = true
                } else {
                    reminderMessage = "Calendar access was not granted."
                    isShowingReminderAlert = true
                }
            }
        }
    }

    struct MailView: UIViewControllerRepresentable {
        @Binding var result: Result<MFMailComposeResult, Error>?
        var message: String

        func makeUIViewController(context: Context) -> MFMailComposeViewController {
            let mailComposeViewController = MFMailComposeViewController()
            mailComposeViewController.mailComposeDelegate = context.coordinator
            mailComposeViewController.setMessageBody(message, isHTML: false)
            return mailComposeViewController
        }

        func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(result: $result)
        }

        class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
            @Binding var result: Result<MFMailComposeResult, Error>?

            init(result: Binding<Result<MFMailComposeResult, Error>?>) {
                _result = result
            }

            func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
                controller.dismiss(animated: true)
                if let error = error {
                    self.result = .failure(error)
                } else {
                    self.result = .success(result)
                }
            }
        }
    }
    
    struct SMSView: UIViewControllerRepresentable {
        @Binding var result: Result<MessageComposeResult, Error>?
        var message: String

        func makeUIViewController(context: Context) -> MFMessageComposeViewController {
            let smsComposeViewController = MFMessageComposeViewController()
            smsComposeViewController.messageComposeDelegate = context.coordinator
            smsComposeViewController.body = message
            return smsComposeViewController
        }

        func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(result: $result)
        }

        class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
            @Binding var result: Result<MessageComposeResult, Error>?

            init(result: Binding<Result<MessageComposeResult, Error>?>) {
                _result = result
            }

            func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
                controller.dismiss(animated: true)
                self.result = .success(result)
            }
        }
    }
