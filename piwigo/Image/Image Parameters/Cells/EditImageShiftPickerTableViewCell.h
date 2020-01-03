//
//  EditImageShiftPickerTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kShiftPickerTableCell_ID;

@protocol EditImageShiftPickerDelegate <NSObject>

-(void)didSelectDateWithPicker:(NSDate *)date;

@end

@interface EditImageShiftPickerTableViewCell : UITableViewCell <UIPickerViewDelegate>

@property (nonatomic, weak) id<EditImageShiftPickerDelegate> delegate;

-(void)setShiftPickerWithDate:(NSDate *)date animated:(BOOL)animated;

@end
