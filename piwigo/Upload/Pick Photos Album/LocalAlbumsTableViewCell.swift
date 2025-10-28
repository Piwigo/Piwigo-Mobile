//
//  LocalAlbumsTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class LocalAlbumsTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!

    func configure(with title: String, nberPhotos: Int64, startDate: Date, endDate: Date,
                   preferredContenSize: UIContentSizeCategory, width: CGFloat) -> Void {
        
        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        tintColor = PwgColor.tintColor
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin
        
        // Title
        titleLabel.textColor = PwgColor.leftLabel
        titleLabel.text = title
        
        // Number of photos
        numberLabel.textColor = PwgColor.rightLabel
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        if nberPhotos != Int64.min {
            numberLabel.text = numberFormatter.string(from: NSNumber(value: nberPhotos))
        } else {
            numberLabel.text = ""
        }
        
        // Date interval
        subtitleLabel.textColor = PwgColor.rightLabel

        // Single date?
        if startDate == endDate {
            switch preferredContenSize {
            case .extraSmall, .small, .medium, .large, .extraLarge:
                subtitleLabel.text = startDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
                
            case .extraExtraLarge, .extraExtraExtraLarge:
                switch width {
                case ...375:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
                case 376...402:
                    fallthrough
                default:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
                }
                
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
                subtitleLabel.text = startDate.formatted(.dateTime
                    .day(.twoDigits) .month(.abbreviated) .year(.twoDigits))
                
            case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                subtitleLabel.text = startDate.formatted(.dateTime
                    .day(.twoDigits) .month(.twoDigits) .year(.twoDigits))
                
            default:
                break
            }
            return
        }
        
        // Images taken the same day?
        let dateRange = startDate..<endDate
        let firstImageDay = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
        let lastImageDay = Calendar.current.dateComponents([.year, .month, .day], from: endDate)
        if firstImageDay == lastImageDay {
            switch preferredContenSize {
            case .extraSmall, .small, .medium, .large, .extraLarge:
                subtitleLabel.text = startDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
                
            case .extraExtraLarge, .extraExtraExtraLarge:
                switch width {
                case ...375:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
                case 376...402:
                    fallthrough
                default:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
                }
                
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
                switch width {
                case ...375:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.twoDigits) .month(.abbreviated) .year(.twoDigits))
                case 376...402:
                    fallthrough
                default:
                    subtitleLabel.text = startDate.formatted(.dateTime
                        .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
                }
                
            case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                subtitleLabel.text = startDate.formatted(.dateTime
                    .day(.twoDigits) .month(.twoDigits) .year(.twoDigits))
                
            default:
                break
            }
            return
        }
        
        // Images taken the same week?
        let firstImageWeek = Calendar.current.dateComponents([.year, .weekOfMonth], from: startDate)
        let lastImageWeek = Calendar.current.dateComponents([.year, .weekOfMonth], from: endDate)
        if firstImageWeek == lastImageWeek {
            switch preferredContenSize {
            case .extraSmall, .small, .medium, .large, .extraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.wide) .year())
                
            case .extraExtraLarge, .extraExtraExtraLarge:
                switch width {
                case ...375:
                    subtitleLabel.text = dateRange.formatted(.interval
                        .day() .month(.abbreviated) .year())
                case 376...402:
                    fallthrough
                default:
                    subtitleLabel.text = dateRange.formatted(.interval
                        .day() .month(.wide) .year())
                }
                
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.abbreviated) .year())
                
            case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.twoDigits) .year())
                
            default:
                break
            }
            return
        }
        
        // Images taken the same month?
        let firstImageMonth = Calendar.current.dateComponents([.year, .month], from: startDate)
        let lastImageMonth = Calendar.current.dateComponents([.year, .month], from: endDate)
        if firstImageMonth == lastImageMonth {
            switch preferredContenSize {
            case .extraSmall, .small, .medium, .large, .extraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.wide) .year())
                
            case .extraExtraLarge, .extraExtraExtraLarge:
                switch width {
                case ...375:
                    subtitleLabel.text = dateRange.formatted(.interval
                        .day() .month(.abbreviated) .year())
                case 376...402:
                    fallthrough
                default:
                    subtitleLabel.text = dateRange.formatted(.interval
                        .day() .month(.wide) .year())
                }
                
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.abbreviated) .year())
                
            case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.twoDigits) .year())
                
            default:
                break
            }
            return
        }
        
        // Images taken the same year?
        let firstImageYear = Calendar.current.dateComponents([.year], from: startDate)
        let lastImageYear = Calendar.current.dateComponents([.year], from: endDate)
        if firstImageYear == lastImageYear {
            switch preferredContenSize {
            case .extraSmall, .small, .medium, .large, .extraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.abbreviated) .year())
                
            case .extraExtraLarge, .extraExtraExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.twoDigits) .year())
                
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.abbreviated) .year())
                
            case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.twoDigits) .year())
                
            default:
                break
            }
            return
        }
        
        // Images not taken the same year
        switch preferredContenSize {
        case .extraSmall, .small, .medium, .large:
            switch width {
            case ...375:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.abbreviated) .year())
            case 376...402:
                fallthrough
            default:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.wide) .year())
            }
            
        case .extraLarge:
            switch width {
            case ...375:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.twoDigits) .year())
            case 376...402:
                fallthrough
            default:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.abbreviated) .year())
            }
            
        case .extraExtraLarge, .extraExtraExtraLarge:
            switch width {
            case ...375:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.abbreviated) .year())
            case 376...402:
                fallthrough
            default:
                subtitleLabel.text = dateRange.formatted(.interval
                    .day() .month(.abbreviated) .year())
            }
            
        case .accessibilityMedium:
            switch width {
            case ...375:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.twoDigits) .year())
            case 376...402:
                fallthrough
            default:
                subtitleLabel.text = dateRange.formatted(.interval
                    .month(.abbreviated) .year())
            }
            
        case .accessibilityLarge, .accessibilityExtraLarge:
            subtitleLabel.text = dateRange.formatted(.interval .year())
            
        case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            switch width {
            case ...375:
                var text = startDate.formatted(.dateTime .year())
                text.append(" - ")
                text.append(endDate.formatted(.dateTime .year()))
                subtitleLabel.text = text
            case 376...402:
                fallthrough
            default:
                subtitleLabel.text = dateRange.formatted(.interval .year())
            }
            
        default:
            break
        }
        return
    }

    override func prepareForReuse() {
        super.prepareForReuse()
//        titleLabel.text = ""
//        subtitleLabel.text = ""
//        numberLabel.text = ""
    }
}
