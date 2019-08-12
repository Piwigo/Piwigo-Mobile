//
//  NberImagesFooterCollectionReusableView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "NberImagesFooterCollectionReusableView.h"
#import "Model.h"

@interface NberImagesFooterCollectionReusableView()

@end

@implementation NberImagesFooterCollectionReusableView

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.noImagesLabel = [UILabel new];
        self.noImagesLabel.backgroundColor = [UIColor clearColor];
        self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.noImagesLabel.numberOfLines = 0;
        self.noImagesLabel.adjustsFontSizeToFitWidth = NO;
        self.noImagesLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.noImagesLabel.textAlignment = NSTextAlignmentCenter;
        self.noImagesLabel.font = [UIFont piwigoFontLight];
        self.noImagesLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");

        [self addSubview:self.noImagesLabel];
        [self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
        [self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.noImagesLabel]];
    }
    return self;
}

@end
