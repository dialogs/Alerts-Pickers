//
//  AlertIconCollection.swift
//  Alerts&Pickers
//
//  Created by Lex on 09.11.2018.
//  Copyright © 2018 Supreme Apps. All rights reserved.
//

import UIKit

final class AlertIconCollection {
    
    private var iconsByAlertTypes: [ViewController.AlertType : UIImage] = [:]
    
    var iconSize: CGSize = CGSize(width: 40.0, height: 40.0)
    
    func icon(alertType: ViewController.AlertType) -> UIImage? {
        if let image = iconsByAlertTypes[alertType] {
            return image
        }
        
        if let image = createImage(alertType: alertType) {
            iconsByAlertTypes[alertType] = image
            return image
        }
        
        return nil
    }
    
    private func createImage(alertType: ViewController.AlertType) -> UIImage? {
        switch alertType {
        case .telegramPicker: return createImage(string: "📨")
        case .singlePhoto: return createImage(string: "🌇")
        case .locationPicker: return createImage(string: "🗺")
        case .contactsPicker: return createImage(string: "👨‍💼")
        case .dataPicker: return createImage(string: "🗓")
        case .countryPicker: return createImage(string: "🇦🇶")
        case .currencyPicker: return createImage(string: "💶")
        case .avatarPicker: return createImage(string: "📸")
        default:
            return #imageLiteral(resourceName: "library")
        }
    }
    
    private func createImage(string: String) -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(iconSize, false, 0)
        UIColor.white.set()
        let rect = CGRect(origin: .zero, size: iconSize)
        UIRectFill(CGRect(origin: .zero, size: iconSize))
        string.draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 40)])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
        
    }
    
}

