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

@objc
protocol EditImageThumbnailDelegate: NSObjectProtocol {
    func didDeselectImage(withId imageId: Int)
    func didRenameFileOfImage(withId imageId: Int, andFilename fileName: String)
}

class EditImageThumbCollectionViewCell: UICollectionViewCell
{
    weak var delegate: EditImageThumbnailDelegate?

    @IBOutlet private weak var imageThumbnailView: UIView!
    @IBOutlet private weak var imageThumbnail: UIImageView!
    @IBOutlet private weak var imageDetails: UIView!
    @IBOutlet private weak var imageSize: UILabel!
    @IBOutlet private weak var imageFile: UILabel!
    @IBOutlet private weak var imageDate: UILabel!
    @IBOutlet private weak var imageTime: UILabel!
    @IBOutlet private weak var editButtonView: UIView!
    @IBOutlet private weak var editImageButton: UIButton!
    @IBOutlet private weak var removeButtonView: UIView!
    @IBOutlet private weak var removeImageButton: UIButton!

    private var imageId = 0
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

        editImageButton.tintColor = .piwigoColorOrange()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
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
        imageDate.textColor = .piwigoColorLeftLabel()
        imageTime.textColor = .piwigoColorLeftLabel()
    }

    func config(withImage imageData: PiwigoImageData?, removeOption hasRemove: Bool) {
        // Colors
        applyColorPalette()
        
        // Check provided image data
        guard let imageData = imageData else {
            return
        }
        
        // Store image ID
        imageId = imageData.imageId

        // Image file name
        if let fileName: String = imageData.fileName, fileName.isEmpty == false {
            imageFile.text = fileName
            editButtonView.isHidden = false     // Show button for renaming file
        }

        // Show button for removing image from selection if needed
        removeButtonView.isHidden = !hasRemove

        // Image from Piwigo server…
        if (imageData.fullResWidth > 0) && (imageData.fullResHeight > 0) {
            if bounds.size.width > CGFloat(299) {
                // i.e. larger than iPhone 5 screen width
                self.imageSize?.text = String(format: "%ldx%ld pixels, %.2f MB",
                                              Int(imageData.fullResWidth),
                                              Int(imageData.fullResHeight),
                                              Double(imageData.fileSize) / 1024.0)
            } else {
                self.imageSize?.text = String(format: "%ldx%ld pixels", 
                                              Int(imageData.fullResWidth),
                                              Int(imageData.fullResHeight))
            }
        }

        imageDate.text = ""
        if let dateCreated = imageData.dateCreated {
            if bounds.size.width > CGFloat(320) {
                // i.e. larger than iPhone 5 screen width
                imageDate.text = DateFormatter.localizedString(from: dateCreated, dateStyle: .full, timeStyle: .none)
            } else {
                imageDate.text = DateFormatter.localizedString(from: dateCreated, dateStyle: .long, timeStyle: .none)
            }
            imageTime.text = DateFormatter.localizedString(from: dateCreated, dateStyle: .none, timeStyle: .medium)
        }

        // Retrieve image thumbnail from Piwigo server
        var thumbnailUrl: String?
        let albumThumbnailSize = kPiwigoImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize)
        switch albumThumbnailSize {
        case kPiwigoImageSizeSquare:
            if AlbumVars.shared.hasSquareSizeImages, let squarePath = imageData.squarePath, squarePath.isEmpty == false {
                thumbnailUrl = squarePath
            } else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.shared.hasXXSmallSizeImages, let xxSmallPath = imageData.xxSmallPath, xxSmallPath.isEmpty == false {
                thumbnailUrl = xxSmallPath
            } else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.shared.hasXSmallSizeImages, let xSmallPath = imageData.xSmallPath, xSmallPath.isEmpty == false {
                thumbnailUrl = xSmallPath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.shared.hasSmallSizeImages, let smallPath = imageData.smallPath, smallPath.isEmpty == false {
                thumbnailUrl = smallPath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeMedium:
            if AlbumVars.shared.hasMediumSizeImages, let mediumPath = imageData.mediumPath, mediumPath.isEmpty == false {
                thumbnailUrl = mediumPath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeLarge:
            if AlbumVars.shared.hasLargeSizeImages, let largePath = imageData.largePath, largePath.isEmpty == false {
                thumbnailUrl = largePath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeXLarge:
            if AlbumVars.shared.hasXLargeSizeImages, let xLargePath = imageData.xLargePath, xLargePath.isEmpty == false {
                thumbnailUrl = xLargePath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeXXLarge:
            if AlbumVars.shared.hasXXLargeSizeImages, let xxLargePath = imageData.xxLargePath, xxLargePath.isEmpty == false {
                thumbnailUrl = xxLargePath
            }  else if AlbumVars.shared.hasThumbSizeImages, let thumbPath = imageData.thumbPath, thumbPath.isEmpty == false {
                 thumbnailUrl = thumbPath
            }
        case kPiwigoImageSizeThumb, kPiwigoImageSizeFullRes:
            fallthrough
        default:
            thumbnailUrl = imageData.thumbPath
        }

        guard let urlStr = thumbnailUrl,
              let imageUrl = URL(string: urlStr) else {
            // No known thumbnail URL
            imageThumbnail.image = UIImage(named: "placeholder")
            return
        }

        // Load album thumbnail
        imageThumbnail.layoutIfNeeded()
        let size: CGSize = imageThumbnail.bounds.size
        let scale = CGFloat(fmax(1.0, imageThumbnail.traitCollection.displayScale))
        var request = URLRequest(url: imageUrl)
        request.addValue("image/*", forHTTPHeaderField: "Accept")
        imageThumbnail.setImageWith(request,
                                    placeholderImage: UIImage(named: "placeholder"))
        { _, _, downloadedImage in
            DispatchQueue.global(qos: .userInitiated).async {
                let imageSize: CGSize = downloadedImage.size
                if fmax(imageSize.width, imageSize.height) > fmax(size.width, size.height) * scale {
                    let thumbnailImage = ImageUtilities.downsample(image: downloadedImage,
                                                                   to: size, scale: scale)
                    DispatchQueue.main.async {
                        self.imageThumbnail.image = thumbnailImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.imageThumbnail.image = downloadedImage
                    }
                }
            }
        } failure: { _, _, error in
            #if DEBUG
            print("setupWithImageData — Fail to get thumbnail for image at \(thumbnailUrl ?? "")")
            #endif
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
        var topViewController = UIApplication.shared.keyWindow?.rootViewController
        while topViewController?.presentedViewController != nil {
            topViewController = topViewController?.presentedViewController
        }

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
        JSONsession.postRequest(withMethod: kPiwigoImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update image filename if successful.
            do {
                // Decode the JSON into codable type TagJSON.
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
                                if delegate?.responds(to: #selector(EditImageThumbnailDelegate.didRenameFileOfImage(withId:andFilename:))) ?? false {
                                    delegate?.didRenameFileOfImage(withId: imageId, andFilename: fileName)
                                }
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
        if delegate?.responds(to: #selector(EditImageThumbnailDelegate.didDeselectImage(withId:))) ?? false {
            delegate?.didDeselectImage(withId: imageId)
        }
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
