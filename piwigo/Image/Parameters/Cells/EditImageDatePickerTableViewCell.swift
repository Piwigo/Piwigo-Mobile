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

    private var is24hFormat = false
    private var formatterShort = DateFormatter()
    private var formatterLong = DateFormatter()
    private var pickerRefDate: Date!
    private var pickerMaxNberDays = 0
    private var ampmSymbols: [String]?
    
    @IBOutlet private weak var datePicker: UIPickerView!
    @IBOutlet private weak var toolBarTop: UIToolbar!
    @IBOutlet private weak var toolBarBottom: UIToolbar!
    @IBOutlet private weak var decrementMonthButton: UIBarButtonItem!
    @IBOutlet private weak var unsetDateButton: UIBarButtonItem!
    @IBOutlet private weak var incrementMonthButton: UIBarButtonItem!
    @IBOutlet private weak var decrementYearButton: UIBarButtonItem!
    @IBOutlet private weak var todayDateButton: UIBarButtonItem!
    @IBOutlet private weak var incrementYearButton: UIBarButtonItem!

    private let pwgPickerMinDate = "1922-01-01 00:00:00"
    private let pwgPickerMaxDate = "2100-01-01 00:00:00"
    private let pwgPickerWidthLimit: CGFloat = 375 // i.e. larger than iPhones 6,7,8 screen width
    private let pwgPicker1Day: Int = 24 * 60 * 60
    private let pwgPicker12Hours: Int = 12
    private let pwgPicker24Hours: Int = 24
    private let pwgPickerMinutesPerHour: Int = 60
    private let pwgPickerSecondsPerMinute: Int = 60
    private let pwgPickerNberOfLoops: Int = 2 * 5000 // i.e. ±5000 loops of picker
    
    enum PickerComponents : Int {
        case day
        case sepDH
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

        // Buttons
        decrementMonthButton.title = NSLocalizedString("editImageDetails_dateMonthDec", comment: "-1 Month")
        unsetDateButton.title = NSLocalizedString("editImageDetails_dateUnset", comment: "Unset")
        incrementMonthButton.title = NSLocalizedString("editImageDetails_dateMonthInc", comment: "+1 Month")
        decrementYearButton.title = NSLocalizedString("editImageDetails_dateYearDec", comment: "-1 Year")
        todayDateButton.title = NSLocalizedString("editImageDetails_dateToday", comment: "Today")
        incrementYearButton.title = NSLocalizedString("editImageDetails_dateYearInc", comment: "+1 Year")

        // Date picker: determine current time format: 12 or 24h
        let formatter = DateFormatter()
        formatter.locale = NSLocale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        ampmSymbols = [formatter.amSymbol, formatter.pmSymbol]
        let amRange = (dateString as NSString).range(of: formatter.amSymbol)
        let pmRange = (dateString as NSString).range(of: formatter.pmSymbol)
        is24hFormat = amRange.location == NSNotFound && pmRange.location == NSNotFound

        // Date picker: adopt format respecting current locale
        var formatString = DateFormatter.dateFormat(
            fromTemplate: "eeedMMM",
            options: 0,
            locale: NSLocale.current)
        formatterShort.dateFormat = formatString
        formatString = DateFormatter.dateFormat(
            fromTemplate: "eeeedMMM",
            options: 0,
            locale: NSLocale.current)
        formatterLong.dateFormat = formatString

        // Define date picker limits in number of days
        formatter.dateFormat = "yyyy-MM-DD hh:mm:ss"
        pickerRefDate = formatter.date(from: pwgPickerMinDate)!
        let maxDate = formatter.date(from: pwgPickerMaxDate)!
        pickerMaxNberDays = Int(maxDate.timeIntervalSince(pickerRefDate) / Double(pwgPicker1Day))

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        datePicker.reloadAllComponents()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

    }

    // MARK: - Picker Methods
    func config(withDate date: Date?, animated: Bool)
    {
        // Adopts current date if provided date is nil
        var pickerDate = Date()
        if date != nil {
            pickerDate = date!
        }
        
        // Set colours
        datePicker.backgroundColor = .piwigoColorCellBackground()
        datePicker.tintColor = .piwigoColorLeftLabel()

        // Initialisation
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var daysInSec = pickerDate.timeIntervalSince(pickerRefDate)

        // Substract right amount of time
        let second = calendar.component(.second, from: pickerDate)
        daysInSec -= TimeInterval(second)
        datePicker.selectRow(pwgPickerNberOfLoops * pwgPickerSecondsPerMinute / 2 + second,
                             inComponent: PickerComponents.second.rawValue, animated: false)

        let minute = calendar.component(.minute, from: pickerDate)
        daysInSec -= TimeInterval(minute * 60)
        datePicker.selectRow(pwgPickerNberOfLoops * pwgPickerMinutesPerHour / 2 + minute,
                             inComponent: PickerComponents.minute.rawValue, animated: false)

        var hour = calendar.component(.hour, from: pickerDate)
        daysInSec -= TimeInterval(hour * 3600)
        if is24hFormat {
            datePicker.selectRow(pwgPickerNberOfLoops * pwgPicker24Hours / 2 + hour,
                                 inComponent: PickerComponents.hour.rawValue, animated: false)
        } else {
            if hour > 11 {
                hour -= 12
                datePicker.selectRow(1, inComponent: PickerComponents.AMPM.rawValue, animated: false)
            }
            datePicker.selectRow(pwgPickerNberOfLoops * pwgPicker12Hours / 2 + hour,
                                 inComponent: PickerComponents.hour.rawValue, animated: false)
        }

        daysInSec /= Double(pwgPicker1Day)
        datePicker.selectRow(lround(daysInSec), inComponent: PickerComponents.day.rawValue, animated: animated)
    }

    private func getDateFromPicker() -> Date {
        // Date from first component
        let dateInSeconds = Date(timeInterval: TimeInterval(datePicker.selectedRow(inComponent: PickerComponents.day.rawValue)) * Double(pwgPicker1Day), since: pickerRefDate)

        // Add seconds to reach time
        var hours: Int
        if is24hFormat {
            hours = datePicker.selectedRow(inComponent: PickerComponents.hour.rawValue) % pwgPicker24Hours
        } else {
            hours = datePicker.selectedRow(inComponent: PickerComponents.hour.rawValue) % pwgPicker12Hours
            hours += datePicker.selectedRow(inComponent: PickerComponents.AMPM.rawValue) * 12
        }
        let minutes = datePicker.selectedRow(inComponent: PickerComponents.minute.rawValue) % pwgPickerMinutesPerHour
        let seconds = datePicker.selectedRow(inComponent: PickerComponents.second.rawValue) % pwgPickerSecondsPerMinute

        // Return date with UTC time
        return dateInSeconds.addingTimeInterval(TimeInterval((hours * 60 + minutes) * 60 + seconds))
    }


    // MARK: - Buttons Methods
    func setDatePickerButtons()
    {
        toolBarTop.barTintColor = .piwigoColorCellBackground()
        unsetDateButton.tintColor = .red
        incrementMonthButton.tintColor = .piwigoColorRightLabel()
        decrementMonthButton.tintColor = .piwigoColorRightLabel()

        toolBarBottom.barTintColor = .piwigoColorCellBackground()
        todayDateButton.tintColor = .piwigoColorRightLabel()
        incrementYearButton.tintColor = .piwigoColorRightLabel()
        decrementYearButton.tintColor = .piwigoColorRightLabel()
    }

    @IBAction func unsetDate(_ sender: Any) {
        // Close date picker
        delegate?.didUnsetImageCreationDate()
    }

    @IBAction func setDateAsToday(_ sender: Any) {
        // Select today
        let newDate = Date()

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
        return PickerComponents.count.rawValue - (is24hFormat ? 1 : 0)
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var nberOfRows = 0
        switch PickerComponents(rawValue: component) {
            case .day:
                nberOfRows = pickerMaxNberDays
            case .sepDH:
                nberOfRows = 1
            case .hour:
                nberOfRows = pwgPickerNberOfLoops * (is24hFormat ? pwgPicker24Hours : pwgPicker12Hours)
            case .sepHM:
                nberOfRows = 1
            case .minute:
                nberOfRows = pwgPickerNberOfLoops * pwgPickerMinutesPerHour
            case .sepMS:
                nberOfRows = 1
            case .second:
                nberOfRows = pwgPickerNberOfLoops * pwgPickerSecondsPerMinute
            case .AMPM:
                nberOfRows = 2
            default:
                break
        }
        return nberOfRows
    }
}


