//
//  XTMapWindowController.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/14/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTMapWindowController.h"
#import "AppDelegate.h"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTGraph.h"
#import "TideGraphController.h"
#import "SuggestionsWindowController.h"

static NSString * const XTMap_RegionKey = @"region";
static const CGFloat deltaLimit = 5;
static XTMapWindowController *selfContext;

@interface XTMapWindowController ()

@property (copy) NSArray *refStations;
@property (copy) NSArray *subStations;
@property (retain) NSColor *refColor;
@property (retain) NSColor *subColor;
@property BOOL showingSubStations;
@property BOOL searchingSubStations;
@property (retain, nonatomic) SuggestionsWindowController *suggestionsController;
@property (retain) id<MKAnnotation> suggestion;
@property (assign) BOOL editing;


@end

@implementation XTMapWindowController

+ (NSArray *)restorableStateKeyPaths
{
    return @[@"searchingSubStations"];
}

- (instancetype)init
{
    return [super initWithWindowNibName:@"XTMapWindow"];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    MKCoordinateRegion region = [self.mapView region];
    NSArray *encodedRegion = @[@(region.center.latitude), @(region.center.longitude),
                               @(region.span.latitudeDelta), @(region.span.longitudeDelta)];
    [coder encodeObject:encodedRegion forKey:XTMap_RegionKey];
    [super encodeRestorableStateWithCoder:coder];
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    NSArray *encodedRegion = [coder decodeObjectForKey:XTMap_RegionKey];
    if ([encodedRegion count] == 4) {
        MKCoordinateRegion newRegion;
        newRegion.center.latitude = [encodedRegion[0] doubleValue];
        newRegion.center.longitude = [encodedRegion[1] doubleValue];
        newRegion.span.latitudeDelta = [encodedRegion[2] doubleValue];
        newRegion.span.longitudeDelta = [encodedRegion[3] doubleValue];
        @try {
            [self.mapView setRegion:newRegion animated:NO];
        } @catch (NSException *e) {
            // Ignore bad data and continue with restoration.
        }
    }
    [super restoreStateWithCoder:coder];
}

- (void)loadStations
{
    NSArray *stationRefArray = [(AppDelegate *)[NSApp delegate] stationRefArray];
    NSMutableArray *refs = [NSMutableArray array];
    NSMutableArray *subs = [NSMutableArray array];
    for (XTStationRef *station in stationRefArray) {
        if (station.isReferenceStation) {
            [refs addObject:station];
        } else {
            [subs addObject:station];
        }
    }
    self.refStations = refs;
    self.subStations = subs;
    [self.mapView addAnnotations:refs];
    [self updateSubStations];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    if ([self.window respondsToSelector:@selector(titleVisibility)]) {
        self.window.titleVisibility = NSWindowTitleHidden;
    }
    
    [self updateColors];
    [self loadStations];
    
    self.mapView.showsZoomControls = YES;
    self.mapView.showsUserLocation = YES;
    self.mapView.mapType = MKMapTypeHybrid;
    self.mapView.showsPointsOfInterest = YES;
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:XTide_ColorKeys[refcolor]
                                               options:NSKeyValueObservingOptionNew
                                               context:&selfContext];
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:XTide_ColorKeys[subcolor]
                                               options:NSKeyValueObservingOptionNew
                                               context:&selfContext];


    NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    [searchMenu setAutoenablesItems:YES];
    
    // first add our custom menu item (Important note: "action" MUST be valid or the menu item is disabled)
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Include Subordinate Stations", @"Include substations")
        action:@selector(toggleSubStations:) keyEquivalent:@""];
    [item setTarget:self];
    [item setState:self.searchingSubStations];
    [searchMenu insertItem:item atIndex:0];
    
    // add our own separator to keep our custom menu separate
    NSMenuItem *separator =  [NSMenuItem separatorItem];
    [searchMenu insertItem:separator atIndex:1];

    NSMenuItem *recentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"Recent Searches" action:nil keyEquivalent:@""];
    // tag this menu item so NSSearchField can use it and respond to it appropriately
    [recentsTitleItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu insertItem:recentsTitleItem atIndex:2];
    
    NSMenuItem *norecentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"No recent searches" action:nil keyEquivalent:@""];
    // tag this menu item so NSSearchField can use it and respond to it appropriately
    [norecentsTitleItem setTag:NSSearchFieldNoRecentsMenuItemTag];
    [searchMenu insertItem:norecentsTitleItem atIndex:3];
    
    NSMenuItem *recentsItem = [[NSMenuItem alloc] initWithTitle:@"Recents" action:nil keyEquivalent:@""];
    // tag this menu item so NSSearchField can use it and respond to it appropriately
    [recentsItem setTag:NSSearchFieldRecentsMenuItemTag];	
    [searchMenu insertItem:recentsItem atIndex:4];
    
    NSMenuItem *separatorItem = (NSMenuItem*)[NSMenuItem separatorItem];
    // tag this menu item so NSSearchField can use it, by hiding/show it appropriately:
    [separatorItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu insertItem:separatorItem atIndex:5];
    
    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"Clear" action:nil keyEquivalent:@""];
    [clearItem setTag:NSSearchFieldClearRecentsMenuItemTag];	// tag this menu item so NSSearchField can use it
    [searchMenu insertItem:clearItem atIndex:6];
    
    id searchCell = [self.searchField cell];
    [searchCell setMaximumRecents:20];
    [searchCell setSearchMenuTemplate:searchMenu];
    [searchCell setRecentsAutosaveName:@"Map"];
}


