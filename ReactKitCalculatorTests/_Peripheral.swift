//
//  _Peripheral.swift
//  ReactKitCalculator
//
//  Created by Yasuhiro Inami on 2015/02/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

class _Peripheral: NSObject
{
    // NOTE: can't use `Calculator.Key?` for `dynamic var`, so use NSString + KVO + filter to workaround
    dynamic var input: NSString?
    
    dynamic var output: NSString?
    dynamic var expression: NSString?
}