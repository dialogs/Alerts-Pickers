//
//  CollectionViewNoAccessCell.swift
//  Alerts&Pickers
//
//  Created by Lex on 14/12/2018.
//  Copyright © 2018 Supreme Apps. All rights reserved.
//

import Foundation
import UIKit

final class CollectionViewNoAccessCell: CollectionViewCustomContentCell<CollectionViewNoAccessCell.NoAccessView> {
    
    class NoAccessView: UIView {
        
        override class var layerClass: AnyClass {
            return CAShapeLayer.self
        }
        
        override var layer: CAShapeLayer {
            return super.layer as! CAShapeLayer
        }
        
        var textLabelInsets: UIEdgeInsets = UIEdgeInsets(top: 6.0, left: 6.0, bottom: 6.0, right: 6.0) {
            didSet {
                self.setNeedsLayout()
            }
        }
        
        lazy var textLabel: UILabel = {
            let label = UILabel()
            label.numberOfLines = 0
            label.textAlignment = .center
            self.addSubview(label)
            return label
        }()
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            let textFrame = UIEdgeInsetsInsetRect(self.bounds, self.textLabelInsets)
            textLabel.frame = textFrame
        }
        
    }
    
    public var textLabel: UILabel {
        return self.customContentView.textLabel
    }
    
    public var borderColor: UIColor? {
        get {
            return self.customContentView.layer.strokeColor.map({UIColor(cgColor: $0)})
        }
        set {
            self.customContentView.layer.strokeColor = newValue?.cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    func configure() {
        self.customContentView.clipsToBounds = false
        
        self.showSelectionCircles = false
        customContentView.layer.fillColor = nil
        customContentView.layer.lineDashPattern = [4, 6]
        customContentView.layer.lineCap = kCALineCapRound
        customContentView.layer.strokeColor = UIColor.black.cgColor
        customContentView.layer.shouldRasterize = true
        customContentView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        textLabel.frame = self.contentView.bounds
        customContentView.layer.frame = customContentView.bounds
        
        let borderBounds = self.customContentView.layer.bounds
        let borderRadius = self.customContentView.layer.cornerRadius
        let path = UIBezierPath(roundedRect: borderBounds, cornerRadius: borderRadius)
        path.lineWidth = 1.0 / UIScreen.main.scale
        customContentView.layer.path = path.cgPath
        
    }
    
}
