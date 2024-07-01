import Accessibility
import UIKit

public struct AccessibilityTarget {

    // MARK: - Public Types

    public enum Shape {

        /// Accessibility frame, in the coordinate space of the view being processed.
        case frame(CGRect)

        /// Accessibility path, in the coordinate space of the view being processed.
        case path(UIBezierPath)

        public func contains(_ point: CGPoint) -> Bool {
            switch self {
            case .frame(let frame):
                return frame.contains(point)
            case .path(let path):
                return path.contains(point)
            }
        }

    }

    // MARK: - Public Properties

    /// The label of the accessibility element similar to a description read by VoiceOver when the element is brought into
    /// focus.
    public var label: String?

    /// The value of the accessibility element similar to a description read by VoiceOver when the element is brought into
    /// focus.
    public var value: String?

    /// The type of the accessibility element similar to a description read by VoiceOver when the element is brought into
    /// focus.
    public var type: UIAccessibilityTraits

    /// The labels that will be used for user input.
    public var userInputLabels: [String]?

    /// The shape that will be highlighted on screen while the element is in focus.
    public var shape: Shape

    /// The object representing the accessibility node.
    public var object: NSObject
}

// MARK: -

/// `AccessibilityHierarchyParser` replicates how assitive technologies such as VoiceOver traverse the accessibility hierarchy to
/// extract accessibility metadata.
public final class AccessibilityHierarchyParser {

    // MARK: - Life Cycle

    public init() {}

    // MARK: - Public Methods

    public func parseAccessibilityElements(
        in root: UIView
    ) -> [AccessibilityTarget] {
        let accessibilityNodes = root.recursiveAccessibilityHierarchy()

        return accessibilityNodes.map { node in
            let description = node.object.accessibilityDescriptions()
            let (label, value, type) = (description.label, description.value, description.type)

            let userInputLabels: [String]? = {
                guard
                    node.object.accessibilityRespondsToUserInteraction,
                    let userInputLabels = node.object.accessibilityUserInputLabels,
                    !userInputLabels.isEmpty
                else {
                    return nil
                }

                return userInputLabels
            }()

            return AccessibilityTarget(
                label: label,
                value: value,
                type: type,
                userInputLabels: userInputLabels,
                shape: accessibilityShape(for: node.object, in: root),
                object: node.object
            )
        }
    }

    // MARK: - Private Methods

    /// Returns the shape of the accessibility element in the root view's coordinate space.
    private func accessibilityShape(for element: NSObject, in root: UIView) -> AccessibilityTarget.Shape {
        if let accessibilityPath = element.accessibilityPath {
            return .path(root.convert(accessibilityPath, from: nil))

        } else if let element = element as? UIAccessibilityElement, let container = element.accessibilityContainer, !element.accessibilityFrameInContainerSpace.isNull {
            return .frame(container.convert(element.accessibilityFrameInContainerSpace, to: root))

        } else {
            return .frame(root.convert(element.accessibilityFrame, from: nil))
        }
    }

}

// MARK: -

private struct AccessibilityNode {

    /// Represents a single accessibility element.
    var object: NSObject

}

// MARK: -

private extension NSObject {

    /// Recursively parses the accessibility elements/containers on the screen.
    func recursiveAccessibilityHierarchy() -> [AccessibilityNode] {
        guard !accessibilityElementsHidden else {
            return []
        }

        // Ignore elements that are views if they are not visible on the screen, either due to visibility, size, or
        // alpha. VoiceOver actually has some very low alpha threshold at which it will still display an element
        // (presumably to account for animations and/or rounding error). We use an alpha threshold of zero since that
        // should fulfill the intent.
        if let `self` = self as? UIView, self.isHidden || self.frame.size == .zero || self.alpha <= 0 {
            return []
        }

        var recursiveAccessibilityHierarchy: [AccessibilityNode] = []

        if isAccessibilityElement {
            recursiveAccessibilityHierarchy.append(AccessibilityNode(object: self))

        } else if let accessibilityElements = accessibilityElements as? [NSObject] {
            for element in accessibilityElements {
                recursiveAccessibilityHierarchy.append(
                    contentsOf: element.recursiveAccessibilityHierarchy()
                )
            }

        } else if let `self` = self as? UIView {
            // If there is at least one modal subview, the last modal is the only subview parsed in the accessibility
            // hierarchy. Otherwise, parse all of the subviews.
            let subviewsToParse: [UIView]
            if let lastModalView = self.subviews.last(where: { $0.accessibilityViewIsModal }) {
                subviewsToParse = [lastModalView]
            } else {
                subviewsToParse = self.subviews
            }

            for subview in subviewsToParse {
                recursiveAccessibilityHierarchy.append(
                    contentsOf: subview.recursiveAccessibilityHierarchy()
                )
            }

        }

        return recursiveAccessibilityHierarchy
    }

    func accessibilityDescriptions() -> AccessibilityInfo {
        return AccessibilityInfo(
            label: accessibilityLabel?.nonEmpty(),
            value: accessibilityValue?.nonEmpty(),
            type: accessibilityTraits
        )
    }

}

// MARK: -

private struct AccessibilityInfo {
    let label: String?
    let value: String?
    let type: UIAccessibilityTraits
}

// MARK: -

extension UIView {

    func convert(_ path: UIBezierPath, from source: UIView?) -> UIBezierPath {
        let offset = convert(CGPoint.zero, from: source)
        let transform = CGAffineTransform(translationX: offset.x, y: offset.y)

        guard let newPath = path.copy() as? UIBezierPath else {
            return UIBezierPath()
        }

        newPath.apply(transform)
        return newPath
    }

}

// MARK: -

extension String {

    /// Returns the string if it is non-empty, otherwise nil.
    func nonEmpty() -> String? {
        return isEmpty ? nil : self
    }

}
