//
//  SliderTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SliderTableViewCell : UITableViewCell

@property (nonatomic, assign) NSInteger sliderValue;
@property (nonatomic, strong) UILabel *cacheType;

-(NSInteger)getCurrentSliderValue;

@end
