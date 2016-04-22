/*
 *  XTSettings.mm
 *  XTideCocoa
 *
 *  Created by Lee Ann Rucker on 4/13/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#include "libxtide.hh" // Includes XTSettingsInt and all sorts of things that are incompatible with cocoa.
#include "config.hh"
#include "XTUtils.h"
#include "XTGraph.h"
#include "XTSettings.h"

static NSString * const PVUnitsKey = @"units";
static NSString * const PVValueKey = @"value";

NSString *XTide_gaspect = @"XTide_gaspect";
NSString *XTide_extralines = @"XTide_extralines";
NSString *XTide_flatearth = @"XTide_flatearth";
NSString *XTide_toplines = @"XTide_toplines";
NSString *XTide_nofill = @"XTide_nofill";
NSString *XTide_infer = @"XTide_infer";
NSString *XTide_deflwidth = @"XTide_deflwidth";
NSString *XTide_units = @"XTide_units";
NSString *XTide_zulu = @"XTide_zulu";
NSString *XTide_showdisclaimer = @"XTide_showdisclaimer";
NSString *XTide_showallstations = @"XTide_showallstations";
NSString *XTide_eventmask = @"XTide_eventmask";
NSString *XTide_ignoreResourceHarmonics = @"XTide_ignoreResourceHarmonics";
NSString *XTide_harmonicsFiles = @"XTide_harmonicsFiles";



namespace libxtide {
libxtide::XTSettings::XTSettings () {
    
    // No way to initialize a map with a literal, so make an array and
    // initialize the map at run time.
    
    // Switches recognized by X11 are magically removed from the command
    // line by XtOpenDisplay, so it is not necessary to list them here.
    
    Configurable cd[] = {
        {"bg", "background", "Background color for text windows and location chooser.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,bgdefcolor,PredictionValue(),DstrVector(), 0},
        {"fg", "foreground", "Color of text and other notations.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,fgdefcolor,PredictionValue(),DstrVector(), 0},
        {"bc", "buttoncolor", "Background color of buttons.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,buttondefcolor,PredictionValue(),DstrVector(), 0},
        {"cc", "currentdotcolor", "Color of dots indicating current stations in the location chooser.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,currentdotdefcolor,PredictionValue(),DstrVector(), 0},
        {"dc", "daycolor", "Daytime background color in tide graphs.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,daydefcolor,PredictionValue(),DstrVector(), 0},
        {"Dc", "datumcolor", "Color of datum line in tide graphs.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,datumdefcolor,PredictionValue(),DstrVector(), 0},
        {"ec", "ebbcolor", "Foreground color in tide graphs during outgoing tide.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,ebbdefcolor,PredictionValue(),DstrVector(), 0},
        {"fc", "floodcolor", "Foreground color in tide graphs during incoming tide.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,flooddefcolor,PredictionValue(),DstrVector(), 0},
        {"mc", "markcolor", "Color of mark line in graphs.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,markdefcolor,PredictionValue(),DstrVector(), 0},
        {"Mc", "mslcolor", "Color of middle-level line in tide graphs.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,msldefcolor,PredictionValue(),DstrVector(), 0},
        {"nc", "nightcolor", "Nighttime background color in tide graphs.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,nightdefcolor,PredictionValue(),DstrVector(), 0},
        {"tc", "tidedotcolor", "Color of dots indicating tide stations in the location chooser.", Configurable::settingKind, Configurable::dstrRep, Configurable::colorInterp, false, 0,0,0,tidedotdefcolor,PredictionValue(),DstrVector(), 0},
        {"to", "tideopacity", "Opacity of the fill in graph style s (0-1).", Configurable::settingKind, Configurable::doubleRep, Configurable::opacityDoubleInterp, false, 0,deftideopacity,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"gt", "graphtenths", "Label tenths of units in tide graphs?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,graphtenths,Dstr(),PredictionValue(),DstrVector(), 0},
        {"el", "extralines", "Draw datum and middle-level lines in tide graphs?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,extralines,Dstr(),PredictionValue(),DstrVector(), 0},
        {"fe", "flatearth", "Prefer flat map to round globe location chooser?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,flatearth,Dstr(),PredictionValue(),DstrVector(), 0},
        {"cb", "cbuttons", "Create tide clocks with buttons?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,cbuttons,Dstr(),PredictionValue(),DstrVector(), 0},
        {"in", "infer", "Use inferred constituents (expert only)?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,infer,Dstr(),PredictionValue(),DstrVector(), 0},
        {"ou", "omitunits", "Print numbers with no ft/m/kt?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,omitunits,Dstr(),PredictionValue(),DstrVector(), 0},
        {"pb", "pagebreak", "Pagebreak and header before every month of a calendar?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,pagebreak,Dstr(),PredictionValue(),DstrVector(), 0},
        {"lb", "linebreak", "Linebreak before prediction value in calendars?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,linebreak,Dstr(),PredictionValue(),DstrVector(), 0},
        {"em", "eventmask", "Event mask:", Configurable::settingKind, Configurable::dstrRep, Configurable::eventMaskInterp, false, 0,0,0,eventmask,PredictionValue(),DstrVector(), 0},
        {"tl", "toplines", "Draw depth lines on top of tide graph?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,toplines,Dstr(),PredictionValue(),DstrVector(), 0},
        {"z", "zulu", "Coerce all time zones to UTC?", Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,forceZuluTime,Dstr(),PredictionValue(),DstrVector(), 0},
        {"cw", "cwidth", "Initial width for tide clocks (pixels):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minGraphWidth,defcwidth),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minGraphWidth},
        {"ch", "cheight", "Initial height for tide clocks (pixels):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minGraphHeight,defcheight),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minGraphHeight},
        {"gw", "gwidth", "Initial width for tide graphs (pixels):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minGraphWidth,defgwidth),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minGraphWidth},
        {"gh", "gheight", "Initial height for tide graphs (pixels):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minGraphHeight,defgheight),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minGraphHeight},
        {"tw", "ttywidth", "Width of text format (characters):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minTTYwidth,defttywidth),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minTTYwidth},
        {"th", "ttyheight", "Height of ASCII graphs and clocks (characters):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, std::max(Global::minTTYheight,defttyheight),0,0,Dstr(),PredictionValue(),DstrVector(), Global::minTTYheight},
        {"pi", "predictinterval", "Default predict interval (days):", Configurable::settingKind, Configurable::unsignedRep, Configurable::posIntInterp, false, 4,0,0,Dstr(),PredictionValue(),DstrVector(), 1},
        {"ga", "gaspect", "Initial aspect for tide graphs.", Configurable::settingKind, Configurable::doubleRep, Configurable::posDoubleInterp, false, 0,defgaspect,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"lw", "lwidth", "Width of line in graph styles l and s (pixels, pos. real number).", Configurable::settingKind, Configurable::doubleRep, Configurable::posDoubleInterp, false, 0,deflwidth,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"mf", "monofont", "Monospace font (requires restart):", Configurable::settingKind, Configurable::dstrRep, Configurable::textInterp, false, 0,0,0,defmonofont,PredictionValue(),DstrVector(), 0},
        {"gf", "graphfont", "Graph/clock font (requires restart):", Configurable::settingKind, Configurable::dstrRep, Configurable::textInterp, false, 0,0,0,defgraphfont,PredictionValue(),DstrVector(), 0},
        {"ph", "pageheight", "Nominal length of paper in LaTeX output (mm).", Configurable::settingKind, Configurable::doubleRep, Configurable::posDoubleInterp, false, 0,defpageheight,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"pm", "pagemargin", "Nominal width of margins in LaTeX output (mm).", Configurable::settingKind, Configurable::doubleRep, Configurable::nonnegativeDoubleInterp, false, 0,defpagemargin,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"pw", "pagewidth", "Nominal width of paper in LaTeX output (mm).", Configurable::settingKind, Configurable::doubleRep, Configurable::posDoubleInterp, false, 0,defpagewidth,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"gl", "globelongitude", "Initial center longitude for globe:", Configurable::settingKind, Configurable::doubleRep, Configurable::glDoubleInterp, false, 0,defgl,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"cf", "caldayfmt", "Strftime style format string for printing days in calendars.", Configurable::settingKind, Configurable::dstrRep, Configurable::timeFormatInterp, false, 0,0,0,caldayfmt,PredictionValue(),DstrVector(), 0},
        {"df", "datefmt", "Strftime style format string for printing dates.", Configurable::settingKind, Configurable::dstrRep, Configurable::timeFormatInterp, false, 0,0,0,datefmt,PredictionValue(),DstrVector(), 0},
        {"hf", "hourfmt", "Strftime style format string for printing hour labels on time axis.", Configurable::settingKind, Configurable::dstrRep, Configurable::timeFormatInterp, false, 0,0,0,hourfmt,PredictionValue(),DstrVector(), 0},
        {"tf", "timefmt", "Strftime style format string for printing times.", Configurable::settingKind, Configurable::dstrRep, Configurable::timeFormatInterp, false, 0,0,0,timefmt,PredictionValue(),DstrVector(), 0},
        {"gs", "graphstyle", "Style of graphs and clocks:", Configurable::settingKind, Configurable::charRep, Configurable::gsInterp, false, 0,0,defgraphstyle,Dstr(),PredictionValue(),DstrVector(), 0},
        {"u", "units", "Preferred units of length:", Configurable::settingKind, Configurable::dstrRep, Configurable::unitInterp, false, 0,0,0,prefunits,PredictionValue(),DstrVector(), 0},
        
        {"v", Dstr(), Dstr(), Configurable::switchKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,'n',Dstr(),PredictionValue(),DstrVector(), 0},
        {"suck", Dstr(), Dstr(), Configurable::switchKind, Configurable::charRep, Configurable::booleanInterp, false, 0,0,'n',Dstr(),PredictionValue(),DstrVector(), 0},
        {"b", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrRep, Configurable::numberInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"e", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrRep, Configurable::numberInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"s", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrRep, Configurable::numberInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"f", Dstr(), Dstr(), Configurable::switchKind, Configurable::charRep, Configurable::formatInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"m", Dstr(), Dstr(), Configurable::switchKind, Configurable::charRep, Configurable::modeInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"l", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrVectorRep, Configurable::textInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"ml", Dstr(), Dstr(), Configurable::switchKind, Configurable::predictionValueRep, Configurable::numberInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"o", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrRep, Configurable::textInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        
        // Deprecated settings
        {"ns", "nosunmoon", Dstr(), Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        {"nf", "nofill", Dstr(), Configurable::settingKind, Configurable::charRep, Configurable::booleanInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        
        // "X" is where the X geometry string ends up.
        {"X", Dstr(), Dstr(), Configurable::switchKind, Configurable::dstrRep, Configurable::textInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        // "XX" is where the X font string ends up if HAVE_XAW3DXFT.
        {"XX", "font", Dstr(), Configurable::settingKind, Configurable::dstrRep, Configurable::textInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0},
        
        {Dstr(), Dstr(), Dstr(), Configurable::switchKind, Configurable::charRep, Configurable::textInterp, true, 0,0,0,Dstr(),PredictionValue(),DstrVector(), 0}
    };
    
    for (unsigned i=0; !cd[i].switchName.isNull(); ++i) {
#ifndef __APPLE__
        // Trusting that the table is OK because it's copied from Settings.cc
        Dstr culprit ("the config.hh definition for ");
        culprit += cd[i].switchName;
        culprit += '/';
        culprit += cd[i].resourceName;
        require (!checkConfigurable (culprit, cd[i]));
#endif
        operator[](cd[i].switchName) = cd[i];
    }
}
} // namespace libxtide

/*
 *------------------------------------------------------------------------------
 *
 * configurablePrefKey --
 *
 *      Creates a NSUserDefaults pref key for the table value.
 *
 * Result:
 *      An NSString
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

static NSString *configurablePrefKey(libxtide::Configurable &cfbl)
{
    return [NSString stringWithFormat:@"XTide_%s", cfbl.resourceName.aschar()];
}


/*
 *------------------------------------------------------------------------------
 *
 * setConfigurableFromPref --
 *
 *      Reads the pref corresponding to the table value and updates
 *      the table.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      May set the table value.
 *
 *------------------------------------------------------------------------------
 */

