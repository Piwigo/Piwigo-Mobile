//
//  TagsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "Model.h"
#import "PiwigoTagData.h"
#import "TagsData.h"
#import "TagsViewController.h"

@interface TagsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tagsTableView;
@property (nonatomic, strong) NSArray *letterIndex;
@property (nonatomic, strong) NSMutableArray *notSelectedTags;


@end

@implementation TagsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.title = NSLocalizedString(@"tags", @"Tags");
				
		self.tagsTableView = [UITableView new];
        self.tagsTableView.backgroundColor = [UIColor clearColor];
		self.tagsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.tagsTableView.sectionIndexColor = [UIColor piwigoOrange];
		self.tagsTableView.delegate = self;
		self.tagsTableView.dataSource = self;
		[self.view addSubview:self.tagsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tagsTableView]];
		
        // ABC index
		[[TagsData sharedInstance] getTagsOnCompletion:^(NSArray *tags) {
            
            // Build list of not selected tags
            [self updateListOfNotSelectedTags];

            // Build ABC index
            NSMutableSet *firstCharacters = [NSMutableSet setWithCapacity:0];
            for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] )
                [firstCharacters addObject:[[string substringToIndex:1] uppercaseString]];
            
            self.letterIndex = [[firstCharacters allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			[self.tagsTableView reloadData];
		}];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
	}
	return self;
}

#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Table view
    self.tagsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.tagsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tagsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self paletteChanged];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
    if([self.delegate respondsToSelector:@selector(didExitWithSelectedTags:)])
	{
		[self.delegate didExitWithSelectedTags:self.alreadySelectedTags];
	}
}


#pragma mark - ABC index

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.letterIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    
    NSInteger newRow = [self indexForFirstChar:title inArray:[[TagsData sharedInstance].tagList valueForKey:@"tagName"]];
    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:newRow inSection:1];
    [tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
    
    return index;
}

// Return the index of the first occurence of an item that begins with the supplied character
- (NSInteger)indexForFirstChar:(NSString *)character inArray:(NSArray *)array
{
    NSUInteger count = 0;
    for (NSString *aString in array) {
        if ([aString hasPrefix:character]) {
            return count;
        }
        count++;
    }
    return 0;
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header;
    if (section == 0) {
        header = NSLocalizedString(@"tagsHeader_selected", @"Selected");
    } else {
        header = NSLocalizedString(@"tagsHeader_all", @"All");
    }
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    return fmax(44.0, ceil(headerRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontBold];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    if (section == 0) {
        headerLabel.text = NSLocalizedString(@"tagsHeader_selected", @"Selected");
    } else {
        headerLabel.text = NSLocalizedString(@"tagsHeader_all", @"All");
    }
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Header view
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"|-[header]-|"
                                options:kNilOptions
                                metrics:nil
                                views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                options:kNilOptions
                                metrics:nil
                                views:@{@"header" : headerLabel}]];
    }
    
    return header;
}


#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.alreadySelectedTags.count;
    } else {
        return self.notSelectedTags.count;
    }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
    
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];

    PiwigoTagData *currentTag;
    if (indexPath.section == 0) {
        // Selected tags
        currentTag = self.alreadySelectedTags[indexPath.row];
        cell.textLabel.text = currentTag.tagName;
    }
    else {
        // Not selected tags
        currentTag = self.notSelectedTags[indexPath.row];
        
        // Number of images not known if getAdminList called
        cell.textLabel.text = [Model sharedInstance].hasAdminRights ? currentTag.tagName : [NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag];
    }
    
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

    PiwigoTagData *currentTag;
    if (indexPath.section == 0) {
        // Tapped selected tag
        currentTag = self.alreadySelectedTags[indexPath.row];
        
        // Delete tag tapped in tag list
        [self.alreadySelectedTags removeObject:currentTag];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        // Add deselected tag to list of not selected tags
        [self updateListOfNotSelectedTags];
        
        // Determine index of added tag
        NSUInteger indexOfTag = [self.notSelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == currentTag.tagId);
        }];
        NSIndexPath *insertPath = [NSIndexPath indexPathForRow:indexOfTag inSection:1];
        [tableView insertRowsAtIndexPaths:@[insertPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    else {
        // Tapped not selected tag
        currentTag = self.notSelectedTags[indexPath.row];
        
        // Delete tag tapped in list of not selected tag
        [self.notSelectedTags removeObject:currentTag];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        // Add tag to list of selected tags
        [self.alreadySelectedTags addObject:currentTag];
        [self.alreadySelectedTags sortUsingDescriptors:
         [NSArray arrayWithObjects:
          [NSSortDescriptor sortDescriptorWithKey:@"tagName" ascending:YES], nil]];

        // Determine index of added tag
        NSUInteger indexOfTag = [self.alreadySelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == currentTag.tagId);
        }];
        NSIndexPath *insertPath = [NSIndexPath indexPathForRow:indexOfTag inSection:0];
        [tableView insertRowsAtIndexPaths:@[insertPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


#pragma mark - Utilities

-(void)updateListOfNotSelectedTags
{
    // Build list of not selected tags
    self.notSelectedTags = [[NSMutableArray alloc] initWithArray:[TagsData sharedInstance].tagList];
    for (PiwigoTagData *selectedTag in self.alreadySelectedTags) {
        
        // Index of selected tag in full list
        NSUInteger indexOfSelection = [self.notSelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == selectedTag.tagId);
        }];
        
        // Remove selected tag from full list
        [self.notSelectedTags removeObjectAtIndex:indexOfSelection];
    }
}

@end
