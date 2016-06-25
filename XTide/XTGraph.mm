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

- (void)drawTides:(XTStation *)sr
              now:(NSDate *)now
{
    libxtide::Timestamp t = libxtide::Timestamp((time_t)[now timeIntervalSince1970]);
    mGraph->drawTides([sr adaptedStation], t);
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTGraph offsetStationTime:now:deltaX:] --
 *
 *      Computes the date shift for the coordinate shift.
 *
 * Result:
 *      The new date
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (NSDate*)offsetStationTime:(XTStation*)sr
                         now:(NSDate *)now
                      deltaX:(double *)deltaX
{
   libxtide::Timestamp t = libxtide::Timestamp((time_t)[now timeIntervalSince1970]);
   t = mGraph->offsetTimeByDeltaX([sr adaptedStation], t, deltaX);
   return TimestampToNSDate(t);
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

void CocoaGraph::drawLevels(const SafeVector<double> &val,
                            const SafeVector<double> &y,
                            double yzulu,
                            bool isCurrent
#ifdef blendingTest
                            , const SafeVector<BlendBlob> &blendBlobs
#endif
)
{
    const char gs (Global::settings["gs"].c);
    const double opacity (gs == 'l' ? 1.0 : Global::settings["to"].d);
    Colors::Colorchoice lastcolor = (Colors::Colorchoice)-1;
    Colors::Colorchoice c = lastcolor;

    NSBezierPath *tidePath = [NSBezierPath bezierPath];
    NSPoint p1;
    
    // Harmonize this with the quantized y coordinate of the 0 kt line to avoid
    // anomalies like a gap between the flood curve and the line.
    yzulu = Global::ifloor(yzulu);
    CGFloat ybase = isCurrent ? yzulu : _ySize;
    BOOL fill = (gs != 'l');
    
    if (_xSize == 0) {
        return;
    }
    for (int x=0; x<(int)_xSize; ++x) {
        
        // Coloration is determined from the predicted heights, not from
        // the eventTypes of surrounding tide events.  Ideally the two
        // would never disagree, but for pathological sub stations they
        // can.
        if (isCurrent) {
            c = (val[x+1] > 0.0 ? Colors::flood : Colors::ebb);
        } else {
            c = (val[x] < val[x+1] ? Colors::flood : Colors::ebb);
        }
        p1 = NSMakePoint(x, y[x+1]);
        if (c != lastcolor) {
            if (lastcolor >= 0) {
                p1 = NSMakePoint(x+1, y[x+2]);
                [tidePath lineToPoint:p1];
                [tidePath lineToPoint:NSMakePoint(x+1, ybase)];
                [[mycolors[lastcolor] colorWithAlphaComponent:opacity] set];
                fill ? [tidePath fill] : [tidePath stroke];
                [tidePath removeAllPoints];
            }
            [tidePath moveToPoint:NSMakePoint(x, ybase)];
            lastcolor = c;
       }
        else {
            [tidePath lineToPoint:p1];
        }
    }
    // and the final bit at the end
    [[mycolors[lastcolor] colorWithAlphaComponent:opacity] set];
    [tidePath lineToPoint:NSMakePoint(_xSize, ybase)];
    fill ? [tidePath fill] : [tidePath stroke];
}


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



void CocoaGraph::drawBoxS (double x1, double x2, double y1, double y2,
                               Colors::Colorchoice c)
{
    int ix1 (Global::ifloor (x1)), ix2 (Global::ifloor (x2));
    int iy1 (Global::ifloor (y1)), iy2 (Global::ifloor (y2));
    if (ix1 > ix2)
        std::swap (ix1, ix2);
    if (iy1 > iy2)
        std::swap (iy1, iy2);
    NSRect fillRect = NSMakeRect(ix1, iy1, ix2 - ix1, iy2 - iy1);
    [mycolors[c] set];
    NSRectFill(fillRect);
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
    if (opacity == 1.0) {
        [mycolors[c] set];
    } else {
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