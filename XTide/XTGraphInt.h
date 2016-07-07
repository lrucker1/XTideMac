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
    CocoaGraph (unsigned xSize, unsigned ySize, CGFloat scale = 1, GraphStyle style = normal);
    ~CocoaGraph();
    
    void startPixelCache();
    void stopPixelCache();
    
    const unsigned stringWidth (const Dstr &s) const;
    const unsigned fontHeight() const;
    const unsigned oughtHeight() const;
    const unsigned oughtVerticalMargin() const;

    void drawX (double x, double y);
    
    void drawLevels (const SafeVector<double> &val,
		   const SafeVector<double> &y,
		   double yzulu,
		   bool isCurrent
#ifdef blendingTest
		   , const SafeVector<BlendBlob> &blendBlobs
#endif
		   );

    void drawBoxS(double x1, double x2, double y1, double y2,
                    Colors::Colorchoice c);
    
    void drawStringP (int x, int y, const Dstr &s);
    
    void drawVerticalLineP (int x, int y1, int y2, Colors::Colorchoice c,
			  double opacity = 1.0);
    void drawHorizontalLineP (int xlo, int xhi, int y, Colors::Colorchoice c);
    
    void setPixel (int x, int y, Colors::Colorchoice c);
    void setPixel (int x, int y, Colors::Colorchoice c, double opacity);
    
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
#if TARGET_OS_IPHONE
    UIColor *mycolors[Colors::numColors];
    UIFont *font;
#else
    NSColor *mycolors[Colors::numColors];
    NSFont *font;
#endif
    NSMutableDictionary *attributes;
    CGFloat scale;
    
    void UpdateColors();
    
};

} // namespace

#endif /* XTGraphInt_h */
