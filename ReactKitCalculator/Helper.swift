//
//  Helper.swift
//  ReactKitCalculator
//
//  Created by Yasuhiro Inami on 2015/02/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import ReactKit

let MAX_DIGIT_FOR_NONEXPONENT = 9
let MIN_EXPONENT = 9
let SIGNIFICAND_DIGIT = 7
let COMMA_SEPARATOR = ","

typealias ScientificNotation = (significand: Double, exponent: Int)

func _scientificNotation(num: Double) -> ScientificNotation
{
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
    
    let significand = num * pow(10.0, Double(-exponent))
    
//    println("_scientificNotation(\(num)) = \((significand, exponent))")
    return (significand, exponent)
}

///
/// add either expontent or readable-commas to numString as follows:
///
/// - "123" -> "123" (no change)
/// - "12345.6700" -> "12,345.67" (rtrims=true) or "12,345.6700" (rtrims=false)
/// - "123456789" -> "1.234567e+8"
/// - inf -> "inf"
/// - NaN -> "nan"
///
func _calculatorString(_ num: Double? = nil, raw numString: NSString? = nil, rtrims rtrimsSuffixedPointAndZeros: Bool = true) -> String
{
    precondition(num != nil || numString != nil, "Either `num` or `numString` must be non-nil.")
    
    let num = num ?? numString!.doubleValue
    
    // return "inf" or "nan" if needed
    if !num.isFinite { return "\(num)" }
    
    var (significand, exponent) =  _scientificNotation(num)
    
    let shouldShowNegativeExponent = (num > -1 && num < 1 && exponent <= -MIN_EXPONENT)
    let shouldShowPositiveExponent = ((num > 1 || num < -1) && exponent >= MIN_EXPONENT)
    
    var string: NSString
        
    // add exponent, e.g. 1.2345678e+9
    if shouldShowPositiveExponent || shouldShowNegativeExponent {
        
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
        let numString = numString ?? NSString(format: "%0.\(MIN_EXPONENT)f", num)
        string = _commaString(numString)
        
        if rtrimsSuffixedPointAndZeros {
            string = _rtrimFloatString(string)
        }
    }
    
    return string
}

/// e.g. "12345.67000" -> "12,345.67000" (used for number with non-exponent only)
func _commaString(var string: NSString) -> String
{
    // split by `.Point`
    let splittedStrings = string.componentsSeparatedByString(Calculator.Key.Point.rawValue)
    if let integerString = splittedStrings.first as? String {
        
        var integerCharacters = Array(integerString)
        let isNegative = integerString.hasPrefix(Calculator.Key.Minus.rawValue)
        
        // insert commas
        for var i = countElements(integerCharacters) - 3; i > (isNegative ? 1 : 0); i -= 3 {
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
        return _calculatorString(self, rtrims: true)
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