- (void)windowWillClose:(NSNotification*)note
{
    if ([note object] != [self window])
        return;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self
                                               forKeyPath:XTide_ColorKeys[refcolor]
                                                  context:&selfContext];
    [[NSUserDefaults standardUserDefaults] removeObserver:self
                                               forKeyPath:XTide_ColorKeys[subcolor]
                                                  context:&selfContext];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    // Might have been changed by restoration, which happens after windowDidLoad.
    if (action == @selector(toggleSubStations:)) {
        [menuItem setState:self.searchingSubStations];
    } else if (   action == @selector(showGraphForSelection:)
        || action == @selector(showDataForSelection:)
        || action == @selector(showCalendarForSelection:)) {
        return self.selectedStation != nil;
    }
    return YES;
}


- (BOOL)updateColors
{
    NSColor *ref = ColorForKey(XTide_ColorKeys[refcolor]);
    NSColor *sub = ColorForKey(XTide_ColorKeys[subcolor]);
    if (![ref isEqual:self.refColor] || ![sub isEqual:self.subColor]) {
        self.refColor = ref;
        self.subColor = sub;
        return YES;
    }
    return NO;
}

// Only show the substations when we're zoomed in; there are over 4000 stations in the database.
- (void)updateSubStations
{
    MKCoordinateRegion newRegion = [self.mapView region];
    BOOL shouldShow =    newRegion.span.latitudeDelta < deltaLimit
                      || newRegion.span.longitudeDelta < deltaLimit;
    if (shouldShow != self.showingSubStations) {
        self.showingSubStations = shouldShow;
        if (shouldShow) {
            [self.mapView addAnnotations:self.subStations];
        } else {
            // Keep any substations in the selection
            NSMutableArray *subs = [NSMutableArray arrayWithArray:self.subStations];
            [subs removeObjectsInArray:self.mapView.selectedAnnotations];
            [self.mapView removeAnnotations:subs];
        }
    }
}

- (XTStationRef *)selectedStation
{
    return [self.mapView.selectedAnnotations firstObject];
}

- (IBAction)goHome:(id)sender
{
    CLLocation *loc = self.mapView.userLocation.location;
    if (loc) {
        MKCoordinateRegion region = [self.mapView region];
        BOOL shouldZoom =    region.span.latitudeDelta > deltaLimit
                          && region.span.longitudeDelta > deltaLimit;
        if (shouldZoom) {
            region.center = loc.coordinate;
            region.span.latitudeDelta = region.span.longitudeDelta = deltaLimit;
            [self.mapView setRegion:region animated:YES];
        } else {
            [self.mapView setCenterCoordinate:loc.coordinate animated:YES];
        }
    }
}

