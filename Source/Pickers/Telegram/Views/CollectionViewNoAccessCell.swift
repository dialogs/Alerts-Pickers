//
//  CollectionViewNoAccessCell.swift
//  Alerts&Pickers
//
//  Created by Lex on 14/12/2018.
//  Copyright © 2018 Supreme Apps. All rights reserved.
//

import Foundation
import UIKit


final class CollectionViewNoCameraAccessCell: CollectionViewCustomContentCell<UIImageView> {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    func configure() {
        self.backgroundColor = .black
        showSelectionCircles = false
        customContentView.image = UIImage(named: "camera_icon")
        customContentView.contentMode = .center
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        customContentView.frame = contentView.bounds
        customContentView.layer.cornerRadius = 12
        self.layer.cornerRadius = 12
        updateSelectionAppearance()
    }
}
