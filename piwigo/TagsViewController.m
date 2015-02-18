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
@property (nonatomic, strong) NSMutableArray *selectedIndices;

@end

@implementation TagsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		self.title = @"Tags";	// @TODO: Localize this!
		
		self.selectedIndices = [NSMutableArray new];
		
		self.tagsTableView = [UITableView new];
		self.tagsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.tagsTableView.delegate = self;
		self.tagsTableView.dataSource = self;
		[self.view addSubview:self.tagsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tagsTableView]];
		
		[[TagsData sharedInstance] getTagsOnCompletion:^(NSArray *tags) {
			[self.tagsTableView reloadData];
		}];
		
	}
	return self;
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if([self.delegate respondsToSelector:@selector(didExitWithSelectedTags:)])
	{
		NSMutableArray *selectedTags = [NSMutableArray new];
		
		for(NSNumber *selectedIndex in self.selectedIndices)
		{
			[selectedTags addObject:[TagsData sharedInstance].tagList[[selectedIndex integerValue]]];
		}
		
		[self.delegate didExitWithSelectedTags:selectedTags];
	}
}

-(void)setAlreadySelectedTags:(NSArray *)alreadySelectedTags
{
	_alreadySelectedTags = alreadySelectedTags;
	
	for(PiwigoTagData *tagData in alreadySelectedTags)
	{
		[self.selectedIndices addObject:@([[TagsData sharedInstance] getIndexOfTag:tagData])];
	}
}

-(void)addOrRemoveIndexToSelected:(NSInteger)index
{
	if(![self.selectedIndices containsObject:@(index)])
	{
		[self.selectedIndices addObject:@(index)];
	}
	else
	{
		[self.selectedIndices removeObject:@(index)];
	}
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [TagsData sharedInstance].tagList.count;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
	
	cell.textLabel.text = [[TagsData sharedInstance].tagList[indexPath.row] tagName];
	
	if([self.selectedIndices containsObject:@(indexPath.row)])
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	[self addOrRemoveIndexToSelected:indexPath.row];
	
	[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
