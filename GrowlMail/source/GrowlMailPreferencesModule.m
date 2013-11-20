/*
 Copyright (c) 2011-2013, Rudy Richter.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MailHeaders.h"
#import "MessageFrameworkHeaders.h"

#import "GrowlMail.h"
#import "GrowlMailPreferencesModule.h"
#import "GrowlMailNotifier.h"
#import "GMSparkleController.h"
#import "GMUserDefaults.h"
#import "GMPreferenceConstants.h"

#import <Sparkle/Sparkle.h>

@interface GrowlMailPreferencesModule ()
@property (nonatomic, assign) IBOutlet NSUserDefaultsController *defaultsController;
@end

@implementation GrowlMailPreferencesModule

- (void) awakeFromNib 
{
    self.defaultsController = [GrowlMailNotifier sharedNotifier].userDefaultsController;

    [self.defaultsController.defaults addObserver:self forKeyPath:GMPrefEnabled options:NSKeyValueObservingOptionNew context:&self];
    [self.defaultsController.defaults addObserver:self forKeyPath:GMPrefInboxOnlyMode options:NSKeyValueObservingOptionNew context:&self];
    [self.defaultsController.defaults addObserver:self forKeyPath:GMPrefBackgroundOnlyMode options:NSKeyValueObservingOptionNew context:&self];

    [_descriptionTextView setFont:[NSFont systemFontOfSize:13.0f]];
    
	NSTableColumn *activeColumn = [_accountsView tableColumnWithIdentifier:@"active"];
	[[activeColumn dataCell] setImagePosition:NSImageOnly]; // center the checkbox
}

- (void)dealloc
{
    [self.defaultsController.defaults removeObserver:self forKeyPath:@"GMEnableGrowlMailBundle"];
    
    [super dealloc];
}

- (void) willBeDisplayed
{
    [self.accountsView reloadData];
}

- (NSString *) preferencesNibName
{
	return @"GrowlMailPreferencesPanel";
}

- (NSView *)preferencesView
{
	if (!_view_preferences)
		[[NSBundle bundleForClass:[self class]] loadNibNamed:[self preferencesNibName] owner:self topLevelObjects:nil];
	return _view_preferences;
}

- (NSString*)version
{
    return [NSString stringWithFormat:@"%@[%@]", [GMGetGrowlMailBundle() objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey], ([GMGetGrowlMailBundle() objectForInfoDictionaryKey:@"BRCommitHash"]?:@"Local Changes")];
}

- (id) viewForPreferenceNamed:(NSString *)aName
{
#pragma unused(aName)
	return [self preferencesView];
}

- (NSString *) titleForIdentifier:(NSString *)aName 
{
#pragma unused(aName)
	return @"GrowlMail";
}

- (NSImage *) imageForPreferenceNamed:(NSString *)aName 
{
	return [NSImage imageNamed:aName];
}

- (NSSize) minSize 
{
	return [[self preferencesView] frame].size;
}

- (BOOL) isResizable 
{
	return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:GMPrefEnabled])
    {
        BOOL enabled = [self.defaultsController.defaults boolForKey:GMPrefEnabled];
        [self enableTextView:enabled];
    }
    else if([keyPath isEqualToString:GMPrefInboxOnlyMode])
    {
        [self.accountsView reloadData];
    }
    else if([keyPath isEqualToString:GMPrefBackgroundOnlyMode])
    {
        BOOL backgroundOnly = [self.defaultsController.defaults boolForKey:GMPrefBackgroundOnlyMode];
        [[GrowlMailNotifier sharedNotifier] configureForBackgroundOnly:backgroundOnly];
    }
}

-(void)enableTextView:(BOOL)enableIt
{
    [_descriptionTextView setSelectable: enableIt];
    [_descriptionTextView setEditable: enableIt];
    if (enableIt)
        [_descriptionTextView setTextColor: [NSColor controlTextColor]];
    else
        [_descriptionTextView setTextColor: [NSColor disabledControlTextColor]];
}

- (BOOL)inboxOnly
{
    return ![self.defaultsController.defaults boolForKey:GMPrefInboxOnlyMode];
}

#pragma mark - Sparkle

- (IBAction)checkForUpdates:(id)sender
{
    [[GMSparkleController sharedController] checkForUpdates:sender];
}

- (IBAction)setCheckInterval:(id)sender
{
    NSPopUpButton *button = (NSPopUpButton*)sender;
    NSMenuItem *item = [button selectedItem];
    NSTimeInterval time = [item tag];
    [[GMSparkleController sharedController] setUpdateCheckInterval:time];
}


#pragma mark - NSTableViewDelegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    Class mailAccountClass = NSClassFromString(GM_MailAccount);
	NSInteger count = 0;
    
    if(!item)
        count = [[[GrowlMailNotifier sharedNotifier] enabledRemoteAccounts] count];
    else if([item isKindOfClass:mailAccountClass])
        count = [[[GrowlMailNotifier sharedNotifier] mailboxesForAccount:item] count];
    return count;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    BOOL expandable = NO;
    if([[[GrowlMailNotifier sharedNotifier] enabledRemoteAccounts] containsObject:item] && [self inboxOnly])
    {
        expandable = YES;
    }
    return expandable;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    Class mailAccountClass = NSClassFromString(GM_MailAccount);

    id child = nil;
    if(!item)
    {
        child = [[[GrowlMailNotifier sharedNotifier] enabledRemoteAccounts] objectAtIndex:index];
    }
    else if([item isKindOfClass:mailAccountClass] && [self inboxOnly])
    {
        NSArray *mailboxes = [[GrowlMailNotifier sharedNotifier] mailboxesForAccount:item];
        child = [mailboxes objectAtIndex:index];
    }
    return child;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id objectValue = nil;
	id account = item;
	if ([[tableColumn identifier] isEqualToString:@"active"])
    {
		objectValue = [NSNumber numberWithInteger:[[GrowlMailNotifier sharedNotifier] accountState:account]];
	}
    else
        if([account respondsToSelector:@selector(mailboxName)])
        {
            NSString *displayName = [account mailboxName];
            if([displayName isEqualToString:@"INBOX"])
                displayName = @"Inbox";
            objectValue = displayName;
        }
        else
            objectValue = [account displayName];
    return objectValue;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	id account = item;
	[[GrowlMailNotifier sharedNotifier] setAccount:account enabled:[object boolValue]];
    [outlineView reloadData];
}

@end
