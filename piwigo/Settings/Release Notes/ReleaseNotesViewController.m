//
//  ReleaseNotesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import <sys/utsname.h>                    // For determining iOS device model
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
        self.piwigoTitle.text = NSLocalizedString(@"settings_appName", @"Piwigo Mobile");
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
        NSString *notesString = @"\n\n\n\n";
        
        // Release 2.1.5 — Bundle string
        NSString *v215String = NSLocalizedStringFromTableInBundle(@"v2.1.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.5 Release Notes text");
        notesString = [notesString stringByAppendingString:v215String];
        
        // Release 2.1.4 — Bundle string
        NSString *v214String = NSLocalizedStringFromTableInBundle(@"v2.1.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.4 Release Notes text");
        notesString = [notesString stringByAppendingString:v214String];
        
        // Release 2.1.3 — Bundle string
        NSString *v213String = NSLocalizedStringFromTableInBundle(@"v2.1.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.3 Release Notes text");
        notesString = [notesString stringByAppendingString:v213String];
        
        // Release 2.1.2 — Bundle string
        NSString *v212String = NSLocalizedStringFromTableInBundle(@"v2.1.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.2 Release Notes text");
        notesString = [notesString stringByAppendingString:v212String];
        
        // Release 2.1.1 — Bundle string
        NSString *v211String = NSLocalizedStringFromTableInBundle(@"v2.1.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.1 Release Notes text");
        notesString = [notesString stringByAppendingString:v211String];
        
        // Release 2.1.0 — Bundle string
        NSString *v210String = NSLocalizedStringFromTableInBundle(@"v2.1.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.0 Release Notes text");
        notesString = [notesString stringByAppendingString:v210String];
        
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
        
        // Release 2.1.5 — Attributed string
        NSRange v215Range = [v215String rangeOfString:@" 2.1.5\n"];
        v215Range.location += [@" 2.1.5\n" length];
        NSRange v215DescriptionRange = NSMakeRange(v215Range.location, [v215String length] - v215Range.location);
        v215String = [v215String stringByReplacingCharactersInRange:v215DescriptionRange withString:@""];
        
        v215Range = [notesString rangeOfString:v215String];
        v215DescriptionRange = NSMakeRange(v215Range.location, [v215String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v215DescriptionRange];
        
        // Release 2.1.4 — Attributed string
        NSRange v214Range = [v214String rangeOfString:@" 2.1.4\n"];
        v214Range.location += [@" 2.1.4\n" length];
        NSRange v214DescriptionRange = NSMakeRange(v214Range.location, [v214String length] - v214Range.location);
        v214String = [v214String stringByReplacingCharactersInRange:v214DescriptionRange withString:@""];
        
        v214Range = [notesString rangeOfString:v214String];
        v214DescriptionRange = NSMakeRange(v214Range.location, [v214String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v214DescriptionRange];
        
        // Release 2.1.3 — Attributed string
        NSRange v213Range = [v213String rangeOfString:@" 2.1.3\n"];
        v213Range.location += [@" 2.1.3\n" length];
        NSRange v213DescriptionRange = NSMakeRange(v213Range.location, [v213String length] - v213Range.location);
        v213String = [v213String stringByReplacingCharactersInRange:v213DescriptionRange withString:@""];
        
        v213Range = [notesString rangeOfString:v213String];
        v213DescriptionRange = NSMakeRange(v213Range.location, [v213String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v213DescriptionRange];
        
        // Release 2.1.2 — Attributed string
        NSRange v212Range = [v212String rangeOfString:@" 2.1.2\n"];
        v212Range.location += [@" 2.1.2\n" length];
        NSRange v212DescriptionRange = NSMakeRange(v212Range.location, [v212String length] - v212Range.location);
        v212String = [v212String stringByReplacingCharactersInRange:v212DescriptionRange withString:@""];
        
        v212Range = [notesString rangeOfString:v212String];
        v212DescriptionRange = NSMakeRange(v212Range.location, [v212String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v212DescriptionRange];
        
        // Release 2.1.1 — Attributed string
        NSRange v211Range = [v211String rangeOfString:@" 2.1.1\n"];
        v211Range.location += [@" 2.1.1\n" length];
        NSRange v211DescriptionRange = NSMakeRange(v211Range.location, [v211String length] - v211Range.location);
        v211String = [v211String stringByReplacingCharactersInRange:v211DescriptionRange withString:@""];
        
        v211Range = [notesString rangeOfString:v211String];
        v211DescriptionRange = NSMakeRange(v211Range.location, [v211String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v211DescriptionRange];
        
        // Release 2.1.0 — Attributed string
        NSRange v210Range = [v210String rangeOfString:@" 2.1\n"];
        v210Range.location += [@" 2.1\n" length];
        NSRange v210DescriptionRange = NSMakeRange(v210Range.location, [v210String length] - v210Range.location);
        v210String = [v210String stringByReplacingCharactersInRange:v210DescriptionRange withString:@""];

        v210Range = [notesString rangeOfString:v210String];
        v210DescriptionRange = NSMakeRange(v210Range.location, [v210String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v210DescriptionRange];
        
        // Release 2.0.4 — Attributed string
        NSRange v204Range = [v204String rangeOfString:@" 2.0.4\n"];
        v204Range.location += [@" 2.0.4\n" length];
        NSRange v204DescriptionRange = NSMakeRange(v204Range.location, [v204String length] - v204Range.location);
        v204String = [v204String stringByReplacingCharactersInRange:v204DescriptionRange withString:@""];
        
        v204Range = [notesString rangeOfString:v204String];
        v204DescriptionRange = NSMakeRange(v204Range.location, [v204String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v204DescriptionRange];
        
        // Release 2.0.3 — Attributed string
        NSRange v203Range = [v203String rangeOfString:@" 2.0.3\n"];
        v203Range.location += [@" 2.0.3\n" length];
        NSRange v203DescriptionRange = NSMakeRange(v203Range.location, [v203String length] - v203Range.location);
        v203String = [v203String stringByReplacingCharactersInRange:v203DescriptionRange withString:@""];
        
        v203Range = [notesString rangeOfString:v203String];
        v203DescriptionRange = NSMakeRange(v203Range.location, [v203String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v203DescriptionRange];
        
        // Release 2.0.2 — Attributed string
        NSRange v202Range = [v202String rangeOfString:@" 2.0.2\n"];
        v202Range.location += [@" 2.0.2\n" length];
        NSRange v202DescriptionRange = NSMakeRange(v202Range.location, [v202String length] - v202Range.location);
        v202String = [v202String stringByReplacingCharactersInRange:v202DescriptionRange withString:@""];
        
        v202Range = [notesString rangeOfString:v202String];
        v202DescriptionRange = NSMakeRange(v202Range.location, [v202String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v202DescriptionRange];
        
        // Release 2.0.1 — Attributed string
        NSRange v201Range = [v201String rangeOfString:@" 2.0.1\n"];
        v201Range.location += [@" 2.0.1\n" length];
        NSRange v201DescriptionRange = NSMakeRange(v201Range.location, [v201String length] - v201Range.location);
        v201String = [v201String stringByReplacingCharactersInRange:v201DescriptionRange withString:@""];
        
        v201Range = [notesString rangeOfString:v201String];
        v201DescriptionRange = NSMakeRange(v201Range.location, [v201String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v201DescriptionRange];
        
        // Release 2.0.0 — Attributed string
        NSRange v200Range = [v200String rangeOfString:@" 2.0\n"];
        v200Range.location += [@" 2.0\n" length];
        NSRange v200DescriptionRange = NSMakeRange(v200Range.location, [v200String length] - v200Range.location);
        v200String = [v200String stringByReplacingCharactersInRange:v200DescriptionRange withString:@""];
        
        v200Range = [notesString rangeOfString:v200String];
        v200DescriptionRange = NSMakeRange(v200Range.location, [v200String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v200DescriptionRange];
        
        // Release 1.0.0 — Attributed string
        NSRange v100Range = [v100String rangeOfString:@" 1.0\n"];
        v100Range.location += [@" 1.0\n" length];
        NSRange v100DescriptionRange = NSMakeRange(v100Range.location, [v100String length] - v100Range.location);
        v100String = [v100String stringByReplacingCharactersInRange:v100DescriptionRange withString:@""];
        
        v100Range = [notesString rangeOfString:v100String];
        v100DescriptionRange = NSMakeRange(v100Range.location, [v100String length]);
        [notesAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont boldSystemFontOfSize:14]
                                      range:v100DescriptionRange];
        
        self.textView.attributedText = notesAttributedString;
        self.textView.editable = NO;
        self.textView.allowsEditingTextAttributes = NO;
        self.textView.selectable = YES;

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
    
    // iPhone X ?
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"]) {
        // Add 25px for iPhone X (not great in landscape mode but temporary solution)
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-105-[title]-[subTitle]-10-[textView]-65-|"
                                   options:kNilOptions metrics:nil views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-80-[title]-[subTitle]-10-[textView]-65-|"
                                   options:kNilOptions metrics:nil views:views]];
    }
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:views]];
}

@end
