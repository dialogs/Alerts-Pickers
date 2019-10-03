//
//  DLGPhotosViewController.swift
//  DLGPicker
//
//  Created by Victor Eysner on 15/01/2019.
//

import Foundation
import UIKit
import Photos

class DLGPhotosViewController: PhotosViewController {
    
    override func loadView() {
        super.loadView()
        navigationItem.titleView = nil
    }
    
    override func updateAlbumTitle(_ album: PHAssetCollection) {
        guard let localizedTitle = album.localizedTitle else { return }
        title = localizedTitle
    }
    
    func updateAlbum(_ album: PHAssetCollection) {
        initializePhotosDataSource(album)
        updateAlbumTitle(album)
        collectionView?.reloadData()
    }
    
    @objc override func collectionViewLongPressed(_ sender: UIGestureRecognizer) {
        if sender.state == .began {
            // Disable recognizer while we are figuring out location and pushing preview
            sender.isEnabled = false
            collectionView?.isUserInteractionEnabled = false
            
            // Calculate which index path long press came from
            let location = sender.location(in: collectionView)
            let indexPath = collectionView?.indexPathForItem(at: location)
            
            if let indexPath = indexPath,
                let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCell,
                let asset = cell.asset {
                openPreview(with: asset)
            }
            
            // Re-enable recognizer, after animation is done
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(expandAnimator.transitionDuration(using: nil) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                sender.isEnabled = true
                self.collectionView?.isUserInteractionEnabled = true
            })
        }
    }
    
    override func openPreview(with asset: PHAsset) {
        if let fetchResult = photosDataSource?.fetchResult {
            let galleryItemIndex = fetchResult.index(of: asset)
            let config = galleryConfiguration()
            let galleryViewController = GalleryViewController(startIndex: galleryItemIndex,
                                                              itemsDataSource:DLGMediaPickerGalleryItemsDataSource(fetchResult),
                                                              itemsDelegate: self,
                                                              displacedViewsDataSource: nil,
                                                              configuration: config)
            
            galleryViewController.selectionCompletion = { [weak self, weak galleryViewController] button in
                if let picker = self, let controller = galleryViewController {
                    picker.handleGallerySelection(ofItemAt: controller.currentIndex, controller: controller, tappedButton: button)
                }
            }
            present(galleryViewController, animated: false, completion: nil)
        }
    }
    
}

extension DLGPhotosViewController: GalleryItemsDelegate {
    
    func asset(at index: Int) -> PHAsset? {
        if photosDataSource?.fetchResult.count > index,
            let asset = photosDataSource?.fetchResult.object(at: index) {
            return asset
        }
        return nil
    }
    
    func itemSelectionIndex(at index: Int) -> Int? {
        if let asset = asset(at: index),
            let indexes = photosDataSource?.assetStore.assets.indexes(of: asset),
            let index = indexes.first {
            return index + 1
        }
        return nil
    }
    
    func removeGalleryItem(at index: Int) {
        if let asset = asset(at: index) {
            photosDataSource?.assetStore.remove(asset)
        }
    }
    
    func sendItem(_ galleryViewController: GalleryViewController, at index: Int) {
        if let asset = asset(at: index) {
            photosDataSource?.assetStore.append(asset)
            galleryViewController.dismiss(animated: false) {
                if let finishBlock = self.finishClosure, let assets = self.photosDataSource?.assetStore.assets {
                    finishBlock(assets)
                }
            }
        }
        
    }
    
    func isItemSelected(at index: Int) -> Bool {
        if let asset = asset(at: index),
            photosDataSource?.assetStore.assets.contains(asset) ?? false {
            return true
        }
        
        return false
    }
    
}

extension DLGPhotosViewController {
    
    func handleGallerySelection(ofItemAt index: Int, controller: GalleryViewController, tappedButton: UIButton) {
        if let asset = asset(at: index),
            let source = photosDataSource {
            if source.assetStore.assets.contains(asset) {
                source.assetStore.remove(asset)
                tappedButton.setSelected(false, withTitle: nil, animated: true)
            } else {
                // If we can pick only one asset we should remove prev selection
                if assetStore.count == settings.maxNumberOfSelections && settings.maxNumberOfSelections == 1 {
                    source.assetStore.removeFirst()
                }
                source.assetStore.append(asset)
                tappedButton.setSelected(true, withTitle: String(source.assetStore.count), animated: true)
            }
            collectionView?.reloadData()
            updateDoneButton()
        }
    }
    
    func galleryConfiguration() -> GalleryConfiguration {
        return [
            GalleryConfigurationItem.closeButtonMode(.builtIn),
            
            GalleryConfigurationItem.pagingMode(.standard),
            GalleryConfigurationItem.presentationStyle(.displacement),
            GalleryConfigurationItem.hideDecorationViewsOnLaunch(false),
            
            GalleryConfigurationItem.swipeToDismissMode(.vertical),
            GalleryConfigurationItem.toggleDecorationViewsBySingleTap(false),
            GalleryConfigurationItem.activityViewByLongPress(false),
            
            GalleryConfigurationItem.overlayColor(UIColor(white: 0.035, alpha: 1)),
            GalleryConfigurationItem.overlayColorOpacity(1),
            GalleryConfigurationItem.overlayBlurOpacity(1),
            GalleryConfigurationItem.overlayBlurStyle(UIBlurEffectStyle.light),
            
            GalleryConfigurationItem.videoControlsColor(.white),
            
            GalleryConfigurationItem.maximumZoomScale(8),
            GalleryConfigurationItem.swipeToDismissThresholdVelocity(500),
            
            GalleryConfigurationItem.doubleTapToZoomDuration(0.15),
            
            GalleryConfigurationItem.blurPresentDuration(0.5),
            GalleryConfigurationItem.blurPresentDelay(0),
            GalleryConfigurationItem.colorPresentDuration(0.25),
            GalleryConfigurationItem.colorPresentDelay(0),
            
            GalleryConfigurationItem.blurDismissDuration(0.1),
            GalleryConfigurationItem.blurDismissDelay(0.4),
            GalleryConfigurationItem.colorDismissDuration(0.45),
            GalleryConfigurationItem.colorDismissDelay(0),
            
            GalleryConfigurationItem.itemFadeDuration(0.3),
            GalleryConfigurationItem.decorationViewsFadeDuration(0.15),
            GalleryConfigurationItem.rotationDuration(0.15),
            
            GalleryConfigurationItem.displacementDuration(0.55),
            GalleryConfigurationItem.reverseDisplacementDuration(0.25),
            GalleryConfigurationItem.displacementTransitionStyle(.springBounce(0.7)),
            GalleryConfigurationItem.displacementTimingCurve(.linear),
            
            GalleryConfigurationItem.statusBarHidden(true),
            GalleryConfigurationItem.displacementKeepOriginalInPlace(false),
            GalleryConfigurationItem.displacementInsetMargin(50)
        ]
    }
    
}
