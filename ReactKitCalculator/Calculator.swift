//
//  Calculator.swift
//  ReactKitCalculator
//
//  Created by Yasuhiro Inami on 2015/02/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import ReactKit

/// mimics iOS's Calculator.app
public class Calculator
{
    public enum Key: String
    {
        case Num0 = "0", Num1 = "1", Num2 = "2", Num3 = "3", Num4 = "4", Num5 = "5", Num6 = "6", Num7 = "7", Num8 = "8", Num9 = "9"
        case Point = "."
        case PlusMinus = "±", Percent = "%"
        
        case Equal = "="
        case Plus = "+", Minus = "-", Multiply = "*", Divide = "/"
        case Clear = "C", AllClear = "AC"
        
        public static func allKeys() -> [Key]
        {
            return self.numBuildKeys() + self.arithOperatorKeys() + self.clearKeys() + [.Equal]
        }
        
        public static func numKeys() -> [Key]
        {
            return [ .Num0, .Num1, .Num2, .Num3, .Num4, .Num5, .Num6, .Num7, .Num8, .Num9, .Point ]
        }
        
        public static func numBuildKeys() -> [Key]
        {
            return self.numKeys() + self.unaryOperators()
        }
        
        public static func unaryOperators() -> [Key]
        {
            return [ .PlusMinus, .Percent ]
        }
        
        /// arithmetic operator keys
        public static func arithOperatorKeys() -> [Key]
        {
            return [ .Plus, .Minus, .Multiply, .Divide ]
        }
        
        public static func clearKeys() -> [Key]
        {
            return [ .Clear, .AllClear ]
        }
        
        public var precedence: Int8
        {
            switch self {
                case .Multiply, .Divide:
                    return 2
                case .Plus, .Minus:
                    return 1
                default:
                    return 0
            }
        }
        
        /// for arithmetic operation
        public func evaluate(a: Double)(_ b: Double) -> Double
        {
            switch self {
                case .Plus:
                    return b + a
                case .Minus:
                    return b - a
                case .Multiply:
                    return b * a
                case .Divide:
                    return b / a
                default:
                    return a
            }
        }
        
        /// for unary operation
        public func evaluate(a: Double) -> Double
        {
            switch self {
                case .PlusMinus:
                    return -a
                case .Percent:
                    return a * 0.01
                default:
                    return a
            }
        }
    }
    
    /// maps `Key` to `Stream<Void>`, then converts to `keyStreams: [Stream<Key>]`
    public class Mapper
    {
        private var _keyMap: [Key : Stream<Void>] = [:]
        
        public subscript(key: Key) -> Stream<Void>?
        {
            get {
                return self._keyMap[key]
            }
            set(newStream) {
                self._keyMap[key] = newStream
            }
        }
        
        internal func keyStreams() -> [Stream<Key>]
        {
            var keyStreams: [Stream<Key>] = []
            for (key, stream) in self._keyMap {
                keyStreams.append(stream |> map { key })
            }
            return keyStreams
        }
    }
    
    /// TODO: implement `bracketLevel` feature
    internal enum _Token: CustomStringConvertible, CustomDebugStringConvertible
    {
        typealias OperatorTuple = (key: Key, calculatedValue: Double, bracketLevel: Int)
        
        case Number(Double)
        case Operator(Key, calculatedValue: Double, bracketLevel: Int)
        
        var number: Double?
        {
            switch self {
                case .Number(let value): return value
                default: return nil
            }
        }
        
        var operatorTuple: OperatorTuple?
        {
            switch self {
                case .Operator(let tuple): return tuple
                default: return nil
            }
        }
        
        var operatorKey: Key?
        {
            return self.operatorTuple?.key ?? nil
        }
        
        var operatorCalculatedValue: Double?
        {
            return self.operatorTuple?.calculatedValue ?? nil
        }
        
        var operatorBracketLevel: Int?
        {
            return self.operatorTuple?.bracketLevel ?? nil
        }
        
        var description: String
        {
            switch self {
                case .Number(let value):
                    return "`\(value)`"
                case .Operator(let tuple):
                    return "`\(tuple.0.rawValue)`"
            }
        }
        
