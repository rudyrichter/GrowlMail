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

#import <Sparkle/Sparkle.h>

@interface GrowlMailPreferencesModule ()
@property (nonatomic, assign) IBOutlet NSUserDefaultsController *defaultsController;
@end

@implementation GrowlMailPreferencesModule

- (void) awakeFromNib 
{
    self.defaultsController = [GrowlMailNotifier sharedNotifier].userDefaultsController;

    [self.defaultsController.defaults addObserver:self forKeyPath:@"GMEnableGrowlMailBundle" options:NSKeyValueObservingOptionNew context:&self];
    [_descriptionTextView setFont:[NSFont systemFontOfSize:13.0f]];
    
	NSTableColumn *activeColumn = [_accountsView tableColumnWithIdentifier:@"active"];
	[[activeColumn dataCell] setImagePosition:NSImageOnly]; // center the checkbox
}

- (void)dealloc
{
    [self.defaultsController.defaults removeObserver:self forKeyPath:@"GMEnableGrowlMailBundle"];
    
    [super dealloc];
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
    return [GMGetGrowlMailBundle() objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
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
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"GMEnableGrowlMailBundle"])
    {
        [self enableTextView:[self.defaultsController.defaults boolForKey:@"GMEnableGrowlMailBundle"]];
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

- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView 
{
	return [[NSClassFromString(GM_MailAccount) remoteAccounts] count];
}

- (IBAction)checkForUpdates:(id)sender
{
    [[GMSparkleController sharedController] checkForUpdates:sender];
}

- (IBAction)changeBackgroundOnlyMode:(id)sender 
{
	[[GrowlMailNotifier sharedNotifier] configureForBackgroundOnly:[sender state]];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex 
{
#pragma unused(aTableView)
	id account = [[NSClassFromString(GM_MailAccount) remoteAccounts] objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:@"active"])
		return [NSNumber numberWithBool:[[GrowlMailNotifier sharedNotifier] isAccountEnabled:account]];
	else
		return [account displayName];
}

- (void) tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex 
{
#pragma unused(aTableView,aTableColumn)
	id account = [[NSClassFromString(GM_MailAccount) remoteAccounts] objectAtIndex:rowIndex];
	[[GrowlMailNotifier sharedNotifier] setAccount:account enabled:[anObject boolValue]];
}

- (IBAction)setCheckInterval:(id)sender
{
    NSPopUpButton *button = (NSPopUpButton*)sender;
    NSMenuItem *item = [button selectedItem];
    NSTimeInterval time = [item tag];
    [[GMSparkleController sharedController] setUpdateCheckInterval:time];
}
@end
