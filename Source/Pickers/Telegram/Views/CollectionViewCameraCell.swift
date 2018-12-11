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
            
            NotificationCenter.default.removeObserver(self,
                                                      name: NSNotification.Name.UIDeviceOrientationDidChange,
                                                      object: nil)
            
            if let newLayer = videoLayer {
                NotificationCenter.default.addObserver(forName: NSNotification.Name.UIDeviceOrientationDidChange,
                                                       object: nil,
                                                       queue: .main,
                                                       using: rotate)
                self.layer.insertSublayer(newLayer, below: cameraIconImageView.layer)
            }
        }
    }
    
    private lazy var cameraIconImageView: UIImageView = {
        let bundle = Bundle(for: CollectionViewCameraCell.self)
        let cameraIcon = UIImage(named: "camera_icon", in: bundle, compatibleWith: nil)
        return UIImageView(image: cameraIcon)
    }()
    
    private var previousOrientation = UIDevice.current.orientation
    
    private func rotate(for notification: Notification) {
        
        let currentOrientation = UIDevice.current.orientation
        var degrees = 0.0
        
        if previousOrientation == .portrait && currentOrientation == .landscapeLeft {
            degrees = -90.0
        } else if previousOrientation == .portrait && currentOrientation == .landscapeRight {
            degrees = 90.0
        } else if previousOrientation == .portrait && currentOrientation == .portraitUpsideDown {
            degrees = 180.0
        } else if previousOrientation == .portraitUpsideDown && currentOrientation == .landscapeLeft {
            degrees = 90.0
        } else if previousOrientation == .portraitUpsideDown && currentOrientation == .landscapeRight {
            degrees = -90.0
        } else if previousOrientation == .landscapeRight && currentOrientation == .landscapeLeft {
            degrees = 90.0
        } else if previousOrientation == .landscapeRight && currentOrientation == .portraitUpsideDown {
            degrees = 180.0
        } else if previousOrientation == .landscapeLeft && currentOrientation == .landscapeRight {
            degrees = -90.0
        } else if previousOrientation == .landscapeLeft && currentOrientation == .portraitUpsideDown {
            degrees = 180.0
        }
        
        if let videoLayer = videoLayer {
            let radians = CGFloat(degrees * Double.pi / 180)
            videoLayer.transform = CATransform3DMakeRotation(radians, 0.0, 0.0, 1.0)
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
        super.layoutSubviews()
        
        if videoLayer?.frame != self.bounds {
            videoLayer?.frame = self.bounds
        }
        
        var degrees = 0.0
        
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            degrees = 180.0
        case.landscapeLeft:
            degrees = -90.0
        case.landscapeRight:
            degrees = 90.0
        default:
            degrees = 0.0
        }
        
        if let videoLayer = videoLayer {
            let radians = CGFloat(degrees * Double.pi / 180)
            videoLayer.transform = CATransform3DMakeRotation(radians, 0.0, 0.0, 1.0)
        }
        
        cameraIconImageView.center = CGPoint(x: bounds.width/2, y: bounds.height/2)
    }
    
    public func reset() {
        self.representedStream = nil
    }
    
}
