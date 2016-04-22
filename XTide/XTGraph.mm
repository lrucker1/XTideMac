//
//  XTGraph.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "libxtide.hh"
#import "Skycal.hh"
#import "XTGraphInt.h"
#import "XTStationInt.h"
#import "XTUtils.h"


@interface XTGraph ()
{
    libxtide::CocoaGraph *mGraph;
}

@end



namespace libxtide {
    int colormap[Colors::numColors] = {-1, fgcolor, markcolor, -1,
        daycolor, nightcolor, floodcolor, ebbcolor, datumcolor, mslcolor};
}

@implementation XTGraph

// Test whether key is the Prefs key for a color we care about
/*
 *-----------------------------------------------------------------------------
 *
 * -[XTGraph isColorOfInterest:] --
 *
 *      Test whether key is the Prefs key for a color we care about.
 *
 * Result:
 *      YES if the key is in the colormap
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

+ (BOOL)isColorOfInterest:(NSString*)key
{
    int i, keyID;
    BOOL result = false;
    for (i = 0; !result && i < libxtide::Colors::numColors; i++) {
        keyID = libxtide::colormap[i];
        if (keyID >= 0) {
            result = (key == XTide_ColorKeys[keyID]);
        }
    }
    return result;
}

+ (NSArray *)colorsOfInterest
{
    NSMutableArray *array = [NSMutableArray array];
    int i, keyID;
    for (i = 0; i < libxtide::Colors::numColors; i++) {
        keyID = libxtide::colormap[i];
        if (keyID >= 0) {
            [array addObject:XTide_ColorKeys[keyID]];
        }
    }
    return array;
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTGraph initWithXSize:ysize:] --
 *
 *      Initializer.
 *
 * Result:
 *      An instance or nil.
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (id)initWithXSize:(unsigned)xsize // IN
              ysize:(unsigned)ysize  // IN
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    mGraph = new libxtide::CocoaGraph(xsize, ysize);
    
    return self;
}



/*
 *-----------------------------------------------------------------------------
 *
 * -[XTGraph dealloc] --
 *
 *      The destructor.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      Deletes the CocoaGraph instance.
 *
 *-----------------------------------------------------------------------------
 */

- (void)dealloc
{
    // Created and owned by self.
    delete mGraph;
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTGraph drawTides:now:] --
 *
 *      Draws tides.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (void)drawTides:(XTStation*)sr now:(NSDate*)now
{
    libxtide::Timestamp t = libxtide::Timestamp((time_t)[now timeIntervalSince1970]);
    mGraph->drawTides([sr adaptedStation], t);
}

@end

