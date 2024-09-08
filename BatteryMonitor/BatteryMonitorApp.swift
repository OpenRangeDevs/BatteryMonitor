import ServiceManagement
import SwiftUI
import IOKit.ps
import UserNotifications

class BatteryMonitor: ObservableObject {
  @Published var batteryLevel: Int = 0
  
  init() {
    updateBatteryLevel()
    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      self.updateBatteryLevel()
    }
  }
  
  func updateBatteryLevel() {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    
    for ps in sources {
      let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: Any]
      if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
        batteryLevel = capacity
        checkBatteryLevels()
        break
      }
    }
  }
  
  func checkBatteryLevels() {
    if batteryLevel <= 10 {
      showNotification(title: "Low Battery", message: "Battery level is at \(batteryLevel)%")
    } else if batteryLevel >= 85 {
      showNotification(title: "High Battery", message: "Battery level is at \(batteryLevel)%")
    }
  }
  
  func showNotification(title: String, message: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}

@main
struct BatteryMonitorApp: App {
  @StateObject private var batteryMonitor = BatteryMonitor()
  @StateObject private var loginItemManager = LoginItemManager()
  
  var body: some Scene {
    MenuBarExtra("Battery: \(batteryMonitor.batteryLevel)%", systemImage: "battery.100") {
      MenuContent(batteryMonitor: batteryMonitor, loginItemManager: loginItemManager)
    }
  }
  
  init() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
      if granted {
        print("Notification permission granted")
      }
    }
  }
}

struct MenuContent: View {
  @ObservedObject var batteryMonitor: BatteryMonitor
  @ObservedObject var loginItemManager: LoginItemManager
  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Battery Level: \(batteryMonitor.batteryLevel)%")
        .font(.headline)
      
      BatteryLevelIndicator(level: batteryMonitor.batteryLevel)
      
      Text("Notifications:")
        .font(.subheadline)
      Text("• Low Battery: 10%")
      Text("• High Battery: 85%")
      
      Divider()
      
      Toggle("Start at login", isOn: $loginItemManager.startsAtLogin)
      
      Divider()
      
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding()
    .frame(width: 200)
  }
}

struct BatteryLevelIndicator: View {
  let level: Int
  
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
        
        Rectangle()
          .fill(levelColor)
          .frame(width: geometry.size.width * CGFloat(level) / 100)
      }
      .frame(height: 20)
      .overlay(
        Text("\(level)%")
          .font(.caption)
          .foregroundColor(.white)
      )
    }
    .frame(height: 20)
  }
  
  var levelColor: Color {
    if level <= 10 {
      return .red
    } else if level <= 20 {
      return .orange
    } else if level >= 85 {
      return .green
    } else {
      return .blue
    }
  }
}

class LoginItemManager: ObservableObject {
  @Published var startsAtLogin: Bool {
    didSet {
      if startsAtLogin {
        addLoginItem()
      } else {
        removeLoginItem()
      }
    }
  }
  
  private let loginItemBundleIdentifier = "com.openrangedevs.BatteryMonitor"
  
  init() {
    startsAtLogin = SMAppService.mainApp.status == .enabled
  }
  
  private func addLoginItem() {
    do {
      try SMAppService.mainApp.register()
    } catch {
      print("Failed to add login item: \(error.localizedDescription)")
    }
  }
  
  private func removeLoginItem() {
    do {
      try SMAppService.mainApp.unregister()
    } catch {
      print("Failed to remove login item: \(error.localizedDescription)")
    }
  }
}

#Preview {
  MenuContent(batteryMonitor: BatteryMonitor(), loginItemManager: LoginItemManager())
}


