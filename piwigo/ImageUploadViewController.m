//
//  ImageUploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadViewController.h"
#import "ImageUploadTableViewCell.h"
#import "ImageUpload.h"
#import "EditImageDetailsViewController.h"

@interface ImageUploadViewController () <UITableViewDelegate, UITableViewDataSource, EditImageDetailsDelegate>

@property (nonatomic, strong) UITableView *uploadImagesTableView;
@property (nonatomic, strong) NSMutableArray *imagesToUpload;

@end

@implementation ImageUploadViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.imagesToUpload = [NSMutableArray new];
		
		self.title = @"Images";
		
		self.uploadImagesTableView = [UITableView new];
		self.uploadImagesTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.uploadImagesTableView.delegate = self;
		self.uploadImagesTableView.dataSource = self;
		[self.uploadImagesTableView registerNib:[UINib nibWithNibName:@"ImageUploadCell" bundle:nil] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.uploadImagesTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadImagesTableView]];
		
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
	self.navigationItem.leftBarButtonItem = back;
}

-(void)done
{
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

-(void)setImagesSelected:(NSArray *)imagesSelected
{
	_imagesSelected = imagesSelected;
	[self setUpImageInfo];
}

-(void)setUpImageInfo
{
	for(NSString *imageName in self.imagesSelected)
	{
		// @TODO: Get a default privacy and default author
		ImageUpload *image = [[ImageUpload alloc] initWithImageName:imageName forCategory:self.selectedCategory forPrivacyLevel:0 author:@"Default Author" description:@"" andTags:@""];
		[self.imagesToUpload addObject:image];
	}
}

#pragma mark UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 150;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.imagesToUpload.count;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ImageUploadTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	ImageUpload *image = [self.imagesToUpload objectAtIndex:indexPath.row];
	
	[cell setupWithImageInfo:image];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
	EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
	editImageVC.imageDetails = [self.imagesToUpload objectAtIndex:indexPath.row];
	editImageVC.delegate = self;
	[self.navigationController pushViewController:editImageVC animated:YES];
}

#pragma mark EditImageDetailsDelegate Methods

-(void)didFinishEditingDetails:(ImageUpload *)details
{
	NSInteger index = 0;
	for(ImageUpload *image in self.imagesToUpload)
	{
		if([image.image isEqualToString:details.image]) break;
		index++;
	}
	
	[self.imagesToUpload replaceObjectAtIndex:index withObject:details];
	[self.uploadImagesTableView reloadData];
}

@end
