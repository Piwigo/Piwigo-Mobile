//
//  EditImageShiftDatePickerTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

@objc protocol EditImageShiftDateDelegate: NSObjectProtocol {
    func didShiftDate(withPicker date: Date)
}

class EditImageShiftDatePickerTableViewCell: UITableViewCell {
    
    weak var delegate: EditImageShiftDateDelegate?
    
    @IBOutlet private weak var shiftPicker: UIPickerView!
    
    // Locale and calendar
    private let locale = Locale.current
    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        return calendar
    }()
    
    // Date components
    private lazy var days: [Int] = []
    private lazy var months: [Int] = []
    private lazy var years: [Int] = []
    private lazy var contentSizeCategory: UIContentSizeCategory = traitCollection.preferredContentSizeCategory
    
    // Original selection
    private lazy var originalDay: Int = 1
    private lazy var originalMonth: Int = 1
    private lazy var originalYear: Int = 2025
    
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
    private lazy var pickerRefDate: Date = Date()
    private lazy var pickerTimeInSecs: TimeInterval = 0

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Configure date components
        /// Setup days using a safe maximum (30 works for most calendars)
        days = Array(1...30)
        
        /// Setup months using a safe maximum (12 works for most calendars)
        months = Array(1...12)
        
        /// Setup years (range from 1900 to today's year)
        let firstYear = calendar.component(.year, from: DateUtilities.unknownDate)
        let lastYear = calendar.component(.year, from: Date())
        years = Array(firstYear...lastYear)
        
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

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Set colors
        applyColorPalette()
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
    func config(withDate date: Date?, animated: Bool)
    {
        // Adopts current date if provided date is nil (should never happen)
        pickerRefDate = date ?? Date()
                
        // Extract time in seconds
        let second = calendar.component(.second, from: pickerRefDate)
        pickerTimeInSecs = TimeInterval(second)
        let minute = calendar.component(.minute, from: pickerRefDate)
        pickerTimeInSecs += TimeInterval(minute * 60)
        let hour = calendar.component(.hour, from: pickerRefDate)
        pickerTimeInSecs += TimeInterval(hour * 3600)
        
        // Set picker components
        let components = calendar.dateComponents([.day, .month, .year], from: pickerRefDate)
        selectedDay = components.day ?? 1
        originalDay = selectedDay
        selectedMonth = components.month ?? 1
        originalMonth = selectedMonth
        selectedYear = components.year ?? 2025
        originalYear = selectedYear
        updateDaysForCurrentMonth()
        updateMonthsForCurrentYear()
        for (index, component) in componentOrder.enumerated() {
            switch component {
            case .day:
                if let dayIndex = days.firstIndex(of: selectedDay) {
                    shiftPicker.selectRow(dayIndex, inComponent: index, animated: animated)
                }
            case .month:
                if let monthIndex = months.firstIndex(of: selectedMonth) {
                    shiftPicker.selectRow(monthIndex, inComponent: index, animated: animated)
                }
            case .year:
                if let yearIndex = years.firstIndex(of: selectedYear) {
                    shiftPicker.selectRow(yearIndex, inComponent: index, animated: animated)
                }
            }
        }
        
        // Replace date with weekday in parent cell
        delegate?.didShiftDate(withPicker: getDateFromPicker())
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
}


// MARK: - UIPickerViewDataSource Methods
extension EditImageShiftDatePickerTableViewCell: UIPickerViewDataSource
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
extension EditImageShiftDatePickerTableViewCell: UIPickerViewDelegate
{
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        // Same height for all components
        return UIFont.preferredFont(forTextStyle: .body).lineHeight + 4.0
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
                    forComponent component: Int, reusing view: UIView?) -> UIView {
        // Create or retrieve the label
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
        
        // Set label content
        guard component < componentOrder.count else { return label! }
        switch componentOrder[component] {
        case .day:
            let value = days[row] - originalDay
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)))
        case .month:
            let value = months[row] - originalMonth
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)))
        case .year:
            let value = years[row] - originalYear
            label?.text = value.formatted(.number .sign(strategy: .always(includingZero: false)))
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
            selectedMonth = months[row]
            adjustDayForSelectedMonth()
        case .year:
            selectedYear = years[row]
            adjustDayForSelectedMonth()
        }
        
        // Change date in parent view
        delegate?.didShiftDate(withPicker: getDateFromPicker())
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
    
    private func updateMonthsForCurrentYear() {
        var components = DateComponents()
        components.year = selectedYear
        
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .month, in: .year, for: date)
        else {
            // Fallback: use a safe maximum (12 works for most calendars)
            months = Array(1...12)
            return
        }
        
        months = Array(1...range.count)
        
        // Adjust selected month if it's now out of range
        if selectedMonth > months.count {
            selectedMonth = months.count
        }
    }
    
    private func adjustDayForSelectedMonth() {
        // Adjust number of days if needed
        updateDaysForCurrentMonth()
        
        // Find which component is the day component and reload it
        if let dayComponentIndex = componentOrder.firstIndex(of: .day) {
            shiftPicker.reloadComponent(dayComponentIndex)
            
            // Re-select the (possibly adjusted) day
            if let dayIndex = days.firstIndex(of: selectedDay) {
                shiftPicker.selectRow(dayIndex, inComponent: dayComponentIndex, animated: true)
            }
        }
    }
}
