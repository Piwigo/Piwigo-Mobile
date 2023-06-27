//
//  SliderTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import UIKit

typealias CellSliderBlock = (Float) -> Void

class SliderTableViewCell: UITableViewCell {

    @IBOutlet weak var sliderName: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var sliderValue: UILabel!
    
    private var valuePrefix: String?
    private var valueSuffix: String?
    private var incrementSliderBy:Float = 0.0
    private var oldNberOfDays:Float = 0.0

    var cellSliderBlock: CellSliderBlock?

    func getCurrentSliderValue() -> Float {
        return slider?.value ?? 0
    }

    func configure(with title:String, value:Float, increment:Float,
                   minValue:Float, maxValue:Float, prefix:String, suffix:String) {

        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()

        // Slider title
        sliderName.font = .systemFont(ofSize: 17)
        sliderName.textColor = .piwigoColorLeftLabel()
        sliderName.text = title

        // Slider
        slider.value = value
        incrementSliderBy = increment
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.tintColor = .piwigoColorOrange()
        slider.thumbTintColor = .piwigoColorThumb()

        // Slider value
        sliderValue.font = .systemFont(ofSize: 17)
        sliderValue.textColor = .piwigoColorRightLabel()
        valuePrefix = prefix
        valueSuffix = suffix
        updateDisplayedValue(value)
    }

    @IBAction func sliderChanged(_ sender: Any) {
        updateDisplayedValue(slider.value)
        (cellSliderBlock ?? {_ in return})(slider.value)
    }

    func updateDisplayedValue(_ value: Float) {
        if Int(incrementSliderBy) == AlbumVars.shared.recentPeriodKey {
            // Special case of recent period, value = index of kRecentPeriods
            // 1, 2, 3, … 19, 20, 25, 30, 40, 50, 60, 80, 99 days (same as Piwigo server)
            var indexOfPeriod:Int = Int(value.rounded(.toNearestOrAwayFromZero))
            indexOfPeriod = min(indexOfPeriod, AlbumVars.shared.recentPeriodList.count - 1)
            indexOfPeriod = max(0, indexOfPeriod)
            slider.value = Float(indexOfPeriod)
            sliderValue.text = String(format: (valueSuffix ?? ""), String(AlbumVars.shared.recentPeriodList[indexOfPeriod]))
        }
        else {
            let quotient = (value / incrementSliderBy).rounded(.towardZero) * incrementSliderBy
            let remainder = value.truncatingRemainder(dividingBy: incrementSliderBy)
            let normalisedReminder = (remainder / incrementSliderBy).rounded(.toNearestOrAwayFromZero)
            slider.value = quotient + normalisedReminder * incrementSliderBy
            sliderValue.text = "\(valuePrefix ?? "")\(NSNumber(value: slider.value))\(valueSuffix ?? "")"
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sliderName.text = ""
        valuePrefix = ""
        valueSuffix = ""
    }
}
