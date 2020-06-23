import Foundation
import UIKit
import Photos

public typealias TelegramSelection = (TelegramSelectionType) -> ()

public enum TelegramSelectionType {
    case media([PHAsset])
    case photoLibrary
    case location(Location?)
    case contact(Contact?)
    case camera(Camera.PreviewStream)
    case document
    case photosAsDocuments([PHAsset])
    case scannerDocument
}

extension UIAlertController {
    
    /// Add Telegram Picker
    ///
    /// - Parameters:
    ///   - selection: type and action for selection of asset/assets
    
    public func addTelegramPicker(selection: @escaping TelegramSelection,
                                  localizer: TelegramPickerResourceProvider) {
        let vc = TelegramPickerViewController(selection: selection, localizer: localizer)
        setTelegramPicker(vc)
    }
    
    public func setTelegramPicker(_ picker: TelegramPickerViewController) {
        set(vc: picker, addPanGestureToDissmiss: true)
    }
}

extension UIImageView: DisplaceableView {}

final public class TelegramPickerViewController: UIViewController {
    
    // MARK: - Nested
    
    public enum ButtonType: Int {
        case photoOrVideo
        case location
        case contact
        case file
        case sendPhotos
        case documentAsFile
        case photoAsFile
        case visionScanner
    }
    
    public enum SelectionMode: Int {
        case single
        case multiple
    }
    
    public struct MediaType: OptionSet {
        
        public typealias RawValue = Int
        
        public let rawValue: Int
        
        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        public static let photos = MediaType.init(1 << 0)
        public static let videos = MediaType.init(1 << 1)
        public static let camera = MediaType.init(1 << 2)
    }
    
    enum StreamItem: Equatable {
        case noAccessToCamera
        case noAccessToPhotos
        case photo(PHAsset)
        case video(PHAsset)
        case camera
        
        var isCamera: Bool {
            switch self {
            case .camera: return true
            default: return false
            }
        }
        
        var isRepresentingCamera: Bool {
            switch self {
            case .camera, .noAccessToCamera: return true
            default: return false
            }
        }
        
        var asset: PHAsset? {
            switch self {
            case .photo(let asset), .video(let asset): return asset
            default: return nil
            }
        }
        
        private var typeId: Int {
            switch self {
            case .camera: return 1
            case .noAccessToCamera: return 2
            case .noAccessToPhotos: return 3
            case .photo(_): return 4
            case .video(_): return 5
            }
        }
        
        public static func == (lhs: StreamItem, rhs: StreamItem) -> Bool {
            switch (lhs, rhs) {
            case (let .photo(lhsAsset), let .photo(rhsAsset)): return lhsAsset == rhsAsset
            case (let .video(lhsAsset), let .video(rhsAsset)): return lhsAsset == rhsAsset
            default: return lhs.typeId == rhs.typeId
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
            default:
                return nil
            }
        }
    }
    
    enum CellId: String {
        case photo
        case video
        case camera
        case noAccess
    }
    
    enum Mode: Int {
        case normal
        case bigPhotoPreviews
        case documentType
    }
    
    enum NoAccessType {
        case noCameraAccess
        case noPhotoAccess
    }
    
    struct UI {
        static let rowHeight: CGFloat = 58
        static let insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        static let minimumInteritemSpacing: CGFloat = 6
        static let minimumLineSpacing: CGFloat = 6
        static let maxHeight: CGFloat = UIScreen.main.bounds.width / 2
        static let multiplier: CGFloat = 2
    }
    
    public enum DismissBehavior {
        case dismissGaleryFirst(animated: Bool, thenDismissPickerAnimated: Bool)
        case dismissPicker(animated: Bool)
    }
    
    // MARK: - Vars
    
    private static let preheatingLength = 20
    
    public var dismissBehavior: DismissBehavior = .dismissPicker(animated: true)
    
    fileprivate var mode = Mode.normal {
        didSet {
            resetButtons()
        }
    }
    
    let assetsCollection = AssetsCollection.init()
    
    private var buttons: [ButtonType] = []
    
    /**
     Buttons types that should not be shown under the media items stream.
     - warning: It's expected that you configure this field before controller view did load. Otherwise behavior is undefined.
     */
    public var disabledButtonTypes: [ButtonType] = []
    
    /**
     Describes what kind of media items should be shown.
     - warning: It's expected that you configure this field before controller view did load. Otherwise behavior is undefined.
     */
    public var mediaTypes: MediaType = [.photos, .videos, .camera] {
        didSet {
            if isViewLoaded {
                self.resetItems(assets: self.assetsCollection.assets)
            }
        }
    }
    
    private var photoLayout: PhotoLayout {
        return collectionView.collectionViewLayout as! PhotoLayout
    }
    
    var preferredTableHeaderHeight: CGFloat {
        switch mode {
        case .normal: return UI.maxHeight / UI.multiplier + UI.insets.top + UI.insets.bottom
        case .bigPhotoPreviews: return UI.maxHeight + UI.insets.top + UI.insets.bottom
        case .documentType: return 0
        }
    }
    
    public var cameraCellNeeded: Bool {
        return self.mediaTypes.contains(.camera)
    }
    
