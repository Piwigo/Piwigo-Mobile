//
//  RenameFileTableHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/09/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class RenameFileTableHeaderView: UIView {
    
    @IBOutlet weak var headerWidth: NSLayoutConstraint!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerViewLeading: NSLayoutConstraint!
    @IBOutlet weak var headerViewTrailing: NSLayoutConstraint!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var exampleLabel: UILabel!
    @IBOutlet weak var exampleLabelLeading: NSLayoutConstraint!
    @IBOutlet weak var exampleLableTrailing: NSLayoutConstraint!
    
    // Constants
    private let margin: CGFloat = 14.0 + TableViewUtilities.rowCornerRadius
    private let exampleFileName: String = "IMG_0023.HEIC"
    private var widthConstraint = CGSize.zero
    
    // Date when Steve Jobs first announced the iPhone
    private let iPhoneAnnouncementDate: Date = {
        var components = DateComponents()
        components.year = 2007
        components.month = 01
        components.day = 9
        components.hour = 9
        components.minute = 41
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configView() {
        let headerView = viewFromNibForClass()
        addSubview(headerView)
    }
    
    // Loads XIB file into a view and returns this view
    private func viewFromNibForClass() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        return view
    }
    
    @MainActor
    func applyColorPalette() {
        titleLabel?.textColor = PwgColor.header
        subtitleLabel?.textColor = PwgColor.header
        exampleLabel?.textColor = PwgColor.text
    }
    
    @MainActor
    func config(with title: String, text: String, forWidth width: CGFloat) {
        // Initialise drawing context
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // Initialise variables and width constraint
        /// The minimum width of a screen is of 320 pixels.
        /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
        var height: CGFloat = CGFloat.zero
        let minWidth: CGFloat = 320.0 - 2 * margin
        let maxWidth = CGFloat(fmax(width - 2.0 * margin, minWidth))
        widthConstraint = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Title
        titleLabel?.text = title
        let titleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)]
        height += title.boundingRect(with: widthConstraint,
                                     options: .usesLineFragmentOrigin,
                                     attributes: titleAttributes,
                                     context: context).height
        
        // Subtitle
        subtitleLabel?.text = text
        let subtitleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .footnote)]
        height += text.boundingRect(with: widthConstraint,
                                    options: .usesLineFragmentOrigin,
                                    attributes: subtitleAttributes,
                                    context: context).height
        
        // Size of headerView
        let headerRect = CGRect(origin: CGPoint.zero,
                                size: CGSize(width: maxWidth, height: height))
        headerView?.frame = headerRect
        headerViewLeading?.constant = margin
        headerViewTrailing?.constant = margin
        
        // Unchanged file name
        let exampleFileName = exampleFileName + "\r" + "⇩" + "\r" + exampleFileName
        let exampleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
        let exampleRect = exampleFileName.boundingRect(with: widthConstraint,
                                                       options: .usesLineFragmentOrigin,
                                                       attributes: exampleAttributes,
                                                       context: context)
        exampleLabel?.frame = exampleRect
        exampleLabelLeading.constant = margin
        exampleLableTrailing.constant = margin
        
        // Global size
        let size = CGSize(width: width, height: headerView.frame.height + 16.0 + exampleRect.height)
        frame = CGRect(origin: CGPoint.zero, size: size)
        headerWidth.constant = width
        
        // Color palette
        applyColorPalette()
    }
    
    func updateExample(prefix: Bool, prefixActions: RenameActionList,
                       replace: Bool, replaceActions: RenameActionList,
                       suffix: Bool, suffixActions: RenameActionList,
                       changeCase: Bool, caseOfExtension: FileExtCase,
                       categoryId: Int32, counter: Int64) {
        var fileName = exampleFileName
        fileName.renameFile(prefixActions: prefix ? prefixActions : [],
                            replaceActions: replace ? replaceActions : [],
                            suffixActions: suffix ? suffixActions : [],
                            caseOfExtension: changeCase ? caseOfExtension : .keep,
                            albumID: categoryId, date: iPhoneAnnouncementDate, counter: counter)
        let exampleFileName = exampleFileName + "\r" + "⇩" + "\r" + fileName
        
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let exampleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
        let exampleRect = exampleFileName.boundingRect(with: widthConstraint,
                                                       options: .usesLineFragmentOrigin,
                                                       attributes: exampleAttributes,
                                                       context: context)
        exampleLabel?.text = exampleFileName
        exampleLabel?.frame = exampleRect

        // Update global size
        frame.size.height = headerView.frame.height + 16.0 + exampleRect.height
        debugPrint(frame)
    }
}
