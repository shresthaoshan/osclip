import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let limits = 10...5000

    let store: HistoryStore
    @AppStorage("limit") private var limit = HistoryStore.defaultLimit
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmClear = false

    var body: some View {
        Form {
            LabeledContent("History size") {
                HStack {
                    TextField("History size", value: $limit, format: .number)
                        .labelsHidden()
                        .frame(width: 70)
                    Stepper("History size", value: $limit, in: Self.limits, step: 10).labelsHidden()
                }
            }
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Button("Clear History…", role: .destructive) { confirmClear = true }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .onChange(of: limit) {
            let clamped = min(max(limit, Self.limits.lowerBound), Self.limits.upperBound)
            if clamped != limit { limit = clamped } else { store.limit = limit }
        }
        .confirmationDialog("Clear all history?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { store.clear() }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
