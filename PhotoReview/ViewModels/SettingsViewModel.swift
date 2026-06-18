import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var notificationEnabled: Bool = false
    @Published var notificationWeekday: Int = 1  // 1 = Sunday
    @Published var notificationHour: Int = 21

    private let service = NotificationService.shared

    func onAppear() async {
        notificationEnabled = await service.isAuthorized()
    }

    func toggleNotification(enabled: Bool) async {
        if enabled {
            let granted = await service.requestAuthorization()
            if granted {
                service.scheduleWeeklyReminder(weekday: notificationWeekday, hour: notificationHour)
                notificationEnabled = true
            }
        } else {
            service.cancelWeeklyReminder()
            notificationEnabled = false
        }
    }

    func updateSchedule() {
        guard notificationEnabled else { return }
        service.scheduleWeeklyReminder(weekday: notificationWeekday, hour: notificationHour)
    }
}
