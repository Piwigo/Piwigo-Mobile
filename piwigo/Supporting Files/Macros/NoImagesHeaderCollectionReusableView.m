//
//  NoImagesHeaderCollectionReusableView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "NoImagesHeaderCollectionReusableView.h"
#import "Model.h"

@interface NoImagesHeaderCollectionReusableView()

@end

@implementation NoImagesHeaderCollectionReusableView

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.noImagesLabel = [UILabel new];
        self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.noImagesLabel.font = [UIFont piwigoFontBold];
        self.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
        [self addSubview:self.noImagesLabel];
        [self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
        [self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.noImagesLabel]];
    }
    return self;
}

@end
