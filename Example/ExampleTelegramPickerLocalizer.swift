import Foundation
import UIKit

public struct ExampleTelegramPickerLocalizer: TelegramPickerLocalizable {
    public func localized(buttonType: LocalizableButtonType) -> String {
        switch buttonType {
        case .photoOrVideo: return "Photo or Video"
        case .file: return "File"
        case .location: return "Location"
        case .contact: return "Contact"
        case .photos(count: let count): return "Send \(count) \(count == 1 ? "Photo" : "Photos")"
        case .sendAsFile: return "Send as File"
        }
    }
    
    public func localizedAlert(failure: Failure) -> UIAlertController? {
        switch failure {
        case .noAccessToCamera: return noCameraAccessAlert()
        case .noAccessToPhoto: return noPhotosAccessAlert()
        case .error(let error): return failureAlert(error)
        }
    }
    
    private func noCameraAccessAlert() -> UIAlertController {
        /// User has denied the current app to access the camera.
        let productName = Bundle.main.infoDictionary!["CFBundleName"]!
        let alert = UIAlertController(style: .alert, title: "Permission denied", message: "\(productName) does not have access to camera. Please, allow the application to access to camera.")
        alert.addAction(title: "Settings", style: .destructive) { action in
            if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
        alert.addAction(title: "OK", style: .cancel)
        return alert
    }
    
    private func noPhotosAccessAlert() -> UIAlertController {
        /// User has denied the current app to access the contacts.
        let productName = Bundle.main.infoDictionary!["CFBundleName"]!
        let alert = UIAlertController(style: .alert, title: "Permission denied", message: "\(productName) does not have access to contacts. Please, allow the application to access to your photo library.")
        alert.addAction(title: "Settings", style: .destructive) { action in
            if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
        alert.addAction(title: "OK", style: .cancel)
        return alert
    }
    
    private func failureAlert(_ error: Error) -> UIAlertController {
        let alert = UIAlertController(style: .alert, title: "Error", message: error.localizedDescription)
        alert.addAction(title: "OK")
        return alert
    }
    
}