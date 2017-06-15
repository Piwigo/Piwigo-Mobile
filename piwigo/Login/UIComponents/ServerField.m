//
//  ServerField.m
//  piwigo
//
//  Created by Spencer Baker on 3/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ServerField.h"
#import "PiwigoTextField.h"
#import "Model.h"

@interface ServerField()

@property (nonatomic, strong) UILabel *protocolLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *divider;

@end

@implementation ServerField

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		if([[Model sharedInstance].serverProtocol isEqualToString:[self protocolToString:ProtocolTypeHttp]])
		{
			self.protocolType = ProtocolTypeHttp;
		}
		else
		{
			self.protocolType = ProtocolTypeHttps;

		}
		self.backgroundColor = [UIColor piwigoWhiteCream];
		
		self.protocolLabel = [UILabel new];
		self.protocolLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.protocolLabel.font = [UIFont piwigoFontNormal];
		self.protocolLabel.text = [self protocolToString:self.protocolType];
		self.protocolLabel.textColor = [UIColor blackColor];
		self.protocolLabel.textAlignment = NSTextAlignmentCenter;
		self.protocolLabel.adjustsFontSizeToFitWidth = YES;
		self.protocolLabel.minimumScaleFactor = 0.5;
		[self addSubview:self.protocolLabel];
		
		self.descriptionLabel = [UILabel new];
		self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.descriptionLabel.font = [UIFont piwigoFontNormal];
		self.descriptionLabel.font = [self.descriptionLabel.font fontWithSize:12];
		self.descriptionLabel.adjustsFontSizeToFitWidth = YES;
		self.descriptionLabel.minimumScaleFactor = 0.5;
		self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
		self.descriptionLabel.text = NSLocalizedString(@"login_protocolDescription", @"(tap to change)");
		[self addSubview:self.descriptionLabel];
		
		self.textField = [PiwigoTextField new];
		self.textField.translatesAutoresizingMaskIntoConstraints = NO;
		self.textField.layer.cornerRadius = 0;
		[self addSubview:self.textField];
		
		self.divider = [UIView new];
		self.divider.translatesAutoresizingMaskIntoConstraints = NO;
		self.divider.backgroundColor = [UIColor lightGrayColor];
		[self addSubview:self.divider];
		
		[self setupAutoLayout];
		
		[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedProtocol)]];
	}
	return self;
}

-(void)setupAutoLayout
{
	NSDictionary *views = @{
							@"label" : self.protocolLabel,
							@"desc" : self.descriptionLabel,
							@"divider" : self.divider,
							@"field" : self.textField
							};
	
	[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[label(70)][field]|"
																 options:kNilOptions
																 metrics:nil
																   views:views]];
	[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.protocolLabel]];
	[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.textField]];
	[self addConstraints:[NSLayoutConstraint constraintFillHeight:self.textField]];
	[self addConstraints:[NSLayoutConstraint constraintFillHeight:self.divider]];
	[self addConstraint:[NSLayoutConstraint constraintView:self.divider toWidth:1.0]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self.divider
													 attribute:NSLayoutAttributeLeft
													 relatedBy:NSLayoutRelationEqual
														toItem:self.textField
													 attribute:NSLayoutAttributeLeft
													multiplier:1.0
													  constant:0]];
	
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self.descriptionLabel
													 attribute:NSLayoutAttributeLeft
													 relatedBy:NSLayoutRelationGreaterThanOrEqual
														toItem:self.protocolLabel
													 attribute:NSLayoutAttributeLeft
													multiplier:1.0
													  constant:3]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self.descriptionLabel
													 attribute:NSLayoutAttributeRight
													 relatedBy:NSLayoutRelationLessThanOrEqual
														toItem:self.protocolLabel
													 attribute:NSLayoutAttributeRight
													multiplier:1.0
													  constant:-3]];
	[self addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.descriptionLabel amount:3]];
	
}

-(void)drawRect:(CGRect)rect
{
	[super drawRect:rect];
	
	UIBezierPath *viewMaskPath;
	viewMaskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
									 byRoundingCorners:(UIRectCornerBottomLeft|UIRectCornerBottomRight|UIRectCornerTopLeft|UIRectCornerTopRight)
										   cornerRadii:CGSizeMake(5.0, 5.0)];
	
	CAShapeLayer *viewMaskLayer = [[CAShapeLayer alloc] init];
	viewMaskLayer.frame = self.bounds;
	viewMaskLayer.path = viewMaskPath.CGPath;
	self.layer.mask = viewMaskLayer;
}

-(NSString*)protocolToString:(ProtocolType)protocol
{
	if(protocol == ProtocolTypeHttp)
	{
		return @"http://";
	}
	
	return @"https://";
}

-(void)tappedProtocol
{
	if(self.protocolType == ProtocolTypeHttp)
	{
		self.protocolType = ProtocolTypeHttps;
	}
	else
	{
		self.protocolType = ProtocolTypeHttp;
	}
	self.protocolLabel.text = [self protocolToString:self.protocolType];
}

-(NSString*)getProtocolString
{
	return [self protocolToString:self.protocolType];
}

@end
