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
    func didDeselectImage(withId imageId: Int64)
    func didRenameFileOfImage(withId imageId: Int64, andFilename fileName: String)
}

class EditImageThumbCollectionViewCell: UICollectionViewCell
{
    weak var delegate: EditImageThumbnailDelegate?

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

    private var imageId = Int64.zero
    private var renameFileNameAction: UIAlertAction?
    private var oldFileName: String?
    private var download: ImageDownload?

    override func awakeFromNib() {

        // Initialization code
        super.awakeFromNib()

        contentView.layer.cornerRadius = 10
        imageThumbnailView.layer.cornerRadius = 14
        imageThumbnail.layer.cornerRadius = 10
        imageDetails.layer.cornerRadius = 10
        editButtonView.layer.cornerRadius = 5
        removeButtonView.layer.cornerRadius = 15

        editImageButton.tintColor = .piwigoColorOrange()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        // Background
        imageThumbnailView.backgroundColor = .piwigoColorBackground()
        imageDetails.backgroundColor = .piwigoColorBackground()
        editButtonView.backgroundColor = .piwigoColorBackground()
        removeButtonView.backgroundColor = .piwigoColorCellBackground()

        // Image size, file name, date and time
        imageSize.textColor = .piwigoColorLeftLabel()
        imageFile.textColor = .piwigoColorLeftLabel()
        imageFileSize.textColor = .piwigoColorLeftLabel()
        imageDate.textColor = .piwigoColorLeftLabel()
        imageTime.textColor = .piwigoColorLeftLabel()
    }

    func config(withImage imageData: Image?, removeOption hasRemove: Bool) {
        // Colors
        applyColorPalette()
        
        // Check provided image data
        guard let imageData = imageData else {
            return
        }
        
        // Store image ID
        imageId = imageData.pwgID

        // Image file name
        if imageData.fileName.isEmpty == false {
            imageFile.text = imageData.fileName
            editButtonView.isHidden = false     // Show button for renaming file
        }

        // Show button for removing image from selection if needed
        removeButtonView.isHidden = !hasRemove

        // Image size in pixels, file size, date and time
        self.imageSize?.text = imageData.fullRes?.pixels ?? "— pixels"
        self.imageFileSize?.text = ByteCountFormatter.string(fromByteCount: imageData.fileSize, countStyle: .file)
        imageDate.text = ""
        if bounds.size.width > CGFloat(320) {
            // i.e. larger than iPhone 5 screen width
            imageDate.text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                           dateStyle: .full, timeStyle: .none)
        } else {
            imageDate.text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                           dateStyle: .long, timeStyle: .none)
        }
        imageTime.text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                       dateStyle: .none, timeStyle: .medium)

        // Retrieve image thumbnail from Piwigo server
        let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        guard let serverID = imageData.server?.uuid,
              let imageURL = ImageUtilities.getURLs(imageData, ofMinSize: thumbnailSize) else {
            return
        }

        // Get image from cache or download it
        imageThumbnail.layoutIfNeeded()
        let placeHolder = UIImage(named: "placeholder")!
        let size: CGSize = imageThumbnail.bounds.size
        let scale = CGFloat(fmax(1.0, imageThumbnail.traitCollection.displayScale))
        download = ImageDownload(imageID: imageData.pwgID, ofSize: thumbnailSize, atURL: imageURL as URL,
                                 fromServer: serverID, placeHolder: placeHolder) { cachedImage in
            DispatchQueue.global(qos: .userInitiated).async {
                let imageSize: CGSize = cachedImage.size
                if fmax(imageSize.width, imageSize.height) > fmax(size.width, size.height) * scale {
                    let thumbnailImage = ImageUtilities.downsample(image: cachedImage,
                                                                   to: size, scale: scale)
                    DispatchQueue.main.async {
                        self.imageThumbnail.image = thumbnailImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.imageThumbnail.image = cachedImage
                    }
                }
            }
        }
        download?.getImage()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        download = nil
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

        alert.addTextField(configurationHandler: { [unowned self] textField in
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
            handler: { [unowned self] action in
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
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        topViewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }

    private func renameImageFile(withName fileName: String,
                         andViewController topViewController: UIViewController?) {
        // Display HUD during the update
        topViewController?.showPiwigoHUD(withTitle: NSLocalizedString("renameImageHUD_label", comment: "Renaming Original File…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Prepare parameters for renaming the image/video filename
        let paramsDict: [String : Any] = ["image_id" : imageId,
                                          "file" : fileName,
                                          "single_value_mode" : "replace"]
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update image filename if successful.
            do {
                // Decode the JSON into codable type ImagesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                    errorMessage: uploadJSON.errorMessage)
                    topViewController?.hidePiwigoHUD {
                        topViewController?.dismissPiwigoError(
                            withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"),
                              message: NSLocalizedString("renameImageError_message", comment: "Failed to rename your image filename"), errorMessage: error.localizedDescription) { }
                    }
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Filename successfully changed
                    topViewController?.updatePiwigoHUDwithSuccess { [unowned self] in
                        topViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                            DispatchQueue.main.async(execute: { [unowned self] in
                                // Adopt new original filename
                                imageFile.text = fileName

                                // Update parent image view
                                delegate?.didRenameFileOfImage(withId: imageId, andFilename: fileName)
                            })
                        }
                    }
                }
                else {
                    // Could not change the filename
                    debugPrint("••> setImageInfoForImageWithId(): no successful")
                    let error = JsonError.unexpectedError
                    topViewController?.hidePiwigoHUD {
                        topViewController?.dismissPiwigoError(
                            withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"),
                              message: NSLocalizedString("renameImageError_message", comment: "Failed to rename your image filename"), errorMessage: error.localizedDescription) { }
                    }
                    return
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                topViewController?.hidePiwigoHUD {
                    topViewController?.dismissPiwigoError(
                        withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"),
                          message: NSLocalizedString("renameImageError_message", comment: "Failed to rename your image filename"), errorMessage: error.localizedDescription) { }
                }
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            topViewController?.hidePiwigoHUD {
                topViewController?.dismissPiwigoError(
                    withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"),
                      message: NSLocalizedString("renameImageError_message", comment: "Failed to rename your image filename"), errorMessage: error.localizedDescription) { }
            }
        }
    }

    
    // MARK: - Remove Image from Selection
    @IBAction func removeImage() {
        // Notify this deselection to parent view
        delegate?.didDeselectImage(withId: imageId)
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
