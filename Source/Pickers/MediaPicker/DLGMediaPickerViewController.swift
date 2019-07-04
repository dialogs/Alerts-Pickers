//
//  DLGMediaPickerViewController.swift
//  DLGPicker
//
//  Created by Victor Eysner on 15/01/2019.
//

import UIKit
import Photos

public class DLGMediaPickerViewController: BSImagePickerViewController {
    
    var selectionClosure: ((_ asset: PHAsset) -> Void)?
    var deselectionClosure: ((_ asset: PHAsset) -> Void)?
    var cancelClosure: ((_ assets: [PHAsset]) -> Void)?
    var finishClosure: ((_ assets: [PHAsset]) -> Void)?
    var selectLimitReachedClosure: ((_ selectionLimit: Int) -> Void)?
    
    public override init() {
        super.init()
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit(){
        settings.selectionFillColor = PickerStyle.shared.selectionButtonTintColor
    }

    
    @objc private lazy var dlgPhotosViewController: DLGPhotosViewController = makePhotoViewController()
    private lazy var toolItems: [UIBarButtonItem] = {
        let items = [cancelButton, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneButton]
        items.forEach({ $0.tintColor = PickerStyle.shared.selectionButtonTintColor })
        return items
        }()
    private lazy var albumsDataSource = AlbumTableViewDataSource(fetchResults: fetchResults)
    private lazy var albumsViewController: DLGAlbumsViewController = {
        let vc = DLGAlbumsViewController()
        vc.tableView.dataSource = self.albumsDataSource
        vc.tableView.delegate = self
        vc.toolbarItems = toolItems
        return vc
    }()
    
    private func setupClosure(select: ((_ asset: PHAsset) -> Void)?,
                              deselect: ((_ asset: PHAsset) -> Void)?,
                              cancel: (([PHAsset]) -> Void)?,
                              finish: (([PHAsset]) -> Void)?,
                              completion: (() -> Void)?,
                              selectLimitReached: ((Int) -> Void)? = nil) {
        
        selectionClosure = select
        dlgPhotosViewController.selectionClosure = {[weak self] asset in self?.selectionClosure?(asset)}
        deselectionClosure = deselect
        dlgPhotosViewController.deselectionClosure = {[weak self] asset in self?.deselectionClosure?(asset)}
        cancelClosure = cancel
        dlgPhotosViewController.cancelClosure = {[weak self] assets in self?.cancelButtonPressed(nil)}
        finishClosure = finish
        dlgPhotosViewController.finishClosure = {[weak self] assets in self?.doneButtonPressed(nil)}
        selectLimitReachedClosure = selectLimitReached
        dlgPhotosViewController.selectLimitReachedClosure = {[weak self] limit in self?.selectLimitReachedClosure?(limit)}
        
    }
    
    static public func presentImagePickerController(in viewController: UIViewController,
                                             imagePicker: DLGMediaPickerViewController,
                                             animated: Bool,
                                             select: ((_ asset: PHAsset) -> Void)?,
                                             deselect: ((_ asset: PHAsset) -> Void)?,
                                             cancel: (([PHAsset]) -> Void)?,
                                             finish: (([PHAsset]) -> Void)?,
                                             completion: (() -> Void)?,
                                             selectLimitReached: ((Int) -> Void)? = nil) {
        
        BSImagePickerViewController.authorize(fromViewController: viewController) { (authorized) -> Void in
            // Make sure we are authorized before proceding
            guard authorized == true else { return }
            imagePicker.setupClosure(select: select,
                                     deselect: deselect,
                                     cancel: cancel,
                                     finish: finish,
                                     completion: completion,
                                     selectLimitReached: selectLimitReached)
            // Present
            viewController.present(imagePicker, animated: animated, completion: completion)
        }
    }
    
    private func makePhotoViewController() -> DLGPhotosViewController {
        var selections: [PHAsset] = []
        defaultSelections?.enumerateObjects({ (asset, idx, stop) in
            selections.append(asset)
        })
        
        let assetStore = AssetStore(assets: selections)
        let vc = DLGPhotosViewController(fetchResults: self.fetchResults,
                                         assetStore: assetStore,
                                         settings: settings)
        vc.toolbarItems = toolItems
        vc.doneBarButton = doneButton
        vc.cancelBarButton = cancelButton
        return vc
    }
    
    open override func loadView() {
        super.loadView()
        
        // Make sure we really are authorized
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            self.setToolbarHidden(false, animated: false)
            setViewControllers([albumsViewController], animated: false)
            doneButton.isEnabled = false
            doneButton.target = self
            doneButton.action = #selector(self.doneButtonPressed(_:))
            cancelButton.target = self
            cancelButton.action = #selector(self.cancelButtonPressed(_:))
        }
    }
    
    // MARK: Button actions
    @objc func cancelButtonPressed(_ sender: UIBarButtonItem?) {
        dismiss(animated: true, completion: nil)
        UIApplication.shared.statusBarStyle = .lightContent
        cancelClosure?(dlgPhotosViewController.assetStore.assets)
    }
    
    @objc func doneButtonPressed(_ sender: UIBarButtonItem?) {
        dismiss(animated: true, completion: nil)
        UIApplication.shared.statusBarStyle = .lightContent
        finishClosure?(dlgPhotosViewController.assetStore.assets)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar.tintColor = PickerStyle.shared.selectionButtonTintColor
        UIApplication.shared.statusBarStyle = .default
    }
    
}

extension DLGMediaPickerViewController: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update photos data source
        let album = albumsDataSource.fetchResults[indexPath.section][indexPath.row]
        dlgPhotosViewController.initializePhotosDataSource(album)
        dlgPhotosViewController.updateAlbumTitle(album)
        dlgPhotosViewController.collectionView?.reloadData()

        // Dismiss album selection
        self.pushViewController(dlgPhotosViewController, animated: true)
    }

}
