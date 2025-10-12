//
//  EditImageDatePickerTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit
import piwigoKit

@objc protocol EditImageDatePickerDelegate: NSObjectProtocol {
    func didSelectDate(withPicker date: Date)
    func didUnsetImageCreationDate()
}

class EditImageDatePickerTableViewCell: UITableViewCell
{
    weak var delegate: EditImageDatePickerDelegate?
    
    @IBOutlet private weak var datePicker: UIPickerView!
    @IBOutlet private weak var decrementMonthButton: UIButton!
    @IBOutlet private weak var unsetDateButton: UIButton!
    @IBOutlet private weak var incrementMonthButton: UIButton!
    @IBOutlet private weak var decrementYearButton: UIButton!
    @IBOutlet private weak var todayDateButton: UIButton!
    @IBOutlet private weak var incrementYearButton: UIButton!
    
    private let picker1Day: TimeInterval = 24 * 60 * 60
    private lazy var pickerDays: Int = {
        let range: TimeInterval = Date.distantFuture.timeIntervalSince(DateUtilities.unknownDate)
        return Int((range / picker1Day).rounded())
    }()
    private let pickerStyle = Date.FormatStyle(timeZone: TimeZone(abbreviation: "UTC")!)
    private var pickerTimeInSecs: TimeInterval = 0
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Buttons
        setConfigOfButton(decrementMonthButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateMonthDec", comment: "-1 Month"))
        setConfigOfButton(decrementYearButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateYearDec", comment: "-1 Year"))
        setConfigOfButton(unsetDateButton, ofStyle: .tinted(),
                          withTitle: String(localized: "editImageDetails_dateUnset", comment: "Unset"))
        setConfigOfButton(todayDateButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateToday", comment: "Today"))
        setConfigOfButton(incrementMonthButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateMonthInc", comment: "+1 Month"))
        setConfigOfButton(incrementYearButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateYearInc", comment: "+1 Year"))
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Set colors
        applyColorPalette()
    }
    
    @MainActor
    private func setConfigOfButton(_ button: UIButton, ofStyle style: UIButton.Configuration, withTitle title: String) {
        var config = button.configuration ?? .filled()
        if #available(iOS 26.0, *) {
            config.cornerStyle = .capsule
        } else {
            config.cornerStyle = .large
        }
        config.title = title
        button.configuration = config
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Date picker
        datePicker?.backgroundColor = PwgColor.cellBackground
        datePicker?.tintColor = PwgColor.leftLabel
        datePicker?.reloadAllComponents()
        
        // Buttons
        applyColorPaletteToButton(decrementMonthButton)
        applyColorPaletteToButton(decrementYearButton)
        applyColorPaletteToButton(todayDateButton)
        applyColorPaletteToButton(incrementMonthButton)
        applyColorPaletteToButton(incrementYearButton)
    }
    
    @MainActor
    private func applyColorPaletteToButton(_ button: UIButton) {
        var config = button.configuration ?? .filled()
        config.baseBackgroundColor = PwgColor.background
        config.baseForegroundColor = PwgColor.leftLabel
        button.configuration = config
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    
    // MARK: - Picker Methods
    func config(withDate date: Date?, animated: Bool)
    {
        // Adopts current date if provided date is nil
        let pickerDate = date ?? Date()
        
        // Initialisation
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Substract seconds in last day
        let second = calendar.component(.second, from: pickerDate)
        pickerTimeInSecs = TimeInterval(second)
        let minute = calendar.component(.minute, from: pickerDate)
        pickerTimeInSecs += TimeInterval(minute * 60)
        let hour = calendar.component(.hour, from: pickerDate)
        pickerTimeInSecs += TimeInterval(hour * 3600)
        
        var daysInSec = pickerDate.timeIntervalSince(DateUtilities.unknownDate)
        daysInSec -= pickerTimeInSecs
        daysInSec /= Double(picker1Day)
        datePicker.selectRow(lround(daysInSec), inComponent: 0, animated: animated)
    }
    
    private func getDateFromPicker() -> Date {
        // Date from first component
        var dateInSeconds: TimeInterval = TimeInterval(datePicker.selectedRow(inComponent: 0)) * picker1Day
        dateInSeconds += pickerTimeInSecs
        
        // Return date with UTC time
        return Date(timeInterval: dateInSeconds, since: DateUtilities.unknownDate)
    }
    
    
    // MARK: - Buttons Methods
    @IBAction func unsetDate(_ sender: Any) {
        // Close date picker
        delegate?.didUnsetImageCreationDate()
    }
    
    @IBAction func setDateAsToday(_ sender: Any) {
        // Select today
        let offsetInSecs = TimeInterval(TimeZone.current.secondsFromGMT())
        let newDate = Date().addingTimeInterval(offsetInSecs)
        
        // Update picker with new date
        updatePicker(with: newDate)
    }
    
    @IBAction func incrementMonth(_ sender: Any) {
        // Increment month
        let gregorian = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.month = 1
        if let newDate = gregorian.date(byAdding: comp, to: getDateFromPicker(),
                                        wrappingComponents: false) {
            // Update picker with new date
            updatePicker(with: newDate)
        }
    }
    
    @IBAction func decrementMonth(_ sender: Any) {
        // Decrement month
        let gregorian = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.month = -1
        if let newDate = gregorian.date(byAdding: comp, to: getDateFromPicker(),
                                        wrappingComponents: false) {
            // Update picker with new date
            updatePicker(with: newDate)
        }
    }
    
    @IBAction func incrementYear(_ sender: Any) {
        // Increment month
        let gregorian = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.year = 1
        if let newDate = gregorian.date(byAdding: comp, to: getDateFromPicker(),
                                        wrappingComponents: false) {
            // Update picker with new date
            updatePicker(with: newDate)
        }
    }
    
    @IBAction func decrementYear(_ sender: Any) {
        // Decrement month
        let gregorian = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.year = -1
        if let newDate = gregorian.date(byAdding: comp, to: getDateFromPicker(),
                                        wrappingComponents: false) {
            // Update picker with new date
            updatePicker(with: newDate)
        }
    }
    
    private func updatePicker(with newDate: Date) {
        // Update picker with new date
        config(withDate: newDate, animated: true)
        
        // Change date in parent view
        delegate?.didSelectDate(withPicker: newDate)
    }
}


// MARK: - UIPickerViewDataSource Methods
extension EditImageDatePickerTableViewCell: UIPickerViewDataSource
{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerDays
    }
}


// MARK: - UIPickerViewDelegate Methods
extension EditImageDatePickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        // Same height for all components
        return UIFont.preferredFont(forTextStyle: .body).lineHeight
    }
    
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return datePicker?.bounds.width ?? UIScreen.main.bounds.width
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

        let dateOfDay = Date(timeInterval: TimeInterval(row) * picker1Day, since: DateUtilities.unknownDate)
        switch traitCollection.preferredContentSizeCategory {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            label?.text = dateOfDay.formatted(pickerStyle
                .weekday(.wide) .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
        case .extraExtraLarge, .extraExtraExtraLarge:
            label?.text = dateOfDay.formatted(pickerStyle
                .weekday(.abbreviated) .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
        default:
            label?.text = dateOfDay.formatted(pickerStyle
                .day(.defaultDigits) .month(.twoDigits) .year(.defaultDigits))
        }
        return label!
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        // Change date in parent view
        delegate?.didSelectDate(withPicker: getDateFromPicker())
    }
}
