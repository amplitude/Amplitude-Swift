#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

internal final class TextFieldDelegateWrapper: NSObject, UITextFieldDelegate {

    // MARK: - Private Properties

    /// The delegate that manages user interactions options.
    private weak var userInteractionCaptureDelegate: UserInteractionCaptureDelegate?

    /// The original delegate of the `UITextField` target. This could be `nil` if there is no delegate.
    private weak var existingDelegate: UITextFieldDelegate?

    /// The accessibility metadata of the `UITextField` target.
    private var accessibilityTarget: AccessibilityTarget

    /// The content of the field when it gains focuse.
    private var previousContent: String?

    // MARK: - Life Cycle

    init(_ userInteractionCaptureDelegate: UserInteractionCaptureDelegate, _ existingDelegate: UITextFieldDelegate?, accessibilityTarget: AccessibilityTarget) {
        self.userInteractionCaptureDelegate = userInteractionCaptureDelegate
        self.existingDelegate = existingDelegate
        self.accessibilityTarget = accessibilityTarget
    }

    // MARK: - Public Methods

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        existingDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        existingDelegate?.textFieldDidBeginEditing?(textField)

        guard
            let captureDelegate = userInteractionCaptureDelegate
        else {
            return
        }

        previousContent = textField.text

        captureDelegate.amplitude?.track(event: UserInteractionEvent(
            .focusGained,
            label: accessibilityTarget.label,
            value: nil,
            type: accessibilityTarget.type))
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        existingDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        existingDelegate?.textFieldDidEndEditing?(textField)

        guard
            let captureDelegate = userInteractionCaptureDelegate
        else {
            return
        }

        captureDelegate.amplitude?.track(event: UserInteractionEvent(
            previousContent != textField.text ? .focusLost(didTextFieldChange: true) : .focusLost(),
            label: accessibilityTarget.label,
            value: nil,
            type: accessibilityTarget.type))
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        existingDelegate?.textFieldDidEndEditing?(textField, reason: reason)

        guard
            let captureDelegate = userInteractionCaptureDelegate
        else {
            return
        }

        captureDelegate.amplitude?.track(event: UserInteractionEvent(
            previousContent != textField.text ? .focusLost(didTextFieldChange: true) : .focusLost(),
            label: accessibilityTarget.label,
            value: nil,
            type: accessibilityTarget.type))
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        existingDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        existingDelegate?.textFieldDidChangeSelection?(textField)
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        existingDelegate?.textFieldShouldClear?(textField) ?? true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        existingDelegate?.textFieldShouldReturn?(textField) ?? true
    }

    @available(iOS 16.0, *)
    func textField(_ textField: UITextField, editMenuForCharactersIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        existingDelegate?.textField?(textField, editMenuForCharactersIn: range, suggestedActions: suggestedActions)
    }

    @available(iOS 16.0, *)
    func textField(_ textField: UITextField, willPresentEditMenuWith animator: any UIEditMenuInteractionAnimating) {
        existingDelegate?.textField?(textField, willPresentEditMenuWith: animator)
    }

    @available(iOS 16.0, *)
    func textField(_ textField: UITextField, willDismissEditMenuWith animator: any UIEditMenuInteractionAnimating) {
        existingDelegate?.textField?(textField, willDismissEditMenuWith: animator)
    }
}

#endif
