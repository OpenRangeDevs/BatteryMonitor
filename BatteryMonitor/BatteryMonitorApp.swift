import SwiftUI
import IOKit.ps
import UserNotifications
import ServiceManagement

class BatteryMonitor: ObservableObject {
  @Published var batteryLevel: Int = 0
  @Published var lowBatteryThreshold: Int = 10 {
    didSet { UserDefaults.standard.set(lowBatteryThreshold, forKey: "LowBatteryThreshold") }
  }
  @Published var highBatteryThreshold: Int = 85 {
    didSet { UserDefaults.standard.set(highBatteryThreshold, forKey: "HighBatteryThreshold") }
  }
  
  init() {
    loadSavedThresholds()
    updateBatteryLevel()
    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      self.updateBatteryLevel()
    }
  }
  
  func loadSavedThresholds() {
    lowBatteryThreshold = UserDefaults.standard.integer(forKey: "LowBatteryThreshold")
    highBatteryThreshold = UserDefaults.standard.integer(forKey: "HighBatteryThreshold")
    if lowBatteryThreshold == 0 { lowBatteryThreshold = 10 }
    if highBatteryThreshold == 0 { highBatteryThreshold = 85 }
  }
  
  func resetToDefaults() {
    lowBatteryThreshold = 10
    highBatteryThreshold = 85
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
    if batteryLevel <= lowBatteryThreshold {
      showNotification(title: "Low Battery", message: "Battery level is at \(batteryLevel)%")
    } else if batteryLevel >= highBatteryThreshold {
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
      
      BatteryLevelIndicator(level: batteryMonitor.batteryLevel,
                            lowThreshold: batteryMonitor.lowBatteryThreshold,
                            highThreshold: batteryMonitor.highBatteryThreshold)
      
      Text("Alert Thresholds:")
        .font(.subheadline)
      
      HStack {
        Text("Low:")
        Slider(value: Binding(
          get: { Double(batteryMonitor.lowBatteryThreshold) },
          set: { batteryMonitor.lowBatteryThreshold = Int($0) }
        ), in: 1...50, step: 1)
        Text("\(batteryMonitor.lowBatteryThreshold)%")
      }
      
      HStack {
        Text("High:")
        Slider(value: Binding(
          get: { Double(batteryMonitor.highBatteryThreshold) },
          set: { batteryMonitor.highBatteryThreshold = Int($0) }
        ), in: 51...100, step: 1)
        Text("\(batteryMonitor.highBatteryThreshold)%")
      }
      
      Button("Reset to Defaults") {
        batteryMonitor.resetToDefaults()
      }
      
      Divider()
      
      Toggle("Start at login", isOn: $loginItemManager.startsAtLogin)
      
      Divider()
      
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding()
    .frame(width: 250)
  }
}

struct BatteryLevelIndicator: View {
  let level: Int
  let lowThreshold: Int
  let highThreshold: Int
  
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
        
        Rectangle()
          .fill(levelColor)
          .frame(width: geometry.size.width * CGFloat(level) / 100)
        
        Rectangle()
          .fill(Color.red)
          .frame(width: 2)
          .offset(x: geometry.size.width * CGFloat(lowThreshold) / 100)
        
        Rectangle()
          .fill(Color.green)
          .frame(width: 2)
          .offset(x: geometry.size.width * CGFloat(highThreshold) / 100)
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
    if level <= lowThreshold {
      return .red
    } else if level <= lowThreshold + 10 {
      return .orange
    } else if level >= highThreshold {
      return .green
    } else {
      return .blue
    }
  }
}

#Preview {
  MenuContent(batteryMonitor: BatteryMonitor(), loginItemManager: LoginItemManager())
}
