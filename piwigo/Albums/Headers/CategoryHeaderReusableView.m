//
//  CategoryHeaderReusableView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/06/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "CategoryHeaderReusableView.h"

@interface CategoryHeaderReusableView()

@end

@implementation CategoryHeaderReusableView

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.commentLabel = [UILabel new];
        self.commentLabel.backgroundColor = [UIColor clearColor];
        self.commentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.commentLabel.numberOfLines = 0;
        self.commentLabel.adjustsFontSizeToFitWidth = NO;
        self.commentLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.commentLabel.textAlignment = NSTextAlignmentCenter;
        self.commentLabel.font = [UIFont piwigoFontNormal];
        self.commentLabel.text = @"";

        [self addSubview:self.commentLabel];
        [self addConstraint:[NSLayoutConstraint constraintViewFromTop:self.commentLabel amount:4]];
        if (@available(iOS 11, *)) {
            [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                           options:kNilOptions
                                                                           metrics:nil
                                                                             views:@{@"header" : self.commentLabel}]];
        } else {
            [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                           options:kNilOptions
                                                                           metrics:nil
                                                                             views:@{@"header" : self.commentLabel}]];
        }
    }
    return self;
}

@end
