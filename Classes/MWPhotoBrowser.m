//
//  MWPhotoBrowser.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWPhotoBrowser.h"
#import "ZoomingScrollView.h"

#if __IPHONE_5_0
#import <Twitter/Twitter.h>
#endif

#define PADDING 10

static NSString *copyLinkButtonName = @"Copy Link";
static NSString *facebookButtonName = @"Facebook";
static NSString *twitterButtonName = @"Twitter";
static NSString *emailButtonName = @"Email";

// Handle depreciations and supress hide warnings
@interface UIApplication (DepreciationWarningSuppresion)
- (void)setStatusBarHidden:(BOOL)hidden animated:(BOOL)animated;
@end

@interface MWPhotoBrowser()

- (void)showShareActionSheet;
- (void)showEditActionSheet;

@end

// MWPhotoBrowser
@implementation MWPhotoBrowser

@synthesize editActionSheet = _editActionSheet;
@synthesize shareActionSheet = _shareActionSheet;

@synthesize delegate;
@synthesize canEditPhotos;

- (id)initWithPhotos:(NSArray *)photosArray {
	if ((self = [super init])) {
		
		// Store photos
		photos = photosArray;
		
        // Defaults
        
        self.wantsFullScreenLayout = YES;
        self.hidesBottomBarWhenPushed = YES;
		currentPageIndex = 0;
		performingLayout = NO;
		rotating = NO;
		
	}
	return self;
}

#pragma mark -
#pragma mark Memory

- (void)didReceiveMemoryWarning {
	
	// Release any cached data, images, etc that aren't in use.
	
	// Release images
	[photos makeObjectsPerformSelector:@selector(releasePhoto)];
	[recycledPages removeAllObjects];
	NSLog(@"didReceiveMemoryWarning");
	
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
}

// Release any retained subviews of the main view.
- (void)viewDidUnload {
	currentPageIndex = 0;
    pagingScrollView = nil;
    visiblePages = nil;
    recycledPages = nil;
    toolbar = nil;
    caption = nil;
    previousButton = nil;
    nextButton = nil;
}


#pragma mark -
#pragma mark View

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	
	// View
	self.view.backgroundColor = [UIColor blackColor];
	
	// Setup paging scrolling view
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
	pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
	pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	pagingScrollView.pagingEnabled = YES;
	pagingScrollView.delegate = self;
	pagingScrollView.showsHorizontalScrollIndicator = NO;
	pagingScrollView.showsVerticalScrollIndicator = NO;
	pagingScrollView.backgroundColor = [UIColor blackColor];
    pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:currentPageIndex];
	[self.view addSubview:pagingScrollView];
	
	// Setup pages
	visiblePages = [[NSMutableSet alloc] init];
	recycledPages = [[NSMutableSet alloc] init];
	[self tilePages];
    
    // Navigation bar
    self.navigationController.navigationBar.tintColor = nil;
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        UIBarButtonItem* backItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
        self.navigationItem.leftBarButtonItem = backItem;
    }
    
    if (self.canEditPhotos) {
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(editButtonHit:)];
        self.navigationItem.rightBarButtonItem = editButton;
    }
    
    // Toolbar
    toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:self.interfaceOrientation]];
    toolbar.tintColor = nil;
    toolbar.barStyle = UIBarStyleBlackTranslucent;
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:toolbar];
    
    // Toolbar Items
    actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareButtonHit:)];
    previousButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIBarButtonItemArrowLeft.png"] style:UIBarButtonItemStylePlain target:self action:@selector(gotoPreviousPage)];
    nextButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIBarButtonItemArrowRight.png"] style:UIBarButtonItemStylePlain target:self action:@selector(gotoNextPage)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *fixedCenter = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedCenter.width = 80.0f;
    UIBarButtonItem *fixedLeft = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedLeft.width = 80.0f;
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    if (photos.count > 1) {
        
        [items addObjectsFromArray:[NSArray arrayWithObjects:flex, previousButton, fixedCenter, nextButton, flex ,nil]];   
    }
    
    if (self.canEditPhotos) {
        
        [items addObject:actionButton];
        
        if (photos.count > 1) {
            [items insertObject:fixedLeft atIndex:0];
        } else {
            [items insertObject:flex atIndex:0];
        }
    }
    
    [toolbar setItems:items];
    
    caption = [[UIView alloc] initWithFrame:[self frameForCaptionAtOrientation:self.interfaceOrientation]];
    caption.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    captionLabel = [[UILabel alloc] initWithFrame:[self frameForCaptionLabelAtOrientation:self.interfaceOrientation]];
    captionLabel.backgroundColor = [UIColor clearColor];
    captionLabel.textAlignment = UITextAlignmentCenter;
    captionLabel.textColor = [UIColor whiteColor];
    captionLabel.font = [UIFont systemFontOfSize:14];
    captionLabel.shadowOffset = CGSizeMake(1.0f, 1.0f);
    captionLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    captionLabel.text = @"";
    captionLabel.numberOfLines = 2;
    [caption addSubview:captionLabel];
    [self.view addSubview:caption];
    
	// Super
    [super viewDidLoad];
	
}

