import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    @AppStorage("autoCapitalize") private var autoCapitalize = true
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("showIndicator") private var showIndicator = true

    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Open Overlay:", name: .openOverlay)
                
                // Custom UI for modifier-only hotkey
                HStack {
                    Text("Instant Dictation:")
                    Spacer()
                    Text("⌃⌥⌘")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .help("Modifier-only hotkey: Hold Control+Option+Command, then release to trigger")
                
                Text("Note: Instant Dictation uses a modifier-only hotkey (⌃⌥⌘). Hold all three modifiers together, then release to toggle recording. Requires Accessibility permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Speech Recognition") {
                // Locale picker
                Picker("Language:", selection: $viewModel.selectedLocale) {
                    ForEach(viewModel.availableLocales, id: \.identifier) { locale in
                        Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                            .tag(locale)
                    }
                }
                .onChange(of: viewModel.selectedLocale) { _ in
                    viewModel.refreshOnDeviceSupport()
                }
                
                // On-device recognition toggle
                Toggle("Use on-device recognition", isOn: $viewModel.useOnDeviceRecognition)
                    .disabled(!viewModel.supportsOnDeviceRecognition)
                    .help(viewModel.supportsOnDeviceRecognition 
                          ? "Faster and more private speech recognition" 
                          : "On-device recognition not supported for this language")
                
                // Audio device picker
                Picker("Microphone:", selection: $viewModel.selectedAudioDevice) {
                    ForEach(viewModel.availableAudioDevices) { device in
                        Text(device.name).tag(device as AudioDevice?)
                    }
                }
                .onAppear {
                    viewModel.refreshAudioDevices()
                }
            }

            Section("Startup") {
                LaunchAtLogin.Toggle("Launch at Login")
            }

            Section("Instant Dictation") {
                // Injection mode picker
                Picker("Injection Mode:", selection: $viewModel.injectionMode) {
                    Text("Batch (inject at end)").tag(InjectionMode.batch)
                    Text("Streaming (real-time)").tag(InjectionMode.streaming)
                }
                
                Toggle("Auto-capitalize sentences", isOn: $viewModel.autoCapitalize)
                Toggle("Play sound on start / stop", isOn: $viewModel.playSounds)
                Toggle("Show recording indicator", isOn: $viewModel.showIndicator)
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if accessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Granted").foregroundColor(.secondary)
                    } else {
                        Button("Grant Access") {
                            PermissionsManager().requestAccessibilityIfNeeded()
                            // Start polling
                            pollAccessibility()
                        }
                    }
                }

                HStack {
                    Text("Microphone")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Managed by system").foregroundColor(.secondary)
                }

                HStack {
                    Text("Speech Recognition")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Managed by system").foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 520)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            viewModel.refreshOnDeviceSupport()
        }
    }

    private func pollAccessibility() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            accessibilityGranted = AXIsProcessTrusted()
            if !accessibilityGranted {
                pollAccessibility()
            }
        }
    }
}