namespace libxtide {

/*
 *------------------------------------------------------------------------------
 *
 * CocoaGraph --
 *
 *      Constructor.
 *
 * Results:
 *      The new Graph
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

libxtide::CocoaGraph::CocoaGraph(unsigned xSize,
                                 unsigned ySize,
                                 GraphStyle style):
PixelatedGraph(xSize, ySize, style)
{
    font = [NSFont userFontOfSize:(float)12.0];
    attributes = [NSMutableDictionary dictionary];
    [attributes setObject:font forKey:NSFontAttributeName];
    
    // There are holes. That's OK, they aren't used in Graph
    int i;
    for (i = 0; i < Colors::numColors; i++) {
        mycolors[i] = nil;
    }
    UpdateColors();
}


/*
 *------------------------------------------------------------------------------
 *
 * CocoaGraph --
 *
 *      Destructor.
 *
 * Results:
 *      None
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

CocoaGraph::~CocoaGraph()
{
}

void
CocoaGraph::UpdateColors()
{
    int i, keyID;
    for (i = 0; i < Colors::numColors; i++) {
        keyID = colormap[i];
        if (keyID >= 0) {
            mycolors[i] = ColorForKey(XTide_ColorKeys[keyID]);
        }
    }
    [attributes setObject:mycolors[Colors::foreground]
                   forKey:NSForegroundColorAttributeName];
}

void
CocoaGraph::clearGraph (Timestamp startTime,
                        Timestamp endTime,
                        Interval increment,
                        Station *station,
                        TideEventsOrganizer &organizer) {
    assert (station);
    
    // True if event mask is set to suppress sunrises *or* sunsets
    bool ns (Global::settings["em"].s.contains("s"));
    
    // Clear the graph by laying down a background of days and nights.
    bool sunIsUp = true;
    if (!(station->coordinates.isNull()) && !ns)
        sunIsUp = Skycal::sunIsUp (startTime, station->coordinates);
    
    Timestamp loopTime (startTime);
    Timestamp nextSunEventTime;
    TideEventsIterator it (organizer.begin());
    findNextSunEvent (it, organizer, loopTime, endTime, nextSunEventTime);
    NSPoint p1, p2;
    Colors::Colorchoice lastcolor = (Colors::Colorchoice)-1;
    Colors::Colorchoice c = lastcolor;
    unsigned x, x1;
    double yTop = _ySize - 1;
    NSBezierPath *tidePath = [NSBezierPath bezierPath];
    for (x=0, x1=0; x<_xSize; ++x, loopTime += increment) {
        p1 = NSMakePoint(x, 0);
        if (loopTime >= nextSunEventTime && !ns) {
            findNextSunEvent (it, organizer, loopTime, endTime, nextSunEventTime);
            assert (loopTime < nextSunEventTime);
            if (it != organizer.end()) {
                switch (it->second.eventType) {
                    case TideEvent::sunrise:
                        sunIsUp = false;
                        break;
                    case TideEvent::sunset:
                        sunIsUp = true;
                        break;
                    default:
                        assert (false);
                }
            } else
                sunIsUp = !sunIsUp;
        }
        lastcolor = c;
        c = (sunIsUp ? Colors::daytime : Colors::nighttime);
        if (c != lastcolor) {
            if (lastcolor >= 0) {
                [tidePath lineToPoint:p1];
                p2 = NSMakePoint(x, yTop);
                [tidePath lineToPoint:p2];
                p2 = NSMakePoint(x1, yTop);
                [tidePath lineToPoint:p2];
                [tidePath closePath];
                [mycolors[lastcolor] set];
                [tidePath fill];
                [tidePath removeAllPoints];
                x1 = x;
            }
            [tidePath moveToPoint:p1];
        }
    }
    // and the final bit at the end
    if (lastcolor >= 0) {
        [tidePath lineToPoint:p1];
        p2 = NSMakePoint(x,yTop);
        [tidePath lineToPoint:p2];
        p2 = NSMakePoint(x1,yTop);
        [tidePath lineToPoint:p2];
        [tidePath closePath];
        [mycolors[lastcolor] set];
        [tidePath fill];
    }
}

void
CocoaGraph::drawTideSegments (Timestamp startTime,
                              Timestamp endTime,
                              Interval increment,
                              Station *station,
                              const double ymin,
                              const double ymax)
{
    const double valmin (station->minLevelHeuristic().val());
    const double valmax (station->maxLevelHeuristic().val());
    double prevval, prevytide;
    double val (station->predictTideLevel(startTime-increment).val());
    double ytide = xlate(val);
    double nextval (station->predictTideLevel(startTime).val());
    double nextytide (xlate (nextval));
    Timestamp loopt;
    int x, x1;
    startPixelCache();
    NSPoint p1;
    Colors::Colorchoice lastcolor = (Colors::Colorchoice)-1;
    Colors::Colorchoice c = lastcolor;
    
    double slw (Global::settings["lw"].d);
    NSBezierPath *tidePath = [NSBezierPath bezierPath];
    [tidePath setLineWidth:slw];
    
    // loopt is actually 1 step ahead of x.
    for (x=0, x1=0, loopt=startTime+increment;
         x<(int)_xSize;
         ++x, loopt += increment) {
        
        prevval = val;
        prevytide = ytide;
        val = nextval;
        ytide = nextytide;
        nextval = station->predictTideLevel(loopt).val();
        nextytide = xlate(nextval);
        lastcolor = c;
        
        // Coloration is determined from the predicted heights, not from
        // the eventTypes of surrounding tide events.  Ideally the two
        // would never disagree, but for pathological sub stations they
        // can.
        if (station->isCurrent) {
            c = (val > 0.0 ? Colors::flood : Colors::ebb);
        } else {
            c = (prevval < val ? Colors::flood : Colors::ebb);
        }
        p1 = NSMakePoint(x, ytide);
        if (c != lastcolor) {
            if (lastcolor >= 0) {
                [mycolors[lastcolor] set];
                [tidePath stroke];
                [tidePath removeAllPoints];
                x1 = x;
            }
            [tidePath moveToPoint:p1];
        }
        else
            [tidePath lineToPoint:p1];
    }
    // and the final bit at the end
    [mycolors[lastcolor] set];
    [tidePath stroke];
    stopPixelCache();
}

// Unlike X11, the versions with doubles are the preferred ones

void
CocoaGraph::drawVerticalLineP(int x,
                              int y1,
                              int y2,
                              Colors::Colorchoice c,
                              double opacity)
{
    NSPoint p1, p2;
    p1 = NSMakePoint(x, y1);
    p2 = NSMakePoint(x, y2);
    if (opacity == 1.0) {
        [mycolors[c] set];
    } else {
        [[mycolors[c] colorWithAlphaComponent:opacity] set];
    }
    [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
}

void
CocoaGraph::drawHorizontalLineP(int xlo,
                                int xhi,
                                int y,
                                Colors::Colorchoice c)
{
    [mycolors[c] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(xlo, y)
                              toPoint:NSMakePoint(xhi, y)];
}

void
CocoaGraph::drawStringP (int x, int y, const Dstr &s)
{
    // Strings should be drawn downwards from the y coordinate provided.
    [DstrToNSString(s) drawAtPoint:NSMakePoint(x,y) withAttributes:attributes];
}

const unsigned int
CocoaGraph::stringWidth (const Dstr &s) const
{
    return [DstrToNSString(s) sizeWithAttributes:attributes].width;
}

const unsigned int
CocoaGraph::fontHeight() const
{
    return [font pointSize];
}

const unsigned CocoaGraph::oughtHeight() const
{
    return [font pointSize] - 3; // TODO: ???
}


const unsigned CocoaGraph::oughtVerticalMargin() const
{
    return 1;
}

void
CocoaGraph::setPixel (int x, int y, Colors::Colorchoice c)
{
    NSPoint p1 = NSMakePoint(x, y);
    [mycolors[c] set];
    [NSBezierPath strokeLineFromPoint:p1 toPoint:p1];
}

void
CocoaGraph::setPixel(int x,
                     int y,
                     Colors::Colorchoice c,
                     double opacity)
{
    if (opacity == 1.0)
        [mycolors[c] set];
    else {
        [[mycolors[c] colorWithAlphaComponent:opacity] set];
    }
    NSPoint p1 = NSMakePoint(x, y);
    [NSBezierPath strokeLineFromPoint:p1 toPoint:p1];
}

void
CocoaGraph::startPixelCache()
{
}

void
CocoaGraph::stopPixelCache()
{
}

}