- (IBAction)showGraphForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideGraphForStation:self.selectedStation];
}

- (IBAction)showDataForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideDataForStation:self.selectedStation];
}

- (IBAction)showCalendarForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideCalendarForStation:self.selectedStation];
}


- (IBAction)tideInfoAction:(id)sender
{
    if (![sender isKindOfClass:[NSSegmentedControl class]]) {
        NSBeep();
        return;
    }
    NSSegmentedControl *button = (NSSegmentedControl *)sender;
    XTStationRef *ref = (XTStationRef *)[[button cell] representedObject];
    if ([button selectedSegment] == 0) {
        [(AppDelegate *)[NSApp delegate] showTideGraphForStation:ref];
    } else {
        [(AppDelegate *)[NSApp delegate] showTideDataForStation:ref];
    }
}

-         (void)mapView:(MKMapView *)mapView
regionDidChangeAnimated:(BOOL)animated
{
    [self updateSubStations];
    [self invalidateRestorableState];
}

-            (void)mapView:(MKMapView *)mapView
 didDeselectAnnotationView:(MKAnnotationView *)view
{
    // Remove subs on deselect if we aren't showing subs at this zoom level.
    XTStationRef *station = (XTStationRef *)view.annotation;
    if (!self.showingSubStations && !station.isReferenceStation) {
        [self.mapView removeAnnotation:station];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    if (![annotation isKindOfClass:[XTStationRef class]]) {
        NSLog(@"Unexpected annotation %@", annotation);
        return nil;
    }
    MKAnnotationView *returnedAnnotationView =
        [mapView dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([XTStationRef class])];
    if (returnedAnnotationView == nil) {
        returnedAnnotationView =
            [[MKPinAnnotationView alloc] initWithAnnotation:annotation
                                            reuseIdentifier:NSStringFromClass([XTStationRef class])];
        
        // There are over 4000 of them!
        ((MKPinAnnotationView *)returnedAnnotationView).animatesDrop = NO;
        returnedAnnotationView.canShowCallout = YES;

        // add a detail disclosure button to the callout which will open a tide window
        NSSegmentedControl *rightButton = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0.0, 0.0, 140.0, 120.0)];
        rightButton.segmentCount = 2;
        rightButton.trackingMode = NSSegmentSwitchTrackingMomentary;
        [rightButton setImage:[NSImage imageNamed:@"ChartViewTemplate"] forSegment:0];
        [rightButton setImage:[NSImage imageNamed:@"ListViewTemplate"] forSegment:1];
        [[rightButton cell] setToolTip:NSLocalizedString(@"Chart", @"Tide chart Button") forSegment:0];
        [[rightButton cell] setToolTip:NSLocalizedString(@"List", @"Tide list Button") forSegment:1];
        [rightButton setTarget:self];
        [rightButton setAction:@selector(tideInfoAction:)];
        returnedAnnotationView.rightCalloutAccessoryView = rightButton;
    }
    else {
        returnedAnnotationView.annotation = annotation;
    }
    XTStationRef *ref = (XTStationRef *)annotation;
    NSSegmentedControl *rightButton = (NSSegmentedControl *)returnedAnnotationView.rightCalloutAccessoryView;
    [[rightButton cell] setRepresentedObject:annotation];
    // 10_11: pinTintColor
    if ([returnedAnnotationView respondsToSelector:@selector(pinTintColor)]) {
        ((MKPinAnnotationView *)returnedAnnotationView).pinTintColor =
                ref.isReferenceStation ? self.refColor
                                       : self.subColor;
    } else {
        ((MKPinAnnotationView *)returnedAnnotationView).pinColor =
                ref.isReferenceStation ? MKPinAnnotationColorRed
                                       : MKPinAnnotationColorGreen;
    }
    return returnedAnnotationView;
}

#pragma mark search

- (IBAction)toggleSubStations:(id)sender
{
    self.searchingSubStations = !self.searchingSubStations;
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    [menuItem setState:self.searchingSubStations];
}

