//
//  LocalImagesHeaderReusableView.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol LocalImagesHeaderDelegate <NSObject>

-(void)didSelectImagesOfSection:(NSInteger)section;

@end

@interface LocalImagesHeaderReusableView : UICollectionReusableView

@property (nonatomic, weak) id<LocalImagesHeaderDelegate> headerDelegate;

@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabelNoPlace;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;
@property (weak, nonatomic) IBOutlet UILabel *placeLabel;

-(void)setupWithImages:(NSArray *)imagesInSection andPlaceNames:(NSString *)placeName inSection:(NSInteger)section andSelectionMode:(BOOL)selected;

@end