- (void)viewWillAppear:(BOOL)animated {
    
    // Super
	[super viewWillAppear:animated];
	
    if(!_storedOldStyles) {
		_oldStatusBarSyle = [UIApplication sharedApplication].statusBarStyle;
        
		_oldNavBarTintColor = self.navigationController.navigationBar.tintColor;
		_oldNavBarStyle = self.navigationController.navigationBar.barStyle;
		_oldNavBarTranslucent = self.navigationController.navigationBar.translucent;
		
		_oldToolBarTintColor = self.navigationController.toolbar.tintColor;
		_oldToolBarStyle = self.navigationController.toolbar.barStyle;
		_oldToolBarTranslucent = self.navigationController.toolbar.translucent;
		_oldToolBarHidden = [self.navigationController isToolbarHidden];
		
		_storedOldStyles = YES;
	}
    
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackTranslucent;
    
    // Layout
	[self performLayout];
    
	// Navigation
	[self updateNavigation];
	[self hideControlsAfterDelay];
	[self didStartViewingPageAtIndex:currentPageIndex]; // initial
	
}

- (void)viewDidAppear:(BOOL)animated {
    
    // Layout
	[self performLayout];
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    self.navigationController.navigationBar.barStyle = _oldNavBarStyle;
	self.navigationController.navigationBar.tintColor = _oldNavBarTintColor;
	self.navigationController.navigationBar.translucent = _oldNavBarTranslucent;
	
	[[UIApplication sharedApplication] setStatusBarStyle:_oldStatusBarSyle animated:YES];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
    
	if(!_oldToolBarHidden) {
		
		if ([self.navigationController isToolbarHidden]) {
			[self.navigationController setToolbarHidden:NO animated:YES];
		}
		
		self.navigationController.toolbar.barStyle = _oldNavBarStyle;
		self.navigationController.toolbar.tintColor = _oldNavBarTintColor;
		self.navigationController.toolbar.translucent = _oldNavBarTranslucent;
		
	} else {
		
		[self.navigationController setToolbarHidden:_oldToolBarHidden animated:YES];
		
	}
    
    if (self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }
    
	// Super
	[super viewWillDisappear:animated];
    
	// Cancel any hiding timers
	[self cancelControlHiding];
	
}

#pragma mark -
#pragma mark Layout

// Layout subviews
- (void)performLayout {
	
	// Flag
	performingLayout = YES;
	
	// Toolbar
	toolbar.frame = [self frameForToolbarAtOrientation:self.interfaceOrientation];
	caption.frame = [self frameForCaptionAtOrientation:self.interfaceOrientation];
    captionLabel.frame = [self frameForCaptionLabelAtOrientation:self.interfaceOrientation];
    
    
	// Remember index
	NSUInteger indexPriorToLayout = currentPageIndex;
	
	// Get paging scroll view frame to determine if anything needs changing
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
	// Frame needs changing
	pagingScrollView.frame = pagingScrollViewFrame;
	
	// Recalculate contentSize based on current orientation
	pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	
	// Adjust frames and configuration of each visible page
	for (ZoomingScrollView *page in visiblePages) {
		page.frame = [self frameForPageAtIndex:page.index];
		[page setMaxMinZoomScalesForCurrentBounds];
	}
	
	// Adjust contentOffset to preserve page location based on values collected prior to location
	pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
	
	// Reset
	currentPageIndex = indexPriorToLayout;
	performingLayout = NO;
}

