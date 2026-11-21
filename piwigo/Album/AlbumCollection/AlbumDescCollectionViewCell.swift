//
//  AlbumDescCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

/// Album cell presented as a notebook:
/// - the left page presents the thumbnail and banner of an AlbumCollectionViewCell cell
///   (name and numbers of photos and sub-albums), which this class inherits outlets,
///   context menu and selection-mode handling from,
/// - the right page is a ruled page presenting the album description,
/// - oblong binding holes are punched along the seam joining both pages.
final class AlbumDescCollectionViewCell: AlbumCollectionViewCell {

    @IBOutlet weak var leftPage: UIView!
    @IBOutlet weak var rightPage: RuledPaperView!
    @IBOutlet weak var binding: BindingHolesView!
    @IBOutlet weak var thumbnailWidth: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Pages are rounded on their outer corners only
        leftPage.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        rightPage.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
    }

    /// The thumbnail adopts the width of AlbumCollectionViewCell cells so that
    /// both cells present identical thumbnails (cells share the same height).
    func config(withAlbum album: Album?, thumbnailWidth width: CGFloat) {
        thumbnailWidth.constant = width
        config(withAlbum: album)
    }

    override func config(withAlbum album: Album?) {
        // Album description
        setDescription(fromAlbumData: album)

        // Thumbnail, banner and recent icon (applies the colour palette)
        super.config(withAlbum: album)
    }

    @MainActor
    override func applyColorPalette() {
        super.applyColorPalette()

        // Pages
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        leftPage.backgroundColor = PwgColor.cellBackground
        rightPage.backgroundColor = PwgColor.cellBackground

        // Rules and binding holes
        rightPage.ruleColor = UIVars.shared.isDarkPaletteActive
            ? UIColor(red: 0.35, green: 0.47, blue: 0.62, alpha: 0.45)
            : UIColor(red: 0.53, green: 0.72, blue: 0.92, alpha: 0.55)
        binding.holeColor = PwgColor.background

        // Description
        setDescription(fromAlbumData: album)
    }


    // MARK: - Description
    /// Height of the lines of plain text descriptions
    private var lineHeight: CGFloat {
        (UIFont.preferredFont(forTextStyle: .footnote).lineHeight * 1.25).rounded()
    }

    private func setDescription(fromAlbumData albumData: Album?) {
        rightPage.defaultLineHeight = lineHeight
        rightPage.attributedText = getDescription(fromAlbumData: albumData)
    }

    private func getDescription(fromAlbumData albumData: Album?) -> NSAttributedString {
        // Any provided description? (presented with its own line spacing)
        if let description = albumData?.commentHTML, description.string.isEmpty == false {
            return description
        }

        // Plain text description or placeholder
        let text: String
        let color: UIColor
        if let description = albumData?.comment, description.string.isEmpty == false {
            text = description.string
            color = PwgColor.gray
        }
        else if albumData?.user?.getProperties().hasAdminRights ?? false {
            text = String(localized: "createNewAlbumDescription_noDescription", comment: "no description")
            color = PwgColor.placeHolder
        }
        else {
            return NSAttributedString()
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .natural
        style.lineBreakMode = .byWordWrapping   // Truncation is managed by the page
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        let attributes: [NSAttributedString.Key : Any] = [
            .foregroundColor: color,
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .paragraphStyle: style
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rightPage.attributedText = NSAttributedString()
    }
}


// MARK: - Ruled Paper
/// Page presenting a text written on horizontal rules, like a notebook page.
/// The text and the rules are drawn from the same TextKit layout, so that the rules lie
/// under the baselines of the lines whatever their spacing (HTML descriptions keep their
/// own line spacing). Below the text, the rules continue with the spacing of its last lines.
final class RuledPaperView: UIView {
    
    /// Text written on the rules
    var attributedText = NSAttributedString() {
        didSet {
            accessibilityLabel = attributedText.string
            invalidateTextLayout()
        }
    }
    
    /// Margins of the text
    var textInsets = UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 12.0) {
        didSet { invalidateTextLayout() }
    }
    
    /// Spacing of the rules when there is no text
    var defaultLineHeight: CGFloat = 18.0 {
        didSet { if defaultLineHeight != oldValue { invalidateTextLayout() } }
    }
    
    /// Distance between baselines and rules
    var ruleOffset: CGFloat = 2.0 {
        didSet { invalidateTextLayout() }
    }
    
    var ruleColor: UIColor = .systemBlue.withAlphaComponent(0.3) {
        didSet { setNeedsDisplay() }
    }
    
    // TextKit 1 stack used for both drawing the text and positioning the rules
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()
    private var layoutSize = CGSize.zero
    private var rules = [CGFloat]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configTextKit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configTextKit()
    }
    
    private func configTextKit() {
        isAccessibilityElement = true
        accessibilityIdentifier = "comment"
        textContainer.lineFragmentPadding = 0.0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }
    
    private func invalidateTextLayout() {
        layoutSize = .zero      // Forces a new layout
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != layoutSize else { return }
        layoutSize = bounds.size
        layoutText()
        setNeedsDisplay()
    }
    
    /// Lays out the lines fitting in the page, truncating the last one if needed,
    /// and determines the positions of the rules.
    private func layoutText() {
        let textWidth = max(0.0, bounds.width - textInsets.left - textInsets.right)
        let textHeight = max(0.0, bounds.height - textInsets.top - textInsets.bottom)
        let bottomLimit = bounds.height - 4.0
        
        // Lay out the whole text
        textStorage.setAttributedString(attributedText)
        textContainer.size = CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        let allLines = lineFragments()
        let nbLines = allLines.count
        let nbFittingLines = allLines.filter { $0.rect.maxY <= textHeight }.count
        
        // Truncate the last fitting line when the text is too long
        if nbLines > nbFittingLines {
            textContainer.maximumNumberOfLines = max(1, nbFittingLines)
            textContainer.lineBreakMode = .byTruncatingTail
            layoutManager.textContainerChangedGeometry(textContainer)
        }
        
        // Baselines of the presented lines, in the coordinates of the page
        var baselines = [CGFloat]()
        var lastLineHeight = defaultLineHeight
        for line in lineFragments() {
            baselines.append(textInsets.top + line.rect.minY + line.baseline)
            lastLineHeight = line.usedRect.height
        }
        
        // No text: rules spaced with the default line height
        guard let lastBaseline = baselines.last
        else {
            let descender = UIFont.preferredFont(forTextStyle: .footnote).descender
            let first = textInsets.top + defaultLineHeight + descender + ruleOffset
            rules = Array(stride(from: first, to: bottomLimit, by: max(defaultLineHeight, 8.0)))
            return
        }
        
        // Rules under the lines, then continuing with the spacing of the last lines
        rules = baselines.map { $0 + ruleOffset }.filter { $0 < bottomLimit }
        var spacing = lastLineHeight
        if baselines.count > 1 {
            spacing = lastBaseline - baselines[baselines.count - 2]
        }
        spacing = max(spacing, 8.0)
        var y = lastBaseline + ruleOffset + spacing
        while y < bottomLimit {
            rules.append(y)
            y += spacing
        }
    }
    
    /// Line fragments with their baseline (relative to the fragment origin)
    private func lineFragments() -> [(rect: CGRect, usedRect: CGRect, baseline: CGFloat)] {
        guard textStorage.length > 0 else { return [] }
        var lines = [(rect: CGRect, usedRect: CGRect, baseline: CGFloat)]()
        let manager = layoutManager
        let glyphRange = manager.glyphRange(for: textContainer)
        manager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, _, lineGlyphs, _ in
            let baseline = manager.location(forGlyphAt: lineGlyphs.location).y
            lines.append((rect, usedRect, baseline))
        }
        return lines
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext()
        else { return }
        
        // Hairline rules aligned on pixels
        if rules.isEmpty == false {
            let scale = max(traitCollection.displayScale, 1.0)
            let lineWidth = 1.0 / scale
            context.setStrokeColor(ruleColor.cgColor)
            context.setLineWidth(lineWidth)
            for y in rules {
                let alignedY = (y * scale).rounded() / scale + lineWidth / 2.0
                context.move(to: CGPoint(x: 0.0, y: alignedY))
                context.addLine(to: CGPoint(x: bounds.width, y: alignedY))
            }
            context.strokePath()
        }
        
        // Text
        guard textStorage.length > 0 else { return }
        let origin = CGPoint(x: textInsets.left, y: textInsets.top)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }
}


// MARK: - Binding Holes
/// Vertical oblong holes punched along the seam of the pages,
/// evenly distributed over its height, i.e. with equal gaps between holes and edges.
final class BindingHolesView: UIView {

    /// Number of holes
    var nbHoles: Int = 3 {
        didSet { setNeedsDisplay() }
    }

    /// Height of holes relative to the height of the view
    var holeHeightRatio: CGFloat = 0.16 {
        didSet { setNeedsDisplay() }
    }

    var holeColor: UIColor = .systemGroupedBackground {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard nbHoles > 0 else { return }
        let holeHeight = bounds.height * holeHeightRatio
        let gap = max(0.0, bounds.height - CGFloat(nbHoles) * holeHeight) / CGFloat(nbHoles + 1)
        holeColor.setFill()
        var y = gap
        for _ in 0..<nbHoles {
            let hole = CGRect(x: 0.0, y: y, width: bounds.width, height: holeHeight)
            UIBezierPath(roundedRect: hole, cornerRadius: bounds.width / 2.0).fill()
            y += holeHeight + gap
        }
    }
}
