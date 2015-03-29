//
//  ExpressionSpec.swift
//  ReactKitCalculator
//
//  Created by Yasuhiro Inami on 2015/02/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKitCalculator
import ReactKit
import Quick
import Nimble

class ExpressionSpec: QuickSpec
{
    override func spec()
    {
        typealias Key = Calculator.Key
        
        var p: _Peripheral!
        var calculator: Calculator!
        
        beforeEach {
            p = _Peripheral()
            
            calculator = Calculator { mapper in
                let signal = KVO.signal(p, "input").map { $0 as? NSString } //.asSignal(NSString?)
                
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
                
                // REACT (debug print)
                calculator.expressionSignal ~> { expression in
                    let expression = expression ?? "(nil)";
                    println("expression = `\(expression)`")
                    println()
                }
            #endif
            
            // REACT (set after debug print)
            (p, "expression") <~ calculator.expressionSignal
        }
        
        describe("accumulate digits") {
            
            context("digits") {
                
                it("`1 2 3` should print `123`") {
                    
                    p.input = "1"
                    expect(p.expression!).to(equal("1 "))
                    
                    p.input = "2"
                    expect(p.expression!).to(equal("12 "))
                    
                    p.input = "3"
                    expect(p.expression!).to(equal("123 "))
                    
                }
                
            }
            
            context("decimal point") {
                
                it("`1 . 2 3` should print `1.23`") {
                    
                    p.input = "1"
                    expect(p.expression!).to(equal("1 "))
                    
                    p.input = "."
                    expect(p.expression!).to(equal("1 "))   // NOTE: outputSignal sends "1."
                    
                    p.input = "2"
                    expect(p.expression!).to(equal("1.2 "))
                    
                    p.input = "3"
                    expect(p.expression!).to(equal("1.23 "))
                    
                }
                
                it("`. 2 3` should print `0.23`") {
                    
                    p.input = "."
                    expect(p.expression).to(equal("0 "))   // NOTE: outputSignal sends "0."
                    
                    p.input = "2"
                    expect(p.expression!).to(equal("0.2 "))
                    
                    p.input = "3"
                    expect(p.expression!).to(equal("0.23 "))
                    
                }
                
            }
        }
        
        describe(".Equal") {
            
            it("`= =` should print `0 = ` then `0 = `") {
                
                p.input = "="
                expect(p.expression!).to(equal("0 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("0 = "))
                
            }
            
            it("`1 = =` should print `1 = ` then `1 = `") {
                
                p.input = "1"
                expect(p.expression!).to(equal("1 "))
                
                p.input = "="
                expect(p.expression!).to(equal("1 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("1 = "))
                
            }
        }
        
        describe(".Clear") {
            
            it("`2 + C = =`") {
                
                p.input = "2"
                expect(p.expression!).to(equal("2 "))
                
                p.input = "+"
                expect(p.expression!).to(equal("2 + "))
                
                p.input = "C"
                expect(p.expression!).to(equal("2 + 0 ")) // 0 is set
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 0 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 0 = "))
                
            }
            
            it("`2 + 3 C = =`") {
                
                p.input = "2"
                expect(p.expression!).to(equal("2 "))
                
                p.input = "+"
                expect(p.expression!).to(equal("2 + "))
                
                p.input = "3"
                expect(p.expression!).to(equal("2 + 3 "))
                
                p.input = "C"
                expect(p.expression!).to(equal("2 + 0 ")) // clear current only
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 0 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 0 = "))
                
            }
            
            it("`2 + 3 C 4 = =`") {
                
                p.input = "2"
                expect(p.expression!).to(equal("2 "))
                
                p.input = "+"
                expect(p.expression!).to(equal("2 + "))
                
                p.input = "3"
                expect(p.expression!).to(equal("2 + 3 "))
                
                p.input = "C"
                expect(p.expression!).to(equal("2 + 0 ")) // clear current only
                
                p.input = "4"
                expect(p.expression!).to(equal("2 + 4 "))
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 4 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("6 + 4 = "))
                
            }
            
            it("`2 + 3 = C = =`") {
                
                p.input = "2"
                expect(p.expression!).to(equal("2 "))
                
                p.input = "+"
                expect(p.expression!).to(equal("2 + "))
                
                p.input = "3"
                expect(p.expression!).to(equal("2 + 3 "))
                
                p.input = "="
                expect(p.expression!).to(equal("2 + 3 = ")) // last operation: +3
                
                p.input = "C"
                expect(p.expression!).to(equal("0 "))
                
                p.input = "="
                expect(p.expression!).to(equal("0 + 3 = "))
                
                p.input = "="
                expect(p.expression!).to(equal("3 + 3 = "))
                
            }
            
        }
        
    }
}