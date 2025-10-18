//
//  EditImageTimePickerTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 11/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

@objc protocol EditImageTimePickerDelegate: NSObjectProtocol {
    func didSelectTime(withPicker date: Date)
}

class EditImageTimePickerTableViewCell: UITableViewCell {
    
    weak var delegate: EditImageTimePickerDelegate?
    
    @IBOutlet var timePicker: UIPickerView!
    
    private var is24hFormat = false
    private var pickerAmPmSymbols: [String] = []
    private let picker12Hours: Int = 12
    private let picker24Hours: Int = 24
    private let pickerMinutesPerHour: Int = 60
    private let pickerSecondsPerMinute: Int = 60
    private var pickerDateInSecs: TimeInterval = TimeInterval()
    
    enum PickerComponents : Int {
        case hour
        case sepHM
        case minute
        case sepMS
        case second
        case AMPM
        case count
    }
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Date picker: determine current time format: 12 or 24h
        let formatter = DateFormatter()
        formatter.locale = NSLocale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        pickerAmPmSymbols = [formatter.amSymbol, formatter.pmSymbol]
        let amRange = (dateString as NSString).range(of: formatter.amSymbol)
        let pmRange = (dateString as NSString).range(of: formatter.pmSymbol)
        is24hFormat = amRange.location == NSNotFound && pmRange.location == NSNotFound
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        timePicker?.backgroundColor = PwgColor.cellBackground
        timePicker?.tintColor = PwgColor.leftLabel
        timePicker?.reloadAllComponents()
    }
        
    override func prepareForReuse() {
        super.prepareForReuse()
    }

    // MARK: - Picker Methods
    func config(withDate date: Date?, animated: Bool) {
        // Adopts current date if provided date is nil
        let pickerDate = date ?? Date()

        // Initialisation
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        var daysInSec = pickerDate.timeIntervalSince(DateUtilities.unknownDate)
        
        // Substract right amount of time
        let second = calendar.component(.second, from: pickerDate)
        daysInSec -= TimeInterval(second)
        timePicker?.selectRow(second, inComponent: PickerComponents.second.rawValue, animated: animated)
        
        let minute = calendar.component(.minute, from: pickerDate)
        daysInSec -= TimeInterval(minute * 60)
        timePicker?.selectRow(minute, inComponent: PickerComponents.minute.rawValue, animated: animated)
        
        var hour = calendar.component(.hour, from: pickerDate)
        daysInSec -= TimeInterval(hour * 3600)
        if is24hFormat {
            timePicker?.selectRow(hour, inComponent: PickerComponents.hour.rawValue, animated: animated)
        } else {
            if hour > 11 {
                hour -= 12
                timePicker?.selectRow(1, inComponent: PickerComponents.AMPM.rawValue, animated: animated)
            }
            timePicker?.selectRow(hour, inComponent: PickerComponents.hour.rawValue, animated: animated)
        }
        
        pickerDateInSecs = daysInSec
    }
}


// MARK: - UIPickerViewDataSource Methods
extension EditImageTimePickerTableViewCell: UIPickerViewDataSource
{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return PickerComponents.count.rawValue - (is24hFormat ? 1 : 0)
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var nberOfRows = 0
        switch PickerComponents(rawValue: component) {
            case .hour:
                nberOfRows = is24hFormat ? picker24Hours : picker12Hours
            case .sepHM:
                nberOfRows = 1
            case .minute:
                nberOfRows = pickerMinutesPerHour
            case .sepMS:
                nberOfRows = 1
            case .second:
                nberOfRows = pickerSecondsPerMinute
            case .AMPM:
                nberOfRows = 2
            default:
                preconditionFailure("Unknown picker component")
        }
        return nberOfRows
    }
}


// MARK: - UIPickerViewDelegate Methods
extension EditImageTimePickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        // Same height for all components
        return UIFont.preferredFont(forTextStyle: .body).lineHeight + 4.0
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        // Initialisation
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]

        switch PickerComponents(rawValue: component) {
        case .hour, .minute, .second:
            return "99".boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude),
                                     options: .usesLineFragmentOrigin,
                                     attributes: attributes, context: context).width + 4.0
        case .sepHM, .sepMS:
            return ":".boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude),
                                    options: .usesLineFragmentOrigin,
                                    attributes: attributes, context: context).width + 4.0
        case .AMPM:
            return pickerAmPmSymbols[0].boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                                  height: CGFloat.greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin,
                                                     attributes: attributes, context: context).width + 4.0
        default:
            return 0.0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var label = view as? UILabel
        if label == nil {
            label = UILabel()
            label?.numberOfLines = 1
            label?.font = .preferredFont(forTextStyle: .body)
            label?.textColor = PwgColor.leftLabel
            label?.textAlignment = .center
            label?.lineBreakMode = .byTruncatingTail
        }
        switch PickerComponents(rawValue: component) {
        case .hour:
            label?.text = String(format: "%02ld", row % (is24hFormat ? picker24Hours : picker12Hours))
            label?.textAlignment = .center
        case .sepHM, .sepMS:
                label?.text = ":"
                label?.textAlignment = .center
        case .minute, .second:
            label?.text = String(format: "%02ld", row)
            label?.textAlignment = .center
        case .AMPM:
            label?.text = pickerAmPmSymbols[row]
            label?.textAlignment = .left
        default:
            break
        }
        return label!
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Current date in seconds
        let dateInSeconds = Date(timeInterval: pickerDateInSecs, since: DateUtilities.unknownDate)

        // Add seconds to reach time
        var hours: Int
        if is24hFormat {
            hours = timePicker.selectedRow(inComponent: PickerComponents.hour.rawValue)
        } else {
            hours = timePicker.selectedRow(inComponent: PickerComponents.hour.rawValue)
            hours += timePicker.selectedRow(inComponent: PickerComponents.AMPM.rawValue) * 12
        }
        let minutes = timePicker.selectedRow(inComponent: PickerComponents.minute.rawValue)
        let seconds = timePicker.selectedRow(inComponent: PickerComponents.second.rawValue)

        // New date with UTC time
        let newDate = dateInSeconds.addingTimeInterval(TimeInterval((hours * 60 + minutes) * 60 + seconds))

        // Update creation date
        delegate?.didSelectTime(withPicker: newDate)
    }
}
