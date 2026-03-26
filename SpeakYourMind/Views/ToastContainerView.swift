import SwiftUI

/// Container view that displays toast notifications overlayed on top of content.
struct ToastContainerView<Content: View>: View {
    let content: Content
    @ObservedObject var feedbackManager: UserFeedbackManager
    
    init(content: Content, feedbackManager: UserFeedbackManager = .shared) {
        self.content = content
        self.feedbackManager = feedbackManager
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            content
            
            VStack(spacing: 8) {
                ForEach(feedbackManager.toasts) { toast in
                    ToastView(toast: toast)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.top, 8)
        }
    }
}

/// Individual toast notification view.
struct ToastView: View {
    @ObservedObject var toast: ToastNotification
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.type.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .frame(width: 280)
        .opacity(toast.opacity)
        .scaleEffect(toast.scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast.opacity)
    }
}
