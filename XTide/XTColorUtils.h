//
//  XTColorUtils.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef XTColorUtils_h
#define XTColorUtils_h

#ifdef __cplusplus
extern "C" {
#endif

#import "TargetConditionals.h" 
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#define colorbase	1001	// Add to get tag id
#define daycolor	0	// Daytime background	// dc
#define nightcolor	1	// Nighttime background	// nc
#define ebbcolor	2	// Outgoing tide		// ec
#define floodcolor	3	// Incoming tide		// fc
#define markcolor	4	// mark line			// mc
#define datumcolor	5	// datum line			// Dc
#define	mslcolor	6	// Mean Astronomical Tide line 	// Mc

#define currentdotcolor	7	// Current station
#define tidedotcolor	8	// Tide station
#define selcolor	9	// Selected station

#define fgcolor		10	// Selected station		// fg
#define colorindexmax (fgcolor+1)

// Colors
extern NSString *XTide_ColorKeys[colorindexmax];

#if TARGET_OS_IPHONE
UIColor *ColorForKey(NSString *key);
#else
NSColor *ColorForKey(NSString *key);
#endif

#ifdef __cplusplus
}
#endif

#endif /* XTColorUtils_h */
