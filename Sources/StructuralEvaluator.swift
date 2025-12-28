//
//  StructuralEvaluator.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 23/10/16.
//

import Foundation

/**
 Base structural evaluator.
 */
public class StructuralEvaluator: Evaluator, @unchecked Sendable {
    let evaluator: Evaluator

    public init(_ evaluator: Evaluator) {
        self.evaluator = evaluator
    }

    public class Root: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element) -> Bool {
            return root === element
        }
    }

    public class Has: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            var stack: [Element] = []
            let children = element.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    if let childEl = child as? Element {
                        stack.append(childEl)
                    }
                }
            }
            while let current = stack.popLast() {
                do {
                    if try evaluator.matches(root, current) {
                        return true
                    }
                } catch {}
                let currentChildren = current.childNodes
                if !currentChildren.isEmpty {
                    for child in currentChildren.reversed() {
                        if let childEl = child as? Element {
                            stack.append(childEl)
                        }
                    }
                }
            }
            return false
        }

        public override func toString() -> String {
            return ":has(\(evaluator.toString()))"
        }
    }

    public class Not: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ node: Element) -> Bool {
            do {
                return try !evaluator.matches(root, node)
            } catch {}
            return false
        }

        public override func toString() -> String {
            return ":not\(evaluator.toString())"
        }
    }

    public class Parent: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ element: Element) -> Bool {
            if (root == element) {
                return false
            }

            var parent = element.parent()
            while (true) {
                do {
                    if let p = parent, try evaluator.matches(root, p) {
                        return true
                    }
                } catch {}

                if (parent == root) {
                    break
                }
                parent = parent?.parent()
            }
            return false
        }

        public override func toString() -> String {
            return ":parent\(evaluator.toString())"
        }
    }

    public class ImmediateParent: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ element: Element) -> Bool {
            if (root == element) {
                return false
            }

            if let parent = element.parent() {
                do {
                    return try evaluator.matches(root, parent)
                } catch {}
            }

            return false
        }

        public override func toString() -> String {
            return ":ImmediateParent\(evaluator.toString())"
        }
    }

    public class PreviousSibling: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if (root == element) {
            return false
            }

            var prev = try element.previousElementSibling()

            while (prev != nil) {
                do {
                if (try evaluator.matches(root, prev!)) {
                    return true
                }
                } catch {}

                prev = try prev!.previousElementSibling()
            }
            return false
        }

        public override func toString() -> String {
            return ":prev*\(evaluator.toString())"
        }
    }

    class ImmediatePreviousSibling: StructuralEvaluator, @unchecked Sendable {
        public override init(_ evaluator: Evaluator) {
            super.init(evaluator)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if (root == element) {
                return false
            }

            if let prev = try element.previousElementSibling() {
                do {
                    return try evaluator.matches(root, prev)
                } catch {}
            }
            return false
        }

        public override func toString() -> String {
            return ":prev\(evaluator.toString())"
        }
    }
}
