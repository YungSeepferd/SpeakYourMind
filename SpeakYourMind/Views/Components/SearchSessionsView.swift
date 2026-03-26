import SwiftUI

struct SearchSessionsView: View {
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("Search sessions…", text: $searchQuery)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .frame(maxWidth: .infinity)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
        .keyboardShortcut("f", modifiers: .command)
    }
}
