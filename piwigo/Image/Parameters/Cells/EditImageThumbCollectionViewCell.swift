//
//  EditImageThumbCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 30/08/2021.
//

import Photos
import UIKit
import piwigoKit

@objc protocol EditImageThumbnailDelegate: NSObjectProtocol {
    func didDeselectImage(withID imageID: Int64)
    func didRenameFileOfImage(withId imageID: Int64, andFilename fileName: String)
}

class EditImageThumbCollectionViewCell: UICollectionViewCell
{
    weak var delegate: (any EditImageThumbnailDelegate)?

    @IBOutlet private weak var imageThumbnailView: UIView!
    @IBOutlet private weak var imageThumbnail: UIImageView!
    @IBOutlet private weak var imageDetails: UIView!
    @IBOutlet private weak var imageFile: UILabel!
    @IBOutlet private weak var imageSize: UILabel!
    @IBOutlet private weak var imageFileSize: UILabel!
    @IBOutlet private weak var imageDate: UILabel!
    @IBOutlet private weak var imageTime: UILabel!
    @IBOutlet private weak var editButtonView: UIView!
    @IBOutlet private weak var editImageButton: UIButton!
    @IBOutlet private weak var removeButtonView: UIView!
    @IBOutlet private weak var removeImageButton: UIButton!

    private var imageID = Int64.zero
    private var renameFileNameAction: UIAlertAction?
    private var oldFileName: String?

    override func awakeFromNib() {

        // Initialization code
        super.awakeFromNib()

        contentView.layer.cornerRadius = 10
        imageThumbnailView.layer.cornerRadius = 14
        imageThumbnail.layer.cornerRadius = 10
        imageDetails.layer.cornerRadius = 10
        editButtonView.layer.cornerRadius = 5
        removeButtonView.layer.cornerRadius = 15

        editImageButton.tintColor = PwgColor.orange

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background
        imageThumbnailView.backgroundColor = PwgColor.background
        imageDetails.backgroundColor = PwgColor.background
        editButtonView.backgroundColor = PwgColor.background
        removeButtonView.backgroundColor = PwgColor.cellBackground

        // Image size, file name, date and time
        imageSize.textColor = PwgColor.leftLabel
        imageFile.textColor = PwgColor.leftLabel
        imageFileSize.textColor = PwgColor.leftLabel
        imageDate.textColor = PwgColor.leftLabel
        imageTime.textColor = PwgColor.leftLabel
    }

    func config(withImage imageData: Image?, removeOption hasRemove: Bool) {
        // Colors
        applyColorPalette()
        
        // Check provided image data
        guard let imageData = imageData
        else { return }
        
        // Store image ID
        imageID = imageData.pwgID

        // Image file name
        if imageData.fileName.isEmpty == false {
            imageFile.text = imageData.fileName
            editButtonView.isHidden = false     // Show button for renaming file
        }

        // Show button for removing image from selection if needed
        removeButtonView.isHidden = !hasRemove

        // Image size in pixels, file size
        self.imageSize?.text = imageData.fullRes?.pixels ?? "?x?"
        self.imageFileSize?.text = ByteCountFormatter.string(fromByteCount: imageData.fileSize, countStyle: .file)
        
        // Image date and time
        imageDate.text = ""; imageTime.text = ""
        if imageData.dateCreated != DateUtilities.unknownDateInterval {
            let dateCreated = Date(timeIntervalSinceReferenceDate: imageData.dateCreated)
            let dateFormatter = DateUtilities.dateFormatter
            if bounds.size.width > CGFloat(430) {
                // i.e. larger than iPhone 14 Pro Max screen width
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .none
                imageDate.text = dateFormatter.string(from: dateCreated)
            } else {
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .none
                imageDate.text = dateFormatter.string(from: dateCreated)
            }
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .medium
            imageTime.text = dateFormatter.string(from: dateCreated)
        }

        // Get image from cache or download it
        imageThumbnail.layoutIfNeeded()   // Ensure imageView in its final size
        let scale = max(imageThumbnail.traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(imageThumbnail.bounds.size.width * scale, imageThumbnail.bounds.size.height * scale)
        let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        PwgSessionDelegate.shared.getImage(withID: imageData.pwgID, ofSize: thumbnailSize, type: .image,
                                           atURL: ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumbnailSize),
                                           fromServer: imageData.server?.uuid) { [weak self] cachedImageURL in
            self?.downsampleImage(atURL: cachedImageURL, to: cellSize)
        } failure: { [weak self] _ in
            self?.setThumbnailWithImage(pwgImageType.image.placeHolder)
        }
    }
    
