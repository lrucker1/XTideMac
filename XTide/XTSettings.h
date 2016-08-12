// $Id: XTSettings.h 2641 2007-09-02 21:31:02Z flaterco $
//
//  XTSettings.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/20/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//


// Cleanup2006 Done

#import <Foundation/Foundation.h>

#ifdef  __cplusplus
extern "C" {
#endif

// Mac specific
extern NSString *XTide_showdisclaimer;
extern NSString *XTide_showallstations;
extern NSString *XTide_ignoreResourceHarmonics;
extern NSString *XTide_harmonicsFiles;

// XTSettings
extern NSString *XTide_gaspect;		// ga
extern NSString *XTide_extralines;	// el
extern NSString *XTide_flatearth;	// fe
extern NSString *XTide_toplines;	// tl
extern NSString *XTide_nofill;		// nf
extern NSString *XTide_eventmask;	// em
extern NSString *XTide_infer;		// in
extern NSString *XTide_deflwidth;	// lw
extern NSString *XTide_tideopacity; // to
extern NSString *XTide_units;		// u
extern NSString *XTide_zulu;		// z


void RegisterUserDefaults(NSUserDefaults *defaults);
NSUserDefaults *XTSettings_GetUserDefaults();

void XTSettings_SetDefaults(NSDictionary *shortcuts);
void XTSettings_ApplyMacResources();

/*
 * Use this for the settings values used in CPP, so that they get set before
 * NSUserDefaults fires the change signal.
 */
void XTSettings_SetShortcutToValue(const char *shortcut, id value);

id XTSettings_ObjectForKey(NSString *key);

NSArray *XTSettings_GetHarmonicsURLsFromPrefs();

#ifdef  __cplusplus
}
#endif
