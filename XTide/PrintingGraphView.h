//
//  PrintingGraphView.h
//  XTide
//
//  Created by Lee Ann Rucker on 8/12/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "GraphView.h"
@class PrintPanelAccessoryController;

@interface PrintingGraphView : GraphView
{
    NSSize originalSize;
    NSSize previousValueOfDocumentSizeInPage;	// As user fiddles with the print panel settings, stores the last document size for which the text was relaid out
    BOOL previousValueOfWrappingToFit;		// Stores the last setting of whether to rewrap to fit page or not
}
@property (assign) PrintPanelAccessoryController *printPanelAccessoryController;
@property (assign) NSSize originalSize; // The original size of the text view in the window (used for non-rewrapped printing)

@end