/* This method is invoked when the user presses return (or enter) on the search text field. 
   OR! when autocomplete fires, which is unavoidable.
We don't want to use the text from the search field as it could be a substring. Instead, use this user action to trigger selecting the suggested annotation.
*/
- (void)updateSelectionWithSuggestion
{
    if (self.suggestion) {
        if (!self.showingSubStations && ![(XTStationRef *)self.suggestion isReferenceStation]) {
            [self.mapView addAnnotation:self.suggestion];
        }
        [self.mapView selectAnnotation:self.suggestion animated:YES];
    }
}

- (IBAction)selectSuggestedAnnotation:(id)sender
{
    // The search field calls this all the time, not just when the user presses enter.
    // We don't want the map jumping around.
    if (sender == self.suggestionsController) {
        [self updateSelectionWithSuggestion];
    }
}

- (NSArray *)suggestionsForText:(NSString*)text
{
    // Wait until there are > 3 characters because the search is slow. TODO: dispatch_async?
    if ([text length] < 3) {
        return nil;
    }
    NSMutableArray *suggestions = [NSMutableArray array];
    NSArray *stationRefArray = nil;
    if (self.searchingSubStations) {
        stationRefArray = [(AppDelegate *)[NSApp delegate] stationRefArray];
    } else {
        stationRefArray = self.refStations;
    }

    // Stop when we have 30 hits. Any more won't show up on most screens, and it'll speed things up.
    NSInteger count = 0;
    if ([[NSString class] instancesRespondToSelector:@selector(localizedStandardContainsString:)]) {
        for (XTStationRef *station in stationRefArray) {
            if ([station.title localizedStandardContainsString:text]) {
                [suggestions addObject:station];
                count++;
                if (count > 30) {
                    break;
                }
            }
       }
    }
    else {
         for (XTStationRef *station in stationRefArray) {
            NSRange range = [station.title rangeOfString:text options:NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                [suggestions addObject:station];
                count++;
                if (count > 30) {
                    break;
                }
            }
        }
    }
    return suggestions;
}

/* Update the field editor with a suggested string.
*/
- (void)updateFieldEditor:(NSText *)fieldEditor
           withAnnotation:(id<MKAnnotation>)annotation
{
    NSString *title = annotation.title;
    NSRange selection = NSMakeRange(0, [title length]);
    [fieldEditor setString:title];
    [fieldEditor setSelectedRange:selection];
}

- (void)updateSuggestionsWithText:(NSString *)text
{
    NSArray *suggestions = [self suggestionsForText:text];
    if ([suggestions count] > 0) {
        // We have at least 1 suggestion. Show the suggestions window.
        self.suggestion = [suggestions objectAtIndex:0];
        
        [self.suggestionsController setSuggestions:suggestions];
        if (![self.suggestionsController.window isVisible]) {
            [self.suggestionsController beginForTextField:self.searchField];
        }
    } else {
        // No suggestions. Cancel the suggestion window and set the suggestion to nil.
        self.suggestion = nil;
        [self.suggestionsController cancelSuggestions];
    }  
}

/* Determines the current list of suggestions, display the suggestions and update the field editor.
*/
- (void)updateSuggestionsFromControl:(NSControl *)control
{
    NSText *fieldEditor = [self.window fieldEditor:NO forObject:control];
    if (fieldEditor) {
        // Only use the text up to the caret position
        NSRange selection = [fieldEditor selectedRange];
        NSString *text = [[fieldEditor string] substringToIndex:selection.location];
        [self updateSuggestionsWithText:text];
    }
}

- (SuggestionsWindowController *)suggestionsController
{
    if (!_suggestionsController) {
        _suggestionsController = [[SuggestionsWindowController alloc] init];
        _suggestionsController.target = self;
        _suggestionsController.action = @selector(updateWithSelectedSuggestion:);
    }
    return _suggestionsController;
}

/* In interface builder, we set this class object as the delegate for the search text field. When the user starts editing the text field, this method is called. This is an opportune time to display the initial suggestions. 
*/
- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    [self updateSuggestionsFromControl:notification.object];
    self.editing = YES;
}

