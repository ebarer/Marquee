//
//  EmojiField.swift
//  MovieTracker
//
//  A zero-size text field used to pick a single emoji for a list icon. UIKit has
//  no public "emoji picker", so this forces the emoji keyboard by reporting the
//  emoji input mode, then grabs the first emoji typed and dismisses itself.
//

import SwiftUI
import UIKit

struct EmojiField: UIViewRepresentable {
    /// Set true to raise the emoji keyboard; cleared once an emoji is picked or
    /// the keyboard is dismissed.
    @Binding var isActive: Bool
    /// Called with the chosen emoji.
    var onPick: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.autocorrectionType = .no
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        if isActive, !field.isFirstResponder {
            field.text = ""
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isActive, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            // Ignore deletions; on the first emoji, report it and dismiss.
            guard let character = string.first else { return false }
            parent.onPick(String(character))
            DispatchQueue.main.async { [parent] in
                textField.resignFirstResponder()
                parent.isActive = false
            }
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isActive { parent.isActive = false }
        }
    }
}

/// A text field that only offers the emoji keyboard.
final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }
}
