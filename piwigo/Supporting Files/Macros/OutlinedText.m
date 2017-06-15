//
//  OutlinedText.m
//  piwigo
//
//  Created by Spencer Baker on 4/1/14.
//  Copyright (c) 2014 BakerCrew Games. All rights reserved.
//

#import "OutlinedText.h"

@interface OutlinedText()

@end

@implementation OutlinedText

- (void)drawTextInRect:(CGRect)rect
{
	CGSize shadowOffset = self.shadowOffset;
	UIColor *textColor = self.textColor;
	
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(c, 1);
	CGContextSetLineJoin(c, kCGLineJoinRound);
	
	CGContextSetTextDrawingMode(c, kCGTextStroke);
	self.textColor = [UIColor piwigoGray];
	[super drawTextInRect:rect];
	
	CGContextSetTextDrawingMode(c, kCGTextFill);
	self.textColor = textColor;
	self.shadowOffset = CGSizeMake(0, 0);
	[super drawTextInRect:rect];
	
	self.shadowOffset = shadowOffset;
}


@end
