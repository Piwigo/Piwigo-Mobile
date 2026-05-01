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
    weak var delegate: (any EditImageDatePickerDelegate)?
    
    @IBOutlet private weak var datePicker: UIPickerView!
    @IBOutlet private weak var unsetDateButton: UIButton!
    @IBOutlet private weak var todayDateButton: UIButton!
    
    // Locale and calendar
    private let locale = Locale.current
    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        return calendar
    }()
    
    // Date components
    private lazy var days: [Int] = []
    private lazy var months: [String] = []
    private lazy var years: [String] = []
    private lazy var yearNumbers: [Int] = []
    private lazy var contentSizeCategory: UIContentSizeCategory = traitCollection.preferredContentSizeCategory
    
    // Current selection
    private lazy var selectedDay: Int = 1
    private lazy var selectedMonth: Int = 1
    private lazy var selectedYear: Int = 2025
    
    // Component order based on locale
    private enum DateComponent: Int {
        case day = 0
        case month = 1
        case year = 2
    }
    private lazy var componentOrder: [DateComponent] = []
    private lazy var pickerTimeInSecs: TimeInterval = 0
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Configure date components
        /// Setup days using a safe maximum (30 works for most calendars)
        days = Array(1...30)
        
        /// Setup years (range from 1900 to today's year)
        let firstYear = calendar.component(.year, from: DateUtilities.unknownDate)
        let lastYear = calendar.component(.year, from: Date())
        yearNumbers = Array(firstYear...lastYear)
        
        /// Setup months using locale-specific names
        setMonthsYearsAccordingToSize()
        
        // Determine component order
        /// Get date format for locale to determine component order
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .short
        let dateFormat = formatter.dateFormat ?? "MM/dd/yyyy"
        
        /// Parse format to determine order
        let dayIndicators = ["d", "D"]
        let monthIndicators = ["M", "L"]
        let yearIndicators = ["y", "Y"]
        
        var dayIndex = Int.max
        var monthIndex = Int.max
        var yearIndex = Int.max
        
        for (index, char) in dateFormat.enumerated() {
            let charStr = String(char)
            if dayIndicators.contains(charStr) && dayIndex == Int.max {
                dayIndex = index
            } else if monthIndicators.contains(charStr) && monthIndex == Int.max {
                monthIndex = index
            } else if yearIndicators.contains(charStr) && yearIndex == Int.max {
                yearIndex = index
            }
        }
        
        /// Sort components by their position in the format string
        var components: [(DateComponent, Int)] = [
            (.day, dayIndex),
            (.month, monthIndex),
            (.year, yearIndex)
        ]
        
        components.sort { $0.1 < $1.1 }
        componentOrder = components.map { $0.0 }

        // Configure buttons
        setConfigOfButton(unsetDateButton, ofStyle: .tinted(),
                          withTitle: String(localized: "editImageDetails_dateUnset", comment: "Unset"))
        setConfigOfButton(todayDateButton, ofStyle: .filled(),
                          withTitle: String(localized: "editImageDetails_dateToday", comment: "Today"))
        
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
        var config = todayDateButton.configuration ?? .filled()
        config.baseBackgroundColor = PwgColor.background
        config.baseForegroundColor = PwgColor.rightLabel
        todayDateButton.configuration = config

        unsetDateButton.tintColor = .red
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    
    // MARK: - Picker Methods
    func config(withDate date: Date?, animated: Bool) {
        // Adopts current date if provided date is nil
        let pickerDate = date ?? Date()
        
        // Extract time in seconds
        let second = calendar.component(.second, from: pickerDate)
        pickerTimeInSecs = TimeInterval(second)
        let minute = calendar.component(.minute, from: pickerDate)
        pickerTimeInSecs += TimeInterval(minute * 60)
        let hour = calendar.component(.hour, from: pickerDate)
        pickerTimeInSecs += TimeInterval(hour * 3600)
        
        // Set picker components
        let components = calendar.dateComponents([.day, .month, .year], from: pickerDate)
        selectedDay = components.day ?? 1
        selectedMonth = components.month ?? 1
        selectedYear = components.year ?? 2025
        updateDaysForCurrentMonth()
        for (index, component) in componentOrder.enumerated() {
            switch component {
            case .day:
                if let dayIndex = days.firstIndex(of: selectedDay) {
                    datePicker.selectRow(dayIndex, inComponent: index, animated: animated)
                }
            case .month:
                datePicker.selectRow(selectedMonth - 1, inComponent: index, animated: animated)
            case .year:
                if let yearIndex = yearNumbers.firstIndex(of: selectedYear) {
                    datePicker.selectRow(yearIndex, inComponent: index, animated: animated)
                }
            }
        }
        
        // Replace date with weekday in parent cell
        delegate?.didSelectDate(withPicker: getDateFromPicker())
    }
    
    private func getDateFromPicker() -> Date {
        // Get date components
        var components = DateComponents()
        components.day = selectedDay
        components.month = selectedMonth
        components.year = selectedYear
        let selectedDate = calendar.date(from: components) ?? Date()
        
        // Return date with unchanged time
        var dateInSeconds: TimeInterval = selectedDate.timeIntervalSince(DateUtilities.unknownDate)
        dateInSeconds += pickerTimeInSecs
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
        return 3    // i.e. day, month, year
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        guard component < componentOrder.count else { return 0 }
        switch componentOrder[component] {
        case .day:
            return days.count
        case .month:
            return months.count
        case .year:
            return years.count
        }
   }
}