#pragma mark -
#pragma mark Photos

// Get image if it has been loaded, otherwise nil
- (UIImage *)imageAtIndex:(NSUInteger)index {
	if (photos && index < photos.count) {
        
		// Get image or obtain in background
		MWPhoto *photo = [photos objectAtIndex:index];
		if ([photo isImageAvailable]) {
			return [photo image];
        } else if ([photo loadingImageAvailable]) {
            [photo obtainImageInBackgroundAndNotify:self];
            return [photo loadingImage];
        } else {
			[photo obtainImageInBackgroundAndNotify:self];
		}
		
	}
	return nil;
}

- (NSString *)captionAtIndex:(NSUInteger)index {
	if (photos && index < photos.count) {
        
		// Get image or obtain in background
		MWPhoto *photo = [photos objectAtIndex:index];
        return [photo caption];
	}
	return nil;
}

#pragma mark -
#pragma mark MWPhotoDelegate

- (void)photoDidFinishLoading:(MWPhoto *)photo {
	NSUInteger index = [photos indexOfObject:photo];
    
    if (actionButton)
    {
		if (currentPageIndex == [photos indexOfObject:photo]) {
			actionButton.enabled = YES;
		}
	}
    
	if (index != NSNotFound) {
		if ([self isDisplayingPageForIndex:index]) {
			
			// Tell page to display image again
			ZoomingScrollView *page = [self pageDisplayedAtIndex:index];
			if (page) [page displayImage];
			
		}
	}
}

- (void)photoDidFailToLoad:(MWPhoto *)photo {
	NSUInteger index = [photos indexOfObject:photo];
    
    if (actionButton)
    {
		if (currentPageIndex == [photos indexOfObject:photo]) {
			actionButton.enabled = NO;
		}
	}
    
	if (index != NSNotFound) {
		if ([self isDisplayingPageForIndex:index]) {
			
			// Tell page it failed
			ZoomingScrollView *page = [self pageDisplayedAtIndex:index];
			if (page) [page displayImageFailure];
			
		}
	}
}

#pragma mark -
#pragma mark Paging

- (void)tilePages {
	
	// Calculate which pages should be visible
	// Ignore padding as paging bounces encroach on that
	// and lead to false page loads
	CGRect visibleBounds = pagingScrollView.bounds;
	int iFirstIndex = (int)floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
	int iLastIndex  = (int)floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > photos.count - 1) iFirstIndex = photos.count - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > photos.count - 1) iLastIndex = photos.count - 1;
	
	// Recycle no longer needed pages
	for (ZoomingScrollView *page in visiblePages) {
		if (page.index < (NSUInteger)iFirstIndex || page.index > (NSUInteger)iLastIndex) {
			[recycledPages addObject:page];
			/*NSLog(@"Removed page at index %i", page.index);*/
			page.index = NSNotFound; // empty
			[page removeFromSuperview];
		}
	}
	[visiblePages minusSet:recycledPages];
	
	// Add missing pages
	for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
		if (![self isDisplayingPageForIndex:index]) {
			ZoomingScrollView *page = [self dequeueRecycledPage];
			if (!page) {
				page = [[ZoomingScrollView alloc] init];
				page.photoBrowser = self;
			}
			[self configurePage:page forIndex:index];
			[visiblePages addObject:page];
			[pagingScrollView addSubview:page];
			/*NSLog(@"Added page at index %i", page.index);*/
		}
	}
	
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
	for (ZoomingScrollView *page in visiblePages)
		if (page.index == index) return YES;
	return NO;
}

