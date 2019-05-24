//
//  DLGAlbumsViewController.swift
//  DLGPicker
//
//  Created by Victor Eysner on 15/01/2019.
//

import UIKit

final class DLGAlbumsViewController: UITableViewController {
    
    init() {
        super.init(style: .grouped)
        title = NSLocalizedString("Albums", comment: "Albums")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.allowsSelection = true
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100
        tableView.register(DLGAlbumCell.self, forCellReuseIdentifier: DLGAlbumCell.cellIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
}
