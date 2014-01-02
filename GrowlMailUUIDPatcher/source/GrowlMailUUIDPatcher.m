//
//  GrowlMailUUIDPatcher.m
//  GrowlMailUUIDPatcher
//
//  Copyright 2010–2011 The Growl Project. All rights reserved.
//

#import "GrowlMailUUIDPatcher.h"

#import "GrowlMailFoundBundle.h"
#import "GrowlMailWarningNote.h"

#include "GrowlVersionUtilities.h"

#import <objc/runtime.h>

NSString *mailAppBundleID = @"com.apple.mail";

@interface GrowlMailUUIDPatcher () <NSTableViewDelegate>

//Returns the selected bundle or nil if none is selected.
- (GrowlMailFoundBundle *) selectedBundle;

- (void) recomputeSelectedBundleNotes;

- (void) applyChangeToFoundBundle:(GrowlMailFoundBundle *)bundle;

- (NSButton *) buttonInWindow:(NSWindow *)window withAction:(SEL)action;
- (NSButton *) buttonDescendantOfView:(NSView *)view withAction:(SEL)action;
- (void) enableOKButton:(NSTimer *)timer;

@end

#define BUTTON_ENABLING_DELAY 15.0 /*seconds*/

//This is due to be replaced by an appcast, as soon as we work out how we want to do that.
static NSString *const hardCodedGrowlMailCurrentVersionNumber = @"1.3.4";

@implementation GrowlMailUUIDPatcher

@synthesize selectedBundleIndexes;
@synthesize warningNotes;
@synthesize window;
@synthesize warningNotesTable;
@synthesize confirmationSheet;
@synthesize growlMailFoundBundles;

+ (NSSet *) keyPathsForValuesAffectingMultipleGrowlMailsInstalled {
	return [NSSet setWithObject:@"growlMailFoundBundles"];
}

+ (NSSet *) keyPathsForValuesAffectingCanAndShouldPatchSelectedBundle {
	return [NSSet setWithObject:@"selectedBundleIndexes"];
}

