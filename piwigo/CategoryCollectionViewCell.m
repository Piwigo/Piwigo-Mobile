//
//  CategoryCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryCollectionViewCell.h"
#import "AlbumTableViewCell.h"

@interface CategoryCollectionViewCell() <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation CategoryCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.tableView = [UITableView new];
		self.tableView.userInteractionEnabled = NO;
		self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.tableView.backgroundColor = [UIColor clearColor];
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		[self.tableView registerClass:[AlbumTableViewCell class] forCellReuseIdentifier:@"cell"];
		self.tableView.delegate = self;
		self.tableView.dataSource = self;
		[self.contentView addSubview:self.tableView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
		
	}
	return self;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
	self.albumData = albumData;
	[self.tableView reloadData];
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	self.albumData = nil;
}

#pragma mark UITableViewDataSource Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 188.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	cell.userInteractionEnabled = NO;
	[cell setupWithAlbumData:self.albumData];
	
	return cell;
}

@end
