//
//  EditImageShiftPickerTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit
import piwigoKit

@objc protocol EditImageShiftPickerDelegate: NSObjectProtocol {
    func didSelectDate(withPicker date: Date?)
}

class EditImageShiftPickerTableViewCell: UITableViewCell
{
    weak var delegate: EditImageShiftPickerDelegate?

    private var pickerRefDate = Date()
    @IBOutlet private weak var addRemoveTimeButton: UISegmentedControl!
    @IBOutlet private weak var shiftPicker: UIPickerView!
    
    private let kPiwigoPickerNberOfYears = 200 // i.e. ±200 years in picker
    private let kPiwigoPickerMonthsPerYear = 12
    private let kPiwigoPickerDaysPerMonth = 32
    private let kPiwigoPickerHoursPerDay = 24
    private let kPiwigoPickerMinutesPerHour = 60
    private let kPiwigoPickerSecondsPerMinute = 60
    private let kPiwigoPickerNberOfLoops = 2 * 1000 // i.e. ±1000 loops of picker

    enum PickerComponents : Int {
        case year
        case sepYM
        case month
        case sepMD
        case day
        case sepDH
        case hour
        case sepHM
        case minute
        case sepMS
        case second
        case count
    }

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        shiftPicker.reloadAllComponents()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }


    // MARK: - Picker Methods
    func config(withDate date: Date?, animated: Bool)
    {
        // Store starting date (now if provided date in nil)
        if date == nil {
            pickerRefDate = Date()
        } else {
            pickerRefDate = date!
        }

        // Start with zero date interval
        shiftPicker.selectRow(0, inComponent: PickerComponents.year.rawValue, animated: false)
        shiftPicker.selectRow(kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear / 2,
                              inComponent: PickerComponents.month.rawValue, animated: false)
        shiftPicker.selectRow(kPiwigoPickerNberOfLoops * kPiwigoPickerDaysPerMonth / 2,
                              inComponent: PickerComponents.day.rawValue, animated: false)
        shiftPicker.selectRow(kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay / 2,
                              inComponent: PickerComponents.hour.rawValue, animated: false)
        shiftPicker.selectRow(kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour / 2,
                              inComponent: PickerComponents.minute.rawValue, animated: false)
        shiftPicker.selectRow(kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute / 2,
                              inComponent: PickerComponents.second.rawValue, animated: false)

        // Consider removing time
        addRemoveTimeButton.setEnabled(true, forSegmentAt: 0)
    }

    func getDateFromPicker() -> Date? {
        // Should we add or substract time?
        let operationSign = addRemoveTimeButton.selectedSegmentIndex == 0 ? -1 : 1

        // Add seconds
        let days = shiftPicker.selectedRow(inComponent: PickerComponents.day.rawValue) % kPiwigoPickerDaysPerMonth
        let hours = shiftPicker.selectedRow(inComponent: PickerComponents.hour.rawValue) % kPiwigoPickerHoursPerDay
        let minutes = shiftPicker.selectedRow(inComponent: PickerComponents.minute.rawValue) % kPiwigoPickerMinutesPerHour
        let seconds = shiftPicker.selectedRow(inComponent: PickerComponents.second.rawValue) % kPiwigoPickerSecondsPerMinute
        let daysInSeconds = pickerRefDate.addingTimeInterval(TimeInterval(operationSign * (((days * 24 + hours) * 60 + minutes) * 60 + seconds)))

        // Add months
        let gregorian = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.month = operationSign * shiftPicker.selectedRow(inComponent: PickerComponents.month.rawValue) % kPiwigoPickerMonthsPerYear
        comp.year = operationSign * shiftPicker.selectedRow(inComponent: PickerComponents.year.rawValue)
        var newDate: Date? = nil
        newDate = gregorian.date(byAdding: comp, to: daysInSeconds, wrappingComponents: false)

        return newDate
    }
    
    
    // MARK: - Button Methods
    @IBAction func changedMode(_ sender: Any)
    {
        // Change date in parent view
        if delegate?.responds(to: #selector(EditImageShiftPickerDelegate.didSelectDate(withPicker:))) ?? false {
            delegate?.didSelectDate(withPicker: getDateFromPicker())
        }
    }
}


