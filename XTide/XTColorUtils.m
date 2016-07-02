//
//  XTColorUtils.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

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

#if TARGET_OS_IPHONE

// This would be a category extension but we only need it here.
static UIColor *
ColorForHex(NSUInteger hex)
{
    NSUInteger red = (hex & 0xFF0000) >> 16;
    NSUInteger green = (hex & 0x00FF00) >> 8;
    NSUInteger blue = (hex & 0x0000FF);
    return [UIColor colorWithRed:red / 255.0
                           green:green / 255.0
                            blue:blue / 255.0
                           alpha:1.0];
}

static UIColor *
ColorFromRGBString(NSString *colorName)
{
  NSInteger r, g, b;
  r = g = b = 0;
  const char *fmt1 = "rgb:%" SCNx8 "/%" SCNx8 "/%" SCNx8;

  if (sscanf ([colorName UTF8String], fmt1, &r, &g, &b) == 3) {
      return [UIColor colorWithRed:r / 255.0
                             green:g / 255.0
                              blue:b / 255.0
                             alpha:1.0];
  }
  return nil;
}

// Dearchive a color object or name, using xtide's names.
UIColor *
ColorForKey(NSString *key)
{
    // Colors from http://www.colourlovers.com/palette/1838545/Evening_Tide
    UIColor *skyBlue = ColorForHex(0x1EB2F7);
    UIColor *deepSkyBlue = ColorForHex(0x041233);
    UIColor *seaGreen = ColorForHex(0x4CFCB3);
    UIColor *darkSeaGreen = ColorForHex(0x28A9E);

    // Map colors used in libxtide::Settings.
    NSDictionary *colorMap =
        @{@"red"        : [UIColor redColor],
          @"blue"        : [UIColor blueColor],
          @"white"       : [UIColor whiteColor],
          @"black"       : [UIColor blackColor],
          @"green"       : [UIColor greenColor],
          @"gray80"      : [UIColor colorWithWhite:0.80 alpha:1.0],
          @"yellow"      : [UIColor yellowColor],
          @"skyblue"     : skyBlue,
          @"seagreen"    : seaGreen,
          @"deepskyblue" : deepSkyBlue,
          @"darkseagreen": darkSeaGreen,
         };
	NSData *colorAsData = [[NSUserDefaults standardUserDefaults]
						objectForKey:key];
    if (!colorAsData) {
        return nil;
    }
    if ([colorAsData isKindOfClass:[NSString class]]) {
        NSString *colorAsString = (NSString *)colorAsData;
        UIColor *color = [colorMap objectForKey:[colorAsString lowercaseString]];
        if (!color) {
            color = ColorFromRGBString(colorAsString);
        }
        if (!color) {
            NSLog(@"ColorForKey: No colorMap value %@ %@", key, colorAsString);
            return [UIColor redColor];
        }
        return color;
    }
    if (![colorAsData isKindOfClass:[NSData class]]) {
        NSLog(@"ColorForKey: Unexpected type %@ %@", key, colorAsData);
        return [UIColor redColor];
    }
    UIColor *color = [NSKeyedUnarchiver unarchiveObjectWithData:colorAsData];
   
	return color;
}

#else
// This would be a category extension but we only need it here.
static NSColor *
ColorForHex(NSUInteger hex)
{
    NSUInteger red = (hex & 0xFF0000) >> 16;
    NSUInteger green = (hex & 0x00FF00) >> 8;
    NSUInteger blue = (hex & 0x0000FF);
    return [NSColor colorWithCalibratedRed:red / 255.0
                                     green:green / 255.0
                                      blue:blue / 255.0
                                     alpha:1.0];
}

static NSColor *
ColorFromRGBString(NSString *colorName)
{
  NSInteger r, g, b;
  r = g = b = 0;
  const char *fmt1 = "rgb:%" SCNx8 "/%" SCNx8 "/%" SCNx8;

  if (sscanf ([colorName UTF8String], fmt1, &r, &g, &b) == 3) {
      return [NSColor colorWithCalibratedRed:r / 255.0
                                       green:g / 255.0
                                        blue:b / 255.0
                                       alpha:1.0];
  }
  return nil;
}


// Dearchive a color object or name, using xtide's names.
NSColor *
ColorForKey(NSString *key)
{
    // Colors from http://www.colourlovers.com/palette/1838545/Evening_Tide
    NSColor *skyBlue = ColorForHex(0x1EB2F7);
    NSColor *deepSkyBlue = ColorForHex(0x041233);
    NSColor *seaGreen = ColorForHex(0x4CFCB3);
    NSColor *darkSeaGreen = ColorForHex(0x28A9E);

    // Map colors used in libxtide::Settings.
    NSDictionary *colorMap =
        @{@"red"        : [NSColor redColor],
          @"blue"        : [NSColor blueColor],
          @"white"       : [NSColor whiteColor],
          @"black"       : [NSColor blackColor],
          @"green"       : [NSColor greenColor],
          @"gray80"      : [NSColor colorWithWhite:0.80 alpha:1.0],
          @"yellow"      : [NSColor yellowColor],
          @"skyblue"     : skyBlue,
          @"seagreen"    : seaGreen,
          @"deepskyblue" : deepSkyBlue,
          @"darkseagreen": darkSeaGreen,
         };
	NSData *colorAsData = [[NSUserDefaults standardUserDefaults]
						objectForKey:key];
    if (!colorAsData) {
        return nil;
    }
    if ([colorAsData isKindOfClass:[NSString class]]) {
        NSString *colorAsString = (NSString *)colorAsData;
        NSColor *color = [colorMap objectForKey:[colorAsString lowercaseString]];
        if (!color) {
            color = ColorFromRGBString(colorAsString);
        }
        if (!color) {
            NSLog(@"ColorForKey: No colorMap value %@ %@", key, colorAsString);
            return [NSColor redColor];
        }
        return color;
    }
    if (![colorAsData isKindOfClass:[NSData class]]) {
        NSLog(@"ColorForKey: Unexpected type %@ %@", key, colorAsData);
        return [NSColor redColor];
    }
    NSColor *color = [NSKeyedUnarchiver unarchiveObjectWithData:colorAsData];
   
	return color;
}
#endif
