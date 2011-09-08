//
//  MWPhotoBrowser.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#import "MWPhoto.h"

// Delegate
@protocol MWPhotoBrowserDelegate <NSObject>
- (void)deletePhoto:(MWPhoto*)photo;
- (void)editPhoto:(MWPhoto*)photo;
@end

@class ZoomingScrollView;

@interface MWPhotoBrowser : UIViewController <UIScrollViewDelegate, MWPhotoDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate> {
	
    id <MWPhotoBrowserDelegate> delegate;
    
	// Photos
	NSArray *photos;
	
	// Views
	UIScrollView *pagingScrollView;
	
	// Paging
	NSMutableSet *visiblePages, *recycledPages;
	NSUInteger currentPageIndex;
	NSUInteger pageIndexBeforeRotation;
	
	// Navigation & controls
	UIToolbar *toolbar;
    UIView *caption;
    UILabel *captionLabel;
    
	NSTimer *controlVisibilityTimer;
	UIBarButtonItem *previousButton, *nextButton, *actionButton;

    BOOL _storedOldStyles;
	UIStatusBarStyle _oldStatusBarSyle;
	UIBarStyle _oldNavBarStyle;
	BOOL _oldNavBarTranslucent;
	UIColor* _oldNavBarTintColor;	
	UIBarStyle _oldToolBarStyle;
	BOOL _oldToolBarTranslucent;
	UIColor* _oldToolBarTintColor;	
	BOOL _oldToolBarHidden;
    
    // Misc
	BOOL performingLayout;
	BOOL rotating;
    
    BOOL canEditPhotos;
	
}

// Init
- (id)initWithPhotos:(NSArray *)photosArray;

// Photos
- (UIImage *)imageAtIndex:(NSUInteger)index;
- (NSString *)captionAtIndex:(NSUInteger)index;

// Layout
- (void)performLayout;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (ZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index;
- (ZoomingScrollView *)dequeueRecycledPage;
- (void)configurePage:(ZoomingScrollView *)page forIndex:(NSUInteger)index;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;
- (CGRect)frameForNavigationBarAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionLabelAtOrientation:(UIInterfaceOrientation)orientation;

// Navigation
- (void)updateNavigation;
- (void)jumpToPageAtIndex:(NSUInteger)index;
- (void)gotoPreviousPage;
- (void)gotoNextPage;

// Controls
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
- (void)setControlsHidden:(BOOL)hidden;
- (void)toggleControls;

// Properties
- (void)setInitialPageIndex:(NSUInteger)index;

@property (nonatomic, assign) id <MWPhotoBrowserDelegate> delegate;
@property (nonatomic, assign) BOOL canEditPhotos;

@end