// MARK: - UIPickerViewDataSource Methods
extension EditImageShiftPickerTableViewCell: UIPickerViewDataSource
{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return PickerComponents.count.rawValue
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var nberOfRows = 0
        switch PickerComponents(rawValue: component) {
        case .year:
            nberOfRows = kPiwigoPickerNberOfYears
        case .sepYM:
            nberOfRows = 1
        case .month:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear
        case .sepMD:
            nberOfRows = 1
        case .day:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay
        case .sepDH:
            nberOfRows = 1
        case .hour:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay
        case .sepHM:
            nberOfRows = 1
        case .minute:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour
        case .sepMS:
            nberOfRows = 1
        case .second:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute
        default:
            break
        }
        return nberOfRows
    }
}
 
// MARK: - UIPickerViewDelegate Methods
extension EditImageShiftPickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat
    {
        // Same height for all components
        return 28.0
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat
    {
        // Widths contants
        let sepDayTime: CGFloat = 10.0
        let numberWidth: CGFloat = 26.0
        let numberSepWidth: CGFloat = 8.0

        var width = 0
        switch PickerComponents(rawValue: component) {
        case .year, .month,  .day, .hour,   .minute, .second:
            width = Int(numberWidth)
        case .sepYM, .sepMD, .sepHM, .sepMS:
            width = Int(numberSepWidth)
        case .sepDH:
            width = Int(sepDayTime)
        default:
            break
        }
        return CGFloat(width)
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
                    forComponent component: Int, reusing view: UIView?) -> UIView
    {
        var label = view as? UILabel
        if label == nil {
            label = UILabel()
            label?.font = UIFont.piwigoFontNormal()
            label?.textColor = .piwigoColorLeftLabel()
        }
        switch PickerComponents(rawValue: component) {
        case .year:
            label?.text = String(format: "%ld", row)
            label?.textAlignment = .center
        case .sepYM:
            label?.text = "-"
            label?.textAlignment = .center
        case .month:
            label?.text = String(format: "%02ld", row % kPiwigoPickerMonthsPerYear)
            label?.textAlignment = .center
        case .sepMD:
            label?.text = "-"
            label?.textAlignment = .center
        case .day:
            label?.text = String(format: "%02ld", row % kPiwigoPickerDaysPerMonth)
            label?.textAlignment = .center
        case .sepDH:
            label?.text = "|"
            label?.textAlignment = .center
        case .hour:
            label?.text = String(format: "%02ld", row % kPiwigoPickerHoursPerDay)
            label?.textAlignment = .center
        case .sepHM:
            label?.text = ":"
            label?.textAlignment = .center
        case .minute:
            label?.text = String(format: "%02ld", row % kPiwigoPickerMinutesPerHour)
            label?.textAlignment = .center
        case .sepMS:
            label?.text = ":"
            label?.textAlignment = .center
        case .second:
            label?.text = String(format: "%02ld", row % kPiwigoPickerSecondsPerMinute)
            label?.textAlignment = .center
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
        case .month:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear / 2 + row % kPiwigoPickerMonthsPerYear
        case .day:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerDaysPerMonth / 2 + row % kPiwigoPickerDaysPerMonth
        case .hour:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay / 2 + row % kPiwigoPickerHoursPerDay
        case .minute:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour / 2 + row % kPiwigoPickerMinutesPerHour
        case .second:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute / 2 + row % kPiwigoPickerSecondsPerMinute
        default:
            break
        }
        pickerView.selectRow(newRow, inComponent: component, animated: false)

        // Change date in parent view
        if delegate?.responds(to: #selector(EditImageShiftPickerDelegate.didSelectDate(withPicker:))) ?? false {
            delegate?.didSelectDate(withPicker: getDateFromPicker())
        }
    }
}
