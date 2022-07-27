//
//  XTColorUtils.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTColorUtils.h"
#import "XTSettings.h"


#if TARGET_OS_IPHONE
#define SEA_GREEN 0x4CFCB3
#define DARK_SEA_GREEN 0x408A50
#else
// These colors look close to the iPhone colors.
// Don't lose them; they're needed for the watch background generation.
#define SEA_GREEN 0x2DE09D
#define DARK_SEA_GREEN 0x266F3E
#endif

#define SKY_BLUE 0x10385A
#define DEEP_SKY_BLUE 0x041233

NSString *XTide_ColorKeys[colorindexmax] = {
	@"XTide_daycolor",	// dc
	@"XTide_nightcolor",	// nc
	@"XTide_ebbcolor",	// ec
	@"XTide_floodcolor",	// fc
	@"XTide_markcolor",	// mc
	@"XTide_datumcolor",	// Dc
	@"XTide_mslcolor",	// Mc
	@"XTide_currentdotcolor",
	@"XTide_tidedotcolor",
	@"XTide_selcolor",
	@"XTide_foreground"	// fg
};

// This would be a category extension but we only need it here.
static COLOR_CLASS *
ColorForHex(NSUInteger hex)
{
    NSUInteger red = (hex & 0xFF0000) >> 16;
    NSUInteger green = (hex & 0x00FF00) >> 8;
    NSUInteger blue = (hex & 0x0000FF);
    return [COLOR_CLASS colorWithRed:red / 255.0
                               green:green / 255.0
                                blue:blue / 255.0
                               alpha:1.0];
}

static COLOR_CLASS *
ColorFromRGBString(NSString *colorName)
{
    NSInteger r, g, b, w;
    r = g = b = w = 0;
    const char *fmt1 = "rgb:%" SCNx8 "/%" SCNx8 "/%" SCNx8;
    const char *fmtGray = "gray%" SCNx8;
    
    if (sscanf ([colorName UTF8String], fmt1, &r, &g, &b) == 3) {
        return [COLOR_CLASS colorWithRed:r / 255.0
                                   green:g / 255.0
                                    blue:b / 255.0
                                   alpha:1.0];
    } else if (sscanf ([colorName UTF8String], fmtGray, &w)) {
        return [COLOR_CLASS colorWithWhite:w / 100.0
                                   alpha:1.0];
    }
    return nil;
}

static NSString *
ColorToGrayString(COLOR_CLASS *color)
{
    CGFloat w, a;
#if TARGET_OS_IPHONE
    if (![color getWhite:&w alpha:&a]) {
        return nil;
    }
#else
    // Using the exceptions because there are more spaces to check, and since
    // this is the failure case for the RGB check it's pretty likely to be a
    // gray color if we get here.
    @try {
        [color getWhite:&w alpha:&a];
    } @catch (NSException *e) {
        return nil;
    }
#endif
    if (w == 0) {
        return @"black";
    } else if (w == 1) {
        return @"white";
    }
    return [NSString stringWithFormat:@"gray%d", (int)(w * 100.0)];
}

NSString *
ColorToRGBString(COLOR_CLASS *color)
{
    CGFloat r, g, b;
    const NSString *fmt1 = @"rgb:%" SCNx8 "/%" SCNx8 "/%" SCNx8;
#if TARGET_OS_IPHONE
    if (![color getRed:&r green:&g blue:&b alpha:NULL]) {
        return ColorToGrayString(color);
    }
#else
    // This could use try/catch, but then you'll hit this a lot with exception breakpoints on.
    NSString *spaceName = [color colorSpaceName];
    if (    [spaceName isEqualToString:NSCalibratedRGBColorSpace]
         || [spaceName isEqualToString:NSDeviceRGBColorSpace]) {
       [color getRed:&r green:&g blue:&b alpha:NULL];
    } else {
        return ColorToGrayString(color);
    }
#endif
    return [NSString stringWithFormat:(NSString *)fmt1, (int)(r * 255.0), (int)(g * 255.0), (int)(b * 255.0)];
}

COLOR_CLASS *
ColorForName(NSString *colorAsString)
{
    // Colors from http://www.colourlovers.com/palette/1838545/Evening_Tide
    // with some tweaking.
    COLOR_CLASS *skyBlue = ColorForHex(SKY_BLUE);
    COLOR_CLASS *deepSkyBlue = ColorForHex(DEEP_SKY_BLUE);
    COLOR_CLASS *seaGreen = ColorForHex(SEA_GREEN);
    COLOR_CLASS *darkSeaGreen = ColorForHex(DARK_SEA_GREEN);

    // Map colors used in libxtide::Settings.
    NSDictionary *colorMap =
        @{@"red"         : [COLOR_CLASS redColor],
          @"blue"        : [COLOR_CLASS blueColor],
          @"white"       : [COLOR_CLASS whiteColor],
          @"black"       : [COLOR_CLASS blackColor],
          @"green"       : [COLOR_CLASS greenColor],
          @"gray80"      : [COLOR_CLASS colorWithWhite:0.80 alpha:1.0],
          @"gray90"      : [COLOR_CLASS colorWithWhite:0.90 alpha:1.0],
          @"yellow"      : [COLOR_CLASS yellowColor],
          @"skyblue"     : skyBlue,
          @"seagreen"    : seaGreen,
          @"deepskyblue" : deepSkyBlue,
          @"darkseagreen": darkSeaGreen,
         };
    COLOR_CLASS *color = [colorMap objectForKey:[colorAsString lowercaseString]];
    if (!color) {
        color = ColorFromRGBString(colorAsString);
    }
    return color;
}

// Dearchive a color object or name, using xtide's names.
COLOR_CLASS *
ColorForKey(NSString *key)
{
	NSData *colorAsData = [XTSettings_GetUserDefaults() objectForKey:key];
    if (!colorAsData) {
        return nil;
    }
    if ([colorAsData isKindOfClass:[NSString class]]) {
        NSString *colorAsString = (NSString *)colorAsData;
        COLOR_CLASS *color = ColorForName(colorAsString);
        if (!color) {
            NSLog(@"ColorForKey: No colorMap value %@ %@", key, colorAsString);
            return [COLOR_CLASS orangeColor];
        }
        return color;
    }
    if (![colorAsData isKindOfClass:[NSData class]]) {
        NSLog(@"ColorForKey: Unexpected type %@ %@", key, colorAsData);
        return [COLOR_CLASS redColor];
    }
    COLOR_CLASS *color = [NSKeyedUnarchiver unarchivedObjectOfClass:[COLOR_CLASS class] fromData:colorAsData error:nil];
    if (color == nil) {
        NSLog(@"ColorForKey: Failed to unarchive %@ %@", key, colorAsData);
        return [COLOR_CLASS redColor];
    }

	return color;
}
