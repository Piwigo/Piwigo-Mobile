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
    
    func configure(with title: String, nberPhotos: Int, nberVideos: Int, startDate: Date?, endDate: Date?) -> Void {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()

        // Title
        titleLabel.font = UIFont.piwigoFontNormal()
        titleLabel.textColor = UIColor.piwigoColorLeftLabel()
        titleLabel.text = title
        
        // Subtitle
        var subtitle: String
        if nberPhotos > 0 && nberVideos > 0 {
            subtitle = String(format: "%ld %@ • %ld %@", nberPhotos,
                              nberPhotos > 1 ? NSLocalizedString("severalImages", comment: "Photos") : NSLocalizedString("singleImage", comment: "Photo"),
                              nberVideos,
                              nberVideos > 1 ? NSLocalizedString("severalVideos", comment: "Videos") : NSLocalizedString("singleVideo", comment: "Video"))

        } else if nberPhotos > 0 && nberVideos == 0 {
            subtitle = String(format: "%ld %@", nberPhotos,
                              nberPhotos > 1 ? NSLocalizedString("severalImages", comment: "Photos") : NSLocalizedString("singleImage", comment: "Photo"))
        } else {
            subtitle = String(format: "%ld %@", nberVideos,
                              nberVideos > 1 ? NSLocalizedString("severalVideos", comment: "Videos") : NSLocalizedString("singleVideo", comment: "Video"))
        }
        
        // Append date interval in landscape mode or on iPad
        if contentView.bounds.size.width > 414 {
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
                                let startString = DateFormatter.localizedString(from: startDate, dateStyle: .long, timeStyle: .none)
                                subtitle.append(String(format: " • %@", startString))
                            } else {
                                // Photos from different days in the same month
                                let dateFormatter = DateFormatter.init()
                                dateFormatter.locale = .current
                                dateFormatter.setLocalizedDateFormatFromTemplate("YYYYMMMM")
                                let startString = dateFormatter.string(from: startDate)
                                subtitle.append(String(format: " • %@", startString))
                            }
                        } else {
                            // Photos from different months in the same year
                            let dateFormatter = DateFormatter.init()
                            dateFormatter.locale = .current
                            dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
                            let startString = dateFormatter.string(from: startDate)
                            let endString = dateFormatter.string(from: endDate)
                            subtitle.append(String(format: " • %@ - %@ (%ld)", startString, endString, startDateComponents.year!))
                        }
                    } else {
                        // Photos from different years
                        let startString = DateFormatter.localizedString(from: startDate, dateStyle: .long, timeStyle: .none)
                        let endString = DateFormatter.localizedString(from: endDate, dateStyle: .long, timeStyle: .none)
                        subtitle.append(String(format: " • %@ - %@", startString, endString))
                    }
                } else {
                    // No end date available
                    let startString = DateFormatter.localizedString(from: startDate, dateStyle: .long, timeStyle: .none)
                    subtitle.append(String(format: " • %@", startString))
                }
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
    }
}
