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
	
    NSString *caption;
    NSNumber *ID;
    
	// Flags
	BOOL workingInBackground;
	
}

@property (retain) UIImage *photoImage;

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
- (UIImage *)image;
- (UIImage *)obtainImage;
- (void)obtainImageInBackgroundAndNotify:(id <MWPhotoDelegate>)notifyDelegate;
- (void)releasePhoto;

@property (copy) NSString* caption;
@property (nonatomic, retain) NSNumber *ID;

@end
