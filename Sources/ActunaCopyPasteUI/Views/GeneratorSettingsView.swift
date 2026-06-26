import SwiftUI

/// Password-generator settings, shown in a separate macOS window (opened from the
/// panel's gear). Edits the persisted `GeneratorSettingsModel`; the actual "generate
/// + copy" action lives on the panel's single button, not here.
struct GeneratorSettingsView: View {
    @Bindable var settings: GeneratorSettingsModel

    var body: some View {
        Form {
            Picker(L("Mode"), selection: $settings.preferences.usePassphrase) {
                Text(L("Characters")).tag(false)
                Text(L("Passphrase")).tag(true)
            }
            .pickerStyle(.segmented)

            if settings.preferences.usePassphrase {
                Stepper("\(L("Words")): \(settings.preferences.wordCount)",
                        value: $settings.preferences.wordCount, in: 3...10)
                Toggle(L("Capitalize"), isOn: $settings.preferences.capitalize)
                Toggle(L("Add a digit"), isOn: $settings.preferences.includeNumber)
            } else {
                VStack(alignment: .leading) {
                    Text("\(L("Length")): \(settings.preferences.length)")
                    Slider(
                        value: Binding(
                            get: { Double(settings.preferences.length) },
                            set: { settings.preferences.length = Int($0) }
                        ),
                        in: 8...64, step: 1
                    )
                }
                Toggle(L("Lowercase"), isOn: $settings.preferences.useLowercase)
                Toggle(L("Uppercase"), isOn: $settings.preferences.useUppercase)
                Toggle(L("Digits"), isOn: $settings.preferences.useDigits)
                Toggle(L("Symbols"), isOn: $settings.preferences.useSymbols)
                Toggle(L("Exclude ambiguous"), isOn: $settings.preferences.excludeAmbiguous)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 360)
    }
}
