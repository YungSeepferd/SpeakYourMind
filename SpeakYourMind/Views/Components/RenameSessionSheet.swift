import SwiftUI

struct RenameSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String
    
    let session: RecordingSession
    let onSave: (String) -> Void
    
    init(session: RecordingSession, onSave: @escaping (String) -> Void) {
        self.session = session
        self.onSave = onSave
        _newName = State(initialValue: session.customTitle ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Session")
                .font(.headline)
            
            TextField("Session name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit {
                    onSave(newName)
                    dismiss()
                }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    onSave(newName)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320, height: 140)
    }
}