    public var cameraStream: Camera.PreviewStream? = nil {
        didSet {
            if cameraStream !== oldValue, isViewLoaded {
                updateCameraCells()
            }
        }
    }
    
    public var shouldShowCameraNoAccess: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) != .authorized
    }
    
    public var shouldShowCameraStream: Bool {
        return cameraCellNeeded && mode == .normal
    }
    
    public var shouldShowPhotosNoAccess: Bool {
        return PHPhotoLibrary.authorizationStatus() != .authorized
    }
    
    /**
     Describes behavior on items tap and configure UI accordingly.
     - warning: It's expected that you configure this field before controller view did load. Otherwise behavior is undefined.
     */
    public var selectionMode = SelectionMode.multiple
    
    private var visibleItemEntries: [(indexPath: IndexPath, item: StreamItem)] {
        let indexPaths = collectionView.indexPathsForVisibleItems
        let entries: [(indexPath: IndexPath, item: StreamItem)] = indexPaths.map({ (indexPath: $0, item: items[$0.item]) })
        return entries
    }
    
    /// Called in case telegram picket was canceled
    private var cancelCompletion: (()-> Void)?
    private func clearCancelCompletion() -> (()-> Void)? {
        let completion = cancelCompletion
        cancelCompletion = nil
        return completion
    }
    
    // MARK: Properties
    
    fileprivate lazy var collectionView: UICollectionView = { [unowned self] in
        $0.dataSource = self
        $0.delegate = self
        $0.allowsMultipleSelection = true
        $0.showsVerticalScrollIndicator = false
        $0.showsHorizontalScrollIndicator = false
        $0.decelerationRate = UIScrollViewDecelerationRateFast
        $0.contentInset = UI.insets
        $0.backgroundColor = .clear
        $0.layer.masksToBounds = false
        $0.clipsToBounds = false
        $0.register(CollectionViewPhotoCell.self, forCellWithReuseIdentifier: CellId.photo.rawValue)
        $0.register(CollectionViewVideoCell.self, forCellWithReuseIdentifier: CellId.video.rawValue)
        $0.register(CollectionViewCameraCell.self, forCellWithReuseIdentifier: CellId.camera.rawValue)
        $0.register(CollectionViewNoCameraAccessCell.self, forCellWithReuseIdentifier: CellId.noAccess.rawValue)
        
        return $0
        }(UICollectionView(frame: .zero, collectionViewLayout: layout))
    
    fileprivate lazy var layout: PhotoLayout = { [unowned self] in
        $0.delegate = self
        $0.lineSpacing = UI.minimumLineSpacing
        return $0
        }(PhotoLayout())
    
    fileprivate lazy var tableView: UITableView = { [unowned self] in
        $0.dataSource = self
        $0.delegate = self
        $0.rowHeight = UI.rowHeight
        $0.separatorColor = UIColor.lightGray.withAlphaComponent(0.4)
        $0.separatorInset = .zero
        $0.backgroundColor = nil
        $0.bounces = false
        $0.tableHeaderView = collectionView
        $0.tableFooterView = UIView()
        $0.register(LikeButtonCell.self, forCellReuseIdentifier: LikeButtonCell.identifier)
        if #available(iOS 11, *) {
            $0.contentInsetAdjustmentBehavior = .always
        }
        return $0
        }(UITableView(frame: .zero, style: .plain))
    
    lazy var items = [StreamItem]()
    lazy var selectedAssets = [PHAsset]()
    var galleryItems: [StreamItem] {
        return items.filter({ $0 != .camera })
    }
    
    let selection: TelegramSelection
    let localizer: TelegramPickerResourceProvider
    let configurator: TelegramPickerConfigurator
    weak var presentsController: UIViewController?
    
    // MARK: - Funcs
    
    // MARK: Initialize
    
    required public init(selection: @escaping TelegramSelection,
                         localizer: TelegramPickerResourceProvider,
                         configurator: TelegramPickerConfigurator = SimpleTelegramPickerConfigurator(),
                         presentsController: UIViewController? = nil,
                         cancelCompletion: (()-> Void)? = nil){
        self.selection = selection
        self.localizer = localizer
        self.configurator = configurator
        self.presentsController = presentsController
        self.cancelCompletion = cancelCompletion
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func sizeForPreviewPreload(asset: PHAsset) -> CGSize {
        let height: CGFloat = UI.maxHeight
        let width: CGFloat = CGFloat(Double(height) * Double(asset.pixelWidth) / Double(asset.pixelHeight))
        
        let imageSize = CGSize(width: width, height: height)
        let previewSize = UIScreen.main.bounds.size
        
        let scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        
        let targetSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        return targetSize
    }
    
    func sizeForAsset(asset: PHAsset) -> CGSize {
        switch mode {
        case .bigPhotoPreviews:
            let minValue: CGFloat = UI.maxHeight / UI.multiplier
            var size = CGSize.init(width: asset.pixelWidth, height: asset.pixelHeight)
            let multiplier = UI.maxHeight / size.height
            size.height *= multiplier
            size.width = max(minValue, size.width*multiplier)
            return size
        case .normal:
            let value: CGFloat = UI.maxHeight / UI.multiplier
            return CGSize(width: value, height: value)
        case .documentType:
            return .zero
        }
    }
    
    func sizeForItem(item: StreamItem) -> CGSize {
        switch item {
        case .photo(let asset), .video(let asset):
            return sizeForAsset(asset: asset)
        default:
            let side = UI.maxHeight / UI.multiplier
            return CGSize.init(width: side, height: side)
        }
    }
    
    override public func loadView() {
        view = tableView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        resetButtons()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            preferredContentSize.width = UIScreen.main.bounds.width * 0.5
        }
        
        updatePhotos()
        checkCameraState{stream in
            self.cameraStream = stream
        }
        resetItems()
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if tableView.tableHeaderView?.frame.size.height != preferredTableHeaderHeight {
            collectionView.frame.size.height = preferredTableHeaderHeight
            tableView.tableHeaderView = collectionView
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if preferredContentSize.height != tableView.contentSize.height {
            preferredContentSize.height = tableView.contentSize.height
            view.layoutIfNeeded()
            tableView.layoutIfNeeded()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        cancelCompletion?()
    }
    
    deinit {
        guard let input = cameraStream?.input else { return }
        self.cameraStream?.session.removeInput(input)
    }
    
    func resetItems() {
        
        var newItems: [StreamItem] = []
        if !shouldShowPhotosNoAccess {
            newItems = createItems(assets: assetsCollection.assets)
        }
        
        if shouldShowCameraStream {
            let item: StreamItem = shouldShowCameraNoAccess ? .noAccessToCamera : .camera
            newItems.insert(item, at: 0)
        }
        
        resetItems(newItems: newItems)
    }
    
    func updateItemsByInsetingCamera() {
        guard !items.contains(.camera) else {
            return
        }
        
        var newItems = items
        if let index = items.firstIndex(of: .noAccessToCamera) {
            newItems[index] = .camera
            
            collectionView.performBatchUpdates({
                items = newItems
                collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }, completion: nil)
        }
        else {
            newItems.insert(.camera, at: 0)
            
            collectionView.performBatchUpdates({
                items = newItems
                collectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
            }, completion: nil)
        }
    }
    
    func createItems(assets: [PHAsset]) -> [StreamItem] {
        let videosAllowed = mediaTypes.contains(.videos)
        let photosAllowed = mediaTypes.contains(.photos)
        return assets
            .filter({
                switch $0.mediaType {
                case .image: return photosAllowed
                case .video: return videosAllowed
                default: return false
                }
            })
            .compactMap({ StreamItem.init(asset: $0) })
    }
    
    func resetItems(assets: [PHAsset]) {
        var newItems: [StreamItem] = []
        if !shouldShowPhotosNoAccess {
            newItems = createItems(assets: assets)
        }
        
        if shouldShowCameraStream {
            let item: StreamItem = shouldShowCameraNoAccess ? .noAccessToCamera : .camera
            newItems.insert(item, at: 0)
        }
        
        resetItems(newItems: newItems)
    }
    
    func resetItems(newItems: [StreamItem]) {
        items = newItems
        tableView.reloadData()
        collectionView.reloadData()
    }
    
    func updateCamera() {
        guard cameraCellNeeded else {
            cameraStream = nil
            return
        }
        
        checkCameraState { [weak self] (stream) in
            self?.cameraStream = stream
        }
    }
    
    func updatePhotos() {
        checkStatus()
    }
    
    func setupCameraStream(_ completionHandler: @escaping (Camera.PreviewStream?) -> ()) {
        Camera.PreviewStream.create { (result) in
            DispatchQueue.main.async {
                switch result {
                case .error(error: let error):
                    self.handleCameraStreamFailure(error)
                    completionHandler(nil)
                case .stream(let stream):
                    completionHandler(stream)
                }
            }
        }
    }
    
    func handleCameraStreamFailure(_ error: Error) {
        print("Error while setup camera stream. \(error.localizedDescription)")
        if let alert = localizer.localizedAlert(failure: .error(error)) {
            alert.show(presentsController: self.presentsController)
        }
    }
    
    var isThisFirstAutorisation: Bool {
        return Camera.authorizationStatus == .notDetermined
    }
    
    func checkCameraState(completionHandler: @escaping (Camera.PreviewStream?)->()) {
        
        /// This case means the user is prompted for the first time for camera access
        switch Camera.authorizationStatus {
        case .notDetermined:
            Camera.requestAccess { [weak self] gotAccess in
                if gotAccess {
                    self?.checkCameraState(completionHandler: completionHandler)
                    DispatchQueue.main.async {
                        self?.resetItems()
                    }
                }
            }
        case .authorized:
            setupCameraStream(completionHandler)
        default:
            return
        }
    }
    
    private func accessToDeniedCamera() {
        DispatchQueue.main.async { [weak self] in
            /// User has denied the current app to access the camera.
            let alert = self?.localizer.localizedAlert(failure: .noAccessToCamera, cancelCompletion: self?.clearCancelCompletion())
            self?.alertController?.dismiss(animated: true) {
                alert?.show(presentsController: self?.presentsController)
            }
        }
    }
        
    
    func checkStatus() {
        switch PHPhotoLibrary.authorizationStatus() {
            
        case .notDetermined:
            /// This case means the user is prompted for the first time for allowing contacts
            Assets.requestAccess { [weak self] status in
                self?.checkStatus()
            }
            
        case .authorized:
            /// Authorization granted by user for this app.
            DispatchQueue.main.async {
                self.resetItems()
                self.runAssetsCollection()
            }
            
        case .denied, .restricted:
            break
        }
    }
    
    func runAssetsCollection() {
        assetsCollection.handler = { [weak self] event in
            self?.handleAssetsCollectionEvent(event)
        }
        assetsCollection.start()
    }
    
    func handleAssetsCollectionEvent(_ update: AssetsCollection.Event) {
        
        switch update {
            
        case .failure(let error):
            if let alert = localizer.localizedAlert(failure: .error(error)) {
                alert.show(presentsController: self.presentsController)
            }
            
        case .fullReloadNeeded:
            resetItems(assets: assetsCollection.assets)
            
        case .loaded:
            resetItems(assets: assetsCollection.assets)
            
        case .update(let changes):
            applyAssetsCollectionChanges(changes)
            
        }
    }
    
    func applyAssetsCollectionChanges(_ changes: [AssetsCollectionChange]) {
        
        let shouldShiftIndexes = shouldShowCameraStream
        let changesToApply = shouldShiftIndexes ? AssetsCollectionChange.shift(changes: changes, offset: 1) : changes
        
        var insertionIndexPaths: [IndexPath] = []
        var removalIndexPaths: [IndexPath] = []
        
        collectionView.performBatchUpdates({
            changesToApply.forEach { (change) in
                switch change {
                case .inserted(let asset, at: let idx):
                    
                    if let item = StreamItem.init(asset: asset) {
                        items.insert(item, at: idx)
                    }
                    
                    let indexPath = IndexPath.init(item: idx, section: 0)
                    collectionView.insertItems(at: [indexPath])
                    insertionIndexPaths.append(indexPath)
                    
                case .removed(_, at: let idx):
                    
                    items.remove(at: idx)
                    
                    let indexPath = IndexPath.init(item: idx, section: 0)
                    collectionView.deleteItems(at: [indexPath])
                    removalIndexPaths.append(indexPath)
                }
            }
            photoLayout.prepareForInsertion(insertionIndexPaths)
            photoLayout.prepareForRemoval(removalIndexPaths)
            
        }) { [weak self] (_) in
            self?.updateVisibleCellsVisibleAreaRects()
        }
        
    }
    
    func fetchPhotos(completionHandler: @escaping ([PHAsset]) -> ()) {
        
        Assets.fetch { [weak self] result in
            switch result {
                
            case .success(let assets):
                completionHandler(assets)
                
            case .error(let error):
                if let alert = self?.localizer.localizedAlert(failure: .error(error)) {
                    alert.show(presentsController: self?.presentsController)
                }
            }
        }
    }
    
    private func handleSingleSelectionUserChoice(item: StreamItem, at indexPath: IndexPath) {
        
        var selectionItem: TelegramSelectionType? = nil
        
        switch item {
        case .camera:
            if let stream = cameraStream {
                selectionItem = .camera(stream)
                selection(.camera(stream))
            }
            
        case .photo(let asset), .video(let asset):
            selectionItem = .media([asset])
            
        case .noAccessToCamera:
            accessToDeniedCamera()
            
        case .noAccessToPhotos:
            break
        }
        
        if let item = selectionItem {
            self.dismissWithSelectionItem(item: item)
        }
    }
    
    private func handleMultiselectionUserChoice(item: StreamItem, at indexPath: IndexPath) {
        switch item {
        case .camera:
            if let stream = cameraStream {
                cancelCompletion = nil
                selection(.camera(stream))
            }
        case .photo(let asset):
            collectionView.deselectItem(at: indexPath, animated: false)
            self.openPreview(with: asset, at: indexPath)
            
        case .video(let asset):
            collectionView.deselectItem(at: indexPath, animated: false)
            self.openPreview(with: asset, at: indexPath)
        
        case .noAccessToCamera:
            accessToDeniedCamera()
            
        case .noAccessToPhotos:
            break
        }
    }
    
    func action(withItem item: StreamItem, at indexPath: IndexPath) {
        
        switch selectionMode {
        case .single:
            handleSingleSelectionUserChoice(item: item, at: indexPath)
            
        case .multiple:
            handleMultiselectionUserChoice(item: item, at: indexPath)
        }
        
    }
    
    func openPreview(with asset: PHAsset, at indexPath: IndexPath) {
        
        let galleryItemIndex = galleryItems.index(of: items[indexPath.item]) ?? 0
        
        var config = galleryConfiguration()
        self.configurator.modifyGalleryConfig(&config)
        
        let galleryViewController = GalleryViewController(startIndex: galleryItemIndex,
                                                          itemsDataSource: createGalleryItemsDataSource(),
                                                          itemsDelegate: self,
                                                          displacedViewsDataSource: self,
                                                          configuration: config)
        
        galleryViewController.selectionCompletion = { [weak self, weak galleryViewController] button in
            if let picker = self, let controller = galleryViewController {
                picker.handleGallerySelection(ofItemAt: indexPath, controller: controller, tappedButton: button)
            }
        }
        present(galleryViewController, animated: false, completion: nil)
    }
    
    func switchSelection(streamItem: StreamItem) {
        switch streamItem {
        case .photo(let asset), .video(let asset):
            if selectedAssets.contains(asset) {
                selectedAssets.remove(asset)
            }
            else {
                selectedAssets.append(asset)
            }
        default: break
        }
    }
    
    func isSelected(streamItem: StreamItem) -> Bool {
        switch streamItem {
        case .photo(let asset), .video(let asset):
            return selectedAssets.contains(asset)
        default:
            return false
        }
    }
    
    func handleGallerySelection(ofItemAt indexPath: IndexPath, controller: GalleryViewController, tappedButton: UIButton) {
        let item = galleryItems[controller.currentIndex]
        
        switchSelection(streamItem: item)
        
        let becomeSelected = isSelected(streamItem: item)

        tappedButton.setSelected(becomeSelected, withTitle: becomeSelected ? String(self.selectedAssets.count) : nil, animated: true)
        
        updateVisibleSelectionIndexes()
        updateModeIfNeed(from: indexPath)
        updateSendButtonsTitleIfNeeded()
    }
    
    func updateVisibleSelectionIndexes() {
        updateSendButtonsTitleIfNeeded()
        
        let visibleIndexPaths = collectionView.visibleCells.compactMap({ collectionView.indexPath(for: $0) })
        for indexPath in visibleIndexPaths {
            let item = items[indexPath.item]
            switch item {
            case .photo(let _asset), .video(let _asset):
                let animated = mode == .bigPhotoPreviews ? selectedAssets.count > 0 : selectedAssets.count > 1
                updateAssetSelection(cell: collectionView.cellForItem(at: indexPath) as? CollectionViewCustomContentCell<UIImageView>, asset: _asset, at: indexPath, animated: animated)
            default:()
            }
        }
    }
    
    func updateSendButtonsTitleIfNeeded() {
        if let idx = buttons.index(of: .sendPhotos),
            let cell = tableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? LikeButtonCell {
            let selectedAssetsTypes = self.selectedAssets.map({ $0.mediaType })
            var buttonTitle = self.localizer.localized(buttonType: .photos(count: self.selectedAssets.count))
            if selectedAssetsTypes.contains(.image) && selectedAssetsTypes.contains(.video) {
                buttonTitle = self.localizer.localized(buttonType: .medias(count: self.selectedAssets.count))
            } else if selectedAssetsTypes.contains(.image) {
                buttonTitle = self.localizer.localized(buttonType: .photos(count: self.selectedAssets.count))
            } else if selectedAssetsTypes.contains(.video) {
                buttonTitle = self.localizer.localized(buttonType: .videos(count: self.selectedAssets.count))
            }
            cell.textLabel?.text = buttonTitle
        }
        
        if let idx = buttons.index(of: .photoAsFile),
            let cell = tableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? LikeButtonCell {
            cell.textLabel?.text = self.localizer.localized(buttonType: .sendPhotoAsFile(count: self.selectedAssets.count))
        }
    }
    
    func applyMode(_ newMode: Mode, collectionIndexPath: IndexPath? = nil) {
        
        guard newMode != self.mode else {
            return
        }
        
        mode = newMode
        
        collectionView.isHidden = newMode == .documentType
        
        collectionView.performBatchUpdates({
            switch mode {
            case .documentType:
                tableView.reloadData()
            case .bigPhotoPreviews:
                tableView.reloadData()
            case .normal:
                tableView.reloadData()
            }
            self.layout.mode = (newMode == .normal) ? .normal : .hidingFirstItem
        }, completion: { [weak self] _ in
            // Workaround. Remove when the whole "wrong selection mark layout" bug will be fixed.
            self?.updateVisibleCellsVisibleAreaRects()
        })
    }
    
    func switchToDocumentTypeMenu() {
        self.applyMode(.documentType)
    }
    
    private func buttonsForMode(_ mode: Mode) -> [ButtonType] {
        switch mode {
        case .normal: return [.photoOrVideo, .file, .location, .contact, .visionScanner]
        case .bigPhotoPreviews: return [.sendPhotos, .photoAsFile]
        case .documentType: return [.documentAsFile, .photoAsFile]
        }
    }
    
    private func resetButtons() {
        self.buttons = buttonsForMode(mode).filter({!disabledButtonTypes.contains($0)})
    }
    
    func action(for button: ButtonType) {
        
        let cancelComplition = clearCancelCompletion()
        
        switch button {
            
        case .photoOrVideo:
            let selection = self.selection
            alertController?.dismiss(animated: true) {
                if self.shouldShowPhotosNoAccess {
                    let alert = self.localizer.localizedAlert(failure: .noAccessToPhoto, cancelCompletion: cancelComplition)
                    alert?.show(presentsController: self.presentsController)
                } else {
                    selection(.photoLibrary)
                }
            }
            
        case .photoAsFile:
            let assets = selectedAssets
            let selection = self.selection
            if configurator.needCallSelectionForAssetsBeforeCompletion() {
                selection(TelegramSelectionType.photosAsDocuments(assets))
                alertController?.dismiss(animated: true, completion: nil)
            } else {
                alertController?.dismiss(animated: true) {
                    selection(TelegramSelectionType.photosAsDocuments(assets))
                }
            }

        case .documentAsFile:
            let selection = self.selection
            alertController?.dismiss(animated: true) {
                selection(.document)
            }
            
        case .location:
            let selection = self.selection
            let provider = self.localizer.resourceProviderForLocationPicker()
            alertController?.addLocationPicker(location: nil,
                                               resourceProvider: provider,
                                               completion: { location in
                                                selection(TelegramSelectionType.location(location))
            })
            
        case .contact:
            let selection = self.selection
            alertController?.addContactsPicker(localizer: localizer) { contact in
                selection(TelegramSelectionType.contact(contact))
            }
            
        case .sendPhotos:
            let assets = selectedAssets
            let selection = self.selection
            if configurator.needCallSelectionForAssetsBeforeCompletion() {
                selection(TelegramSelectionType.media(assets))
                alertController?.dismiss(animated: true, completion: nil)
            } else {
                alertController?.dismiss(animated: true) {
                    selection(TelegramSelectionType.media(assets))
                }
            }
            
        case .file:
            let selection = self.selection
            alertController?.dismiss(animated: true) {
                selection(.document)
            }
        case .visionScanner:
            let selection = self.selection
            alertController?.dismiss(animated: true, completion: {
                selection(.scannerDocument)
            })
        }
    }
}

// MARK: - TableViewDelegate

extension TelegramPickerViewController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        action(withItem: items[indexPath.item], at: indexPath)
    }
    
    private func isSelectableItem(at indexPath: IndexPath, collectionView: UICollectionView) -> Bool {
        switch items[indexPath.item] {
        case .camera:
            return false
        case .photo(_), .video(_):
            return true
        default:
            return true
        }
    }
    
}

