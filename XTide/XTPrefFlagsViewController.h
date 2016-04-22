//
//  XTPrefFlagsViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/21/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTPrefFlagsViewController : NSViewController

@property (readwrite, assign) BOOL phaseOfMoon;
@property (readwrite, assign) BOOL sunrise;
@property (readwrite, assign) BOOL sunset;
@property (readwrite, assign) BOOL moonrise;
@property (readwrite, assign) BOOL moonset;

@end
