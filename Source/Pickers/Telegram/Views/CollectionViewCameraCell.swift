import Foundation
import UIKit
import AVFoundation

public class CollectionViewCameraCell: CollectionViewCustomContentCell<CameraView> {
    
    public override func setup() {
        super.setup()
        
        selectionElement.isHidden = true
    }
    
}

public final class CameraView: UIView {
    
    public var representedStream: Camera.PreviewStream? = nil {
        didSet {
            guard representedStream != oldValue else {
                return
            }
            self.setup()
        }
    }
    
    private var videoLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            guard oldValue !== videoLayer else {
                return
            }
            oldValue?.removeFromSuperlayer()
            
            let name = NSNotification.Name.UIDeviceOrientationDidChange
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
            
            if let newLayer = videoLayer {
                NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: .main, using: rotate
                )
                self.layer.insertSublayer(newLayer, below: cameraIconImageView.layer)
            }
        }
    }
    
    private lazy var cameraIconImageView: UIImageView = {
        let bundle = Bundle(for: CollectionViewCameraCell.self)
        let cameraIcon = UIImage(named: "camera_icon", in: bundle, compatibleWith: nil)
        return UIImageView(image: cameraIcon)
    }()
    
    private func rotate(for notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setNeedsLayout()
        }
    }
    
    private func setup() {
        self.videoLayer = nil
        self.layer.backgroundColor = UIColor.black.cgColor
        
        if let stream = self.representedStream {
            stream.queue.async {
                let videoLayer = AVCaptureVideoPreviewLayer.init(session: stream.session)
                videoLayer.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                    self.videoLayer = videoLayer
                }
            }
        }
        
        if subviews.contains(cameraIconImageView) == false {
            addSubview(cameraIconImageView)
        }
    }
    
    public override func layoutSubviews() {
        let app = UIApplication.shared
        if videoLayer?.connection?.isVideoOrientationSupported ?? false,
            let orientation = app.statusBarOrientation.asVideoCaptureOrientation {
            videoLayer?.connection?.videoOrientation = orientation
        }
        
        super.layoutSubviews()
        
        if videoLayer?.frame != self.bounds {
            videoLayer?.frame = self.bounds
        }
        
        cameraIconImageView.center = CGPoint(x: bounds.width/2, y: bounds.height/2)
    }
    
    public func reset() {
        self.representedStream = nil
    }
    
}

fileprivate extension UIInterfaceOrientation {
    
    var asVideoCaptureOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}
