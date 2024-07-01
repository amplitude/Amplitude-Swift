import UIKit

public class UserInteractionEvent: BaseEvent {

    public enum InteractionValue {
        case tap(dead: Bool = false)
        case longPress(dead: Bool = false)
        case rageTap
        case focusGained
        case focusLost(didTextFieldChange: Bool = false)
        case sliderChanged(to: Int)

        var description: String {
            switch self {
            case .tap(let dead): return dead ? "Dead Tapped" : "Tapped"
            case .longPress(let dead): return dead ? "Dead Long Pressed" : "Long Pressed"
            case .rageTap: return "Rage Tapped"
            case .focusGained: return "Focus Gained"
            case .focusLost(let didTextFieldChange):
                return didTextFieldChange ? "Focus Lost After Text Modification" : "Focus Lost"
            case .sliderChanged(let percentage):
                return "Value Changed To \(percentage)%"
            }
        }
    }

    convenience init(_ interactionValue: InteractionValue, label: String? = nil, value: String? = nil, type: UIAccessibilityTraits = .none) {
        self.init(eventType: Constants.AMP_USER_INTERACTION_EVENT, eventProperties: [
            Constants.AMP_INTERACTION_PROPERTY: interactionValue.description,
            Constants.AMP_ELEMENT_LABEL_PROPERTY: label,
            Constants.AMP_ELEMENT_VALUE_PROPERTY: value,
            Constants.AMP_ELEMENT_TYPE_PROPERTY: type.stringify()
        ])
    }
}

extension UIAccessibilityTraits {
    func stringify() -> String? {
        var strings = [String]()
        if contains(.adjustable) { strings.append("Adjustable") }
        if contains(.allowsDirectInteraction) { strings.append("Allows Direct Interaction") }
        if contains(.button) { strings.append("Button") }
        if contains(.causesPageTurn) { strings.append("Causes Page Turn") }
        if contains(.header) { strings.append("Header") }
        if contains(.image) { strings.append("Image") }
        if contains(.keyboardKey) { strings.append("Keyboard Key") }
        if contains(.link) { strings.append("Link") }
        if contains(.notEnabled) { strings.append("Not Enabled") }
        if contains(.playsSound) { strings.append("Plays Sound") }
        if contains(.searchField) { strings.append("Search Field") }
        if contains(.selected) { strings.append("Selected") }
        if contains(.startsMediaSession) { strings.append("Starts Media Session") }
        if contains(.staticText) { strings.append("Static Text") }
        if contains(.summaryElement) { strings.append("Summary Element") }
        if contains(.tabBar) { strings.append("Tab Bar") }
        if contains(.updatesFrequently) { strings.append("Updates Frequently") }

        return strings.isEmpty ? nil : strings.joined(separator: ", ")
    }
}
