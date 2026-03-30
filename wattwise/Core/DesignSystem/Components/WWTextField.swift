import SwiftUI

struct WWTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
        }
        .textContentType(textContentType)
        .font(WWFont.body())
        .foregroundColor(.wwTextPrimary)
        .submitLabel(submitLabel)
        .onSubmit { onSubmit?() }
        .focused($isFocused)
        .padding(.horizontal, WWSpacing.m)
        .frame(height: 52)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(isFocused ? Color.wwBlue : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Labeled Field

struct WWLabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            Text(label)
                .font(WWFont.caption(.medium))
                .foregroundColor(.wwTextSecondary)
            WWTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType,
                textContentType: textContentType,
                submitLabel: submitLabel,
                onSubmit: onSubmit
            )
        }
    }
}
