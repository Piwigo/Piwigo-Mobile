//
//  ImageCollectionViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ImageCollectionViewController: UICollectionViewController
{
    var user: User!
    var albumData: Album!
    
    // https://viet-tran.medium.com/uicollectionview-inside-a-uitableviewcell-with-self-sizing-beccb6de4159
    // Set this action during initialization to get a callback when the collection view finishes its layout.
    // To prevent infinite loop, this action should be called only once. Once it is called, it resets itself
    // to nil.
    var didLayoutAction: (() -> Void)?
    
    @IBOutlet var imageCollectionView: UICollectionView!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("===============================")
        print("••> imageCollectionView: \(view.debugDescription)")
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update table row height after first collection view layouting
        didLayoutAction?()
        didLayoutAction = nil   //  Call only once
    }
}