- (ZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
	ZoomingScrollView *thePage = nil;
	for (ZoomingScrollView *page in visiblePages) {
		if (page.index == index) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (void)configurePage:(ZoomingScrollView *)page forIndex:(NSUInteger)index {
	page.frame = [self frameForPageAtIndex:index];
	page.index = index;
}

- (ZoomingScrollView *)dequeueRecycledPage {
	ZoomingScrollView *page = [recycledPages anyObject];
	if (page) {
        // ARC
//		[[page retain] autorelease];
		[recycledPages removeObject:page];
	}
	return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    NSUInteger i;
    if (index > 0) {
        
        // Release anything < index - 1
        for (i = 0; i < index-1; i++) { [(MWPhoto *)[photos objectAtIndex:i] releasePhoto]; /*NSLog(@"Release image at index %i", i);*/ }
        
        // Preload index - 1
        i = index - 1; 
        if (i < photos.count) { [(MWPhoto *)[photos objectAtIndex:i] obtainImageInBackgroundAndNotify:self]; /*NSLog(@"Pre-loading image at index %i", i);*/ }
        
    }
    if (index < photos.count - 1) {
        
        // Release anything > index + 1
        for (i = index + 2; i < photos.count; i++) { [(MWPhoto *)[photos objectAtIndex:i] releasePhoto]; /*NSLog(@"Release image at index %i", i);*/ }
        
        // Preload index + 1
        i = index + 1; 
        if (i < photos.count) { [(MWPhoto *)[photos objectAtIndex:i] obtainImageInBackgroundAndNotify:self]; /*NSLog(@"Pre-loading image at index %i", i);*/ }
        
    }
}

#pragma mark -
#pragma mark Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.navigationController.view.bounds;// [[UIScreen mainScreen] bounds];
    
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * photos.count, bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
	CGFloat pageWidth = pagingScrollView.bounds.size.width;
	CGFloat newOffset = index * pageWidth;
	return CGPointMake(newOffset, 0);
}

- (CGRect)frameForNavigationBarAtOrientation:(UIInterfaceOrientation)orientation {

    CGFloat height;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        height = 44;
    } else {
        height = UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32;
    }
	
	return CGRectMake(0, 20, self.view.bounds.size.width, height);
}

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    
    CGFloat height;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        height = 44;
    } else {
        height = UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32;
    }
    
    return CGRectMake(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height);
}

- (CGRect)frameForCaptionAtOrientation:(UIInterfaceOrientation)orientation {
    
	CGFloat height = 44;
    CGRect toolbarFrame = [self frameForToolbarAtOrientation:orientation];
    
	return CGRectMake(0, CGRectGetMinY(toolbarFrame)-height, self.view.bounds.size.width, height);
}

- (CGRect)frameForCaptionLabelAtOrientation:(UIInterfaceOrientation)orientation {
	
    CGFloat verticalPadding = 5;
    CGFloat horizontalPadding = 10;
    
    CGFloat height = [self frameForCaptionAtOrientation:orientation].size.height;
    
	return CGRectMake(10, 5, self.view.bounds.size.width-horizontalPadding*2, height-verticalPadding*2);
}

#pragma mark -
#pragma mark UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	
	if (performingLayout || rotating) return;
	
	// Tile pages
	[self tilePages];
	
	// Calculate current page
	CGRect visibleBounds = pagingScrollView.bounds;
	int index = (int)(floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
	if (index > photos.count - 1) index = photos.count - 1;
	NSUInteger previousCurrentPage = currentPageIndex;
	currentPageIndex = index;
	if (currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
    }
	
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	// Hide controls when dragging begins
	[self setControlsHidden:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	// Update nav when page changes
	[self updateNavigation];
}

#pragma mark -
#pragma mark Navigation

- (void)updateNavigation {
    
	// Title
	if (photos.count > 1) {
		self.title = [NSString stringWithFormat:@"%i of %i", currentPageIndex+1, photos.count];		
	} else {
		self.title = nil;
	}
	
	// Buttons
	previousButton.enabled = (currentPageIndex > 0);
	nextButton.enabled = (currentPageIndex < photos.count-1);
    
    if (actionButton)
    {
		if ([self imageAtIndex:currentPageIndex]) {
			actionButton.enabled = YES;
		} else {
			actionButton.enabled = NO;
		}
	}
    
    NSString *photoCaption = [self captionAtIndex:currentPageIndex];
    
    if ((photoCaption == nil) || ([photoCaption isEqualToString:@""])) {
        [caption setHidden:YES];
    } else {
        [caption setHidden:NO];
    }
    
    captionLabel.text = [self captionAtIndex:currentPageIndex];
	
}

- (void)jumpToPageAtIndex:(NSUInteger)index {
	
	// Change page
	if (index < photos.count) {
		CGRect pageFrame = [self frameForPageAtIndex:index];
		pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);
		[self updateNavigation];
	}
	
	// Update timer to give more time
	[self hideControlsAfterDelay];
	
}

