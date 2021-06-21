//
//  EditImageShiftPickerTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "EditImageShiftPickerTableViewCell.h"

NSString * const kShiftPickerTableCell_ID = @"ShiftPickerTableCell";

static NSInteger const kPiwigoPickerNberOfYears = 200;         // i.e. ±200 years in picker
static NSInteger const kPiwigoPickerMonthsPerYear = 12;
static NSInteger const kPiwigoPickerDaysPerMonth = 32;
static NSInteger const kPiwigoPickerHoursPerDay = 24;
static NSInteger const kPiwigoPickerMinutesPerHour = 60;
static NSInteger const kPiwigoPickerSecondsPerMinute = 60;
static NSInteger const kPiwigoPickerNberOfLoops = 2 * 1000;     // i.e. ±1000 loops of picker

typedef enum {
    ComponentOrderYear,
    ComponentOrderSepYM,
    ComponentOrderMonth,
    ComponentOrderSepMD,
    ComponentOrderDay,
    ComponentOrderSepDH,
    ComponentOrderHour,
    ComponentOrderSepHM,
    ComponentOrderMinute,
    ComponentOrderSepMS,
    ComponentOrderSecond,
    ComponentCount
} PickerComponents;

@interface EditImageShiftPickerTableViewCell() <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) NSDate *pickerRefDate;
@property (weak, nonatomic) IBOutlet UISegmentedControl *addRemoveTimeButton;
@property (nonatomic, weak) IBOutlet UIPickerView *shiftPicker;

@end

@implementation EditImageShiftPickerTableViewCell

-(void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];
    
    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:[PwgNotifications paletteChangedObjc] object:nil];
}

-(void)applyColorPalette
{
    [self.shiftPicker reloadAllComponents];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
}


#pragma mark - Picker Methods

-(void)setShiftPickerWithDate:(NSDate *)date animated:(BOOL)animated
{
    // Store starting date (now if provided date in nil)
    if (date == nil) {
        self.pickerRefDate = [NSDate date];
    } else {
        self.pickerRefDate = date;
    }
    
    // Start with zero date interval
    [self.shiftPicker selectRow:0 inComponent:ComponentOrderYear animated:NO];
    [self.shiftPicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear / 2) inComponent:ComponentOrderMonth animated:NO];
    [self.shiftPicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerDaysPerMonth / 2) inComponent:ComponentOrderDay animated:NO];
    [self.shiftPicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay / 2) inComponent:ComponentOrderHour animated:NO];
    [self.shiftPicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour / 2) inComponent:ComponentOrderMinute animated:NO];
    [self.shiftPicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute / 2) inComponent:ComponentOrderSecond animated:NO];
    
    // Consider removing time
    [self.addRemoveTimeButton setEnabled:YES forSegmentAtIndex:0];
}

-(NSDate *)getDateFromPicker
{
    // Should we add or substract time?
    NSInteger operator = self.addRemoveTimeButton.selectedSegmentIndex == 0 ? -1 : 1;
    
    // Add seconds
    NSInteger days = [self.shiftPicker selectedRowInComponent:ComponentOrderDay] % kPiwigoPickerDaysPerMonth;
    NSInteger hours = [self.shiftPicker selectedRowInComponent:ComponentOrderHour] % kPiwigoPickerHoursPerDay;
    NSInteger minutes = [self.shiftPicker selectedRowInComponent:ComponentOrderMinute] % kPiwigoPickerMinutesPerHour;
    NSInteger seconds = [self.shiftPicker selectedRowInComponent:ComponentOrderSecond] % kPiwigoPickerSecondsPerMinute;
    NSDate *daysInSeconds = [self.pickerRefDate dateByAddingTimeInterval: operator * (((days * 24 + hours) * 60 + minutes) * 60 + seconds)];
    
    // Add months
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setMonth:operator * [self.shiftPicker selectedRowInComponent:ComponentOrderMonth] % kPiwigoPickerMonthsPerYear];
    [comp setYear:operator * [self.shiftPicker selectedRowInComponent:ComponentOrderYear]];
    NSDate* newDate = [gregorian dateByAddingComponents:comp toDate:daysInSeconds options:0];
    
    return newDate;
}

