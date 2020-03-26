//
//  EditImageDatePickerTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "EditImageDatePickerTableViewCell.h"

NSString * const kDatePickerTableCell_ID = @"DatePickerTableCell";

static NSString * const kPiwigoPickerMinDate = @"1922-01-01 00:00:00";     // UTC
static NSString * const kPiwigoPickerMaxDate = @"2100-01-01 00:00:00";     // UTC
static NSInteger const kPiwigoComponentWidthLimit = 375;         // i.e. larger than iPhones 6,7,8 screen width
static NSTimeInterval const kPiwigoPicker1Day = 24 * 60 * 60;
static NSInteger const kPiwigoPicker12Hours = 12;
static NSInteger const kPiwigoPicker24Hours = 24;
static NSInteger const kPiwigoPickerMinutesPerHour = 60;
static NSInteger const kPiwigoPickerSecondsPerMinute = 60;
static NSInteger const kPiwigoPickerNberOfLoops = 2 * 5000;       // i.e. ±5000 loops of picker

typedef enum {
    ComponentOrderDay,
    ComponentOrderSepDH,
    ComponentOrderHour,
    ComponentOrderSepHM,
    ComponentOrderMinute,
    ComponentOrderSepMS,
    ComponentOrderSecond,
    ComponentOrderAMPM,
    ComponentCount
} PickerComponents;

@interface EditImageDatePickerTableViewCell() <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, assign) BOOL is24hFormat;
@property (nonatomic, strong) NSDateFormatter *formatterShort;
@property (nonatomic, strong) NSDateFormatter *formatterLong;
@property (nonatomic, strong) NSDate *pickerRefDate;
@property (nonatomic, assign) NSInteger pickerMaxNberDays;
@property (nonatomic, strong) NSArray<NSString *> *ampmSymbols;

@property (nonatomic, weak) IBOutlet UIPickerView *datePicker;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBarTop;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBarBottom;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *decrementMonthButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *unsetDateButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *incrementMonthButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *decrementYearButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *todayDateButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *incrementYearButton;

@end

@implementation EditImageDatePickerTableViewCell

-(void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];
    
    // Buttons
    self.decrementMonthButton.title = NSLocalizedString(@"editImageDetails_dateMonthDec", @"-1 Month");
    self.unsetDateButton.title = NSLocalizedString(@"editImageDetails_dateUnset", @"Unset");
    self.incrementMonthButton.title = NSLocalizedString(@"editImageDetails_dateMonthInc", @"+1 Month");
    self.decrementYearButton.title = NSLocalizedString(@"editImageDetails_dateYearDec", @"-1 Year");
    self.todayDateButton.title = NSLocalizedString(@"editImageDetails_dateToday", @"Today");
    self.incrementYearButton.title = NSLocalizedString(@"editImageDetails_dateYearInc", @"+1 Year");

    // Date picker: determine current time format: 12 or 24h
    NSDateFormatter *formatterShort = [[NSDateFormatter alloc] init];
    [formatterShort setLocale:[NSLocale currentLocale]];
    [formatterShort setDateStyle:NSDateFormatterNoStyle];
    [formatterShort setTimeStyle:NSDateFormatterShortStyle];
    NSString *dateString = [formatterShort stringFromDate:[NSDate date]];
    self.ampmSymbols = @[[formatterShort AMSymbol], [formatterShort PMSymbol]];
    NSRange amRange = [dateString rangeOfString:[formatterShort AMSymbol]];
    NSRange pmRange = [dateString rangeOfString:[formatterShort PMSymbol]];
    self.is24hFormat = (amRange.location == NSNotFound && pmRange.location == NSNotFound);
    
    // Date picker: adopt format respecting current locale
    NSString *formatString = [NSDateFormatter dateFormatFromTemplate:@"eeedMMM" options:0
    locale:[NSLocale currentLocale]];
    self.formatterShort = [[NSDateFormatter alloc] init];
    [self.formatterShort setDateFormat:formatString];
    formatString = [NSDateFormatter dateFormatFromTemplate:@"eeeedMMM" options:0
    locale:[NSLocale currentLocale]];
    self.formatterLong = [[NSDateFormatter alloc] init];
    [self.formatterLong setDateFormat:formatString];

    // Define date picker limits in number of days
    formatterShort.dateFormat = @"YYYY-MM-DD hh:mm:ss";
    formatterShort.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    self.pickerRefDate = [formatterShort dateFromString:kPiwigoPickerMinDate];
    NSDate *maxDate = [formatterShort dateFromString:kPiwigoPickerMaxDate];
    self.pickerMaxNberDays = [maxDate timeIntervalSinceDate:self.pickerRefDate] / kPiwigoPicker1Day;
//    NSLog(@"=> minDate:0 day, maxDate:%g days", self.pickerMaxNberDays);
    // => minDate:0 day, maxDate:101538 days
    
    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
}

-(void)applyColorPalette
{
    [self.datePicker reloadAllComponents];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
}


