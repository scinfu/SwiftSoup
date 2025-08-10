//
//  CombiningEvaluator.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 23/10/16.
//

import Foundation

/**
 * Base combining (and, or) evaluator.
 */
public class CombiningEvaluator: Evaluator {

    public private(set) var evaluators: Array<Evaluator>

    public override init() {
        evaluators = Array<Evaluator>()
        super.init()
    }

    public init(_ evaluators: Array<Evaluator>) {
        self.evaluators = evaluators
        super.init()
    }

    public init(_ evaluators: Evaluator...) {
        self.evaluators = evaluators
        super.init()
    }

    func rightMostEvaluator() -> Evaluator? {
        return evaluators.last
    }

    func replaceRightMostEvaluator(_ replacement: Evaluator) {
        evaluators[evaluators.count - 1] = replacement
    }

    public final class And: CombiningEvaluator {
        
        public override func matches(_ root: Element, _ node: Element) -> Bool {
            for evaluator in self.evaluators {
                do {
                    if (try !evaluator.matches(root, node)) {
                        return false
                    }
                } catch {}
            }

            return true
        }

        public override func toString() -> String {
            let array: [String] = evaluators.map { String($0.toString()) }
            return StringUtil.join(array, sep: " ")
        }
    }

    public final class Or: CombiningEvaluator {
        
        public func add(_ evaluator: Evaluator) {
            evaluators.append(evaluator)
        }

        public override func matches(_ root: Element, _ node: Element) -> Bool {
            for evaluator in self.evaluators {
                do {
                    if (try evaluator.matches(root, node)) {
                        return true
                    }
                } catch {}
            }
            return false
        }

        public override func toString() -> String {
            return ":or\(evaluators.map {String($0.toString())})"
        }
    }
}