        var debugDescription: String
        {
            switch self {
                case .Number(let value):
                    return "<Token.Number; value=\(value)>"
                case .Operator(let tuple):
                    return "<Token.Operator; key=`\(tuple.0.rawValue)`; calc=\(tuple.calculatedValue); level=\(tuple.bracketLevel)>"
            }
        }
    }
    
    internal class _Buffer: CustomStringConvertible
    {
        var tokens: [_Token] = []
        var lastAnswer: Double = 0
        var lastArithKey: Key = .Equal
        var lastArithValue: Double = 0
        
        var description: String
        {
            return "<_Buffer; tokens=\(tokens); lastAnswer=\(lastAnswer); lastArithKey=`\(lastArithKey.rawValue)`; lastArithValue=\(lastArithValue)>"
        }
        
        func addNumber(value: Double)
        {
            // remove last number-token if needed
            if self.tokens.last?.number != nil {
                self.tokens.removeLast()
            }
            
            self.tokens.append(_Token.Number(value))
            
            // update lastArithValue if needed
            if self.tokens.count > 1 && Key.arithOperatorKeys().contains(self.lastArithKey) {
                self.lastArithValue = value
            }
        }
        
        func clear()
        {
            self.lastAnswer = 0
        }
        
        func allClear()
        {
            self.tokens.removeAll(keepCapacity: false)
            self.lastAnswer = 0
            self.lastArithKey = .Equal
            self.lastArithValue = 0
        }
    }
    
    /// a.k.a mergedKeyStream
    public internal(set) var inputStream: Stream<Key>!
    
    /// retro-calculator (single-lined & narrow display) output
    public internal(set) var outputStream: Stream<String?>!
    
    /// realtime buffering stream
    public internal(set) var expressionStream: Stream<String?>!
    