#pragma mark - Picker Methods

-(void)setDatePickerWithDate:(NSDate *)date animated:(BOOL)animated
{
    self.datePicker.backgroundColor = [UIColor piwigoColorCellBackground];
    self.datePicker.tintColor = [UIColor piwigoColorLeftLabel];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSTimeInterval daysInSec = [date timeIntervalSinceDate:self.pickerRefDate];
    // Corrects number of seconds to work in local time zone and substract right amount of time
    NSInteger tzShift = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
    daysInSec += tzShift;
    NSInteger second = [calendar component:NSCalendarUnitSecond fromDate:date];
    daysInSec -= second;
    [self.datePicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerSecondsPerMinute / 2 + second) inComponent:ComponentOrderSecond animated:NO];
    
    NSInteger minute = [calendar component:NSCalendarUnitMinute fromDate:date];
    daysInSec -= minute * 60;
    [self.datePicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPickerMinutesPerHour / 2 + minute) inComponent:ComponentOrderMinute animated:NO];
    
    NSInteger hour = [calendar component:NSCalendarUnitHour fromDate:date];
    daysInSec -= hour * 3600;
    if (self.is24hFormat) {
        [self.datePicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPicker24Hours / 2 + hour) inComponent:ComponentOrderHour animated:NO];
    } else {
        if (hour > 11) {
            hour -= 12;
            [self.datePicker selectRow:1 inComponent:ComponentOrderAMPM animated:NO];
        }
        [self.datePicker selectRow:(kPiwigoPickerNberOfLoops * kPiwigoPicker12Hours / 2 + hour) inComponent:ComponentOrderHour animated:NO];
    }

    daysInSec /= kPiwigoPicker1Day;
    [self.datePicker selectRow:lround(daysInSec) inComponent:ComponentOrderDay animated:animated];
}


-(NSDate *)getDateFromPicker
{
    // Date from first component
    NSDate *dateInSeconds = [NSDate dateWithTimeInterval:[self.datePicker selectedRowInComponent:ComponentOrderDay] * kPiwigoPicker1Day sinceDate:self.pickerRefDate];
    
    // Add seconds to reach time
    NSInteger hours;
    if (self.is24hFormat) {
        hours = [self.datePicker selectedRowInComponent:ComponentOrderHour] % kPiwigoPicker24Hours;
    } else {
        hours = [self.datePicker selectedRowInComponent:ComponentOrderHour] % kPiwigoPicker12Hours;
        hours += [self.datePicker selectedRowInComponent:ComponentOrderAMPM] * 12;
    }
    NSInteger minutes = [self.datePicker selectedRowInComponent:ComponentOrderMinute] % kPiwigoPickerMinutesPerHour;
    NSInteger seconds = [self.datePicker selectedRowInComponent:ComponentOrderSecond] % kPiwigoPickerSecondsPerMinute;
    
    // Date displayed in picker is in local timezone!
    NSInteger tzShift = [[NSTimeZone localTimeZone] secondsFromGMTForDate:dateInSeconds];
    NSDate *dhms = [dateInSeconds dateByAddingTimeInterval: (hours * 60 + minutes) * 60 + seconds - tzShift];
    
    return dhms;
}

