//
//  DLGAlbumCell.swift
//  DLGPicker
//
//  Created by Victor Eysner on 15/01/2019.
//

import UIKit

class DLGAlbumCell: UITableViewCell {
    
    static let cellIdentifier = "DLGAlbumCell"
    
    let firstImageView: UIImageView = UIImageView(frame: .zero)
    let secondImageView: UIImageView = UIImageView(frame: .zero)
    let thirdImageView: UIImageView = UIImageView(frame: .zero)
    let albumTitleLabel: UILabel = UILabel(frame: .zero)
    
    private let imageContainerView: UIView = UIView(frame: .zero)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageContainerView)
        albumTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumTitleLabel)
        
        NSLayoutConstraint.activate([
            imageContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            imageContainerView.heightAnchor.constraint(equalToConstant: 84),
            imageContainerView.widthAnchor.constraint(equalToConstant: 84),
            imageContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            albumTitleLabel.leadingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: 8),
            albumTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            albumTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            albumTitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        
        // Image views
        [thirdImageView, secondImageView, firstImageView].forEach {
            imageContainerView.addSubview($0)
            NSLayoutConstraint.activate([
                $0.heightAnchor.constraint(equalToConstant: 79),
                $0.widthAnchor.constraint(equalToConstant: 79)
                ])
            
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.layer.shadowColor = UIColor.white.cgColor
            $0.layer.shadowRadius = 1.0
            $0.layer.shadowOffset = CGSize(width: 0.5, height: -0.5)
            $0.layer.shadowOpacity = 1.0
            $0.clipsToBounds = true
        }
        
        NSLayoutConstraint.activate([
            thirdImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            thirdImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            secondImageView.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
            secondImageView.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),
            firstImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            firstImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        firstImageView.image = nil
        secondImageView.image = nil
        thirdImageView.image = nil
        albumTitleLabel.text = nil
    }
    
}