    private let mapper = Mapper()
    
    
    public init(initClosure: Mapper -> Void)
    {
        // pass `self.mapper` to collect keyStreams via `initClosure`
        initClosure(self.mapper)
        
        let mergedKeyStream = self.mapper.keyStreams() |> mergeAll
        
        ///
        /// sends digit-accumulated numString
        ///
        /// e.g. `1 2 + 3 + * 4 =` will send:
        ///
        /// - [t = 1] "1"
        /// - [t = 2] "12"
        /// - [t = 3] (none)
        /// - [t = 4] "3"
        /// - [t = 5] (none)
        /// - [t = 6] (none)
        /// - [t = 7] "4"
        /// - [t = 8] (none)
        ///
        let numBuildStream: Stream<String?> =
            mergedKeyStream
                |> mapAccumulate(nil) { (accumulatedString, newKey) -> String? in
                    
                    let acc = (accumulatedString ?? Key.Num0.rawValue)
                    
                    switch newKey {
                        case .Point:
                            if acc.rangeOfString(Key.Point.rawValue) != nil {
                                return acc    // don't add another `.Point` if already exists
                            }
                            else {
                                return acc + newKey.rawValue
                            }
                        
                        // numKey except `.Point` (NOTE: `case .Point` declared above)
                        case let numKey where Key.numKeys().contains(numKey):
                            if acc == Key.Minus.rawValue + Key.Num0.rawValue {
                                return Key.Minus.rawValue + newKey.rawValue  // e.g. "-0" then "1" will be "-1"
                            }
                            else if acc == Key.Num0.rawValue {
                                return newKey.rawValue  // e.g. "0" then "1" will be "1"
                            }
                            else {
                                return (accumulatedString ?? "") + newKey.rawValue // e.g. "12" then "3" will be "123"
                            }
                        
                        case .PlusMinus:
                            // comment-out: iOS Calculator.app evaluates `.PlusMinus` with string-based, not double-based (especially important when `.Point` is suffixed)
                            //return newKey.evaluate(acc.doubleValue).calculatorString
                        
                            // string-based toggling of prefixed "-"
                            if acc.hasPrefix(Key.Minus.rawValue) {
                                return acc.substringFromIndex(acc.startIndex.advancedBy(1))
                            }
                            else {
                                return Key.Minus.rawValue + acc
                            }
                        
                        // NOTE: this unaryKey will not contain `.PlusMinus` as `case .PlusMinus` is declared above
                        case let unaryKey where Key.unaryOperators().contains(unaryKey):
                            return newKey.evaluate((acc as NSString).doubleValue).calculatorString
                        
                        // comment-out: don't send "0" because it will confuse with `Key.Num0` input
//                        case .Clear:
//                            return Key.Num0.rawValue    // clear to 0
                        
                        default:
                            // clear previous accumulatedString
                            // (NOTE: don't send "" which will cause forthcoming stream-operations to convert to 0.0 via `str.doubleValue`)
                            return nil
                    }
                }
                |> filter { $0 != nil }
                |> peek { print("numBuildStream ---> \($0)") }
        
        let numTokenStream: Stream<_Token> =
            numBuildStream
                |> map { _Token.Number(($0! as NSString).doubleValue) }
        
        let operatorKeyTokenStream: Stream<_Token> =
            mergedKeyStream
                |> filter { !Key.numBuildKeys().contains($0) }
                |> map { _Token.Operator($0, calculatedValue: 0, bracketLevel: 0) }
        
        /// numTokenStream + operatorKeyTokenStream
        let tokenStream: Stream<_Token> =
            numTokenStream
                |> merge(operatorKeyTokenStream)
                |> peek { print(""); print("tokenStream ---> \($0)") }
        
        ///
        /// Quite complex stream-operation using `customize()` to encapsulate `buffer`
        /// and send its `buffer.tokens`.
        ///
        /// (TODO: break down this mess into smaller fundamental operations)
        ///
        let bufferingTokensStream: Stream<[_Token]> =
            tokenStream
                |> customize { upstream, progress, fulfill, reject in
                    
                    let _b = _Buffer()  // buffer
                    
                    upstream.react { (newToken: _Token) in
                        
                        print("[progress] newToken = \(newToken)")
                        print("[progress] buffer = \(_b)")
                        
                        assert(_b.tokens.find { $0.operatorKey != nil && $0.operatorKey! == Key.Equal } == nil, "`buffer.tokens` should not contain `.Equal`.")
                        
                        switch newToken {
                            
                            case .Number(let newValue):
                                _b.addNumber(newValue)
                                
                                // send stream value
                                progress(_b.tokens)
                            
                            case .Operator(let newOperatorKey, _, _):
                                
                                switch newOperatorKey {
                                    
                                    case .Clear:
                                        _b.clear()
                                        _b.addNumber((Key.Num0.rawValue as NSString).doubleValue)
                                    
                                    case .AllClear:
                                        _b.allClear()
                                    
                                    default:
                                        // use lastAnswer if `_b.tokens` are empty
                                        if _b.tokens.count == 0 {
                                            _b.tokens.append(_Token.Number(_b.lastAnswer))
                                        }
                                        
                                        // use `_b.lastArithKey` & `_b.lastArithValue` e.g. `2 + 3 = 4 =` will print `7`
                                        if _b.tokens.count == 1 && newOperatorKey == .Equal && Key.arithOperatorKeys().contains(_b.lastArithKey) {
                                            let lastNumber = _b.tokens.last!.number!
                                            _b.tokens.append(_Token.Operator(_b.lastArithKey, calculatedValue: lastNumber, bracketLevel: 0))
                                            _b.tokens.append(_Token.Number(_b.lastArithValue))
                                        }
                                            
                                        // append/remove token if consecutive operatorKeys
                                        if let lastOperatorCalculatedValue = _b.tokens.last?.operatorCalculatedValue {
                                            if newOperatorKey == .Equal {   // force-equal: e.g. `+` then `=`
                                                // fill lastOperatorCalculatedValue (displaying value) before Equal-calculation
                                                _b.tokens.append(_Token.Number(lastOperatorCalculatedValue))
                                                
                                                _b.lastArithValue = lastOperatorCalculatedValue   // update lastArithValue
                                            }
                                            else {  // operator change: e.g. `+` then `*`
                                                _b.tokens.removeLast()
                                            }
                                        }
                                        
                                        print("prepared tokens = \(_b.tokens)")
                                        
                                        assert(_b.tokens.last?.number != nil, "`buffer.tokens.last` should have number.")
                                        let lastNumber = _b.tokens.last!.number!
                                        
                                        //
                                        // append new operatorKey-token
                                        // (TODO: consider operatorBracketLevel)
                                        //
                                        let prevOperatorToken = _b.tokens.reverse().find {
                                            $0.operatorKey != nil && $0.operatorBracketLevel == newToken.operatorBracketLevel
                                        }
                                        print("prevOperatorToken = \(prevOperatorToken)")
                                        
                                        if let prevOperatorKey = prevOperatorToken?.operatorKey {
                                        
                                            // if moving to higher precedence, e.g. `3 + 4 *`
                                            if newOperatorKey.precedence > prevOperatorKey.precedence {
                                                let token = _Token.Operator(newOperatorKey, calculatedValue: lastNumber, bracketLevel: 0)
                                                _b.tokens.append(token)
                                            }
                                            else {
                                                // calculate `calculatedValue`
                                                
                                                var calculatedValue: Double = lastNumber
                                                var maxPrecedence = Int8.max
                                                
                                                // look for past operators and precalculate if possible
                                                for pastToken in _b.tokens.reverse() {
                                                    if let pastOperatorTuple = pastToken.operatorTuple {
                                                        
                                                        let pastOperatorPrecedence = pastOperatorTuple.key.precedence
                                                        if pastOperatorPrecedence < newOperatorKey.precedence || pastOperatorPrecedence <= Key.Equal.precedence {
                                                            break   // stop: no need to precalculate for lower precedence
                                                        }
                                                        
                                                        if pastOperatorPrecedence < maxPrecedence {
                                                            let beforeCalculatedValue = calculatedValue
                                                            calculatedValue = pastOperatorTuple.key.evaluate(calculatedValue)(pastOperatorTuple.calculatedValue)
                                                            print("[precalculate] \(beforeCalculatedValue) -> (\(pastOperatorTuple.key.rawValue), \(pastOperatorTuple.calculatedValue)) -> \(calculatedValue)")
                                                            maxPrecedence = pastOperatorPrecedence
                                                        }
                                                    }
                                                }
                                                
                                                // append new operatorKey
                                                _b.tokens.append(_Token.Operator(newOperatorKey, calculatedValue: calculatedValue, bracketLevel: 0))
                                            }
                                            
                                        }
                                        // if no prevOperatorKey
                                        else {
                                            // append new operatorKey
                                            _b.tokens.append(_Token.Operator(newOperatorKey, calculatedValue: lastNumber, bracketLevel: 0))
                                        }
                                        
                                        // update lastArithKey
                                        if Key.arithOperatorKeys().contains(newOperatorKey) {
                                            _b.lastArithKey = newOperatorKey
                                        }
                                        
                                        break // default
                                    
                                }   // switch newOperatorKey
                                
                                // send stream value
                                progress(_b.tokens)
                                
                                if newOperatorKey == .Equal {
                                    if let answer = _b.tokens.last?.operatorCalculatedValue {
                                        _b.lastAnswer = answer
                                    }
                                    
                                    _b.tokens.removeAll(keepCapacity: false)
                                }
                            
                                break // case .Operator:
                            
                        }   // switch newToken
                    }
                }
                |> peek { print("bufferingTokensStream ---> \($0)") }
        
        let precalculatingStream: Stream<String?> =
            bufferingTokensStream
                |> map { ($0.last?.operatorCalculatedValue ?? 0).calculatorString }
                |> peek { print("precalculatingStream ---> \($0)") }
        
        self.inputStream = mergedKeyStream
        
        self.outputStream =
            numBuildStream
                |> map { _calculatorString(raw: $0!, rtrims: false) }   // output `calculatorString` to show commas & exponent, and also suffixed `.Point`+`.Num0`s if needed
                |> merge(precalculatingStream)
                |> peek { print("outputStream ---> \($0)") }
        
        self.expressionStream =
            bufferingTokensStream
                |> map { (tokens: [_Token]) in
                    // NOTE: explicitly declare `acc` & `token` type, or Swift compiler will take too much time for compiling
                    return tokens.reduce("") { (acc: String, token: _Token) -> String in
                        return acc + (token.number?.calculatorString ?? token.operatorKey?.rawValue ?? "") + " "
                    }
                }
                |> peek { print("expressionStream ---> \($0)") }
    }
    
    deinit
    {
        print("[deinit] \(self)")
    }
}