//
//  DLGMediaPickerGalleryItemsDataSource.swift
//  DLGPicker
//
//  Created by Victor Eysner on 16/01/2019.
//

import UIKit
import Photos

internal enum DLGMediaItem: Equatable {
    
    case photo(PHAsset)
    case video(PHAsset)
    case camera
    
    var isCamera: Bool {
        switch self {
        case .camera: return true
        default: return false
        }
    }
    
    var asset: PHAsset? {
        switch self {
        case .camera: return nil
        case .photo(let asset), .video(let asset): return asset
        }
    }
    
    public static func items(assets: [PHAsset]) -> [DLGMediaItem] {
        let newItems = assets
            .filter({
                switch $0.mediaType {
                case .image: return true
                case .video: return true
                default: return false
                }
            })
            .compactMap({ DLGMediaItem.init(asset: $0) })
        
        return newItems
    }
    
    public static func == (lhs: DLGMediaItem, rhs: DLGMediaItem) -> Bool {
        switch (lhs, rhs) {
        case (let .photo(lhsAsset), let .photo(rhsAsset)): return lhsAsset == rhsAsset
        case (let .video(lhsAsset), let .video(rhsAsset)): return lhsAsset == rhsAsset
        case (.camera, .camera): return true
        default: return false
        }
    }
    
    init?(asset: PHAsset) {
        switch asset.mediaType {
        case .video: self = .video(asset)
        case .image: self = .photo(asset)
        default: return nil
        }
    }
    
    var galleryItem: GalleryItem? {
        switch self {
        case .photo(let asset):
            return GalleryItem.image(fetchImageBlock: { completion in
                Assets.resolve(asset: asset) { image in
                    completion(image ?? UIImage())
                } })
        case .video(let asset):
            return GalleryItem.video(fetchPreviewImageBlock:  { completion in
                Assets.resolve(asset: asset) { image in
                    completion(image ?? UIImage())
                }
            }, videoURL: { completion in
                Assets.resolveVideo(asset: asset, completion: { (url) in
                    completion(url)
                })
            })
        case .camera:
            return nil
        }
    }
}

internal class DLGMediaPickerGalleryItemsDataSource: GalleryItemsDataSource {
    
    let fetchResult: PHFetchResult<PHAsset>
    var items: [DLGMediaItem]
    
    init(_ fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
        self.items = DLGMediaItem.items(assets: fetchResult.dlg_assets)
    }
    
    func itemCount() -> Int {
        return fetchResult.count
    }
    
    func provideGalleryItem(_ index: Int) -> GalleryItem {
        if let galleryItem = items[index].galleryItem {
            return galleryItem
        }
        
        return GalleryItem.image(fetchImageBlock: { $0(UIImage()) })
    }
    
}
