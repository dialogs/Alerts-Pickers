// The MIT License (MIT)
//
// Copyright (c) 2015 Joakim Gyllström
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import Photos

/**
The photo cell.
*/
final class PhotoCell: UICollectionViewCell {
    static let cellIdentifier = "photoCellIdentifier"
    
    let imageView: UIImageView = UIImageView(frame: .zero)
    private let bundle = Bundle(for: PhotoCell.self)
    private lazy var videoIconImageView: UIImageView = UIImageView(image: UIImage(named: "video", in: bundle, compatibleWith: nil))
    private lazy var gradientBackgroundImageView: UIImageView = UIImageView(image: UIImage(named: "gradient_black_transparent", in: bundle, compatibleWith: nil))
    
    private let selectionView: SelectionView = SelectionView(frame: .zero)
    var selectBlock: (PhotoCell) -> () = { _ in }
    
    weak var asset: PHAsset? {
        didSet {
            if asset?.mediaType == .video {
                gradientBackgroundImageView.isHidden = false
                videoIconImageView.isHidden = false
            } else {
                gradientBackgroundImageView.isHidden = true
                videoIconImageView.isHidden = true
            }
        }
    }
    var settings: BSImagePickerSettings {
        get {
            return selectionView.settings
        }
        set {
            selectionView.settings = newValue
        }
    }
    
    var selectionString: String {
        get {
            return selectionView.selectionString
        }
        
        set {
            selectionView.selectionString = newValue
        }
    }
    
    var photoSelected: Bool = false {
        didSet {
            self.updateAccessibilityLabel(photoSelected)
            selectionView.selected = photoSelected
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Setup views
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        selectionView.translatesAutoresizingMaskIntoConstraints = false
        gradientBackgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        videoIconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        contentView.addSubview(selectionView)
        contentView.addSubview(gradientBackgroundImageView)
        contentView.addSubview(videoIconImageView)
        
        // Add constraints
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionView.heightAnchor.constraint(equalToConstant: 30),
            selectionView.widthAnchor.constraint(equalToConstant: 30),
            selectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            
            gradientBackgroundImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientBackgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientBackgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientBackgroundImageView.heightAnchor.constraint(equalToConstant: 16),
            videoIconImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            videoIconImageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 8),
            videoIconImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 15),
            videoIconImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 15),
        ])
        selectionView.selectBlock = {[weak self] in
            if let cell = self {
                cell.selectBlock(cell)
                cell.animationSelected()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateAccessibilityLabel(_ selected: Bool) {
        self.accessibilityLabel = selected ? "deselect image" : "select image"
    }
    
    private func animationSelected() {
        if UIView.areAnimationsEnabled {
            UIView.animate(withDuration: TimeInterval(0.15), animations: { () -> Void in
                // Scale all views down a little
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { (finished: Bool) -> Void in
                UIView.animate(withDuration: TimeInterval(0.05), animations: { () -> Void in
                    // And then scale them back upp again to give a bounce effect
                    self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                }, completion: nil)
            })
        }
    }
}