#pragma mark - UIPickerViewDataSource Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return ComponentCount - self.is24hFormat;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    NSInteger nberOfRows = 0;
    switch (component) {
        case ComponentOrderDay:
            nberOfRows = self.pickerMaxNberDays;
            break;
            
        case ComponentOrderSepDH:
            nberOfRows = 1;
            break;
            
        case ComponentOrderHour:
            nberOfRows = kPiwigoPickerNberOfLoops * (self.is24hFormat ? kPiwigoPicker24Hours : kPiwigoPicker12Hours);
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
            
        case ComponentOrderAMPM:
            nberOfRows = 2;
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
    const CGFloat dayWidth = 106.0f + (self.datePicker.bounds.size.width > kPiwigoComponentWidthLimit) * 60.0f;
    const CGFloat sepDay = 10.0f;
    const CGFloat time = 26.0f;
    const CGFloat sepTime = 8.0f;
    const CGFloat ampm = 30.0f;
    const CGFloat separatorWidth = 5.0f;

    // Calculate left and right pane widths (for debugging)
//    const CGFloat leftMargin = pickerView.superview.layoutMargins.left;
//    const CGFloat rightMargin = pickerView.superview.layoutMargins.right;
//    CGFloat leftPaneWidth = leftMargin + separatorWidth + dayWidth + separatorWidth + sepDay/2;
//    CGFloat rightPaneWidth = sepDay/2 + 5 * separatorWidth + 3*time + 2*sepTime + !self.is24hFormat * (separatorWidth + ampm) + separatorWidth + rightMargin;
//    CGFloat remainingSpace = pickerView.bounds.size.width - leftPaneWidth - rightPaneWidth;
//    NSLog(@"=> left:%g, right:%g, width:%g (remaining:%g)", leftPaneWidth, rightPaneWidth, pickerView.bounds.size.width, remainingSpace);
    // iPhone SE, iOS 11 => left:136, right:179, width:318 (remaining:3)
    // iPhone Xs, iOS 12 => left:131, right:174, width:373 (remaining:68)

    NSInteger width = 0;
    switch (component) {
        case ComponentOrderDay:
            width = dayWidth;
            break;
            
        case ComponentOrderSepDH:
            width = sepDay + self.is24hFormat * separatorWidth;
            break;
            
        case ComponentOrderHour:
        case ComponentOrderMinute:
        case ComponentOrderSecond:
            width = time;
            break;
            
        case ComponentOrderSepHM:
        case ComponentOrderSepMS:
            width = sepTime;
            break;
            
        case ComponentOrderAMPM:
            width = ampm;
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
        case ComponentOrderDay:
        {
            NSDate *dateOfDay = [NSDate dateWithTimeInterval:row * kPiwigoPicker1Day sinceDate:self.pickerRefDate];
            if (self.datePicker.bounds.size.width > kPiwigoComponentWidthLimit) {
                label.text = [self.formatterLong stringFromDate:dateOfDay];
            } else {
                label.text = [self.formatterShort stringFromDate:dateOfDay];
            }
            label.textAlignment = NSTextAlignmentRight;
            break;
        }
            
        case ComponentOrderSepDH:
            label.text = @"-";
            label.textAlignment = NSTextAlignmentCenter;
            break;
            
        case ComponentOrderHour:
            label.text = [NSString stringWithFormat:@"%02ld", (long)row % (self.is24hFormat ? kPiwigoPicker24Hours : kPiwigoPicker12Hours)];
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
            
        case ComponentOrderAMPM:
            label.text = [self.ampmSymbols objectAtIndex:row];
            label.textAlignment = NSTextAlignmentLeft;
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
        case ComponentOrderHour:
        {
            NSInteger hoursPerDay = self.is24hFormat ? kPiwigoPicker24Hours : kPiwigoPicker12Hours;
            newRow = kPiwigoPickerNberOfLoops * hoursPerDay / 2 + row % hoursPerDay;
            break;
        }

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


#pragma mark - Buttons Methods

-(void)setDatePickerButtons
{
    self.toolBarTop.barTintColor = [UIColor piwigoColorCellBackground];
    self.unsetDateButton.tintColor = [UIColor redColor];
    self.incrementMonthButton.tintColor = [UIColor piwigoColorRightLabel];
    self.decrementMonthButton.tintColor = [UIColor piwigoColorRightLabel];

    self.toolBarBottom.barTintColor = [UIColor piwigoColorCellBackground];
    self.todayDateButton.tintColor = [UIColor piwigoColorRightLabel];
    self.incrementYearButton.tintColor = [UIColor piwigoColorRightLabel];
    self.decrementYearButton.tintColor = [UIColor piwigoColorRightLabel];
}

- (IBAction)unsetDate:(id)sender
{
    // Close date picker
    if ([self.delegate respondsToSelector:@selector(didUnsetImageCreationDate)])
    {
        [self.delegate didUnsetImageCreationDate];
    }
}

- (IBAction)setDateAsToday:(id)sender
{
    // Select today
    NSDate *newDate = [NSDate date];
    
    // Update picker with new date
    [self setDatePickerWithDate:newDate animated:YES];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:newDate];
    }
}

- (IBAction)incrementMonth:(id)sender
{
    // Increment month
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setMonth: 1];
    NSDate* newDate = [gregorian dateByAddingComponents:comp toDate:[self getDateFromPicker] options:0];

    // Update picker with new date
    [self setDatePickerWithDate:newDate animated:YES];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:newDate];
    }
}

- (IBAction)decrementMonth:(id)sender
{
    // Decrement month
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setMonth: -1];
    NSDate* newDate = [gregorian dateByAddingComponents:comp toDate:[self getDateFromPicker] options:0];

    // Update picker with new date
    [self setDatePickerWithDate:newDate animated:YES];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:newDate];
    }
}

- (IBAction)incrementYear:(id)sender
{
    // Increment month
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setYear: 1];
    NSDate* newDate = [gregorian dateByAddingComponents:comp toDate:[self getDateFromPicker] options:0];

    // Update picker with new date
    [self setDatePickerWithDate:newDate animated:YES];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:newDate];
    }
}

- (IBAction)decrementYear:(id)sender
{
    // Decrement month
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    [comp setYear: -1];
    NSDate* newDate = [gregorian dateByAddingComponents:comp toDate:[self getDateFromPicker] options:0];

    // Update picker with new date
    [self setDatePickerWithDate:newDate animated:YES];

    // Change date in parent view
    if ([self.delegate respondsToSelector:@selector(didSelectDateWithPicker:)])
    {
        [self.delegate didSelectDateWithPicker:newDate];
    }
}


@end
