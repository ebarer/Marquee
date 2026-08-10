//
//  EmojiField.swift
//  MovieTracker
//

import SwiftUI
import UIKit

/// Picks a single emoji for a list icon. UIKit has no public emoji picker, so this
/// forces the emoji keyboard, grabs the first emoji typed, and dismisses itself.
struct EmojiField: UIViewRepresentable {
    @Binding var isActive: Bool
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
            // Ignore deletions; on the first emoji, dismiss the keyboard first,
            // then report it. Resigning before mutating SwiftUI state matters: the
            // field lives inside a List row, so picking the emoji queues a List
            // diff — if the field is still first responder when the keyboard
            // teardown forces that batch update, UICollectionView aborts with a
            // "first responder inside a deleted section refused to resign" assert.
            guard let character = string.first else { return false }
            let emoji = String(character)
            DispatchQueue.main.async { [parent] in
                textField.resignFirstResponder()
                parent.isActive = false
                parent.onPick(emoji)
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
