#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Accessibility
import UIKit

public struct AccessibilityTarget {
    fileprivate enum Shape {
        case frame(CGRect)

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

    public var label: String?

    public var type: UIAccessibilityTraits

    public var object: NSObject
}

public final class UIKitAccessibilityHierarchyParser {
    public func parseAccessibilityElement(on point: CGPoint, in root: UIView) -> AccessibilityTarget? {
        let accessibilityNodes = root.recursiveAccessibilityHierarchy(on: point, in: root)

        return accessibilityNodes.lazy
            .map { node in
                let (label, type) = node.object.accessibilityDescriptions()
                return AccessibilityTarget(
                    label: label,
                    type: type,
                    object: node.object
                )
            }
            .first
    }
}

private struct AccessibilityNode {
    var object: NSObject
}

private extension NSObject {
    func recursiveAccessibilityHierarchy(on point: CGPoint, in root: UIView) -> [AccessibilityNode] {
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

        guard accessibilityShape(in: root).contains(point) else { return [] }

        var recursiveAccessibilityHierarchy: [AccessibilityNode] = []

        if isAccessibilityElement {
            recursiveAccessibilityHierarchy.append(AccessibilityNode(object: self))

        } else if let accessibilityElements = accessibilityElements as? [NSObject] {
            for element in accessibilityElements {
                recursiveAccessibilityHierarchy.append(
                    contentsOf: element.recursiveAccessibilityHierarchy(on: point, in: root)
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
                    contentsOf: subview.recursiveAccessibilityHierarchy(on: point, in: root)
                )
            }
        }

        return recursiveAccessibilityHierarchy
    }

    func accessibilityShape(in root: UIView) -> AccessibilityTarget.Shape {
        if let accessibilityPath = accessibilityPath {
            return .path(root.convert(accessibilityPath, from: nil))

        } else if let element = self as? UIAccessibilityElement, let container = element.accessibilityContainer, !element.accessibilityFrameInContainerSpace.isNull {
            return .frame(container.convert(element.accessibilityFrameInContainerSpace, to: root))

        } else {
            return .frame(root.convert(accessibilityFrame, from: nil))
        }
    }

    func accessibilityDescriptions() -> (String?, UIAccessibilityTraits) {
        return (accessibilityLabel?.nonEmpty(), accessibilityTraits)
    }
}

private struct AccessibilityInfo {
    let label: String?
    let type: UIAccessibilityTraits
}

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

extension String {
    func nonEmpty() -> String? {
        return isEmpty ? nil : self
    }
}

#endif
