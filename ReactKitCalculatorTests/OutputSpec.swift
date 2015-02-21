//
//  OutputSpec.swift
//  ReactKitCalculator
//
//  Created by Yasuhiro Inami on 2015/02/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKitCalculator
import ReactKit
import Quick
import Nimble

class OutputSpec: QuickSpec
{
    override func spec()
    {
        typealias Key = Calculator.Key
        
        var p: _Peripheral!
        var calculator: Calculator!
        
        beforeEach {
            p = _Peripheral()
            
            calculator = Calculator { mapper in
                let signal = KVO.signal(p, "input").map { $0 as NSString? } //.asSignal(NSString?)
                
                for key in Calculator.Key.allKeys() {
                    mapper[key] = signal.filter { $0 == key.rawValue }.map { _ -> Void in } //.asSignal(Void)
                }
            }
            
            #if true
                // REACT (debug print)
                calculator.inputSignal ~> { key in
                    println()
                    println("***************************")
                    println("pressed key = `\(key.rawValue)`")
                }
                
                // REACT (debug print)
                calculator.outputSignal ~> { output in
                    let output = output ?? "(nil)";
                    println("output = `\(output)`")
                    println()
                }
            #endif
            
            // REACT (set after debug print)
            (p, "output") <~ calculator.outputSignal
        }
        
        describe("accumulate number") {
            
            context("digits") {
                
                it("`1 2 3` should accumulate 3-digits") {
                    
                    p.input = "1"
                    expect(p.output!).to(equal("1"))
                    
                    p.input = "2"
                    expect(p.output!).to(equal("12"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("123"))
                    
                }
                
            }
            
            context("decimal point") {
                
                it("`1 . 2 3` should print `1.23`") {
                    
                    p.input = "1"
                    expect(p.output!).to(equal("1"))
                    
                    p.input = "."
                    expect(p.output!).to(equal("1."))   // not "1"
                    
                    p.input = "2"
                    expect(p.output!).to(equal("1.2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("1.23"))
                    
                }
                
                it("`. 2 3` should print `0.23`") {
                    
                    p.input = "."
                    expect(p.output!).to(equal("0."))   // "0" should be prepended
                    
                    p.input = "2"
                    expect(p.output!).to(equal("0.2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("0.23"))
                    
                }
                
            }
            
            context("decimal point + zero") {
                
                it("`0 . 0` should print `0.0`") {
                    
                    p.input = "0"
                    expect(p.output!).to(equal("0"))
                    
                    p.input = "."
                    expect(p.output!).to(equal("0."))
                    
                    p.input = "0"
                    expect(p.output!).to(equal("0.0"))
                    
                }
                
                it("`. 0` should print `0.0`") {
                    
                    p.input = "."
                    expect(p.output!).to(equal("0."))   // "0" should be prepended
                    
                    p.input = "0"
                    expect(p.output!).to(equal("0.0"))
                    
                }
                
            }
        }
        
        describe("simple operation") {
            
            it("`2 + 3 = =` should print `5` then `8`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("5"))
                
                p.input = "="
                expect(p.output!).to(equal("8"))
                
            }
            
            it("`2 - 3 = =` should print `-1` then `-4`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "-"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("-1"))
                
                p.input = "="
                expect(p.output!).to(equal("-4"))
                
            }
            
            it("`2 * 3 = =` should print `6` then `18`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "*"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("6"))
                
                p.input = "="
                expect(p.output!).to(equal("18"))
                
            }
            
            it("`2 / 3 = =` should print `0.666...` then `0.222...`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "/"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(beginWith("0.666"))
                
                p.input = "="
                expect(p.output!).to(beginWith("0.222"))
                
            }
        }
        
        describe("multiple operations") {
        
            context("same operators") {
                
                it("`2 + 3 + 4 = =` should print `9` then `13`, with printing result of `2 + 3` in midway") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("5"))
                    
                    p.input = "4"
                    expect(p.output!).to(equal("4"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("9"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("13"))
                    
                }
            }
            
            context("different operators (precedence)") {
                
                it("`2 + 3 * 4 = =` should print `14` then `56`, WITHOUT printing result of `2 + 3` in midway") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "*"
                    expect(p.output!).to(equal("3"))    // NOTE: not printing result of `2 + 3`
                    
                    p.input = "4"
                    expect(p.output!).to(equal("4"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("14"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("56"))
                    
                }
                
                it("`2 * 3 + 4 = =` should print `10` then `14`, with printing result of `2 * 3` in midway") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "*"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("6"))
                    
                    p.input = "4"
                    expect(p.output!).to(equal("4"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("10"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("14"))
                    
                }
            }
        }
        
        describe("forced-`.Equal` e.g. `+` then `=`") {
            
            context("same operators") {
                
                it("`2 + 3 + = =` should print `10` then `15`") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "*"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("11"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("33"))
                    
                }
                
            }
            
            context("different operators (precedence)") {
            
                it("`2 + 3 * = =` should print `11` then `33`") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "*"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("11"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("33"))
                    
                }
                
                it("`2 * 3 + = =` should print `12` then `18`") {
                    
                    p.input = "2"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "*"
                    expect(p.output!).to(equal("2"))
                    
                    p.input = "3"
                    expect(p.output!).to(equal("3"))
                    
                    p.input = "+"
                    expect(p.output!).to(equal("6"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("12"))
                    
                    p.input = "="
                    expect(p.output!).to(equal("18"))
                    
                }
            }
        }
        
        describe("operator change") {
            
            it("`1 2 + 3 + * 4 =` should cancel previous addition and print `24`") {
                
                p.input = "1"
                expect(p.output!).to(equal("1"))
                
                p.input = "2"
                expect(p.output!).to(equal("12"))
                
                p.input = "+"
                expect(p.output!).to(equal("12"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "+"
                expect(p.output!).to(equal("15"))   // should immediately calculate addition
                
                p.input = "*"
                expect(p.output!).to(equal("3"))    // should revert output for multiply (higher precedence)
                
                p.input = "4"
                expect(p.output!).to(equal("4"))
                
                p.input = "="
                expect(p.output!).to(equal("24"))
                
            }
            
        }
        
        describe("`.Clear`") {
            
            it("`2 + 3 = C = =` should print `5` then `3` then `6`") {
                
                p.input = "2"
                expect(p.output).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("5"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "="
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("6"))
                
            }
            
            it("`2 + 3 = C 4 = =` should print `5` then `7` then `10`") {
                
                p.input = "2"
                expect(p.output).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "="
                expect(p.output!).to(equal("5"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "4"
                expect(p.output!).to(equal("4"))
                
                p.input = "="
                expect(p.output!).to(equal("7"))
                
                p.input = "="
                expect(p.output!).to(equal("10"))
                
            }
            
            it("`2 + C = =` should print `2` then `2`") {
                
                p.input = "2"
                expect(p.output).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "="
                expect(p.output!).to(equal("2"))
                
                p.input = "="
                expect(p.output!).to(equal("2"))
                
            }
            
            it("`2 + 3 C = =` should print `2` then `2`") {
                
                p.input = "2"
                expect(p.output).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "="
                expect(p.output!).to(equal("2"))
                
                p.input = "="
                expect(p.output!).to(equal("2"))
                
            }
            
            it("`2 + 3 C 4 = =` should print `6` then `10`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "4"
                expect(p.output!).to(equal("4"))
                
                p.input = "="
                expect(p.output!).to(equal("6"))
                
                p.input = "="
                expect(p.output!).to(equal("10"))
                
            }
            
            it("`2 + 3 + 4 C = =` should print `5` then `5` after 1st `.Equal`") {
                
                p.input = "2"
                expect(p.output!).to(equal("2"))
                
                p.input = "+"
                expect(p.output!).to(equal("2"))
                
                p.input = "3"
                expect(p.output!).to(equal("3"))
                
                p.input = "+"
                expect(p.output!).to(equal("5"))
                
                p.input = "4"
                expect(p.output!).to(equal("4"))
                
                p.input = "C"
                expect(p.output!).to(equal("0"))
                
                p.input = "="
                expect(p.output!).to(equal("5"))
                
                p.input = "="
                expect(p.output!).to(equal("5"))
            }
            
        }
        
        // TODO: add bracket feature
//        describe("bracket") {
//        
//            it("`2 * ( 3 + 4 ) = =` should print `14` then `21` (+7 for consecutive-.Equal)") {
//            }
//        }
        
    }
}