    private func downsampleImage(atURL fileURL: URL, to cellSize: CGSize) {
        // Downsample image
        let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: cellSize, for: .image)

        // Set image thumbnail
        setThumbnailWithImage(cachedImage)
    }
    
    private func setThumbnailWithImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.imageThumbnail.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        imageFile.text = ""
        imageSize.text = ""
        imageDate.text = ""
        imageTime.text = ""
    }

    
    // MARK: - Edit Filename
    // Propose to edit original filename
    @IBAction func editFileName() {
        // Store old file name
        oldFileName = imageFile.text

        // Determine the present view controller
        let topViewController = window?.topMostViewController()

        let alert = UIAlertController(
            title: NSLocalizedString("renameImage_title", comment: "Original File"),
            message: "\(NSLocalizedString("renameImage_message", comment: "Enter a new file name for this image")) \"\(imageFile.text ?? "")\":",
            preferredStyle: .alert)

        alert.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = NSLocalizedString("renameImage_title", comment: "Original File")
            textField.text = imageFile.text
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel,
            handler: { _ in })

        renameFileNameAction = UIAlertAction(
            title: NSLocalizedString("renameCategory_button", comment: "Rename"),
            style: .default,
            handler: { [self] action in
                // Rename album if possible
                if let fileName = alert.textFields?.first?.text, fileName.count > 0 {
                    renameImageFile(withName: fileName,
                                    andViewController: topViewController)
                }
            })

        alert.addAction(cancelAction)
        if let renameFileNameAction = renameFileNameAction {
            alert.addAction(renameFileNameAction)
        }
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        topViewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }

    @MainActor
    private func renameImageFile(withName fileName: String,
                                 andViewController topViewController: UIViewController?) {
        // Display HUD during the update
        topViewController?.showHUD(withTitle: NSLocalizedString("renameImageHUD_label", comment: "Renaming Original File…"))

        // Prepare parameters for renaming the image/video filename
        let paramsDict: [String : Any] = ["image_id" : imageID,
                                          "file" : fileName,
                                          "single_value_mode" : "replace"]
        // Launch request
        let JSONsession = JSONManager.shared
        JSONsession.postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            switch result {
            case .success:
                // Filename successfully changed
                DispatchQueue.main.async {
                    topViewController?.updateHUDwithSuccess { [self] in
                        topViewController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            // Adopt new original filename
                            imageFile.text = fileName
                            
                            // Update parent image view
                            delegate?.didRenameFileOfImage(withId: imageID, andFilename: fileName)
                        }
                    }
                }
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                DispatchQueue.main.async {
                    topViewController?.hideHUD {
                        topViewController?.dismissPiwigoError(
                            withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"),
                            message: NSLocalizedString("renameImageError_message", comment: "Failed to rename your image filename"),
                            errorMessage: error.localizedDescription) { }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Remove Image from Selection
    @MainActor
    @IBAction func removeImage() {
        // Notify this deselection to parent view
        delegate?.didDeselectImage(withID: imageID)
    }
}


// MARK: - UITextFieldDelegate Methods
extension EditImageThumbCollectionViewCell: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable Add/Delete Category action
        renameFileNameAction?.isEnabled = false
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Rename button if name and extension not empty
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        let fileExt = URL(fileURLWithPath: finalString ?? "").pathExtension
        renameFileNameAction?.isEnabled = ((finalString?.count ?? 0) > 0) && ((fileExt.count ) >= 3) && (finalString != oldFileName)
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Rename button
        renameFileNameAction?.isEnabled = false
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
