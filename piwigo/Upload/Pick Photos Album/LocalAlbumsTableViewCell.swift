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
    
    func configure(with title: String, nberPhotos: Int, startDate: Date?, endDate: Date?) -> Void {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()

        // Title
        titleLabel.font = UIFont.piwigoFontNormal()
        titleLabel.textColor = UIColor.piwigoColorLeftLabel()
        titleLabel.text = title
        
        // Number of photos
        numberLabel.font = UIFont.piwigoFontSmall()
        numberLabel.textColor = UIColor.piwigoColorRightLabel()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        if nberPhotos != NSNotFound {
            numberLabel.text = numberFormatter.string(from: NSNumber(value: nberPhotos))
        } else {
            numberLabel.text = ""
        }

        // Append date interval
        var subtitle: String = ""
        if let startDate = startDate {
            if let endDate = endDate {
                let calendar = Calendar.current
                let startDateComponents = calendar.dateComponents([.day, .month, .year], from: startDate)
                let endDateComponents = calendar.dateComponents([.day, .month, .year], from: endDate)

                if startDateComponents.year == endDateComponents.year {
                    // Photos from the same year
                    if startDateComponents.month == endDateComponents.month {
                        // Photo from the same month
                        if startDateComponents.day == endDateComponents.day {
                            // Photos from the same day
                            if UIScreen.main.bounds.size.width > 414 {
                                let dateFormatter1 = DateFormatter.init(), dateFormatter2 = DateFormatter.init()
                                dateFormatter1.locale = .current
                                dateFormatter2.locale = .current
                                dateFormatter1.setLocalizedDateFormatFromTemplate("EEEE MMMMYYYYd HH:mm")
                                dateFormatter2.setLocalizedDateFormatFromTemplate("HH:mm")
                                subtitle.append(dateFormatter1.string(from: startDate) + " — " + dateFormatter2.string(from: endDate))
                            } else {
                                let dateFormatter = DateFormatter.init()
                                dateFormatter.locale = .current
                                dateFormatter.setLocalizedDateFormatFromTemplate("MMMMYYYYd")
                                subtitle.append(dateFormatter.string(from: startDate))
                            }
                        } else {
                            // Photos from different days in the same month
                            let dateFormatter1 = DateFormatter.init(), dateFormatter2 = DateFormatter.init()
                            dateFormatter1.locale = .current
                            dateFormatter2.locale = .current
                            if UIScreen.main.bounds.size.width > 414 {
                                // i.e. larger than iPhones 6, 7 screen width
                                dateFormatter1.setLocalizedDateFormatFromTemplate("EEEE d HH:mm")
                                dateFormatter2.setLocalizedDateFormatFromTemplate("EEEE MMMMYYYYd HH:mm")
                                subtitle.append(dateFormatter1.string(from: startDate) + " — " + dateFormatter1.string(from: endDate))
                            } else {
                                dateFormatter1.setLocalizedDateFormatFromTemplate("d")
                                dateFormatter2.setLocalizedDateFormatFromTemplate("MMMMYYYYd")
                                subtitle.append(dateFormatter1.string(from: startDate) + " — " + dateFormatter1.string(from: endDate))
                            }

                            let dateFormatter = DateFormatter.init()
                            dateFormatter.locale = .current
                            dateFormatter.setLocalizedDateFormatFromTemplate("YYYYMMMM")
                            let startString = dateFormatter.string(from: startDate)
                            subtitle.append(String(format: "%@", startString))
                        }
                    } else {
                        // Photos from different months in the same year
                        let dateFormatter1 = DateFormatter.init(), dateFormatter2 = DateFormatter.init()
                        dateFormatter1.locale = .current
                        dateFormatter2.locale = .current
                        if UIScreen.main.bounds.size.width > 414 {
                            // i.e. larger than iPhones 6, 7 screen width
                            dateFormatter1.setLocalizedDateFormatFromTemplate("MMMMd")
                            dateFormatter2.setLocalizedDateFormatFromTemplate("YYYYMMMMd")
                            subtitle.append(dateFormatter1.string(from: startDate) + " — " + dateFormatter2.string(from: endDate))
                        } else {
                            dateFormatter1.setLocalizedDateFormatFromTemplate("MMd")
                            dateFormatter2.setLocalizedDateFormatFromTemplate("YYMMd")
                            subtitle.append(dateFormatter1.string(from: startDate) + " — " + dateFormatter2.string(from: endDate))
                        }
                    }
                } else {
                    // Photos from different years
                    let startString: String, endString: String
                    if contentView.bounds.size.width > 414 {
                        startString = DateFormatter.localizedString(from: startDate, dateStyle: .full, timeStyle: .none)
                        endString = DateFormatter.localizedString(from: endDate, dateStyle: .full, timeStyle: .none)
                    } else {
                        startString = DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .none)
                        endString = DateFormatter.localizedString(from: endDate, dateStyle: .medium, timeStyle: .none)
                    }
                    subtitle.append(String(format: "%@ - %@", startString, endString))
                }
            } else {
                // No end date available
                let startString = DateFormatter.localizedString(from: startDate, dateStyle: .long, timeStyle: .none)
                subtitle.append(String(format: "%@", startString))
            }
        }
        subtitleLabel.font = UIFont.piwigoFontSmall()
        subtitleLabel.textColor = UIColor.piwigoColorLeftLabel()
        subtitleLabel.text = subtitle
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        subtitleLabel.text = ""
        numberLabel.text = ""
    }
}
