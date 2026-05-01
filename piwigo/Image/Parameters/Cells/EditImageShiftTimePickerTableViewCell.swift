//
//  EditImageShiftTimePickerTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

@objc protocol EditImageShiftTimeDelegate: NSObjectProtocol {
    func didShiftTime(withPicker date: Date)
}

class EditImageShiftTimePickerTableViewCell: UITableViewCell {
    
    weak var delegate: (any EditImageShiftTimeDelegate)?
    
    @IBOutlet private weak var shiftPicker: UIPickerView!
    
    private var is24hFormat = false
    private var pickerAmPmSymbols: [String] = []
    private let picker12Hours: Int = 12
    private let picker24Hours: Int = 24
    private let pickerMinutesPerHour: Int = 60
    private let pickerSecondsPerMinute: Int = 60
    private var pickerDateInSecs: TimeInterval = TimeInterval()
    
    // Original selection
    private var originalHour: Int = 0
    private var originalMinute: Int = 0
    private var originalSecond: Int = 0

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
        shiftPicker?.backgroundColor = PwgColor.cellBackground
        shiftPicker?.tintColor = PwgColor.leftLabel
        shiftPicker?.reloadAllComponents()
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
        originalSecond = calendar.component(.second, from: pickerDate)
        daysInSec -= TimeInterval(originalSecond)
        shiftPicker?.selectRow(originalSecond, inComponent: PickerComponents.second.rawValue, animated: animated)
        
        originalMinute = calendar.component(.minute, from: pickerDate)
        daysInSec -= TimeInterval(originalMinute * 60)
        shiftPicker?.selectRow(originalMinute, inComponent: PickerComponents.minute.rawValue, animated: animated)
        
        originalHour = calendar.component(.hour, from: pickerDate)
        daysInSec -= TimeInterval(originalHour * 3600)
        if is24hFormat {
            shiftPicker?.selectRow(originalHour, inComponent: PickerComponents.hour.rawValue, animated: animated)
        } else {
            if originalHour > 11 {
                originalHour -= 12
                shiftPicker?.selectRow(1, inComponent: PickerComponents.AMPM.rawValue, animated: animated)
            }
            shiftPicker?.selectRow(originalHour, inComponent: PickerComponents.hour.rawValue, animated: animated)
        }
        
        pickerDateInSecs = daysInSec
    }
}


// MARK: - UIPickerViewDataSource Methods
extension EditImageShiftTimePickerTableViewCell: UIPickerViewDataSource
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
extension EditImageShiftTimePickerTableViewCell: UIPickerViewDelegate
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
            return "-29".boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude),
                                     options: .usesLineFragmentOrigin,
                                     attributes: attributes, context: context).width
        case .sepHM, .sepMS:
            return ":".boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude),
                                    options: .usesLineFragmentOrigin,
                                    attributes: attributes, context: context).width
        case .AMPM:
            return pickerAmPmSymbols[0].boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                                  height: CGFloat.greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin,
                                                     attributes: attributes, context: context).width
        default:
            return 0.0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var label = view as? UILabel
        if label == nil {
            label = UILabel()
            label?.numberOfLines = 1
            if self.bounds.width > 375.0 {
                label?.font = .preferredFont(forTextStyle: .body)
            } else {
                label?.font = .preferredFont(forTextStyle: .callout)
            }
            label?.textColor = PwgColor.leftLabel
            label?.textAlignment = .center
            label?.lineBreakMode = .byTruncatingTail
        }
        switch PickerComponents(rawValue: component) {
        case .hour:
            let value = (row - originalHour) % (is24hFormat ? picker24Hours : picker12Hours)
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)) )
            label?.textAlignment = .center
        case .sepHM, .sepMS:
                label?.text = ":"
                label?.textAlignment = .center
        case .minute:
            let value = row - originalMinute
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)))
            label?.textAlignment = .center
        case .second:
            let value = row - originalSecond
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)))
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
            hours = shiftPicker.selectedRow(inComponent: PickerComponents.hour.rawValue)
        } else {
            hours = shiftPicker.selectedRow(inComponent: PickerComponents.hour.rawValue)
            hours += shiftPicker.selectedRow(inComponent: PickerComponents.AMPM.rawValue) * 12
        }
        let minutes = shiftPicker.selectedRow(inComponent: PickerComponents.minute.rawValue)
        let seconds = shiftPicker.selectedRow(inComponent: PickerComponents.second.rawValue)

        // New date with UTC time
        let newDate = dateInSeconds.addingTimeInterval(TimeInterval((hours * 60 + minutes) * 60 + seconds))

        // Update creation date
        delegate?.didShiftTime(withPicker: newDate)
    }
}