static void setConfigurableToValue(libxtide::Configurable &cfbl,
                                   id value)
{
    if (!value) {
        return;
    }
    switch (cfbl.representation) {
        case libxtide::Configurable::unsignedRep:
            cfbl.u = [value unsignedIntValue];
            break;
        case libxtide::Configurable::doubleRep:
            cfbl.d = [value doubleValue];
            break;
        case libxtide::Configurable::charRep:
            if (cfbl.interpretation == libxtide::Configurable::booleanInterp) {
                cfbl.c = [value boolValue] ? 'y' : 'n';
            } else {
                cfbl.c = [value charValue];
            }
            break;
        case libxtide::Configurable::dstrRep:
            /*
             * Colors might be NSData or a string. We only use Configurable
             * colors for the initial defaults, then get them from NSUserDefaults
             * after that. So don't worry about it.
             */
            if ([value isKindOfClass:[NSString class]]) {
                cfbl.s = Dstr([value UTF8String]);
            }
            break;
        case libxtide::Configurable::predictionValueRep:
        {
            double v = [[value objectForKey:PVValueKey] doubleValue];
            Dstr uts([[value objectForKey:PVUnitsKey] UTF8String]);
            cfbl.p = libxtide::PredictionValue (libxtide::Units::parse(uts), v);
        }
            break;
        case libxtide::Configurable::dstrVectorRep:
            // "l" is only used in tide.cc
            break;
        default:
            assert (false);
    }
}

