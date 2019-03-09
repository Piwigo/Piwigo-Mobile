//
//  LocalImageHeaderReusableView.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImagesHeaderDelegate <NSObject>

-(void)didSelectImagesOfSection:(NSInteger)section;

@end

@interface LocalImageHeaderReusableView : UICollectionReusableView

@property (nonatomic, weak) id<ImagesHeaderDelegate> headerDelegate;

@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;

-(void)setupWithImages:(NSArray *)imagesInSection inSection:(NSInteger)section andSelectionMode:(BOOL)selected;

@end
