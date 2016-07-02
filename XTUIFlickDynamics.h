//
//  FlickDynamics.h
//  (c) 2009 Dave Peck <davepeck [at] davepeck [dot] org> 
//  Let me know if you have any questions/improvements.
//
//  This code mimics the scroll/flick dynamics of the iPhone UIScrollView.
//  What's cool about this code is that it is entirely independent of any iPhone
//  UI, so you can use it do provide scroll/flick behavior on your custom views.
//
//  This code is released under the BSD license. If you use my code in your product,
//  please put my name somewhere in the credits.
//

#import <Foundation/Foundation.h>

typedef struct TouchInfo {
	double x;
	double y;
	NSTimeInterval time; // all relative to the 1970 GMT epoch
} TouchInfo;

@interface FlickDynamics : NSObject {	
	TouchInfo *history;
	NSUInteger historyCount;
	NSUInteger historyHead;

	double currentScrollLeft;
	double currentScrollTop;
	
	double animationRate;
	
	double viewportWidth;
	double viewportHeight;	
	
	double scrollBoundsLeft;
	double scrollBoundsTop;
	double scrollBoundsRight;
	double scrollBoundsBottom;
	
	double motionX;
	double motionY;
	
	double motionDamp;
	double motionMultiplier;
	double motionMinimum;
	double flickThresholdX;
	double flickThresholdY;	
}

+(id)flickDynamicsWithViewportWidth:(double)viewportWidth viewportHeight:(double)viewportHeight scrollBoundsLeft:(double)scrollBoundsLeft scrollBoundsTop:(double)scrollBoundsTop scrollBoundsRight:(double)scrollBoundsRight scrollBoundsBottom:(double)scrollBoundsBottom animationRate:(NSTimeInterval)animationRate;
+(id)flickDynamicsWithViewportWidth:(double)viewportWidth viewportHeight:(double)viewportHeight scrollBoundsLeft:(double)scrollBoundsLeft scrollBoundsTop:(double)scrollBoundsTop scrollBoundsRight:(double)scrollBoundsRight scrollBoundsBottom:(double)scrollBoundsBottom;

@property (readwrite) double currentScrollLeft;
@property (readwrite) double currentScrollTop;

-(void)startTouchAtX:(double)x y:(double)y;
-(void)moveTouchAtX:(double)x y:(double)y;
-(void)endTouchAtX:(double)x y:(double)y;
-(void)animate; /* call this with whatever periodicity you specified on initialization */
-(void)stopMotion;

@end
