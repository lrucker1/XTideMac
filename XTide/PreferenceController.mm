//
//  PreferenceController.m
//  XTide-Cocoa
//
//  Created by Lee Ann Rucker on 7/9/06.
//  Copyright 2006 .
//
/*
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import <MapKit/MapKit.h>
#import "libxtide.hh"
#import "XTGlobal.h"
#import "XTGraph.h"
#import "XTSettings.h"
#import "XTStation.h"
#import "XTStationIndex.h"
#import "XTUtils.h"
#import "PreferenceController.h"

static NSString *bookmarkKey = @"bookmark";
static NSString *urlKey = @"url";
static NSString *versionKey = @"version";

@implementation PreferenceController

- (id)init
{
    return [super initWithWindowNibName:@"Preferences"];
}

- (NSColor*)colorForKey:(NSString*)key
{
    return ColorForKey(key);
}

- (void)windowDidLoad
{
    [colorWell_fgcolor setColor:[self colorForKey:XTide_ColorKeys[fgcolor]]];
    [colorWell_daycolor setColor:[self colorForKey:XTide_ColorKeys[daycolor]]];
    [colorWell_nightcolor setColor:[self colorForKey:XTide_ColorKeys[nightcolor]]];
    [colorWell_ebbcolor setColor:[self colorForKey:XTide_ColorKeys[ebbcolor]]];
    [colorWell_floodcolor setColor:[self colorForKey:XTide_ColorKeys[floodcolor]]];
    [colorWell_markcolor setColor:[self colorForKey:XTide_ColorKeys[markcolor]]];
    [colorWell_datumcolor setColor:[self colorForKey:XTide_ColorKeys[datumcolor]]];
    [colorWell_mslcolor setColor:[self colorForKey:XTide_ColorKeys[mslcolor]]];
    
    if ([MKPinAnnotationView instancesRespondToSelector:@selector(pinTintColor)]) {
        [colorWell_currentdotcolor setColor:[self colorForKey:XTide_ColorKeys[currentdotcolor]]];
        [colorWell_tidedotcolor setColor:[self colorForKey:XTide_ColorKeys[tidedotcolor]]];
    } else {
        [colorWell_currentdotcolor setColor:[NSColor redColor]];
        [colorWell_tidedotcolor setColor:[NSColor greenColor]];
        [colorWell_currentdotcolor setEnabled:NO];
        [colorWell_tidedotcolor setEnabled:NO];
    }
    
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    
    BOOL tl = [settings boolForKey:XTide_toplines]; //"tl" toplines - draw depth lines
    BOOL el = [settings boolForKey:XTide_extralines]; //"el" extralines - draw datum and Mean Astronomical Tide lines
    
    [checkBox_extralines setState:el];
    [checkBox_toplines setState:tl];
    
    [textfield_deflwidth setFloatValue:[settings floatForKey:XTide_deflwidth]]; // "lw"
    [slider_opacity setFloatValue:[settings floatForKey:XTide_tideopacity]]; // "to"
    
    NSString *unitPref = [settings objectForKey:XTide_units];
    NSInteger index = 0;
    if (unitPref) {
        index = [[XTStation unitsPrefMap] indexOfObject:unitPref];
    }
    [popup_combo selectItemAtIndex:index];
    
    NSData *data = [[[XTStationIndex sharedStationIndex] harmonicsFileIDs] dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString *html = [[NSAttributedString alloc] initWithHTML:data documentAttributes:nil];
    if (html) {
        [harmonicsInfoField setAttributedStringValue:html];
    } else {
        [harmonicsInfoField setStringValue:@""];
    }
    NSString *resourceTCDVersion = [[XTStationIndex sharedStationIndex] resourceTCDVersion];
    if (resourceTCDVersion) {
        [resourceHarmonicsInfoField setStringValue:resourceTCDVersion];
    }
    [self readHarmonicsFromPrefs];
}

- (void)readHarmonicsFromPrefs
{
    self.useStandardHarmonics = ![[NSUserDefaults standardUserDefaults] boolForKey:XTide_ignoreResourceHarmonics];
    NSArray *urls = XTSettings_GetHarmonicsURLsFromPrefs();
    [harmonicsFileArray removeObjects:[harmonicsFileArray arrangedObjects]];
    [harmonicsFileArray addObjects:[self objectsForURLs:urls]];
}

- (IBAction)changeColor:(id)sender
{
    // Both the NSColorWell and the NSColorPanel send us updates...
    if (![sender isKindOfClass: [NSColorWell class]]) {
        return;
    }
    
    NSColor *color = [sender color];
    NSData *colorAsData = [NSKeyedArchiver archivedDataWithRootObject:color];
    
    NSInteger keyIndex = [sender tag] - colorbase;
    NSString *key;
    if (keyIndex >= 0 && keyIndex < colorindexmax) {
        key = XTide_ColorKeys[keyIndex];
        
        // We read colors from prefs, so we don't need to worry about syncing.
        [[NSUserDefaults standardUserDefaults] setObject:colorAsData forKey:key];
    }
}

- (IBAction)changeExtralines:(id)sender
{
    // extralines
    XTSettings_SetShortcutToValue("el", @([sender state]));
}

- (IBAction)changeToplines:(id)sender
{
    // toplines
    XTSettings_SetShortcutToValue("tl", @([sender state]));
}

- (IBAction)changeLinewidth:(id)sender
{
    XTSettings_SetShortcutToValue("lw", @([sender floatValue]));
}

- (IBAction)changeOpacity:(id)sender
{
    XTSettings_SetShortcutToValue("to", @([sender floatValue]));
}

- (IBAction)changeUnits:(id)sender
{
    NSInteger index = [sender indexOfSelectedItem];
    if (index < 0 || index >= 3) {
        return;
    }
    XTSettings_SetShortcutToValue("u", [[XTStation unitsPrefMap] objectAtIndex:index]);
}

#pragma mark harmonics files

- (NSDictionary *)tableItemFromURL:(NSURL *)url
{
    NSString *version = [[XTStationIndex sharedStationIndex] versionFromHarmonicsFile:[url path]];
    return @{urlKey:url,  versionKey: version};
}


- (NSArray *)objectsForURLs:(NSArray *)urls
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSString *version = [[XTStationIndex sharedStationIndex] versionFromHarmonicsFile:[url path]];
        [array addObject:@{urlKey:url,
                          versionKey: version}];
    }
    return array;
}


// -------------------------------------------------------------------------------
//	add:sender
// -------------------------------------------------------------------------------
- (IBAction)add:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:@[@"tcd"]];
    openPanel.allowsMultipleSelection = YES;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [harmonicsFileArray addObjects:[self objectsForURLs:[openPanel URLs]]];
        }
    }];
}

// -------------------------------------------------------------------------------
//	remove:sender
// -------------------------------------------------------------------------------
- (IBAction)remove:(id)sender
{
    NSIndexSet *selections = [harmonicsFileArray selectionIndexes];
    if ([selections count]) {
        [harmonicsFileArray removeObjectsAtArrangedObjectIndexes:selections];
    }
}


- (IBAction)applyHarmonics:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:!self.useStandardHarmonics forKey:XTide_ignoreResourceHarmonics];
    NSMutableArray *array = [NSMutableArray array];
    for (NSDictionary *tableData in [harmonicsFileArray arrangedObjects]) {
        NSURL *url = [tableData objectForKey:urlKey];
        if (url) {
            NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                                 includingResourceValuesForKeys:nil
                                                  relativeToURL:nil
                                                          error:NULL];
            if (bookmarkData) {
                [array addObject:bookmarkData];
            }
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:XTide_harmonicsFiles];
}

- (IBAction)revertHarmonics:(id)sender
{
    [self readHarmonicsFromPrefs];
}
@end