static void setConfigurableFromPref(libxtide::Configurable &cfbl)
{
    NSString *resName = configurablePrefKey(cfbl);
    id pref = [[NSUserDefaults standardUserDefaults] objectForKey:resName];
    //NSLog(@"%@ %@", resName, pref);
    setConfigurableToValue(cfbl, pref);
}


/*
 *------------------------------------------------------------------------------
 *
 * valueForConfigurable --
 *
 *      Returns an NSObject corresponding to the table value.
 *
 * Result:
 *      A property list value or nil.
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

static id valueForConfigurable(libxtide::Configurable &cfbl)
{
    switch (cfbl.representation) {
        case libxtide::Configurable::unsignedRep:
            return [NSNumber numberWithUnsignedInt:cfbl.u];
        case libxtide::Configurable::doubleRep:
            return [NSNumber numberWithDouble:cfbl.d];
        case libxtide::Configurable::charRep:
            if (cfbl.interpretation == libxtide::Configurable::booleanInterp) {
                return [NSNumber numberWithBool:(cfbl.c == 'y')];
            }
            return [NSNumber numberWithChar:cfbl.c];
        case libxtide::Configurable::dstrRep:
            return DstrToNSString(cfbl.s);
        case libxtide::Configurable::predictionValueRep:
        {
            NSNumber *v = [NSNumber numberWithDouble:cfbl.p.val()];
            NSString *uts = [NSString stringWithUTF8String:libxtide::Units::longName(cfbl.p.Units())];
            return [NSDictionary dictionaryWithObjectsAndKeys:
                    v, PVValueKey,
                    uts, PVUnitsKey,
                    nil];
        }
            break;
        case libxtide::Configurable::dstrVectorRep:
            // "l" is only used in tide.cc
            break;
        default:
            assert (false);
    }
    return nil;
}


/*
 *------------------------------------------------------------------------------
 *
 * XTSettings::updateOldPref --
 *
 *      Change any "XTide*Foo" resources to "XTide_Foo";
 *      '*' is not legal in bindings.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

static void updateOldPref(const char *s)
{
    NSString *oldName = [NSString stringWithFormat:@"XTide*%s", s];
    id pref = [[NSUserDefaults standardUserDefaults] objectForKey:oldName];
    if (pref) {
        NSString *newName = [NSString stringWithFormat:@"XTide_%s", s];
        if ([newName isEqualToString:@"XTide_units"]) {
            int unit = [pref intValue];
            switch (unit) {
                case 0:
                    pref = @"ft";
                    break;
                case 1:
                    pref = @"m";
                    break;
                default:
                    pref = @"x";
                    break;
            }
        } else if ([newName isEqualToString:@"XTide_nosunmoon"]) {
            // YES -> "pSsMm", NO -> "x"
        }
        [[NSUserDefaults standardUserDefaults] setObject:pref forKey:newName];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:oldName];
    }
}

NSMutableDictionary *XTSettingsDefaultValues()
{
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
    
    // Colors (graphing)
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor redColor]]
                      forKey:XTide_ColorKeys[markcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:@"skyBlue"]
                      forKey:XTide_ColorKeys[daycolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:@"deepSkyBlue"]
                      forKey:XTide_ColorKeys[nightcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor blueColor]]
                      forKey:XTide_ColorKeys[floodcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:@"seaGreen"]
                      forKey:XTide_ColorKeys[ebbcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor whiteColor]]
                      forKey:XTide_ColorKeys[datumcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor yellowColor]]
                      forKey:XTide_ColorKeys[mslcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor blackColor]]
                      forKey:XTide_ColorKeys[fgcolor]];
    
    // Colors (stations)
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor redColor]]
                      forKey:XTide_ColorKeys[refcolor]];
    [defaultValues setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSColor greenColor]]
                      forKey:XTide_ColorKeys[subcolor]];
    
    return defaultValues;
}


/*
 *------------------------------------------------------------------------------
 *
 * XTSettings::setMacDefaults --
 *
 *      Register the NSUserDefaults default values based on the table values.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

void libxtide::XTSettings::setMacDefaults()
{
    NSMutableDictionary *defaultValues = XTSettingsDefaultValues();
    for (ConfigurablesMap::iterator it = begin(); it != end(); ++it) {
        Configurable &cfbl = it->second;
        if (cfbl.kind == Configurable::settingKind) {
            id value = valueForConfigurable(cfbl);
            if (value) {
                [defaultValues setObject:value
                                  forKey:configurablePrefKey(cfbl)];
            };
        }
    }
    
    // Register the dictionary of defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    
    // Fix any old prefs
    for (ConfigurablesMap::iterator it = begin(); it != end(); ++it) {
        Configurable &cfbl = it->second;
        if (cfbl.kind == Configurable::settingKind) {
            updateOldPref(cfbl.resourceName.aschar());
        }
    }
    // Also fix the colors and Mac-specific prefs.
    const char *otherPrefs[] = {
        "background",
        "foreground",
        "buttoncolor",
        "daycolor",
        "datumcolor",
        "ebbcolor",
        "floodcolor",
        "markcolor",
        "mslcolor",
        "nightcolor",
        "showdisclaimer",
        "selcolor",
        NULL};
    
    int i;
    for (i = 0; otherPrefs[i] != NULL; i++) {
        updateOldPref(otherPrefs[i]);
    }
}


/*
 *------------------------------------------------------------------------------
 *
 * XTSettings::applyMacResources --
 *
 *      Update the table values to the NSUserDefaults.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

void libxtide::XTSettings::applyMacResources()
{
    for (ConfigurablesMap::iterator it = begin(); it != end(); ++it) {
        Configurable &cfbl = it->second;
        if (cfbl.kind == Configurable::settingKind) {
            setConfigurableFromPref(cfbl);
        }
    }
}


void XTSettings_SetShortcutToValue(const char *shortcut, id value)
{
    libxtide::Configurable &cfbl = libxtide::Global::settings[shortcut];

    NSString *resName = configurablePrefKey(cfbl);
    // CPP update has to happen before NSUserDefaults change fires, so applyMacResources is too late.
    setConfigurableToValue(cfbl, value);
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:resName];
}

NSArray *XTSettings_GetHarmonicsURLsFromPrefs()
{
    NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] objectForKey:XTide_harmonicsFiles];
    NSMutableArray *urls = [NSMutableArray array];
    
    for (NSData *bookmarkData in bookmarks) {
        // test if the file still exists
        NSURL *resolvedFileURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                           options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
                                                     relativeToURL:nil
                                               bookmarkDataIsStale:NULL
                                                             error:NULL];
        if (resolvedFileURL) {
            [urls addObject:resolvedFileURL];
        }
    }
    return urls;
}
