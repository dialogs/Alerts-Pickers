//
//  ShortTapGestureRecognizer.swift
//  DLGPicker
//
//  Created by Dmitry Tikhonov on 22/12/2018.
//

import UIKit

class ShortTapGestureRecognizer: UITapGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.state != .ended {
                self.state = .failed
            }
        }
    }
}
