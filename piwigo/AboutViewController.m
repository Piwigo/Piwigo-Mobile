//
//  AboutViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AboutViewController.h"

@interface AboutViewController ()

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *byLabel;
@property (nonatomic, strong) UILabel *usuOSSLabel;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation AboutViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		
		self.piwigoTitle = [UILabel new];
		self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoTitle.font = [UIFont piwigoFontNormal];
		self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
		self.piwigoTitle.textColor = [UIColor piwigoOrange];
		self.piwigoTitle.text = @"Piwigo Mobile";
		[self.view addSubview:self.piwigoTitle];
		
		self.byLabel = [UILabel new];
		self.byLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.byLabel.font = [UIFont piwigoFontNormal];
		self.byLabel.font = [self.byLabel.font fontWithSize:19];
		self.byLabel.textColor = [UIColor piwigoGrayLight];
		self.byLabel.text = @"By Spencer Baker";
		[self.view addSubview:self.byLabel];
		
		self.usuOSSLabel = [UILabel new];
		self.usuOSSLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.usuOSSLabel.font = [UIFont piwigoFontNormal];
		self.usuOSSLabel.font = [self.usuOSSLabel.font fontWithSize:12];
		self.usuOSSLabel.textColor = [UIColor piwigoGrayLight];
		self.usuOSSLabel.text = @"(Utah State University OSS)";
		[self.view addSubview:self.usuOSSLabel];
		
		self.textView = [UITextView new];
		self.textView.translatesAutoresizingMaskIntoConstraints = NO;
		self.textView.layer.cornerRadius = 5;
		[self.view addSubview:self.textView];
		
		NSString *aboutString = NSLocalizedStringFromTableInBundle(@"about_text", @"About", [NSBundle mainBundle], @"About text");
		NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:aboutString];
		NSRange afnetworkingRange = [aboutString rangeOfString:@"AFNetworking"];
		NSRange piwigoDescriptionRange = NSMakeRange(0, afnetworkingRange.location);
		[aboutAttributedString addAttribute:NSFontAttributeName
									  value:[UIFont systemFontOfSize:18]
									  range:piwigoDescriptionRange];
		self.textView.attributedText = aboutAttributedString;
		
		[self addConstraints];
	}
	return self;
}

-(void)addConstraints
{
	NSDictionary *views = @{
							@"title" : self.piwigoTitle,
							@"by" : self.byLabel,
							@"usu" : self.usuOSSLabel,
							@"textView" : self.textView
							};
	
	[self.view addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.piwigoTitle]];
	[self.view addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.byLabel]];
	[self.view addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.usuOSSLabel]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[title]-15-[by][usu]-20-[textView]-65-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[textView]-10-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
}

@end
