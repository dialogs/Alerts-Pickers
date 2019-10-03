import UIKit
import AudioToolbox

let kDefaultViewInset: CGFloat = 8
// MARK: - Initializers
extension UIAlertController {
	
    /// Create new alert view controller.
    ///
    /// - Parameters:
    ///   - style: alert controller's style.
    ///   - title: alert controller's title.
    ///   - message: alert controller's message (default is nil).
    ///   - defaultActionButtonTitle: default action button title (default is "OK")
    ///   - tintColor: alert controller's tint color (default is nil)
    convenience public init(style: UIAlertControllerStyle, source: UIView? = nil, title: String? = nil, message: String? = nil, tintColor: UIColor? = nil) {
        self.init(title: title, message: message, preferredStyle: style)
        
        // TODO: for iPad or other views
        let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
        let root = UIApplication.shared.keyWindow?.rootViewController?.view
        
        //self.responds(to: #selector(getter: popoverPresentationController))
        if let source = source {
            Log("----- source")
            popoverPresentationController?.sourceView = source
            popoverPresentationController?.sourceRect = source.bounds
        } else if isPad, let source = root, style == .actionSheet {
            Log("----- is pad")
            popoverPresentationController?.sourceView = source
            popoverPresentationController?.sourceRect = CGRect(x: source.bounds.midX, y: source.bounds.midY, width: 0, height: 0)
            //popoverPresentationController?.permittedArrowDirections = .down
            popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)
        }
        
        if let color = tintColor {
            self.view.tintColor = color
        }
    }
}


// MARK: - Methods
extension UIAlertController {
    
    /// Present alert view controller in the current view controller.
    ///
    /// - Parameters:
    ///   - animated: set true to animate presentation of alert controller (default is true).
    ///   - vibrate: set true to vibrate the device while presenting the alert (default is false).
    ///   - completion: an optional completion handler to be called after presenting alert controller (default is nil).
    func show(presentsController: UIViewController? = nil,
              animated: Bool = true,
              vibrate: Bool = false,
              style: UIBlurEffectStyle? = nil,
              completion: (() -> Void)? = nil) {
        
        defer {
            if vibrate {
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            }
        }
        
        /// TODO: change UIBlurEffectStyle
        if let style = style {
            for subview in view.subviews where subview is UIVisualEffectView {
                (subview as? UIVisualEffectView)?.effect = UIBlurEffect(style: style)
            }
        }
        
        DispatchQueue.main.async {
            guard let presentsController = presentsController else {
                UIApplication.shared.keyWindow?.rootViewController?.present(self, animated: animated, completion: completion)
                return
            }
            presentsController.present(self, animated: animated, completion: completion)
        }
    }
    
    /// Add an action to Alert
    ///
    /// - Parameters:
    ///   - title: action title
    ///   - style: action style (default is UIAlertActionStyle.default)
    ///   - isEnabled: isEnabled status for action (default is true)
    ///   - handler: optional action handler to be called when button is tapped (default is nil)
    func addAction(image: UIImage? = nil, title: String, color: UIColor? = nil, style: UIAlertActionStyle = .default, isEnabled: Bool = true, handler: ((UIAlertAction) -> Void)? = nil) {
        //let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
        //let action = UIAlertAction(title: title, style: isPad && style == .cancel ? .default : style, handler: handler)
        let action = UIAlertAction(title: title, style: style, handler: handler)
        action.isEnabled = isEnabled
        
        // button image
        if let image = image {
            action.setValue(image, forKey: "image")
        }
        
        // button title color
        if let color = color {
            action.setValue(color, forKey: "titleTextColor")
        }
        
        addAction(action)
    }
    
    /// Set alert's title, font and color
    ///
    /// - Parameters:
    ///   - title: alert title
    ///   - font: alert title font
    ///   - color: alert title color
    func set(title: String?, font: UIFont, color: UIColor) {
        if title != nil {
            self.title = title
        }
        setTitle(font: font, color: color)
    }
    
    func setTitle(font: UIFont, color: UIColor) {
        guard let title = self.title else { return }
        let attributes: [NSAttributedStringKey: Any] = [.font: font, .foregroundColor: color]
        let attributedTitle = NSMutableAttributedString(string: title, attributes: attributes)
        setValue(attributedTitle, forKey: "attributedTitle")
    }
    
    /// Set alert's message, font and color
    ///
    /// - Parameters:
    ///   - message: alert message
    ///   - font: alert message font
    ///   - color: alert message color
    func set(message: String?, font: UIFont, color: UIColor) {
        if message != nil {
            self.message = message
        }
        setMessage(font: font, color: color)
    }
    
    func setMessage(font: UIFont, color: UIColor) {
        guard let message = self.message else { return }
        let attributes: [NSAttributedStringKey: Any] = [.font: font, .foregroundColor: color]
        let attributedMessage = NSMutableAttributedString(string: message, attributes: attributes)
        setValue(attributedMessage, forKey: "attributedMessage")
    }
    
    /// Set alert's content viewController
    ///
    /// - Parameters:
    ///   - vc: ViewController
    ///   - height: height of content viewController
    func set(vc: UIViewController?, width: CGFloat? = nil, height: CGFloat? = nil, addPanGestureToDissmiss: Bool = false) {
        guard let vc = vc else { return }
        setValue(vc, forKey: "contentViewController")
        if let height = height {
            vc.preferredContentSize.height = height
            preferredContentSize.height = height
        }
        guard addPanGestureToDissmiss else { return }
        let panGestureRcognizer = UIPanGestureRecognizer(target: self, action: #selector(onDrage(_:)))
        if let vcAsGestureRecognizerDelegate  = vc as? UIGestureRecognizerDelegate {
            panGestureRcognizer.delegate = vcAsGestureRecognizerDelegate
        }
        vc.view.addGestureRecognizer(panGestureRcognizer)
    }
    
    @objc private func onDrage(_ sender: UIPanGestureRecognizer) {
        
        let kVelocityToDismissAlert: CGFloat = 333
        
        let translation = sender.translation(in: view)
        
        let newY = ensureRange(value: view.frame.minY + translation.y, minimum: 0, maximum: view.frame.maxY)
        
        let originOffsetFromBottom = UIScreen.main.bounds.height - view.frame.height
        
        if translation.y > 0 ||  view.frame.origin.y > originOffsetFromBottom {
            view.frame.origin.y = newY
        }

        if sender.state == .ended {
            let velocity = sender.velocity(in: view)
            if velocity.y >= kVelocityToDismissAlert  {
                UIView.animate(withDuration: 0.15, animations: {
                    self.view.frame.origin.y =  UIScreen.main.bounds.height
                }, completion: { _ in
                    self.dismiss(animated: false)
                })
            } else {
                if #available(iOS 11.0, *) {
                    let window = UIApplication.shared.keyWindow
                    let bottomPadding = window?.safeAreaInsets.bottom ?? 0
                    UIView.animate(withDuration: 0.2, animations: {
                        self.view.frame.origin.y =  originOffsetFromBottom - (bottomPadding == 0 ? kDefaultViewInset : bottomPadding)
                    })
                } else {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.view.frame.origin.y =  originOffsetFromBottom - kDefaultViewInset
                    })
                }
            }
        }
        sender.setTranslation(.zero, in: view)
    }
    
    private func ensureRange<T>(value: T, minimum: T, maximum: T) -> T where T : Comparable {
        return min(max(value, minimum), maximum)
    }
}




