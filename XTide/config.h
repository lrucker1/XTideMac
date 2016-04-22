//
//  config.h
//  XTide-Cocoa
//
//  Created by Lee Ann Rucker on 7/8/06.
//  Copyright 2006 . 
//
// Default graph width and height (pixels), and aspect
#define defgwidth 960
#define defgheight 312
#define defgaspect 1.0

// Draw datum and Mean Astronomical Tide lines?
#define extralines NO //'n'

// Prefer flat map to round globe location chooser?
#define flatearth NO //'n'

// Create tide clocks with buttons?
#define cbuttons NO //'n'

// Draw depth lines on top of graph?
#define toplines NO //'n'

// Draw tide graph as a line graph?
#define nofill NO //'n'

// Suppress sunrise, sunset, moon phases?
#define nosunmoon NO //'n'

// Infer constituents?  (Expert use only)
#define infer NO //'n'

// Default width of lines in line graphs
#define deflwidth 2.5

// Default clock width
#define defcwidth 84

// Default preferred units:  0=ft, 1=m, or -1=x (no preference).
#define prefunits -1 //@"x"

// Force UTC?
#define zulu NO //'n'



// General.
#define DAYSECONDS 86400
#define HOURSECONDS 3600


// Stuff for mathematical code in ConstantSetWrapper and Station

/* TIDE_TIME_BLEND
 *   Half the number of seconds over which to blend the tides from
 *   one epoch to the next.
 */
#define TIDE_BLEND_SECONDS (3600)

// Precision (in seconds) to which we will find roots.
#define def_TIDE_TIME_PREC 15

// In drawing of line graphs, slope at which to abandon the thick line
// drawing algorithm.
#define slopelimit 5.0

// Default width of ASCII graphs and banners (characters).
#define defttywidth 79

// Default height of ASCII graphs (characters).
#define defttyheight 24

/***********************************************************/
/*********** STUFF YOU PROBABLY SHOULDN'T CHANGE ***********/
/***********************************************************/

// Minimum TTY width and height.  It is actually a very good thing
// for these to be the same to avoid assertion failures in banner
// mode where everything gets sideways.
#define minttywidth 10
#define minttyheight 10

// Margin left at top and bottom of tide graphs when scaling tides;
// how much "water" at lowest tide; how much "sky" at highest tide.
// This is a scaling factor for the graph height.
#define margin 0.0673

// Length of tick marks on time axis of graphs
#define hourticklen 8

// Number of pixels from left hand side of graph to place "now"
#define nowposition 42


// Controls for how many columns you get in calendar mode, CSV format.
// If you get more events than there is room for, they are discarded.
//
// A value of x for calcsv_nummaxmin means that you get x columns for
// the max times, x columns for the max heights, x columns for the min
// times, x columns for the min heights, and 2x columns for slacks.
#define calcsv_nummaxmin 5
// A value of x for calcsv_numriseset means that you get x columns for
// sunrise, x columns for sunset, x columns for moonrise, and x columns
// for moonset.
//
// Yes, you can have two sunsets in one day, and you don't even need
// Daylight Savings Time to do it:
//
// Isla Neny, Antarctica
// 68.2000° S, 67.0000° W
//
// 2001-01-24 12:03 AM ARST   Sunset
// 2001-01-24  3:17 AM ARST   Sunrise
// 2001-01-24 11:57 PM ARST   Sunset
#define calcsv_numriseset 1
// Moon phases are discarded.

/*******************************************************************/
/************ STUFF YOU DEFINITELY SHOULDN'T MESS WITH *************/
/*******************************************************************/

#define VERSION "2.10"
#define PATCHLEVEL 0
