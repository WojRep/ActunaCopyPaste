import Foundation

/// This module's localization bundle (en/pl/de/es `Localizable.strings`). Exposed so
/// tests can verify the per-language tables; `.module` resolves to the UI module's
/// resource bundle (not the test target's).
let uiBundle = Bundle.module

/// Localized UI string from this module's resource bundle. The system picks the
/// language automatically from the user's preferred languages (en/pl/de/es) — base
/// language is English (the lookup key). See `Resources/*.lproj/Localizable.strings`.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: uiBundle)
}
