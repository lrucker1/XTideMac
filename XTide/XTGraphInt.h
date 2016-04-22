//
//  XTGraphInt.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/14/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef XTGraphInt_h
#define XTGraphInt_h

#import "XTGraph.h"

#import "libxtide.hh"
#import "Graph.hh"
#import "PixelatedGraph.hh"


namespace libxtide {

class CocoaGraph: public PixelatedGraph
{
public:
    CocoaGraph (unsigned xSize, unsigned ySize, GraphStyle style = normal);
    ~CocoaGraph();
    
    void startPixelCache();
    void stopPixelCache();
    
    const unsigned stringWidth (const Dstr &s) const;
    const unsigned fontHeight() const;
    const unsigned oughtHeight() const;
    const unsigned oughtVerticalMargin() const;
    
    void drawStringP (int x, int y, const Dstr &s);
    
    void drawVerticalLineP (int x, int y1, int y2, Colors::Colorchoice c,
			  double opacity = 1.0);
    void drawHorizontalLineP (int xlo, int xhi, int y, Colors::Colorchoice c);
    
    void setPixel (int x, int y, Colors::Colorchoice c);
    void setPixel (int x, int y, Colors::Colorchoice c, double opacity);
    
    // This fills in the background, which indicates sunrise/sunset.
    void clearGraph (Timestamp startTime,
                     Timestamp endTime,
                     Interval increment,
                     Station *station,
                     TideEventsOrganizer &organizer);
    
    // Ordering of y1 and y2 is irrelevant.
    void drawVerticalLine (int x,
                           double y1,
                           double y2,
                           Colors::Colorchoice c);
    
    // No line will be drawn if xlo > xhi.
    void drawHorizontalLine (int xlo,
                             int xhi,
                             double y,
                             Colors::Colorchoice c);
    
    void drawString(int x, double y, const Dstr &s);
    
protected:
    NSColor *mycolors[Colors::numColors];
    NSFont *font;
    NSMutableDictionary *attributes;
    
    void UpdateColors();
    
    void drawTideSegments(Timestamp startTime,
                          Timestamp endTime,
                          Interval increment,
                          Station *station,
                          const double ymin,
                          const double ymax);
    
};

} // namespace

#endif /* XTGraphInt_h */
