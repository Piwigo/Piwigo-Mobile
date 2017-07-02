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
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation AboutViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.title = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
		
		self.piwigoTitle = [UILabel new];
		self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoTitle.font = [UIFont piwigoFontNormal];
		self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
		self.piwigoTitle.textColor = [UIColor piwigoOrange];
		self.piwigoTitle.text = @"Piwigo Mobile";
		[self.view addSubview:self.piwigoTitle];
		
		self.byLabel1 = [UILabel new];
		self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
		self.byLabel1.font = [UIFont piwigoFontNormal];
		self.byLabel1.font = [self.byLabel1.font fontWithSize:16];
		self.byLabel1.textColor = [UIColor piwigoWhiteCream];
		self.byLabel1.text = NSLocalizedStringFromTableInBundle(@"authors1", @"About", [NSBundle mainBundle], @"By Spencer Baker, Olaf Greck,");
		[self.view addSubview:self.byLabel1];
		
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontNormal];
        self.byLabel2.font = [self.byLabel2.font fontWithSize:16];
        self.byLabel2.textColor = [UIColor piwigoWhiteCream];
        self.byLabel2.text = NSLocalizedStringFromTableInBundle(@"authors2", @"About", [NSBundle mainBundle], @"and Eddy Lelièvre-Berna");
        [self.view addSubview:self.byLabel2];

        self.versionLabel = [UILabel new];
		self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.versionLabel.font = [UIFont piwigoFontNormal];
		self.versionLabel.font = [self.versionLabel.font fontWithSize:10];
		self.versionLabel.textColor = [UIColor piwigoWhiteCream];
		[self.view addSubview:self.versionLabel];
		
		NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		self.versionLabel.text = [NSString stringWithFormat:@"— %@ %@ (%@) —", NSLocalizedString(@"Version:", nil), appVersionString, appBuildString];
		
		self.textView = [UITextView new];
		self.textView.translatesAutoresizingMaskIntoConstraints = NO;
		self.textView.layer.cornerRadius = 5;
		[self.view addSubview:self.textView];
		
		NSString *aboutString = NSLocalizedStringFromTableInBundle(@"about_text", @"About", [NSBundle mainBundle], @"About text");
		NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:aboutString];
		
        NSRange mitLicenseRange = [aboutString rangeOfString:@"The MIT License (MIT)"];
        NSRange mitLicenseDescriptionRange = NSMakeRange(mitLicenseRange.location, [@"The MIT License (MIT)" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:mitLicenseDescriptionRange];
        
        NSRange afnetworkingRange = [aboutString rangeOfString:@"AFNetworking"];
        NSRange afnetworkingDescriptionRange = NSMakeRange(afnetworkingRange.location, [@"AFNetworking" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:afnetworkingDescriptionRange];

        NSRange mgSwipeTCRange = [aboutString rangeOfString:@"MGSwipeTableCell"];
        NSRange mgSwipeTCDescriptionRange = NSMakeRange(mgSwipeTCRange.location, [@"MGSwipeTableCell" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:mgSwipeTCDescriptionRange];
        
        NSRange uiCountingLabelRange = [aboutString rangeOfString:@"UICountingLabel"];
        NSRange uiCountingLabelDescriptionRange = NSMakeRange(uiCountingLabelRange.location, [@"UICountingLabel" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:uiCountingLabelDescriptionRange];
        
        NSRange iRateRange = [aboutString rangeOfString:@"iRate"];
        NSRange iRateDescriptionRange = NSMakeRange(iRateRange.location, [@"iRate" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:iRateDescriptionRange];
        
        self.textView.attributedText = aboutAttributedString;
		
		[self addConstraints];
	}
	return self;
}

-(void)addConstraints
{
	NSDictionary *views = @{
							@"title" : self.piwigoTitle,
							@"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
							@"usu" : self.versionLabel,
							@"textView" : self.textView
							};
	
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoTitle]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[title]-[by1][by2]-3-[usu]-10-[textView]-65-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
}

@end
