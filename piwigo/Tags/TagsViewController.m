//
//  TagsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TagsViewController.h"
#import "TagsData.h"
#import "PiwigoTagData.h"

@interface TagsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tagsTableView;
@property (nonatomic, strong) NSArray *letterIndex;

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
		self.tagsTableView.delegate = self;
		self.tagsTableView.dataSource = self;
		[self.view addSubview:self.tagsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tagsTableView]];
		
		[[TagsData sharedInstance] getTagsOnCompletion:^(NSArray *tags) {
            NSMutableSet *firstCharacters = [NSMutableSet setWithCapacity:0];
            for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] )
                [firstCharacters addObject:[[string substringToIndex:1] uppercaseString]];
            
            self.letterIndex = [[firstCharacters allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			[self.tagsTableView reloadData];
		}];
		
	}
	return self;
}

#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Table view
    self.tagsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.tagsTableView reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
    if([self.delegate respondsToSelector:@selector(didExitWithSelectedTags:)])
	{
		[self.delegate didExitWithSelectedTags:self.alreadySelectedTags];
	}
}


#pragma mark - Abcindex

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


#pragma mark - UITableView - Headers

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

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.alreadySelectedTags.count;
    } else {
        return [TagsData sharedInstance].tagList.count;
    }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
    
    PiwigoTagData *currentTag;
    if (indexPath.section == 0) {
        currentTag = self.alreadySelectedTags[indexPath.row];
    } else {
        currentTag = [TagsData sharedInstance].tagList[indexPath.row];
    }
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.text = currentTag.tagName;
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
        
    NSArray *selectedTagIDs = [self.alreadySelectedTags valueForKey:@"tagId"];
    if ([selectedTagIDs containsObject:@(currentTag.tagId)]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
    PiwigoTagData *currentTag;
    if (indexPath.section == 0) { // delete tag if tapped
        [self.alreadySelectedTags removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else { // add if not yet selected or remove if already selected
        currentTag = [TagsData sharedInstance].tagList[indexPath.row];
        NSUInteger indexOfSelection = [self.alreadySelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == currentTag.tagId);
        }];
        
        if (NSNotFound == indexOfSelection ) { // add if not yet selected
            [self.alreadySelectedTags addObject:currentTag];
            [self.alreadySelectedTags sortUsingDescriptors:
             [NSArray arrayWithObjects:
              [NSSortDescriptor sortDescriptorWithKey:@"tagName" ascending:YES], nil]];

            NSIndexPath *somePath = [NSIndexPath indexPathForRow:(self.alreadySelectedTags.count - 1) inSection:0];
            [tableView insertRowsAtIndexPaths:@[somePath] withRowAnimation:UITableViewRowAnimationAutomatic];
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
            [tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
        } else { // remove if already selected
            [self.alreadySelectedTags removeObject:currentTag];
            NSIndexPath *removePath = [NSIndexPath indexPathForRow:indexOfSelection inSection:0];
            if (!removePath && (removePath != nil) && (removePath >= 0)) {
                [tableView deleteRowsAtIndexPaths:@[removePath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        // update the checkmark
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