- (void)gotoPreviousPage { [self jumpToPageAtIndex:currentPageIndex-1]; }
- (void)gotoNextPage { [self jumpToPageAtIndex:currentPageIndex+1]; }

#pragma mark -
#pragma mark Control Hiding / Showing

- (void)setControlsHidden:(BOOL)hidden {
    
    // Get status bar height if visible
    CGFloat statusBarHeight = 0;
    if (![UIApplication sharedApplication].statusBarHidden) {
        CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
        statusBarHeight = MIN(statusBarFrame.size.height, statusBarFrame.size.width);
    }
    
    // Status Bar
    if ([UIApplication instancesRespondToSelector:@selector(setStatusBarHidden:withAnimation:)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:UIStatusBarAnimationFade];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:hidden animated:YES];
    }
    
    // Get status bar height if visible
    if (![UIApplication sharedApplication].statusBarHidden) {
        CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
        statusBarHeight = MIN(statusBarFrame.size.height, statusBarFrame.size.width);
    }
    
    // Set navigation bar frame
    CGRect navBarFrame = self.navigationController.navigationBar.frame;
    navBarFrame.origin.y = statusBarHeight;
    self.navigationController.navigationBar.frame = navBarFrame;

	// Bars
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.35];
	[self.navigationController.navigationBar setAlpha:hidden ? 0 : 1];
	[toolbar setAlpha:hidden ? 0 : 1];
    [caption setAlpha:hidden ? 0 : 1];
    
	[UIView commitAnimations];
	
    controlsHidden = hidden;
    
	// Control hiding timer
	// Will cancel existing timer but only begin hiding if
	// they are visible
	[self hideControlsAfterDelay];
	
}

- (void)cancelControlHiding {
	// If a timer exists then cancel and release
	if (controlVisibilityTimer) {
		[controlVisibilityTimer invalidate];
		controlVisibilityTimer = nil;
	}
}

// Enable/disable control visiblity timer
- (void)hideControlsAfterDelay {
	[self cancelControlHiding];
	if (!controlsHidden) {
		controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
	}
}

- (void)hideControls { [self setControlsHidden:YES]; }
- (void)toggleControls { [self setControlsHidden:!controlsHidden]; }

#pragma mark -
#pragma mark Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
	// Remember page index before rotation
	pageIndexBeforeRotation = currentPageIndex;
	rotating = YES;
	
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	
	// Perform layout
	currentPageIndex = pageIndexBeforeRotation;
	[self performLayout];
	
	// Delay control holding
	[self hideControlsAfterDelay];	
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	rotating = NO;
}

#pragma mark -
#pragma mark Properties

- (void)setInitialPageIndex:(NSUInteger)index {
	if (![self isViewLoaded]) {
		if (index >= photos.count) {
			currentPageIndex = 0;
		} else {
			currentPageIndex = index;
		}
	}
}

#pragma mark -
#pragma mark Actions

- (void)doneSavingImage{
	NSLog(@"done saving image");
}

- (void)savePhoto{
	
	UIImageWriteToSavedPhotosAlbum([self imageAtIndex:currentPageIndex], nil, nil, nil);
}

- (void)copyPhoto {
    
    [[UIPasteboard generalPasteboard] setData:UIImagePNGRepresentation([self imageAtIndex:currentPageIndex]) forPasteboardType:@"public.png"];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Photo Copied" message:@"The photo has been succesfully copied to your clipboard." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
}

- (void)emailPhoto{
	
	MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
	[mailViewController setSubject:@"Shared Photo"];
	[mailViewController addAttachmentData:[NSData dataWithData:UIImagePNGRepresentation([self imageAtIndex:currentPageIndex])] mimeType:@"png" fileName:@"Photo.png"];
	mailViewController.mailComposeDelegate = self;
	
	if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad) {
		mailViewController.modalPresentationStyle = UIModalPresentationPageSheet;
	}
	
	[self presentModalViewController:mailViewController animated:YES];
}