// MARK: - CollectionViewDataSource

extension TelegramPickerViewController: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch items[indexPath.item] {
        case .camera:
            return dequeue(collectionView, cellForCameraAt: indexPath)
            
        case .photo(let asset), .video(let asset):
            return dequeue(collectionView, cellForAsset: asset, at: indexPath)
            
        case .noAccessToCamera:
            return dequeue(collectionView, noAccess: .noCameraAccess, cellAt: indexPath)
            
        case .noAccessToPhotos:
            return dequeue(collectionView, noAccess: .noPhotoAccess, cellAt: indexPath)
        }
        
    }
    
    private func dequeue(_ collectionView: UICollectionView, noAccess: NoAccessType, cellAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CollectionViewNoCameraAccessCell = dequeue(collectionView, id: .noAccess, indexPath: indexPath)
        return cell
    }
    
    private func dequeue(_ collectionView: UICollectionView, cellForCameraAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CollectionViewCameraCell = dequeue(collectionView, id: .camera, indexPath: indexPath)
        cell.showSelectionCircles = false
        return cell
    }
    
    private func dequeue(_ collectionView: UICollectionView,
                         cellForAsset asset: PHAsset,
                         at indexPath: IndexPath) -> UICollectionViewCell {
        var cell: CollectionViewCustomContentCell<UIImageView>
        
        var configuration = galleryConfiguration()
        configurator.modifyGalleryConfig(&configuration)
        
        switch asset.mediaType {
        case .video:
            cell = dequeue(collectionView, id: .video, indexPath: indexPath)
        default:
            cell = dequeue(collectionView, id: .photo, indexPath: indexPath)
        }
        
        cell.showSelectionCircles = selectionMode == .multiple
        
        var color: UIColor? {
            for item in configuration {
                if case GalleryConfigurationItem.selectionButtonTintColor(let color) = item {
                    return color
                }
            }
            return nil
        }
        
        cell.setSelectionElement(color: color ?? view.tintColor, forState: .selected)
        
        return cell
    }
    
    private func dequeue<CellClass>(_ collectionView: UICollectionView, id: CellId, indexPath: IndexPath) -> CellClass {
        return collectionView.dequeueReusableCell(withReuseIdentifier: id.rawValue, for: indexPath) as! CellClass
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        preheatNextItems(at: indexPath)
        
        switch items[indexPath.item] {
            
        case .photo(let asset):
            guard let photoCell = cell as? CollectionViewPhotoCell else {
                return
            }
            
            photoCell.isLoading = true
            
            photoCell.delegate = self
            let size = sizeForPreviewPreload(asset: asset)
            updateAssetSelection(cell: photoCell, asset: asset, at: indexPath, animated: false)
            // We must sure that cell still visible and represents same asset
            Assets.resolve(asset: asset, size: size) { [weak self] new in
                self?.updatePhoto(new, asset: asset)
            }
            
        case .video(let asset):
            guard let videoCell = cell as? CollectionViewVideoCell else {
                return
            }
            videoCell.delegate = self
            let size = sizeForPreviewPreload(asset: asset)
            updateAssetSelection(cell: videoCell, asset: asset, at: indexPath, animated: false)
            // We must sure that cell still visible and represents same asset
            Assets.resolve(asset: asset, size: size) { [weak self] new in
                self?.updatePhoto(new, asset: asset)
            }
            
        case .camera:
            guard let cameraCell = cell as? CollectionViewCameraCell else {
                return
            }
            
            cameraCell.customContentView.representedStream = self.cameraStream
            
        default:
            break
        }
        
        self.updateVisibleAreaRect(cell: cell, indexPath: indexPath)
    }
    
    private func preheatNextItems(at indexPath: IndexPath) {
        
        guard let lastIdx = items.indices.last else {
            return
        }
        
        let upperBound = min(indexPath.item + TelegramPickerViewController.preheatingLength, lastIdx)
        let lowerBound = indexPath.item + 1
        guard upperBound > lowerBound else {
            return
        }
        
        let range = lowerBound..<upperBound
        let streamItemsToPreheat = items[range]
        let assetsToPreheat = streamItemsToPreheat.compactMap({$0.asset})
        
        let preheatEntries = assetsToPreheat.map({
            Assets.PreheatRequest.Entry.init(asset: $0, size: sizeForAsset(asset: $0))
        })
        let request = Assets.PreheatRequest.init(entries: preheatEntries)
        Assets.preheat(request: request)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else {
            return
        }
        
        updateVisibleCellsVisibleAreaRects()
    }
    
    private func updateVisibleCellsVisibleAreaRects() {
        let indexPaths = collectionView.indexPathsForVisibleItems
        for indexPath in indexPaths {
            if let cell = collectionView.cellForItem(at: indexPath) {
                updateVisibleAreaRect(cell: cell, indexPath: indexPath)
            }
        }
    }
    
    private func updateVisibleAreaRect(cell: UICollectionViewCell, indexPath: IndexPath) {
        guard let cell = cell as? CollectionViewCustomContentCell<UIImageView> else {
            return
        }
        
        let cellVisibleRectInCollectionView = cell.convert(cell.bounds, to: collectionView)
        let cellVisibleAreaInCollectionView = cellVisibleRectInCollectionView.intersection(collectionView.bounds)
        let cellVisibleRect = cell.convert(cellVisibleAreaInCollectionView, from: collectionView)
        
        layout.updateVisibleArea(cellVisibleRect, itemAt: indexPath, cell: cell)
    }
    
    private func updatePhoto(_ photo: UIImage?, asset: PHAsset) {
        for entry in visibleItemEntries {
            switch entry.item {
            case .photo(let itemAsset):
                if asset == itemAsset, let cell = collectionView.cellForItem(at: entry.indexPath) as? CollectionViewPhotoCell {
                    cell.customContentView.image = photo
                    cell.isLoading = false
                }
            case .video(let itemAsset):
                if asset == itemAsset, let cell = collectionView.cellForItem(at: entry.indexPath) as? CollectionViewVideoCell {
                    cell.customContentView.image = photo
                    cell.updateVideo(duration: asset.duration)
                }
            default:
                continue
            }
        }
    }
    
    private func updateCameraCells() {
        
        guard shouldShowCameraStream else {
            return
        }
        
        if items.contains(.camera) {
            for entry in visibleItemEntries where entry.item.isCamera {
                guard let cell = collectionView.cellForItem(at: entry.indexPath) as? CollectionViewCameraCell else {
                    return
                }
                cell.customContentView.representedStream = cameraStream
            }
        } else {
            
        }

    }
    
    private func dismissWithSelectionItem(item: TelegramSelectionType) {
        let selection = self.selection
        switch item {
        case .media(_):
            if configurator.needCallSelectionForAssetsBeforeCompletion() {
                selection(item)
                alertController?.dismiss(animated: true, completion: nil)
            } else {
                alertController?.dismiss(animated: true) {
                    selection(item)
                }
            }

        default:
            alertController?.dismiss(animated: true, completion: {
                selection(item)
            })
        }
    }
    
}