- (id) init {
	if ((self = [super init])) {
		growlMailFoundBundles = [[NSMutableArray alloc] init];

		NSArray *libraryFolders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
		for (NSString *libraryPath in libraryFolders) {
			NSString *mailFolderPath = [libraryPath stringByAppendingPathComponent:@"Mail"];
			NSString *bundlesFolderPath = [mailFolderPath stringByAppendingPathComponent:@"Bundles"];
			NSString *growlMailBundlePath = [bundlesFolderPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"];

			NSURL *growlMailBundleURL = [NSURL fileURLWithPath:growlMailBundlePath];
			if ([growlMailBundleURL checkResourceIsReachableAndReturnError:NULL]) {
				[growlMailFoundBundles addObject:[GrowlMailFoundBundle foundBundleWithURL:growlMailBundleURL]];
			}
            
			bundlesFolderPath = [mailFolderPath stringByAppendingPathComponent:@"Bundles (Disabled)"];
			growlMailBundlePath = [bundlesFolderPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"];
            
			growlMailBundleURL = [NSURL fileURLWithPath:growlMailBundlePath];
			if ([growlMailBundleURL checkResourceIsReachableAndReturnError:NULL]) {
				[growlMailFoundBundles addObject:[GrowlMailFoundBundle foundBundleWithURL:growlMailBundleURL]];
			}

		}

		if ([growlMailFoundBundles count] > 0UL) {
			selectedBundleIndexes = [[NSIndexSet indexSetWithIndex:0UL] copy];
		} else {
			selectedBundleIndexes = [[NSIndexSet indexSet] copy];
		}

		NSBundle *mailAppBundle = [NSBundle bundleWithPath:@"/Applications/Mail.app"];
		NSBundle *messageFrameworkBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/Message.framework"];
		mailUUID = [[mailAppBundle objectForInfoDictionaryKey:@"PluginCompatibilityUUID"] copy];
		messageFrameworkUUID = [[messageFrameworkBundle objectForInfoDictionaryKey:@"PluginCompatibilityUUID"] copy];

		currentVersionOfGrowlMail = [hardCodedGrowlMailCurrentVersionNumber copy];

		[NSBundle loadNibNamed:@"GrowlMailBundles" owner:self];
		
		[self recomputeSelectedBundleNotes];
		[warningNotesTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	}
	return self;
}

- (void) dealloc {
	[delayedEnableTimer invalidate];
	[delayedEnableTimer release];
	[confirmationSheet close];
	[confirmationSheet release];
	[window close];
	[window release];

	[growlMailFoundBundles release];

	[mailUUID release];
	[messageFrameworkUUID release];

	[super dealloc];
}

- (BOOL) multipleGrowlMailsInstalled {
	return [growlMailFoundBundles count] > 1UL;
}

- (void) setGrowlMailFoundBundles:(NSArray *)newBundles {
	[growlMailFoundBundles setArray:newBundles];
}

- (void) setSelectedBundleIndexes:(NSIndexSet *)newIndexes {
	[selectedBundleIndexes autorelease];
	selectedBundleIndexes = [newIndexes copy];

	[self recomputeSelectedBundleNotes];
}

- (BOOL) canAndShouldPatchSelectedBundle {
	return self.selectedBundle && (!self.selectedBundle.isCompatibleWithCurrentMailAndMessageFramework) && ([[self.warningNotes valueForKeyPath:@"@sum.fatal"] unsignedIntegerValue] == 0UL);
}

- (void) recomputeSelectedBundleNotes {
	GrowlMailFoundBundle *selectedBundle = self.selectedBundle;
	NSMutableArray *newNotes = [NSMutableArray array];

	if ([self.growlMailFoundBundles count] > 1UL) {
		[newNotes addObject:[GrowlMailWarningNote warningNoteForMultipleGrowlMailsWithCurrentVersion:currentVersionOfGrowlMail]];
	}
	if (selectedBundle) {
		if (compareVersionStrings(selectedBundle.bundleVersion, currentVersionOfGrowlMail) == kCFCompareLessThan) {
			[newNotes addObject:[GrowlMailWarningNote warningNoteForGrowlMailOlderThanCurrentVersion:currentVersionOfGrowlMail]];
		}
		if (selectedBundle.domain != NSUserDomainMask) {
			[newNotes addObject:[GrowlMailWarningNote warningNoteForGrowlMailInTheWrongPlace]];
		}
	}

	self.warningNotes = newNotes;

	//Recompute window size.
	NSView *scrollView = [warningNotesTable superview];
	NSRect tableFrameInWindowSpace = [scrollView convertRect:[scrollView bounds] toView:nil];
	NSRect windowFrame = [window frame];
	CGFloat heightOfWindow = windowFrame.size.height;
	CGFloat heightBelow = NSMinY(tableFrameInWindowSpace);
	CGFloat heightAbove = heightOfWindow - NSMaxY(tableFrameInWindowSpace);

	CGFloat newHeightOfTable = 0.0f;
	for (NSUInteger i = 0UL, numNotes = [warningNotes count]; i < numNotes; ++i) {
		newHeightOfTable += [self tableView:warningNotesTable heightOfRow:i];
	}
	if (newHeightOfTable < 1.0f)
		newHeightOfTable = 1.0f;
	else {
		//Icky fudge factor to avoid the descent of the last line of the last row being cut off in some cases.
		newHeightOfTable += 4.0f;
	}

	CGFloat newHeightOfWindow = heightAbove + newHeightOfTable + heightBelow;
	CGFloat windowTop = windowFrame.origin.y + windowFrame.size.height;
	windowFrame.size.height = newHeightOfWindow;
	windowFrame.origin.y = windowTop - newHeightOfWindow;
	[window setFrame:windowFrame display:YES animate:YES];
}

- (GrowlMailFoundBundle *) selectedBundle {
	return ([self.selectedBundleIndexes count] == 1UL)
		? [self.growlMailFoundBundles objectAtIndex:[self.selectedBundleIndexes firstIndex]]
		: nil;
}

//Ensure that the warning notes table never has a selection.
- (NSIndexSet *) selectionIndexesOfWarningNotes {
	return [NSIndexSet indexSet];
}
- (void) setSelectionIndexesOfWarningNotes:(NSIndexSet *)newIndexes {
	//Do nothing, successfully.
	//The only reason this is here is because NSArrayController hates being bound to this property if there's no setter.
}

- (void) applyChangeToFoundBundle:(GrowlMailFoundBundle *)bundle {
	NSParameterAssert(bundle != nil);
	NSParameterAssert([bundle isKindOfClass:[GrowlMailFoundBundle class]]);

	NSURL *bundleURL = bundle.URL;
	NSURL *infoDictURL = [[bundleURL URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];

	NSInputStream *inStream = [NSInputStream inputStreamWithURL:infoDictURL];
	NSError *error = nil;
	NSPropertyListFormat format = 0;
	[inStream open];
	NSMutableDictionary *dict = [NSPropertyListSerialization propertyListWithStream:inStream
																			options:NSPropertyListMutableContainers
																			 format:&format
																			  error:&error];
	[inStream close];
	if (!dict) {
		[window presentError:error];
	} else {
		NSMutableArray *UUIDs = [dict objectForKey:@"SupportedPluginCompatibilityUUIDs"];
		if(!UUIDs)
        {
            [dict setValue:[NSMutableArray array] forKey:@"SupportedPluginCompatibilityUUIDs"];
            UUIDs = [dict objectForKey:@"SupportedPluginCompatibilityUUIDs"];
        }
        if (mailUUID && ![UUIDs containsObject:mailUUID])
			[UUIDs addObject:mailUUID];
		if (messageFrameworkUUID && ![UUIDs containsObject:messageFrameworkUUID])
			[UUIDs addObject:messageFrameworkUUID];

		NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict
																  format:format
																 options:0
																   error:&error];
		if (!data) {
			[window presentError:error];
		} else {
			[self willChangeValueForKey:@"canAndShouldPatchSelectedBundle"];
			[bundle willChangeValueForKey:@"isCompatibleWithCurrentMailAndMessageFramework"];
			BOOL wrote = [data writeToURL:infoDictURL
								  options:NSDataWritingAtomic
									error:&error];
			[bundle didChangeValueForKey:@"isCompatibleWithCurrentMailAndMessageFramework"];
			[self didChangeValueForKey:@"canAndShouldPatchSelectedBundle"];
			if (!wrote) {
				[window presentError:error];
			}
		}
	}

}

static Class buttonClass = Nil;
- (NSButton *) buttonInWindow:(NSWindow *)windowToSearch withAction:(SEL)action {
	if (!buttonClass)
		buttonClass = [NSButton class];
	return [self buttonDescendantOfView:[windowToSearch contentView] withAction:action];
}
//Note: buttonDescendantOfView:withAction: won't work unless buttonInWindow:withAction: has been called previously (since it initializes the buttonClass variable).
- (NSButton *) buttonDescendantOfView:(NSView *)view withAction:(SEL)action {
	if ([view isKindOfClass:buttonClass]) {
		NSButton *button = (NSButton *)view;
		if (sel_isEqual([button action], action))
			return button;
	}

	for (NSView *subview in [view subviews]) {
		NSButton *foundButton = [self buttonDescendantOfView:subview withAction:action];
		if (foundButton)
			return foundButton;
	}

	return nil;
}

- (IBAction) patchSelectedBundle:(id)sender {
	//First, find the OK button, disable it, and prepare to enable it in some number of seconds.
	//We search out the button rather than use an outlet so that the user cannot simply enable the button and disconnect the outlet.
	okButton = [self buttonInWindow:confirmationSheet withAction:@selector(ok:)]; //Not retained because the window's view hierarchy owns it
	[okButton setEnabled:NO];
    
	[delayedEnableTimer invalidate];
	[delayedEnableTimer release];
	
    if([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
    {
        [self enableOKButton:nil];
    }
    else
    {
        delayedEnableTimer = [[NSTimer scheduledTimerWithTimeInterval:BUTTON_ENABLING_DELAY target:self selector:@selector(enableOKButton:) userInfo:nil repeats:NO] retain];
	}
    [NSApp beginSheet:confirmationSheet modalForWindow:window modalDelegate:self didEndSelector:@selector(confirmationSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void) enableOKButton:(NSTimer *)timer {
	[okButton setEnabled:YES];
}
- (void) confirmationSheetDidEnd:(NSWindow *)sheet
					  returnCode:(NSInteger)returnCode
					 contextInfo:(void *)contextInfo
{
	[delayedEnableTimer invalidate];
	[delayedEnableTimer release];
	delayedEnableTimer = nil;

	if (returnCode == NSOKButton) {
		[self applyChangeToFoundBundle:self.selectedBundle];
        [self moveBundleBackToActiveLocation:[NSBundle bundleWithPath:self.selectedBundle.URL.path]];
        [self relaunchMail];
	}

	[sheet close];
}

- (IBAction) ok:(id) sender {
	NSWindow *dialog = [sender respondsToSelector:@selector(window)] ? [sender window] : sender;
	[NSApp endSheet:dialog returnCode:NSOKButton];
}
- (IBAction) cancel:(id) sender {
	NSWindow *dialog = [sender respondsToSelector:@selector(window)] ? [sender window] : sender;
	[NSApp endSheet:dialog returnCode:NSCancelButton];
}

- (BOOL)moveBundleBackToActiveLocation:(NSBundle*)chosenOne
{
    BOOL result = YES;
    NSString *path = [chosenOne bundlePath];
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    NSString *destinationPath = [parentPath stringByDeletingLastPathComponent];
    
    if(![[parentPath lastPathComponent] isEqualToString:@"Bundles"])
    {
        destinationPath = [destinationPath stringByAppendingPathComponent:@"Bundles"];
        BOOL dir = NO;
        NSError *error = nil;
        if(![[NSFileManager defaultManager] fileExistsAtPath:destinationPath isDirectory:&dir] || !dir)
            [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:&error];
        
        if(error)
            result = NO;
        
        if(result)
            [[NSFileManager defaultManager] moveItemAtPath:[chosenOne bundlePath] toPath:[destinationPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"] error:&error];
        
        if(error)
            result = NO;
    }
    else
        result = NO;
    
    return result;
}

- (BOOL)mailIsRunning
{
	BOOL result = NO;
	NSArray *applications = [[NSWorkspace sharedWorkspace] runningApplications];
	for(NSRunningApplication *application in applications)
	{
		if([[application bundleIdentifier] isEqualToString:@"com.apple.mail"])
		{	
			result = YES;
			break;
		}
	}
	return result;
}

- (void)relaunchMail
{
    NSArray *applications = [[NSWorkspace sharedWorkspace] runningApplications];
    for(NSRunningApplication *application in applications)
    {
        if([[application bundleIdentifier] isEqualToString:mailAppBundleID])
        {	
            [application retain];
            [application addObserver:self forKeyPath:@"terminated" options:NSKeyValueObservingOptionNew context:self];
            if([application terminate])
            {
                [application removeObserver:self forKeyPath:@"terminated"];
                [application release];
                [[NSWorkspace sharedWorkspace] performSelector:@selector(launchApplication:) withObject:@"Mail.app" afterDelay:2.0f];
            }
        }
    }
}

#pragma mark NSTableViewDelegate protocol conformance

- (CGFloat) tableView:(NSTableView *)theTableView heightOfRow:(NSInteger)row {
	CGFloat height = [warningNotesTable rowHeight];
	/*This code is adapted from an Apple code sample:
	 *	http://developer.apple.com/mac/library/samplecode/CocoaTipsAndTricks/Listings/TableViewVariableRowHeights_TableViewVariableRowHeightsAppDelegate_m.html
	 *It is more reliable than measuring the text directly. Thanks to Jesper for telling me about it. -PRH
	 */ {
		// It is important to use a constant value when calculating the height. Querying the tableColumn width will not work, since it dynamically changes as the user resizes -- however, we don't get a notification that the user "did resize" it until after the mouse is let go. We use the latter as a hook for telling the table that the heights changed. We must return the same height from this method every time, until we tell the table the heights have changed. Not doing so will quicly cause drawing problems.
		NSString *tableColumnIdentifier = @"message";
		NSTableColumn *tableColumnToWrap = [warningNotesTable tableColumnWithIdentifier:tableColumnIdentifier];
		NSInteger columnToWrap = [warningNotesTable.tableColumns indexOfObject:tableColumnToWrap];

		// Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
		NSCell *cell = [warningNotesTable preparedCellAtColumn:columnToWrap row:row];

		// See how tall it naturally would want to be if given a restricted with, but unbound height
		NSRect constrainedBounds = NSMakeRect(0, 0, [[warningNotesTable tableColumnWithIdentifier:tableColumnIdentifier] width], CGFLOAT_MAX);
		NSSize naturalSize = [cell cellSizeForBounds:constrainedBounds];

		// Make sure we have a minimum height -- use the table's set height as the minimum.
		if (naturalSize.height > height) {
			height = naturalSize.height;
		}
	}
	
	CGFloat iconColumnWidth = [[theTableView tableColumnWithIdentifier:@"fatality"] width];
	if (height < iconColumnWidth)
		height = iconColumnWidth;
	return height;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes {
	//Never allow any selection.
	return [NSIndexSet indexSet];
}

@end
