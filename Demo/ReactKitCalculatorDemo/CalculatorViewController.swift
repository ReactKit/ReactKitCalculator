//
//  CalculatorViewController.swift
//  ReactKitCalculatorDemo
//
//  Created by Yasuhiro Inami on 2015/02/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import UIKit
import ReactKit
import ReactKitCalculator

class CalculatorViewController: UIViewController {

    @IBOutlet var nonClearButtons: [UIButton]!
    @IBOutlet var clearButton: UIButton!
    
    @IBOutlet var textField: UITextField!
    @IBOutlet var historyLabel: UILabel!
    
    var calculator: Calculator?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupSubviews()
        self.setupStreams()
    }
    
    func setupSubviews()
    {
        for subview in (self.nonClearButtons + [self.clearButton]) {
            subview.layer.borderWidth = 0.5
            subview.layer.borderColor = UIColor.blackColor().colorWithAlphaComponent(0.5).CGColor
        }
        
        self.historyLabel.text = ""
    }

    func setupStreams()
    {
        self.calculator = Calculator { mapper in
            
            let alternativeMappingTuples = [
                ("×", Calculator.Key.Multiply), // convert "×" to "*"
                ("÷", Calculator.Key.Divide)    // convert "÷" to "/"
            ]
            
            // map buttonStream to calculator via `button.title`
            for button in self.nonClearButtons {
                let buttonTitle = button.titleForState(.Normal)
                let defaultMappedKey = Calculator.Key(rawValue: buttonTitle!)
                
                let key = defaultMappedKey ?? (alternativeMappingTuples.filter { $0.0 == buttonTitle }.first?.1) ?? nil
                
                if let key = key {
                    mapper[key] = button.buttonStream()
                }
            }
            
            // manually map `.Clear` & `.AllClear`
            for clearKey in Calculator.Key.clearKeys() {
                mapper[clearKey] = self.clearButton.buttonStream { button -> Bool in button?.titleForState(.Normal) == clearKey.rawValue }
                    |> filter { $0 == true }
                    |> map { _ in () as Void }    // asStream(Void)
            }
        }
        
        // REACT
        (self.textField, "text") <~ self.calculator!.outputStream
        (self.historyLabel, "text") <~ self.calculator!.expressionStream

        // REACT: toggle C <-> AC
        self.calculator!.inputStream ~> { [weak self] key in
            if Calculator.Key.numKeys().contains(key) {
                self?.clearButton?.setTitle("C", forState: .Normal)
                
            }
            else if key == .Clear {
                self?.clearButton?.setTitle("AC", forState: .Normal)
            }
        }
    }

}