// MARK: - PhotoLayoutDelegate

extension TelegramPickerViewController: PhotoLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        return sizeForItem(item: items[indexPath.item])
    }
}

// MARK: - TableViewDelegate

extension TelegramPickerViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.action(for: self.buttons[indexPath.row])
    }
}

// MARK: - TableViewDataSource

extension TelegramPickerViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return buttons.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LikeButtonCell.identifier) as! LikeButtonCell
        if let label = cell.textLabel {
            label.font = font(for: buttons[indexPath.row])
            label.text = title(for: buttons[indexPath.row])
            label.textColor = view.tintColor
        }
        return cell
    }
}

//MARK: - GalleryItemsDelegate

extension TelegramPickerViewController: GalleryItemsDelegate {
    
    public func isItemSelected(at index: Int) -> Bool {
        guard let item = galleryItems.item(at: index) else { return false }
        switch item {
        case .photo(let asset), .video(let asset):
            return selectedAssets.contains(asset)
        default:
            return false
        }
    }
    
    public func itemSelectionIndex(at index: Int) -> Int? {
        guard let item = galleryItems.item(at: index) else { return nil }
        switch item {
        case .photo(let asset), .video(let asset):
            if let selectionIndex = selectedAssets.index(of: asset) {
                return selectionIndex + 1
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    public func removeGalleryItem(at index: Int) {
        
    }
    
    public func sendItem(_ galleryViewController: GalleryViewController, at index: Int) {
        //send current asset if selected array is empty
        if selectedAssets.isEmpty, let item = galleryItems.item(at: index) {
            switch item {
            case .photo(let asset), .video(let asset):
                selectedAssets.append(asset)
            default:
                break
            }
        }
        
        let assets = self.selectedAssets
        let selection = self.selection

        if configurator.needCallSelectionForAssetsBeforeCompletion() {
            selection(TelegramSelectionType.media(assets))
            self.parent?.presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            alertController?.dismiss(animated: true) {
                selection(TelegramSelectionType.media(assets))
            }
        }
    }
    
    func dismiss(galleryViewController: GalleryViewController, behavior: DismissBehavior) {
        
        let assets = self.selectedAssets
        let selection = self.selection
        
        switch behavior {
            
        case .dismissGaleryFirst(animated: let galeryAnimated, thenDismissPickerAnimated: let pickerAnimated):
            galleryViewController.closeGallery(galeryAnimated) {
                if self.configurator.needCallSelectionForAssetsBeforeCompletion() {
                    selection(TelegramSelectionType.media(assets))
                    self.alertController?.dismiss(animated: pickerAnimated, completion: nil)
                } else {
                    self.alertController?.dismiss(animated: pickerAnimated) {
                        selection(TelegramSelectionType.media(assets))
                    }
                }
            }
            
        case .dismissPicker(animated: let animated):
            guard let alert = self.parent, let alertPresenter = alert.presentingViewController else {
                return
            }
            if self.configurator.needCallSelectionForAssetsBeforeCompletion() {
                selection(TelegramSelectionType.media(assets))
                alertPresenter.dismiss(animated: animated, completion: nil)
            } else {
                self.alertController?.dismiss(animated: animated) {
                    selection(TelegramSelectionType.media(assets))
                }
            }
        }
    }
    
    func title(for button: ButtonType) -> String {
        
        let localizableButton: LocalizableButtonType
        
        switch button {
        case .photoOrVideo: localizableButton = .photoOrVideo
        case .file: localizableButton = .file
        case .location: localizableButton = .location
        case .contact: localizableButton = .contact
        case .sendPhotos: localizableButton = .photos(count: selectedAssets.count)
        case .documentAsFile: localizableButton = .sendDocumentAsFile
        case .photoAsFile: localizableButton = .sendPhotoAsFile(count: selectedAssets.count)
        case .visionScanner: localizableButton = .contact
        }
        
        return self.localizer.localized(buttonType: localizableButton)
    }
    
    func font(for button: ButtonType) -> UIFont {
        switch button {
        case .sendPhotos: return UIFont.boldSystemFont(ofSize: 20)
        default: return UIFont.systemFont(ofSize: 20) }
    }
    
}

//MARK: - GalleryDisplacedViewsDataSource

extension TelegramPickerViewController: GalleryDisplacedViewsDataSource {
    
    public func provideDisplacementItem(atIndex index: Int) -> DisplaceableView? {
        let item = galleryItems[index]
        let indexPath = IndexPath(item: items.index(of: item) ?? 0, section: 0)
        let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCustomContentCell<UIImageView>
        return cell?.customContentView
    }
    
}

private extension TelegramPickerViewController {
    
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
            GalleryConfigurationItem.displacementInsetMargin(50),
            GalleryConfigurationItem.selectionButtonTintColor(.red),
            GalleryConfigurationItem.sendButtonTintColor(.red)
        ]
    }
    
    func updateAssetSelection<T>(cell: CollectionViewCustomContentCell<T>? = nil, asset: PHAsset, at indexPath: IndexPath, animated: Bool) where T: UIView {
        let isSelected = selectedAssets.contains(asset)
        let index = isSelected ? (selectedAssets.index(of: asset) ?? 0) + 1 : 0
        let cellAnimated = isSelected ? selectedAssets.count > 1 : selectedAssets.count > 0
        cell?.updateSelectionIndex(isSelected: isSelected, with: index, animated: animated && cellAnimated)
    }
    
    func updateModeIfNeed(from indexPath: IndexPath) {
        if isSelectableItem(at: indexPath, collectionView: collectionView) {
            layout.selectedCellIndexPath = indexPath
        }
        if selectedAssets.count > 0 {
            applyMode(.bigPhotoPreviews, collectionIndexPath: indexPath)
        } else {
            applyMode(.normal, collectionIndexPath: indexPath)
        }
    }
    
}

extension TelegramPickerViewController: CollectionViewCustomContentCellDelegate {
    func collectionViewCustomContentCell<T>(cell: CollectionViewCustomContentCell<T>, didTapOnSelection button: UIButton) where T : UIView {
        guard let indexPath = collectionView.indexPath(for: cell),
            let item = items.item(at: indexPath.item) else { return }
        
        switch item {
        case .photo(let asset), .video(let asset):
            if selectedAssets.contains(asset) {
                selectedAssets.remove(asset)
            } else {
                selectedAssets.append(asset)
            }
        default:
            break
        }
        
        updateModeIfNeed(from: indexPath)
        
        //TODO: Make scroll to selected view and thier NEW index path
        
        updateVisibleSelectionIndexes()
    }
}

