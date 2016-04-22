//
//  XTColorUtils.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTColorUtils.h"


NSString *XTide_ColorKeys[colorindexmax] = {
	@"XTide_daycolor",	// dc
	@"XTide_nightcolor",	// nc
	@"XTide_ebbcolor",	// ec
	@"XTide_floodcolor",	// fc
	@"XTide_markcolor",	// mc
	@"XTide_datumcolor",	// Dc
	@"XTide_mslcolor",	// Mc
	@"XTide_refcolor",
	@"XTide_subcolor",
	@"XTide_selcolor",
	@"XTide_fgcolor"	// fg
};


// Dearchive a color object or name, using xtide's names.
NSColor *
ColorForKey(NSString *key)
{
    NSColor *skyBlue = [NSColor colorWithDeviceRed:0.0
                                             green:0.5
                                              blue:1.0
                                             alpha:1.0];
    NSColor *deepSkyBlue = [NSColor colorWithDeviceRed:0.0
                                                 green:0.25
                                                  blue:0.5
                                                 alpha:1.0];
    NSColor *seaGreen = [NSColor colorWithDeviceRed:0.0
                                              green:1.0
                                               blue:0.5
                                              alpha:1.0];
    // Map colors used in libxtide::Settings.
    NSDictionary *colorMap =
        @{@"red"        : [NSColor redColor],
          @"blue"       : [NSColor blueColor],
          @"white"      : [NSColor whiteColor],
          @"black"      : [NSColor blackColor],
          @"gray80"     : [NSColor lightGrayColor], // 2/3 instead of 80%d
          @"yellow"     : [NSColor yellowColor],
          @"skyblue"    : skyBlue,
          @"seagreen"   : seaGreen,
          @"deepskyblue": deepSkyBlue,
         };
	NSData *colorAsData = [[NSUserDefaults standardUserDefaults]
						objectForKey:key];
    if ([colorAsData isKindOfClass:[NSString class]]) {
        NSColor *color = [colorMap objectForKey:[(NSString *)colorAsData lowercaseString]];
        if (!color) {
            NSLog(@"ColorForKey: No colorMap value %@ %@", key, colorAsData);
            return [NSColor redColor];
        }
        return color;
    }
    if (![colorAsData isKindOfClass:[NSData class]]) {
        NSLog(@"ColorForKey: Unexpected type %@ %@", key, colorAsData);
        return [NSColor redColor];
    }
    NSColor *color = [NSKeyedUnarchiver unarchiveObjectWithData:colorAsData];
   
	return [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
}