// MARK: - UIPickerViewDelegate Methods
extension EditImageDatePickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        // Same height for all components
        return UIFont.preferredFont(forTextStyle: .body).lineHeight + 4.0
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        // Create or retrieve the label
        var label = view as? UILabel
        if label == nil {
            label = UILabel()
            label?.numberOfLines = 1
            label?.font = .preferredFont(forTextStyle: .body)
            label?.textColor = PwgColor.leftLabel
            label?.textAlignment = .center
            label?.lineBreakMode = .byTruncatingTail
        }
        
        // Change month name?
        if contentSizeCategory != traitCollection.preferredContentSizeCategory {
            contentSizeCategory = traitCollection.preferredContentSizeCategory
            setMonthsYearsAccordingToSize()
        }
        
        // Set label content
        guard component < componentOrder.count else { return label! }
        switch componentOrder[component] {
        case .day:
            label?.text = "\(days[row])"
        case .month:
            label?.text = months[row]
        case .year:
            label?.text = "\(years[row])"
        }
        return label!
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Update selection and day range
        guard component < componentOrder.count else { return }
        switch componentOrder[component] {
        case .day:
            selectedDay = days[row]
        case .month:
            selectedMonth = row + 1
            adjustDayForSelectedMonth()
        case .year:
            selectedYear = yearNumbers[row]
            adjustDayForSelectedMonth()
        }
        
        // Change date in parent cell
        delegate?.didSelectDate(withPicker: getDateFromPicker())
    }
    
    private func setMonthsYearsAccordingToSize() {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        
        switch contentSizeCategory {
        case .extraSmall, .small, .medium, .large:
            months = formatter.monthSymbols
            years = yearNumbers.map { "\($0)" }
        case .extraLarge, .extraExtraLarge, .extraExtraExtraLarge, .accessibilityMedium:
            months = formatter.shortMonthSymbols
            years = yearNumbers.map { "\($0)" }
        default:
            // Setup month numbers as two-digit strings based on calendar
            let monthCount = calendar.monthSymbols.count
            let monthTwoDigits = (1...monthCount).map { String(format: "%02d", $0) }
            months = monthTwoDigits
            years = yearNumbers.map { $0 % 100 }.map { String(format: "%02d", $0) }
        }
    }
    
    private func updateDaysForCurrentMonth() {
        var components = DateComponents()
        components.month = selectedMonth
        components.year = selectedYear
        
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date)
        else {
            // Fallback: use a safe maximum (30 works for most calendars)
            days = Array(1...30)
            return
        }
        
        days = Array(1...range.count)
        
        // Adjust selected day if it's now out of range
        if selectedDay > days.count {
            selectedDay = days.count
        }
    }

    private func adjustDayForSelectedMonth() {
        // Adjust number of days if needed
        updateDaysForCurrentMonth()
        
        // Find which component is the day component and reload it
        if let dayComponentIndex = componentOrder.firstIndex(of: .day) {
            datePicker.reloadComponent(dayComponentIndex)
            
            // Re-select the (possibly adjusted) day
            if let dayIndex = days.firstIndex(of: selectedDay) {
                datePicker.selectRow(dayIndex, inComponent: dayComponentIndex, animated: true)
            }
        }
    }
}
