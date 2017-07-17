//
//  ReleaseNotesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "ReleaseNotesViewController.h"

@interface ReleaseNotesViewController ()

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *releaseNotes;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation ReleaseNotesViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoGray];
        self.title = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
        
        self.piwigoTitle = [UILabel new];
        self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoTitle.font = [UIFont piwigoFontNormal];
        self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
        self.piwigoTitle.textColor = [UIColor piwigoOrange];
        self.piwigoTitle.text = @"Piwigo Mobile";
        [self.view addSubview:self.piwigoTitle];
        
        self.releaseNotes = [UILabel new];
        self.releaseNotes.translatesAutoresizingMaskIntoConstraints = NO;
        self.releaseNotes.font = [UIFont piwigoFontNormal];
        self.releaseNotes.font = [self.releaseNotes.font fontWithSize:16];
        self.releaseNotes.textColor = [UIColor piwigoWhiteCream];
        self.releaseNotes.text = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");;
        [self.view addSubview:self.releaseNotes];
        
        self.textView = [UITextView new];
        self.textView.translatesAutoresizingMaskIntoConstraints = NO;
        self.textView.layer.cornerRadius = 5;
        [self.view addSubview:self.textView];
        
        // Release notes string
        NSString *notesString = @"";
        
            // Release 2.0.4 — Bundle string
            NSString *v204String = NSLocalizedStringFromTableInBundle(@"v2.0.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.4 Release Notes text");
            notesString = [notesString stringByAppendingString:v204String];

            // Release 2.0.3 — Bundle string
            NSString *v203String = NSLocalizedStringFromTableInBundle(@"v2.0.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.3 Release Notes text");
            notesString = [notesString stringByAppendingString:v203String];
            
            // Release 2.0.2 — Bundle string
            NSString *v202String = NSLocalizedStringFromTableInBundle(@"v2.0.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.2 Release Notes text");
            notesString = [notesString stringByAppendingString:v202String];

            // Release 2.0.1 — Bundle string
            NSString *v201String = NSLocalizedStringFromTableInBundle(@"v2.0.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.1 Release Notes text");
            notesString = [notesString stringByAppendingString:v201String];
            
            // Release 2.0.0 — Bundle string
            NSString *v200String = NSLocalizedStringFromTableInBundle(@"v2.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.0 Release Notes text");
            notesString = [notesString stringByAppendingString:v200String];
            
            // Release 1.0.0 — Bundle string
            NSString *v100String = NSLocalizedStringFromTableInBundle(@"v1.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v1.0.0 Release Notes text");
            notesString = [notesString stringByAppendingString:v100String];
            
        // Attributed strings
        NSMutableAttributedString *notesAttributedString = [[NSMutableAttributedString alloc] initWithString:notesString];
    
            // Release 2.0.4 — Attributed string
            NSRange v204Range = [notesString rangeOfString:@"Version 2.0.4"];
            NSRange v204DescriptionRange = NSMakeRange(v204Range.location, [@"Version 2.0.4" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v204DescriptionRange];
            
            // Release 2.0.3 — Attributed string
            NSRange v203Range = [notesString rangeOfString:@"Version 2.0.3 — May 26, 2017"];
            NSRange v203DescriptionRange = NSMakeRange(v203Range.location, [@"Version 2.0.3 — May 26, 2017" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v203DescriptionRange];

            // Release 2.0.2 — Attributed string
            NSRange v202Range = [notesString rangeOfString:@"Version 2.0.2 — May 8, 2017"];
            NSRange v202DescriptionRange = NSMakeRange(v202Range.location, [@"Version 2.0.2 — May 8, 2017" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v202DescriptionRange];

            // Release 2.0.1 — Attributed string
            NSRange v201Range = [notesString rangeOfString:@"Version 2.0.1 — June 26, 2015"];
            NSRange v201DescriptionRange = NSMakeRange(v201Range.location, [@"Version 2.0.1 — June 26, 2015" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v201DescriptionRange];

            // Release 2.0.0 — Attributed string
            NSRange v200Range = [notesString rangeOfString:@"Version 2.0 — April 24, 2015"];
            NSRange v200DescriptionRange = NSMakeRange(v200Range.location, [@"Version 2.0 — April 24, 2015" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v200DescriptionRange];
            
            // Release 1.0.0 — Attributed string
            NSRange v100Range = [notesString rangeOfString:@"Version 1.0 — October 17, 2011"];
            NSRange v100DescriptionRange = NSMakeRange(v100Range.location, [@"Version 1.0 — October 17, 2011" length]);
            [notesAttributedString addAttribute:NSFontAttributeName
                                          value:[UIFont boldSystemFontOfSize:14]
                                          range:v100DescriptionRange];
            
        self.textView.attributedText = notesAttributedString;
        [self addConstraints];
    }
    return self;
}

-(void)addConstraints
{
    NSDictionary *views = @{
                            @"title" : self.piwigoTitle,
                            @"subTitle" : self.releaseNotes,
                            @"textView" : self.textView
                            };
    
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoTitle]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.releaseNotes]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[title]-[subTitle]-10-[textView]-65-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:views]];
}

@end