// MARK: - UIPickerViewDelegate Methods
extension EditImageDatePickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        // Same height for all components
        return 28.0
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        // Widths contants
        var dayWidth: CGFloat = 106.0
        dayWidth += datePicker.bounds.size.width > pwgPickerWidthLimit ? 60.0 : 0.0
        let sepDay: CGFloat = 10.0
        let time: CGFloat = 26.0
        let sepTime: CGFloat = 8.0
        let ampm: CGFloat = 30.0
        let separatorWidth: CGFloat = 5.0

        // Calculate left and right pane widths (for debugging)
//        let leftMargin = pickerView.superview?.layoutMargins.left ?? 0.0
//        let rightMargin = pickerView.superview?.layoutMargins.right ?? 0.0
//        let leftPaneWidth = leftMargin + separatorWidth + dayWidth + separatorWidth + sepDay / 2
//        var rightPaneWidth = sepDay / 2 + 5 * separatorWidth + 3 * time + 2 * sepTime
//        rightPaneWidth += is24hFormat ? 0.0 : separatorWidth + ampm + separatorWidth + rightMargin
//        let remainingSpace = pickerView.bounds.size.width - leftPaneWidth - rightPaneWidth
//        debugPrint("=> left:\(leftPaneWidth), right:\(rightPaneWidth), width:\(pickerView.bounds.size.width) (remaining:\(remainingSpace))")
        // iPhone SE, iOS 11 => left:136, right:179, width:318 (remaining:3)
        // iPhone Xs, iOS 12 => left:131, right:174, width:373 (remaining:68)

        var width:CGFloat = 0
        switch PickerComponents(rawValue: component) {
            case .day:
                width = dayWidth
            case .sepDH:
                width = sepDay + (is24hFormat ? separatorWidth : 0.0)
            case .hour, .minute, .second:
                width = time
            case .sepHM, .sepMS:
                width = sepTime
            case .AMPM:
                width = ampm
            default:
                break
        }
        return width
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var label = view as? UILabel
        if label == nil {
            label = UILabel()
            label?.font = .systemFont(ofSize: 17)
            label?.textColor = .piwigoColorLeftLabel()
        }
        switch PickerComponents(rawValue: component) {
            case .day:
                var dateOfDay: Date? = nil
                if let pickerRefDate = pickerRefDate {
                    dateOfDay = Date(timeInterval: TimeInterval(row * pwgPicker1Day), since: pickerRefDate)
                }
                if datePicker.bounds.size.width > pwgPickerWidthLimit {
                    if let dateOfDay = dateOfDay {
                        label?.text = formatterLong.string(from: dateOfDay)
                    }
                } else {
                    if let dateOfDay = dateOfDay {
                        label?.text = formatterShort.string(from: dateOfDay)
                    }
                }
                label?.textAlignment = .right
            case .sepDH:
                label?.text = "-"
                label?.textAlignment = .center
            case .hour:
                label?.text = String(format: "%02ld", row % (is24hFormat ? pwgPicker24Hours : pwgPicker12Hours))
                label?.textAlignment = .center
            case .sepHM:
                label?.text = ":"
                label?.textAlignment = .center
            case .minute:
                label?.text = String(format: "%02ld", row % pwgPickerMinutesPerHour)
                label?.textAlignment = .center
            case .sepMS:
                label?.text = ":"
                label?.textAlignment = .center
            case .second:
                label?.text = String(format: "%02ld", row % pwgPickerSecondsPerMinute)
                label?.textAlignment = .center
            case .AMPM:
                label?.text = ampmSymbols?[row]
                label?.textAlignment = .left
            default:
                break
        }
        return label!
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        // Jump back to the row with the current value that is closest to the middle
        var newRow = row
        switch PickerComponents(rawValue: component) {
            case .hour:
                let hoursPerDay = is24hFormat ? pwgPicker24Hours : pwgPicker12Hours
                newRow = pwgPickerNberOfLoops * hoursPerDay / 2 + row % hoursPerDay
            case .minute:
                newRow = pwgPickerNberOfLoops * pwgPickerMinutesPerHour / 2 + row % pwgPickerMinutesPerHour
            case .second:
                newRow = pwgPickerNberOfLoops * pwgPickerSecondsPerMinute / 2 + row % pwgPickerSecondsPerMinute
            default:
                break
        }
        pickerView.selectRow(newRow, inComponent: component, animated: false)

        // Change date in parent view
        delegate?.didSelectDate(withPicker: getDateFromPicker())
    }
}
