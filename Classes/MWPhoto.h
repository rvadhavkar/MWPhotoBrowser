//
//  MWPhoto.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>

// Class
@class MWPhoto;

// Delegate
@protocol MWPhotoDelegate <NSObject>
- (void)photoDidFinishLoading:(MWPhoto *)photo;
- (void)photoDidFailToLoad:(MWPhoto *)photo;
@end

// MWPhoto
@interface MWPhoto : NSObject {
	
	// Image
	NSString *photoPath;
	NSURL *photoURL;
    
	UIImage *photoImage;
    UIImage *loadingImage;
	
    NSString *caption;
    NSNumber *ID;
    
	// Flags
	BOOL workingInBackground;
	
}

@property (nonatomic, strong) UIImage *photoImage;
@property (nonatomic, strong) UIImage *loadingImage;

// Class
+ (MWPhoto *)photoWithImage:(UIImage *)image;
+ (MWPhoto *)photoWithFilePath:(NSString *)path;
+ (MWPhoto *)photoWithURL:(NSURL *)url;

// Init
- (id)initWithImage:(UIImage *)image;
- (id)initWithFilePath:(NSString *)path;
- (id)initWithURL:(NSURL *)url;

// Public methods
- (BOOL)isImageAvailable;
- (BOOL)loadingImageAvailable;
- (UIImage *)image;
- (UIImage *)obtainImage;
- (void)obtainImageInBackgroundAndNotify:(id <MWPhotoDelegate>)notifyDelegate;
- (void)releasePhoto;

@property (copy) NSString* caption;
@property (nonatomic, strong) NSNumber *ID;

@end
