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

    var cellSliderBlock: CellSliderBlock?

    func getCurrentSliderValue() -> Float {
        return slider?.value ?? 0
    }

    func configure(with title:String, value:Float, increment:Float, minValue:Float, maxValue:Float, prefix:String, suffix:String) {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()

        // Slider title
        sliderName.font = UIFont.piwigoFontNormal()
        sliderName.textColor = UIColor.piwigoColorLeftLabel()
        sliderName.text = title

        // Slider
        slider.value = value
        incrementSliderBy = increment
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.tintColor = UIColor.piwigoColorOrange()
        slider.thumbTintColor = UIColor.piwigoColorThumb()

        // Slider value
        sliderValue.font = UIFont.piwigoFontNormal()
        sliderValue.textColor = UIColor.piwigoColorRightLabel()
        valuePrefix = prefix
        valueSuffix = suffix
        updateDisplayedValue(value)
    }

    @IBAction func sliderChanged(_ sender: Any) {
        updateDisplayedValue(slider.value)
        (cellSliderBlock ?? {_ in return})(slider.value)
    }

    func updateDisplayedValue(_ value: Float) {
        let quotient = (value / incrementSliderBy).rounded(.towardZero) * incrementSliderBy
        let remainder = value.truncatingRemainder(dividingBy: incrementSliderBy)
        let normalisedReminder = (remainder / incrementSliderBy).rounded(.toNearestOrAwayFromZero)
        slider.value = quotient + normalisedReminder * incrementSliderBy
        sliderValue.text = "\(valuePrefix ?? "")\(NSNumber(value: slider.value))\(valueSuffix ?? "")"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sliderName.text = ""
        valuePrefix = ""
        valueSuffix = ""
    }
}
