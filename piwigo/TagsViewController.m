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

@end

@implementation TagsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		self.title = @"Tags";	// @TODO: Localize this!
		
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
	
	return cell;
}

@end