#pragma mark - UIPickerViewDataSource Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return ComponentCount;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    NSInteger nberOfRows = 0;
    switch (component) {
        case ComponentOrderYear:
            nberOfRows = kPiwigoPickerNberOfYears;
            break;
            
        case ComponentOrderSepYM:
            nberOfRows = 1;
            break;
            
        case ComponentOrderMonth:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear;
            break;
            
        case ComponentOrderSepMD:
            nberOfRows = 1;
            break;
            
        case ComponentOrderDay:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay;
            break;
            
        case ComponentOrderSepDH:
            nberOfRows = 1;
            break;
            
        case ComponentOrderHour:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay;
            break;
            
        case ComponentOrderSepHM:
            nberOfRows = 1;
            break;
            
        case ComponentOrderMinute:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour;
            break;
            
        case ComponentOrderSepMS:
            nberOfRows = 1;
            break;
            
        case ComponentOrderSecond:
            nberOfRows = kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute;
            break;
            
        default:
            break;
    }
    return nberOfRows;
}


#pragma mark - UIPickerViewDelegate Methods

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    // Same height for all components
    return 28.0;
}

-(CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    // Widths contants
    const CGFloat sepDayTime = 10.0f;
    const CGFloat numberWidth = 26.0f;
    const CGFloat numberSepWidth = 8.0f;
//    const CGFloat separatorWidth = 5.0f;

    // Calculate left and right pane widths (for debugging - see EditImageDatePickerTableViewCell)
//    const CGFloat leftMargin = pickerView.superview.layoutMargins.left;
//    const CGFloat rightMargin = pickerView.superview.layoutMargins.right;
//    CGFloat leftPaneWidth = leftMargin + separatorWidth + day + separatorWidth + sepDay/2;
//    CGFloat rightPaneWidth = sepDay/2 + 5 * separatorWidth + 3*time + 2*sepTime + !self.is24hFormat * (separatorWidth + ampm) + separatorWidth + rightMargin;
//    CGFloat remainingSpace = pickerView.bounds.size.width - leftPaneWidth - rightPaneWidth;
//    NSLog(@"=> left:%g, right:%g, width:%g (remaining:%g)", leftPaneWidth, rightPaneWidth, pickerView.bounds.size.width, remainingSpace);
    // iPhone SE, iOS 11 => left:136, right:179, width:318 (remaining:3)
    // iPhone Xs, iOS 12 => left:131, right:174, width:373 (remaining:68)

    NSInteger width = 0;
    switch (component) {
        case ComponentOrderYear:
        case ComponentOrderMonth:
        case ComponentOrderDay:
        case ComponentOrderHour:
        case ComponentOrderMinute:
        case ComponentOrderSecond:
            width = numberWidth;
            break;
            
        case ComponentOrderSepYM:
        case ComponentOrderSepMD:
        case ComponentOrderSepHM:
        case ComponentOrderSepMS:
            width = numberSepWidth;
            break;
            
        case ComponentOrderSepDH:
            width = sepDayTime;
            break;
            
        default:
            break;
    }
    return width;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = (UILabel *)view;
    if (label == nil) {
        label = [UILabel new];
        label.font = [UIFont piwigoFontNormal];
        label.textColor = [UIColor piwigoColorLeftLabel];
    }
    switch (component) {
        case ComponentOrderYear:
            label.text = [NSString stringWithFormat:@"%ld", (long)row];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSepYM:
            label.text = @"-";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderMonth:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % kPiwigoPickerMonthsPerYear];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSepMD:
            label.text = @"-";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderDay:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % kPiwigoPickerDaysPerMonth];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSepDH:
            label.text = @"|";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderHour:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % kPiwigoPickerHoursPerDay];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSepHM:
            label.text = @":";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderMinute:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % kPiwigoPickerMinutesPerHour];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSepMS:
            label.text = @":";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderSecond:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % kPiwigoPickerSecondsPerMinute];
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        default:
            break;
    }
    return label;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
//    NSLog(@"=> Selected row:%ld in component:%ld", (long)row, (long)component);

    // Jump back to the row with the current value that is closest to the middle
    NSInteger newRow = row;
    switch (component) {
        case ComponentOrderMonth:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerMonthsPerYear / 2 + row % kPiwigoPickerMonthsPerYear;
            break;

        case ComponentOrderDay:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerDaysPerMonth / 2 + row % kPiwigoPickerDaysPerMonth;
            break;

        case ComponentOrderHour:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerHoursPerDay / 2 + row % kPiwigoPickerHoursPerDay;
            break;

        case ComponentOrderMinute:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour / 2 + row % kPiwigoPickerMinutesPerHour;
            break;
            
        case ComponentOrderSecond:
            newRow = kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute / 2 + row % kPiwigoPickerSecondsPerMinute;
            break;
            
        default:
            break;
    }
    [pickerView selectRow:newRow inComponent:component animated:NO];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:[self getDateFromPicker]];
    }
}


#pragma mark - Button Methods

- (IBAction)changedMode:(id)sender
{
    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:[self getDateFromPicker]];
    }
}

@end
