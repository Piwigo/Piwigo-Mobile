//
//  EditImageDatePickerTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kDatePickerTableCell_ID;

FOUNDATION_EXPORT NSTimeInterval const kPiwigoPicker1Day;
FOUNDATION_EXPORT NSInteger const kPiwigoPicker12Hours;
FOUNDATION_EXPORT NSInteger const kPiwigoPicker24Hours;
FOUNDATION_EXPORT NSInteger const kPiwigoPickerMinutesPerHour;
FOUNDATION_EXPORT NSInteger const kPiwigoPickerSecondsPerMinute;
FOUNDATION_EXPORT NSInteger const kPiwigoPickerNberOfLoops;

@protocol EditImageDatePickerDelegate <NSObject>

-(void)didSelectDateWithPicker:(NSDate *)date;
-(void)didUnsetImageCreationDate;

@end

@interface EditImageDatePickerTableViewCell : UITableViewCell <UIPickerViewDelegate>

@property (nonatomic, weak) id<EditImageDatePickerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIPickerView *datePicker;

-(void)setDatePickerWithDate:(NSDate *)date animated:(BOOL)animated;
-(void)setDatePickerButtons;

@end
