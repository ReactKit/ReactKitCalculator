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
    public enum Key: NSString
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
        
        // TODO: remove "b:" label for Swift 1.2
        /// for arithmetic operation
        public func evaluate(a: Double)(b: Double) -> Double
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
    
    /// maps `Key` to `Signal<Void>`, then converts to `keySignals: [Signal<Key>]`
    public class Mapper
    {
        private var _keyMap: [Key : Signal<Void>] = [:]
        
        public subscript(key: Key) -> Signal<Void>?
        {
            get {
                return self._keyMap[key]
            }
            set(newSignal) {
                self._keyMap[key] = newSignal
            }
        }
        
        internal func keySignals() -> [Signal<Key>]
        {
            var keySignals: [Signal<Key>] = []
            for (key, signal) in self._keyMap {
                keySignals.append(signal.map { key })
            }
            return keySignals
        }
    }
    
    /// TODO: implement `bracketLevel` feature
    internal enum _Token: Printable, DebugPrintable
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
    
    internal class _Buffer: Printable
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
            if self.tokens.count > 1 && contains(Key.arithOperatorKeys(), self.lastArithKey) {
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
    
    /// a.k.a mergedKeySignal
    public internal(set) var inputSignal: Signal<Key>!
    
    /// retro-calculator (single-lined & narrow display) output
    public internal(set) var outputSignal: Signal<NSString?>!
    
    /// realtime buffering signal
    public internal(set) var expressionSignal: Signal<NSString?>!
    
    private let mapper = Mapper()
    
    
    public init(initClosure: Mapper -> Void)
    {
        // pass `self.mapper` to collect keySignals via `initClosure`
        initClosure(self.mapper)
        
        let mergedKeySignal = Signal<Key>.merge(self.mapper.keySignals())
        
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
        let numBuildSignal: Signal<NSString?> =
            mergedKeySignal
                .mapAccumulate(nil) { (accumulatedString, newKey) -> NSString? in
                    
                    let acc = (accumulatedString ?? Key.Num0.rawValue)
                    
                    switch newKey {
                        case .Point:
                            if acc.containsString(Key.Point.rawValue) {
                                return acc    // don't add another `.Point` if already exists
                            }
                            else {
                                return acc + newKey.rawValue
                            }
                        
                        // numKey except `.Point` (NOTE: `case .Point` declared above)
                        case let numKey where contains(Key.numKeys(), numKey):
                            if acc == Key.Num0.rawValue {
                                return newKey.rawValue  // e.g. "0" -> "1" will be "1"
                            }
                            else {
                                return (accumulatedString ?? "")  + newKey.rawValue // e.g. "12" -> "3" will be "123"
                            }
                        
                        case .PlusMinus:
                            // comment-out: iOS Calculator.app evaluates `.PlusMinus` with string-based, not double-based (especially important when `.Point` is suffixed)
                            //return newKey.evaluate(acc.doubleValue).calculatorString
                        
                            // string-based toggling of prefixed "-"
                            if acc.hasPrefix(Key.Minus.rawValue) {
                                return acc.substringFromIndex(1)
                            }
                            else {
                                return Key.Minus.rawValue + acc
                            }
                        
                        // NOTE: this unaryKey will not contain `.PlusMinus` as `case .PlusMinus` is declared above
                        case let unaryKey where contains(Key.unaryOperators(), unaryKey):
                            return newKey.evaluate(acc.doubleValue).calculatorString
                        
                        // comment-out: don't send "0" because it will confuse with `Key.Num0` input
//                        case .Clear:
//                            return Key.Num0.rawValue    // clear to 0
                        
                        default:
                            // clear previous accumulatedString
                            // (NOTE: don't send "" which will cause forthcoming signal-operations to convert to 0.0 via `str.doubleValue`)
                            return nil
                    }
                }
                .filter { $0 != nil }
                .peek { println("numBuildSignal ---> \($0)") }
        
        let numTokenSignal: Signal<_Token> =
            numBuildSignal
                .map { _Token.Number($0!.doubleValue) }
        
        let operatorKeyTokenSignal: Signal<_Token> =
            mergedKeySignal
                .filter { !contains(Key.numBuildKeys(), $0) }
                .map { _Token.Operator($0, calculatedValue: 0, bracketLevel: 0) }
        
        /// numTokenSignal + operatorKeyTokenSignal
        let tokenSignal: Signal<_Token> =
            numTokenSignal
                .merge(operatorKeyTokenSignal)
                .peek { println(); println("tokenSignal ---> \($0)") }
        
        ///
        /// Quite complex signal-operation using `customize()` to encapsulate `buffer`
        /// and send its `buffer.tokens`.
        ///
        /// (TODO: break down this mess into smaller fundamental operations)
        ///
        let bufferingTokensSignal: Signal<[_Token]> =
            tokenSignal
                .customize { upstreamSignal, progress, fulfill, reject in
                    
                    let _b = _Buffer()  // buffer
                    
                    upstreamSignal.progress { (_, newToken: _Token) in
                        
                        println("[progress] newToken = \(newToken)")
                        println("[progress] buffer = \(_b)")
                        
                        assert(_b.tokens.find { $0.operatorKey != nil && $0.operatorKey! == Key.Equal } == nil, "`buffer.tokens` should not contain `.Equal`.")
                        
                        switch newToken {
                            
                            case .Number(let newValue):
                                _b.addNumber(newValue)
                                
                                // send signal value
                                progress(_b.tokens)
                            
                            case .Operator(let newOperatorKey, _, _):
                                
                                switch newOperatorKey {
                                    
                                    case .Clear:
                                        _b.clear()
                                        _b.addNumber(Key.Num0.rawValue.doubleValue)
                                    
                                    case .AllClear:
                                        _b.allClear()
                                    
                                    default:
                                        // use lastAnswer if `_b.tokens` are empty
                                        if _b.tokens.count == 0 {
                                            _b.tokens.append(_Token.Number(_b.lastAnswer))
                                        }
                                        
                                        // use `_b.lastArithKey` & `_b.lastArithValue` e.g. `2 + 3 = 4 =` will print `7`
                                        if _b.tokens.count == 1 && newOperatorKey == .Equal && contains(Key.arithOperatorKeys(), _b.lastArithKey) {
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
                                        
                                        println("prepared tokens = \(_b.tokens)")
                                        
                                        assert(_b.tokens.last?.number != nil, "`buffer.tokens.last` should have number.")
                                        let lastNumber = _b.tokens.last!.number!
                                        
                                        //
                                        // append new operatorKey-token
                                        // (TODO: consider operatorBracketLevel)
                                        //
                                        let prevOperatorToken = _b.tokens.reverse().find {
                                            $0.operatorKey != nil && $0.operatorBracketLevel == newToken.operatorBracketLevel
                                        }
                                        println("prevOperatorToken = \(prevOperatorToken)")
                                        
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
                                                            calculatedValue = pastOperatorTuple.key.evaluate(calculatedValue)(b: pastOperatorTuple.calculatedValue)
                                                            println("[precalculate] \(beforeCalculatedValue) -> (\(pastOperatorTuple.key.rawValue), \(pastOperatorTuple.calculatedValue)) -> \(calculatedValue)")
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
                                        if contains(Key.arithOperatorKeys(), newOperatorKey) {
                                            _b.lastArithKey = newOperatorKey
                                        }
                                        
                                        break // default
                                    
                                }   // switch newOperatorKey
                                
                                // send signal value
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
                .peek { println("bufferingTokensSignal ---> \($0)") }
        
        let precalculatingSignal: Signal<NSString?> =
            bufferingTokensSignal
                .map { ($0.last?.operatorCalculatedValue ?? 0).calculatorString }
                .peek { println("precalculatingSignal ---> \($0)") }
        
        self.inputSignal = mergedKeySignal
        
        self.outputSignal =
            numBuildSignal
                .map { _calculatorString($0!, rtrims: false) }   // output `calculatorString` to show commas & exponent, and also suffixed `.Point`+`.Num0`s if needed
                .merge(precalculatingSignal)
                .peek { println("outputSignal ---> \($0)") }
        
        self.expressionSignal =
            bufferingTokensSignal
                .map { tokens in tokens.reduce("") { $0 + ($1.number?.calculatorString ?? $1.operatorKey?.rawValue ?? "") + " " } }
                .peek { println("expressionSignal ---> \($0)") }
    }
    
    deinit
    {
        println("[deinit] \(self)")
    }
}

let MAX_DIGIT_FOR_NONEXPONENT = 9
let MIN_EXPONENT = 8
let DECIMAL_PRECISION = 8
let SIGNIFICAND_DIGIT = 7
let COMMA_SEPARATOR = ","

///
/// add either expontent or readable-commas to numString as follows:
///
/// - "123" -> "123" (no change)
/// - "12345.6700" -> "12,345.67" (rtrims=true) or "12,345.6700" (rtrims=false)
/// - "123456789" -> "1.234567e+8"
/// - inf -> "inf"
/// - NaN -> "nan"
///
func _calculatorString(numString: NSString, rtrims rtrimsSuffixedPointAndZeros: Bool = true) -> String
{
    let num = numString.doubleValue
    
    // return "inf" or "nan" if needed
    if !num.isFinite { return "\(num)" }
    
    var exponent: Int = 0
    
    var orderValue: Double = 1.0
    let absSelf = abs(num)
    if absSelf > 1 {
        while absSelf >= orderValue * 10 {
            exponent++
            orderValue *= 10
        }
    }
    else if absSelf > 0 {
        while absSelf < orderValue {
            exponent--
            orderValue *= 0.1
        }
    }
    
    let shouldShowNegativeExponent = (num > -1 && num < 1 && exponent <= -MIN_EXPONENT)
    let shouldShowPositiveExponent = ((num > 1 || num < -1) && exponent >= MIN_EXPONENT)
    
    var string: NSString
        
    // add exponent, e.g. 1.2345678e+9
    if shouldShowPositiveExponent || shouldShowNegativeExponent {
        
        let significand = num * pow(10.0, Double(-exponent))
        
        println()
        println("*** calculatorString ***")
        println("num = \(num)")
        println("significand = \(significand)")
        println("exponent = \(exponent)")
        
        if significand == Double.infinity {
            string = "\(significand)"
        }
        else {
            //
            // NOTE: 
            // Due to rounding of floating-point,
            // `NSString(format:)` (via `doubleValue.calculatorString`) is not capable of
            // printing very long decimal value e.g. `9.999...` as-is 
            // (expecting "9.999..." but often returns "10"),
            // even when higher decimal-precision is given.
            //
            string = _rtrimFloatString(significand.calculatorString)
            if string == "10" {
                string = "1"
                exponent++
            }
            
            if string.length > SIGNIFICAND_DIGIT + 1 {  // +1 for `.Point`
                string = string.substringToIndex(SIGNIFICAND_DIGIT + 1)
            }
            
            // append exponent
            if shouldShowPositiveExponent {
                // e.g. `1e+9`
                string = string + "e\(Calculator.Key.Plus.rawValue)\(exponent)"
            }
            else {
                // e.g. `1e-9`
                string = string + "e\(Calculator.Key.Minus.rawValue)\(-exponent)"
            }
        }
        
    }
    // add commas for integer-part
    else {
        string = _commaString(numString)
        
        if rtrimsSuffixedPointAndZeros {
            string = _rtrimFloatString(string)
        }
    }
    
    return string
}

/// e.g. "12345.67000" -> "12,345.67000" (used for number with non-exponent only)
func _commaString(numString: NSString) -> String
{
    var string = numString
    
    // split by `.Point`
    let splittedStrings = string.componentsSeparatedByString(Calculator.Key.Point.rawValue)
    if let integerString = splittedStrings.first as? String {
        
        var integerCharacters = Array(integerString)
        
        // insert commas
        for var i = countElements(integerCharacters) - 3; i > 0; i -= 3 {
            integerCharacters.insert(Character(COMMA_SEPARATOR), atIndex: i)
        }
        
        string = String(integerCharacters)
        
        if splittedStrings.count == 2 {
            // append `.Point` & decimal-part
            string = string + (Calculator.Key.Point.rawValue as String) + (splittedStrings.last! as String)
        }
    }
    
    var nonNumberCount = 0
    for char in string as String {
        if char == Character(COMMA_SEPARATOR) || char == Character(Calculator.Key.Point.rawValue) {
            nonNumberCount++
        }
    }
    
    // limit to MAX_DIGIT_FOR_NONEXPONENT considering non-number characters
    if string.length > MAX_DIGIT_FOR_NONEXPONENT + nonNumberCount {
        string = string.substringToIndex(MAX_DIGIT_FOR_NONEXPONENT + nonNumberCount)
    }
    
    return string
}

/// e.g. "123.000" -> "123"
func _rtrimFloatString(var string: NSString) -> String
{
    // trim floating zeros, e.g. `123.000` -> `123.`
    if string.containsString(Calculator.Key.Point.rawValue) {
        while string.hasSuffix(Calculator.Key.Num0.rawValue) {
            string = string.substringToIndex(string.length-1)
        }
    }
    
    // trim suffix `.Point` if needed, e.g. `123.` -> `123`
    if string.hasSuffix(Calculator.Key.Point.rawValue) {
        string = string.substringToIndex(string.length-1)
    }
    
    return string
}

extension Double
{
    var calculatorString: String
    {
        let numString = NSString(format: "%0.\(DECIMAL_PRECISION)f", self) // NOTE: `%f` will never print exponent
        return _calculatorString(numString, rtrims: true)
    }
}

extension Array
{
    func find(findClosure: T -> Bool) -> T?
    {
        for (idx, element) in enumerate(self) {
            if findClosure(element) {
                return element
            }
        }
        return nil
    }
}