- (void)confirmDeleteGallery
{
    NSString* deleteWarning = [NSString stringWithFormat:@"Are you sure you want to delete this gallery? This will delete all %i photos in this gallery. This cannot be undone.", photos.count, [self.navigationItem.title lowercaseString]];
    
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                    message:deleteWarning
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
}

- (void)confirmDeletePhoto
{
    NSString* deleteWarning = [NSString stringWithFormat:@"Are you sure you want to delete this photo? This cannot be undone.",[self.navigationItem.title lowercaseString]];
    
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                    message:deleteWarning
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
}

- (void)deletePhoto {
    if ([self.delegate respondsToSelector:@selector(deletePhoto:)]) {
        [self.delegate deletePhoto:[photos objectAtIndex:currentPageIndex]];
    }
}

//- (void)deleteGallery {
//    if ([self.delegate respondsToSelector:@selector(deleteGallery:)]) {
//        [self.delegate deleteGallery:photos];
//    }    
//}

- (void)editPhoto {
    if ([self.delegate respondsToSelector:@selector(editPhoto:)]) {
        [self.delegate editPhoto:[photos objectAtIndex:currentPageIndex]];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [self deletePhoto];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error{
	
	[self dismissModalViewControllerAnimated:YES];
	
	NSString *mailError = nil;
	
	switch (result) {
		case MFMailComposeResultSent: ; break;
		case MFMailComposeResultFailed: mailError = @"Failed sending media, please try again...";
			break;
		default:
			break;
	}
	
	if (mailError != nil) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:mailError delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
	
}

- (void)editButtonHit:(id)sender {
    
    _editActionSheet = [[UIActionSheet alloc] initWithTitle:@"" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:@"Edit", nil];
    
    _editActionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	_editActionSheet.delegate = self;
	
	[_editActionSheet showFromToolbar:toolbar];
}

- (void)shareButtonHit:(id)sender {
	
    if ([self.delegate canSharePhoto:[photos objectAtIndex:currentPageIndex]]) {
        
        [self showShareActionSheet];
    }
}

#pragma mark -
#pragma mark UIActionSheet Methods

- (void)showShareActionSheet {
    
    BOOL canSendMail = [MFMailComposeViewController canSendMail];
#if __IPHONE_5_0
    BOOL canTweet = [TWTweetComposeViewController canSendTweet];
#endif
    
	if (canSendMail && canTweet) {
        _shareActionSheet = [[UIActionSheet alloc] initWithTitle:@"Share Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:copyLinkButtonName, facebookButtonName, twitterButtonName, emailButtonName, nil];
	} else if (canTweet && !canSendMail) {
        _shareActionSheet = [[UIActionSheet alloc] initWithTitle:@"Share Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:copyLinkButtonName, facebookButtonName, twitterButtonName, nil];
	} else if (!canTweet && canSendMail) {
        _shareActionSheet = [[UIActionSheet alloc] initWithTitle:@"Share Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:copyLinkButtonName,  facebookButtonName, emailButtonName, nil];
    } else if (!canTweet && !canSendMail) {
        _shareActionSheet = [[UIActionSheet alloc] initWithTitle:@"Share Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:copyLinkButtonName, facebookButtonName, nil];
    }
	
	_shareActionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	[_shareActionSheet showFromToolbar:toolbar];
}

- (void)showEditActionSheet {
    
    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
	
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
    MWPhoto *currentPhoto = [photos objectAtIndex:currentPageIndex];
    
    if (actionSheet == _editActionSheet) {
        
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self confirmDeletePhoto];
        } else if (buttonIndex == actionSheet.firstOtherButtonIndex) {
            [self editPhoto];	
        }
        
    } else if (actionSheet == _shareActionSheet) {
        
        NSLog(@"Share button tapped with title: %@", title);
        
        if ([title isEqualToString:copyLinkButtonName]) {
            [self.delegate copyLinkToPhoto:currentPhoto];
        } else if ([title isEqualToString:facebookButtonName]) {
            [self.delegate facebookPhoto:currentPhoto];
        } else if ([title isEqualToString:emailButtonName]) {
            [self.delegate emailPhoto:currentPhoto];
        } else if ([title isEqualToString:twitterButtonName]) {
            [self.delegate tweetPhoto:currentPhoto];
        }
    }
}


@end
