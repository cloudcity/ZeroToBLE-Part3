//
//  UIColorExtensions.swift
//  BLEConnect
//
//  Created by Evan Stone on 8/22/16.
//  Copyright © 2016 Cloud City. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(hexInt:Int) {
        self.init(red:(hexInt >> 16) & 0xff, green:(hexInt >> 8) & 0xff, blue:hexInt & 0xff)
    }

    convenience init(hexString:String) {
        self.init(hexString:hexString, alpha: 1.0)
    }

    convenience init(hexString:String, alpha:CGFloat) {
        // limit the alpha range to 0 to 1
        var correctedAlpha = alpha
        if correctedAlpha < 0.0 { correctedAlpha = 0.0 }
        if correctedAlpha > 1.0 { correctedAlpha = 1.0 }
        
        // begin parsing the hex string
        var trimmedString:String = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // if string was passed with pound sign, filter it out...
        if (trimmedString.hasPrefix("#")) {
            trimmedString = trimmedString.substring(from: trimmedString.characters.index(trimmedString.startIndex, offsetBy: 1))
        }
        
        // process the remaining string
        if ((trimmedString.characters.count) != 6) {
            // create a gray color if the string is malformed
            print("Malformed hex color string - generating grey")
            self.init(red:127, green: 127, blue: 127)
        } else {
            var rgbValue:UInt32 = 0
            if Scanner(string: trimmedString).scanHexInt32(&rgbValue) {
                self.init(
                    red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: CGFloat(correctedAlpha)
                )
            } else {
                print("Input string not convertible to UInt32")
                self.init(red:127, green: 127, blue: 127)
            }
        }
        
    }
    
    public func hexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        // Get the RGB values for this UIColor...
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // We will ignore the alpha and just return the hex string for the RGB values
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