/* This is the action method for when the user changes the suggestion selection. Note, this action is called continuously as the suggestion selection changes while being tracked and does not denote user committal of the suggestion. For suggestion committal, the text field's action method is used (see above). This method is wired up programatically when suggestionsController is created.
*/
- (IBAction)updateWithSelectedSuggestion:(id)sender
{
    id<MKAnnotation> entry = [sender selectedSuggestion];
    if (entry) {
        NSText *fieldEditor = [self.window fieldEditor:NO forObject:self.searchField];
        if (fieldEditor) {
            //[self updateFieldEditor:fieldEditor withAnnotation:entry];
            self.suggestion = entry;
        }
    }
}

/* The field editor's text may have changed for a number of reasons. Generally, we should update the suggestions window with the new suggestions.
*/
- (void)controlTextDidChange:(NSNotification *)notification
{
    [self updateSuggestionsFromControl:notification.object];
}

/* The field editor has ended editing the text. This is not the same as the action from the NSTextField. In the MainMenu.xib, the search text field is setup to only send its action on return / enter. If the user tabs to or clicks on another control, text editing will end and this method is called. We don't consider this committal of the action. Instead, we realy on the text field's action (see -takeImageFromSuggestedURL: above) to commit the suggestion. However, since the action may not occur, we need to cancel the suggestions window here.
*/
- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    /* If the suggestionController is already in a cancelled state, this call does nothing and is therefore always safe to call.
    */
    self.editing = NO;
    [self.suggestionsController cancelSuggestions];
}

/* As the delegate for the NSTextField, this class is given a chance to respond to the key binding commands interpreted by the input manager when the field editor calls -interpretKeyEvents:. This is where we forward some of the keyboard commands to the suggestion window to facilitate keyboard navigation. Also, this is where we can determine when the user deletes and where we can prevent AppKit's auto completion.
*/
- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector
{
    //NSLog(@"%@", NSStringFromSelector(commandSelector));
    if (commandSelector == @selector(moveUp:)) {
        // Move up in the suggested selections list
        [self.suggestionsController moveUp:textView];
        return YES;
    }
    
    if (commandSelector == @selector(moveDown:)) {
        // Move down in the suggested selections list
        [self.suggestionsController moveDown:textView];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:)) {
        // If they pressed return/tab while it's not visible, make it visible.
        // If not, then they've been editing and want the selection.
        if ([self.suggestionsController.window isVisible]) {
            [self updateSelectionWithSuggestion];
            return NO;
        } else {
            [self updateSuggestionsWithText:[self.searchField stringValue]];
            return YES;
        }
    }
    
    if (commandSelector == @selector(complete:)) {
        // The user has pressed the key combination for auto completion. AppKit has a built in auto completion. By overriding this command we prevent AppKit's auto completion and can respond to the user's intention by showing or cancelling our custom suggestions window.
        if ([self.suggestionsController.window isVisible]) {
            [self.suggestionsController cancelSuggestions];
        } else {
            [self updateSuggestionsFromControl:control];
        }

        return YES;
    }
    
    // This is a command that we don't specifically handle, let the field editor do the appropriate thing.
    return NO;
}

- (NSArray<NSString *> *)control:(NSControl *)control
                        textView:(NSTextView *)textView
                     completions:(NSArray<NSString *> *)words
             forPartialWordRange:(NSRange)charRange
             indexOfSelectedItem:(NSInteger *)index
{
    //
    // http://stackoverflow.com/questions/3981439/how-to-prevent-nssearchfield-from-overwriting-entered-strings-using-the-first-au
    NSString *substring = [[textView string] substringWithRange:charRange];
    return @[substring];
}

#pragma mark observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if (   [keyPath isEqualToString:XTide_ColorKeys[refcolor]]
               || [keyPath isEqualToString:XTide_ColorKeys[subcolor]]) {
        NSLog(@"color kvo");
		if ([self updateColors]) {
            // Force all the annotation views to reload iff the colors changed.
            NSArray *oldAnnotations = self.mapView.annotations;
            [self.mapView removeAnnotations:oldAnnotations];
            [self.mapView addAnnotations:oldAnnotations];
        }
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}

@end
