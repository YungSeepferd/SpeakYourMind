import SwiftUI

struct LanguagePicker: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var searchText = ""

    /// When true, shows only flag + code (e.g. "🇺🇸 EN"). When false, shows flag + name.
    var compact: Bool = false

    private var filteredLanguages: [Locale] {
        if searchText.isEmpty {
            return speechManager.availableLanguages
        }
        return speechManager.availableLanguages.filter { locale in
            Self.displayName(for: locale)
                .lowercased()
                .contains(searchText.lowercased())
        }
    }

    var body: some View {
        Menu {
            ForEach(filteredLanguages, id: \.identifier) { locale in
                let isSelected = locale.identifier == speechManager.currentLanguage.identifier
                Button {
                    speechManager.currentLanguage = locale
                } label: {
                    // NSMenu ignores HStack — must be a single Text
                    Text("\(Self.flag(for: locale))  \(Self.displayName(for: locale))\(isSelected ? "  ✓" : "")")
                }
            }
        } label: {
            // Same rule: single Text with flag + name combined
            Text("\(Self.flag(for: speechManager.currentLanguage))  \(labelText)  ▾")
                .lineLimit(1)
                .font(DS.Typography.caption.weight(.medium))
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(DS.Colors.surfaceSecondary)
                .cornerRadius(DS.Radius.sm)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Language: \(Self.displayName(for: speechManager.currentLanguage))")
    }

    private var labelText: String {
        if compact {
            return Self.code(for: speechManager.currentLanguage)
        }
        return Self.shortName(for: speechManager.currentLanguage)
    }

    // MARK: - Static Helpers

    /// Two-letter uppercase code, e.g. "EN", "DE"
    static func code(for locale: Locale) -> String {
        (locale.language.languageCode?.identifier ?? "??").uppercased()
    }

    /// Flag emoji for locale
    static func flag(for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? ""
        return flagMap[langCode] ?? "🌐"
    }

    /// Full display name, e.g. "English (United States)"
    static func displayName(for locale: Locale) -> String {
        locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    /// Short display name, e.g. "English" (strips region parenthetical)
    static func shortName(for locale: Locale) -> String {
        let full = displayName(for: locale)
        // Strip anything in parentheses for compact display
        if let parenRange = full.range(of: " (") {
            return String(full[full.startIndex..<parenRange.lowerBound])
        }
        return full
    }

    private static let flagMap: [String: String] = [
        "en": "🇺🇸", "de": "🇩🇪", "fr": "🇫🇷", "es": "🇪🇸",
        "it": "🇮🇹", "pt": "🇧🇷", "ja": "🇯🇵", "zh": "🇨🇳",
        "ko": "🇰🇷", "ru": "🇷🇺", "ar": "🇸🇦", "hi": "🇮🇳",
        "nl": "🇳🇱", "pl": "🇵🇱", "sv": "🇸🇪", "da": "🇩🇰",
        "fi": "🇫🇮", "no": "🇳🇴", "tr": "🇹🇷", "el": "🇬🇷",
        "he": "🇮🇱", "th": "🇹🇭", "vi": "🇻🇳", "id": "🇮🇩",
        "cs": "🇨🇿", "sk": "🇸🇰", "uk": "🇺🇦", "ro": "🇷🇴",
        "hu": "🇭🇺", "hr": "🇭🇷", "bg": "🇧🇬", "ca": "🇪🇸",
        "ms": "🇲🇾"
    ]
}
