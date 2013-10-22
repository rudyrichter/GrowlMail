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


#import "GrowlMailNotifier.h"
#import "GrowlMail.h"
#import "Message+GrowlMail.h"
#import <objc/objc-runtime.h>
#import "MailHeaders.h"
#import "MessageFrameworkHeaders.h"
#import "GMUserDefaults.h"

#define AUTO_THRESHOLD	10
#define	MAX_NOTIFICATION_THREADS	5

static int activeNotificationThreads = 0;
static int messageCopies = 0;
static GrowlMailNotifier *sharedNotifier = nil;
static BOOL notifierEnabled = YES;

@interface GrowlMailNotifier ()
@end

@implementation GrowlMailNotifier

#pragma mark Panic buttons

//The purpose of this method is to shut down GrowlMail completely: we should not be notified of any messages, nor notify the user of any messages, after this message is called.
- (void) shutDownGrowlMail 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[GrowlApplicationBridge setGrowlDelegate:nil];
}

#pragma mark The circle of life

+ (id) sharedNotifier 
{
	if (!sharedNotifier) 
    {
		//-init and -dealloc will each assign to sharedNotifier.
		sharedNotifier = [[GrowlMailNotifier alloc] init];
	}
	return sharedNotifier;
}

- (id) init 
{
	if (sharedNotifier) 
    {
		[self release];
		return [sharedNotifier retain];
	}

	//No shared notifier yet; someone is trying to create one. If we previously disabled ourselves, abort this attempt.
	if (!notifierEnabled) 
    {
		[self release];
		return nil;
	}

	if((self = [super init])) 
    {
		NSNumber *automatic = [NSNumber numberWithInt:GrowlMailSummaryModeAutomatic];
		NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			@"(%account) %sender",         @"GMTitleFormat",
			@"%subject\n%body",            @"GMDescriptionFormat",
			automatic,                     @"GMSummaryMode",
			[NSNumber numberWithBool:YES], @"GMEnableGrowlMailBundle",
			[NSNumber numberWithBool:NO],  @"GMInboxOnly",
			[NSNumber numberWithBool:YES], @"GMBackgroundOnly",
			nil];
        GMUserDefaults *defaults = [[[GMUserDefaults alloc] initWithPersistentDomainName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]] autorelease];

		[defaults registerDefaults:defaultsDictionary];
        [defaults synchronize];
        
        //make sure our shared user defaults controller is set to use our domain for preferences
        self.userDefaultsController = [[[NSUserDefaultsController alloc] initWithDefaults:defaults initialValues:defaultsDictionary] autorelease];

		[GrowlApplicationBridge setGrowlDelegate:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(messageStoreDidAddMessages:)
													 name:@"MessageStoreMessagesAdded"
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(monitoredActivityStarted:)
													 name:@"MonitoredActivityStarted_inMainThread_"
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(monitoredActivityEnded:)
													 name:@"MonitoredActivityEnded_inMainThread_"
												   object:nil];
		//If the user wants to they can disable notifications for when Mail.app is in the foreground
		
		shouldNotify = YES;
		if([self isBackgroundOnlyEnabled])
			shouldNotify = ![NSApp isActive];
		[self configureForBackgroundOnly:[self isBackgroundOnlyEnabled]];

#ifdef GROWL_MAIL_DEBUG
		//[self informationSpew];
//        [[NSNotificationCenter defaultCenter] addObserver:self
//										 selector:@selector(showAllNotifications:)
//											 name:nil object:nil];
#endif
		sharedNotifier = self;
	}
	return self;
}

- (void) dealloc 
{
	[self shutDownGrowlMail];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[sharedNotifier release];
	sharedNotifier = nil;

	[super dealloc];
}

#pragma mark GrowlApplicationBridge delegate methods

- (NSString *) applicationNameForGrowl 
{
	return @"GrowlMail";
}

- (NSImage *) applicationIconForGrowl 
{
	return [NSImage imageNamed:@"NSApplicationIcon"];
}

- (void) growlNotificationWasClicked:(NSString *)clickContext 
{
	if ([clickContext length]) 
    {
		//Make sure we have all the methods we need.
		Class singleMessageViewerClass = NSClassFromString(GM_SingleMessageViewer);
        Class libraryClass = NSClassFromString(GM_Library);
        
		if (!class_getClassMethod(singleMessageViewerClass, @selector(viewerForMessage:hiddenCopies:relatedMessages:showRelatedMessages:showAllHeaders:expandedSelectedMailboxes:)))
			GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to +viewerForMessage:hiddenCopies:relatedMessages:showRelatedMessages:showAllHeaders:viewingState:expandedSelectedMailboxes:");
		if (!class_getInstanceMethod(singleMessageViewerClass, @selector(showAndMakeKey:)))
			GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to -showAndMakeKey:");
        
        if(!class_getClassMethod(libraryClass, @selector(markMessageAsViewed:viewedDate:)))
            GMShutDownGrowlMailAndWarn(@"Library does not respond to +markMessageAsViewed:viewedDate:");
        if(!class_getClassMethod(libraryClass, @selector(messageWithMessageID:)))
            GMShutDownGrowlMailAndWarn(@"Library does not respond to +messageWithMessageID:");
        
		id message = [libraryClass messageWithMessageID:clickContext];
		id messageViewer = nil;
		
        if (class_getClassMethod(singleMessageViewerClass, @selector(viewerForMessage:hiddenCopies:relatedMessages:showRelatedMessages:showAllHeaders:expandedSelectedMailboxes:)))
            messageViewer = [singleMessageViewerClass viewerForMessage:message hiddenCopies:nil relatedMessages:nil showRelatedMessages:NO showAllHeaders:NO expandedSelectedMailboxes:nil];
        
        [NSApp activateIgnoringOtherApps:YES];
		[messageViewer showAndMakeKey:YES];
		[libraryClass markMessageAsViewed:message viewedDate:[NSDate date]];
	}
}

- (NSDictionary *) registrationDictionaryForGrowl 
{
	// Register our ticket with Growl
	NSArray *allowedNotifications = [NSArray arrayWithObjects:
		NEW_MAIL_NOTIFICATION,
		NEW_JUNK_MAIL_NOTIFICATION,
		NEW_NOTE_NOTIFICATION,
		nil];
	NSDictionary *humanReadableNames = [NSDictionary dictionaryWithObjectsAndKeys:
										NSLocalizedStringFromTableInBundle(@"New mail", nil, GMGetGrowlMailBundle(), ""), NEW_MAIL_NOTIFICATION,
										NSLocalizedStringFromTableInBundle(@"New junk mail", nil, GMGetGrowlMailBundle(), ""), NEW_JUNK_MAIL_NOTIFICATION,
										NSLocalizedStringFromTableInBundle(@"New note", nil, GMGetGrowlMailBundle(), ""), NEW_NOTE_NOTIFICATION,
										nil];
	NSArray *defaultNotifications = [NSArray arrayWithObject:NEW_MAIL_NOTIFICATION];

	NSDictionary *ticket = [NSDictionary dictionaryWithObjectsAndKeys:
		allowedNotifications, GROWL_NOTIFICATIONS_ALL,
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		humanReadableNames, GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES,
                            [self applicationNameForGrowl], GROWL_APP_NAME,
		nil];

	return ticket;
}

- (BOOL)hasNetworkClientEntitlement
{
    return YES;
}

#pragma mark Mail notification handlers

+ (void)showNotificationForMessage:(id)message
{
	if (activeNotificationThreads < MAX_NOTIFICATION_THREADS) 
    { 
		activeNotificationThreads++;
		
		/* Why use a thread?
		 *
		 * If we want the message body, it may not be immediately available.
		 * It can be retrieved without blocking if it's available, which we initially try.
		 * However, if we really, really want it, we may have to request it in a blocking fashion:
		 *		for example, if the user doesn't read the message and doesn't have Mail set to download it automatically,
		 *		we'll never get it without blocking.
		 *
		 * Blocking the main thread is, of course, out of the question.
		 *
		 * We're making some assumptions about Mail's internals, but the fact that notifications are posted on auxiliary threads
		 * and then again with a _inMainThread_ suffix on the main thread indicates that threads are being used for mail access elsewhere.
		 */
		[NSThread detachNewThreadSelector:@selector(GMShowNotificationPart1)
								 toTarget:message
							   withObject:nil];
	} 
    else 
    {
		[self performSelector:@selector(showNotificationForMessage:)
				   withObject:message
				   afterDelay:2.0];
	}
}

- (void)didFinishNotificationForMessage:(/*Message **/id)message
{
#pragma unused(message)
	activeNotificationThreads--;	
}

- (void)messageStoreDidAddMessages:(NSNotification *)notification 
{
	if (![self isEnabled]) 
        return;
	if(!shouldNotify && [self isBackgroundOnlyEnabled]) 
        return;
		
	if (messageCopies) 
    {
#ifdef GROWL_MAIL_DEBUG
		NSLog(@"Ignoring because %i message copies are in process", messageCopies);
#endif
		return;
	}

	id store = [notification object];
	if (!store) 
    {
		GMShutDownGrowlMailAndWarn([NSString stringWithFormat:@"'%@' notification has no object", [notification name]]);
	}
	/*if ([store isKindOfClass:[LibraryStore class]]) 
     {
		//As of Tiger, this is normal; this notification is posted a couple times (perhaps once per inbox) with a LibraryStore object.
		//This is not the notification we're looking for; we don't need to see its papers. We will move along now.
		return;
	}*/   
    
	NSDictionary *userInfo = [notification userInfo];
	if (!userInfo) 
        GMShutDownGrowlMailAndWarn(@"Notification had no userInfo");
    
    //we return if they were added during Mail.app launching.
    if([[userInfo objectForKey:@"MessageStoreMessagesAddedDuringOpen"] boolValue])
        return;
    
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s called: %@", __PRETTY_FUNCTION__, [notification userInfo]);
#endif
    NSArray *mailboxes = nil;
    id mailBox = nil;
    if([store respondsToSelector:@selector(mailbox)])
    {
        mailBox = [store performSelector:@selector(mailbox)];
    }
    if([mailBox respondsToSelector:@selector(isStore)] && [mailBox respondsToSelector:@selector(isSmartMailbox)])
        if([mailBox isStore] && ![mailBox isSmartMailbox])
            mailboxes = [NSArray arrayWithObject:mailBox];

#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Adding messages to mailboxes %@", __PRETTY_FUNCTION__, mailboxes);
#endif

	//As of Tiger, it's normal for about half of these notifications to not have any mailboxes. We simply ignore the notification in this case.
	if (!(mailboxes && [mailboxes count])) 
        return;

	//Ignore a notification if we're ignoring all of the mailboxes involved.
	Class MailAccount_class = NSClassFromString(GM_MailAccount);
	if (!class_getClassMethod(MailAccount_class, @selector(draftMailboxes)))
		GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +draftMailboxUids");
	if (!class_getClassMethod(MailAccount_class, @selector(outboxMailboxes)))
		GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +outboxMailboxUids");
	if (!class_getClassMethod(MailAccount_class, @selector(sentMessagesMailboxes)))
		GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +sentMessagesMailboxUids");
	if (!class_getClassMethod(MailAccount_class, @selector(trashMailboxes)))
		GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +trashMailboxUids");
	//We need this method to support the Inbox Only preference.
	if (!class_getClassMethod(MailAccount_class, @selector(inboxMailboxes)))
		GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +inboxMailboxUids");

	//Ignore messages being written.
	NSMutableSet *mailboxesToIgnore = [NSMutableSet setWithArray:[MailAccount_class draftMailboxes]];
	//Ignore messages being sent.
	[mailboxesToIgnore unionSet:[NSSet setWithArray:[MailAccount_class outboxMailboxes]]];
	[mailboxesToIgnore unionSet:[NSSet setWithArray:[MailAccount_class sentMessagesMailboxes]]];
	//Ignore messages being deleted.
	[mailboxesToIgnore unionSet:[NSSet setWithArray:[MailAccount_class trashMailboxes]]];

	NSSet *mailboxesSet = [NSSet setWithArray:mailboxes];
	NSMutableSet *mailboxesNotIgnored = [[mailboxesSet mutableCopy] autorelease];
	[mailboxesNotIgnored minusSet:mailboxesToIgnore];
	if ([mailboxesNotIgnored count] == 0U)
		return;

	NSArray *messages = [userInfo objectForKey:@"messages"];
	if (!messages) 
        GMShutDownGrowlMailAndWarn(@"Notification's userInfo has no messages");
	
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Mail added messages [1] to mailboxes [2].\n[1]: %@\n[2]: %@", __PRETTY_FUNCTION__, messages, mailboxes);
#endif
	
	NSUInteger count = [messages count];

	GrowlMailSummaryMode summaryMode = [self summaryMode];
	if (summaryMode == GrowlMailSummaryModeAutomatic) 
    {
		if (count >= AUTO_THRESHOLD)
			summaryMode = GrowlMailSummaryModeAlways;
		else
			summaryMode = GrowlMailSummaryModeDisabled;
	}

#ifdef GROWL_MAIL_DEBUG
	NSLog(@"Got %d new messages. Summary mode was %d and is now %d", (int)count, (int)[self summaryMode], (int)summaryMode);
#endif

	Class Message_class = NSClassFromString(GM_Message);

	switch (summaryMode) 
    {
		default:
		case GrowlMailSummaryModeDisabled: 
        {
			NSEnumerator *messagesEnum = [messages objectEnumerator];
			id message;
			while ((message = [messagesEnum nextObject])) {
				id mailbox = [message mailbox];
				//If this mailbox is not an inbox, and we only care about inboxes, then skip this message.
				if ([self inboxOnly] && ![[MailAccount_class inboxMailboxes] containsObject:mailbox])
					continue;

				id account = [mailbox account];
				if (![self isAccountEnabled:account])
					continue;

				if (![message isKindOfClass:Message_class])
					GMShutDownGrowlMailAndWarn([NSString stringWithFormat:@"Message in notification was not a Message; it is %@", message]);

				if (![message respondsToSelector:@selector(isRead)] || ![message isRead]) {
					/* Don't display read messages */
					[[self class] showNotificationForMessage:message];
				}
			}
			break;
		}
		case GrowlMailSummaryModeAlways: 
        {
			if (!class_getClassMethod(MailAccount_class, @selector(mailAccounts)))
				GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +mailAccounts");
			if (!class_getInstanceMethod(Message_class, @selector(mailbox)))
				GMShutDownGrowlMailAndWarn(@"Message does not respond to -mailbox");

			NSArray *accounts = [MailAccount_class mailAccounts];
			NSUInteger accountsCount = [accounts count];
			NSCountedSet *accountSummary = [NSCountedSet setWithCapacity:accountsCount];
			NSCountedSet *accountJunkSummary = [NSCountedSet setWithCapacity:accountsCount];
			NSEnumerator *messagesEnum = [messages objectEnumerator];
			NSArray *junkMailboxes = [MailAccount_class junkMailboxes];
			id message;
			while ((message = [messagesEnum nextObject])) 
            {
				id mailbox = [message mailbox];
				//If this mailbox is not an inbox, and we only care about inboxes, then skip this message.
				if ([self inboxOnly] && ![[MailAccount_class inboxMailboxes] containsObject:mailbox])
					continue;

				id account = [mailbox account];
				if (![self isAccountEnabled:account])
					continue;

				if (([message isJunk]) || [junkMailboxes containsObject:[message mailbox]])
					[accountJunkSummary addObject:account];
				else
					[accountSummary addObject:account];
			}
			NSString *title = NSLocalizedStringFromTableInBundle(@"New mail", NULL, GMGetGrowlMailBundle(), "");
			NSString *titleJunk = NSLocalizedStringFromTableInBundle(@"New junk mail", NULL, GMGetGrowlMailBundle(), "");
			NSString *description;

			id account;

			NSEnumerator *accountSummaryEnum = [accountSummary objectEnumerator];
			while ((account = [accountSummaryEnum nextObject])) 
            {
				if (![self isAccountEnabled:account])
					continue;

				NSUInteger summaryCount = [accountSummary countForObject:account];
				if (summaryCount) {
					if (summaryCount == 1) 
                    {
						description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n 1 new mail", NULL, GMGetGrowlMailBundle(), "%@ is an account name"), [account displayName]];
					} 
                    else
                    {
						description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n %u new mails", NULL, GMGetGrowlMailBundle(), "%@ is an account name; %u becomes a number"), [account displayName], summaryCount];
					}
					[GrowlApplicationBridge notifyWithTitle:title
												description:description
										   notificationName:NEW_MAIL_NOTIFICATION
												   iconData:nil
												   priority:0
												   isSticky:NO
											   clickContext:@""];	// non-nil click context
				}
			}

			NSEnumerator *accountJunkSummaryEnum = [accountJunkSummary objectEnumerator];
			while ((account = [accountJunkSummaryEnum nextObject])) 
            {
				if (![self isAccountEnabled:account])
					continue;

				NSUInteger summaryCount = [accountJunkSummary countForObject:account];
				if (summaryCount) 
                {
					if (summaryCount == 1) 
                    {
						description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n 1 new mail", NULL, GMGetGrowlMailBundle(), "%@ is an account name"), [account displayName]];
					} else {
						description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n %u new mails", NULL, GMGetGrowlMailBundle(), "%@ is an account name; %u becomes a number"), [account displayName], summaryCount];
					}					
					[GrowlApplicationBridge notifyWithTitle:titleJunk
												description:description
										   notificationName:NEW_JUNK_MAIL_NOTIFICATION
												   iconData:nil
												   priority:0
												   isSticky:NO
											   clickContext:@""];	// non-nil click context
				}
			}
			break;
		}
	}
}

- (void)showAllNotifications:(NSNotification *)notification
{
	if (([[notification name] rangeOfString:@"NSWindow"].location == NSNotFound) &&
		([[notification name] rangeOfString:@"NSMouse"].location == NSNotFound) &&
		([[notification name] rangeOfString:@"_NSThread"].location == NSNotFound)) 
    {
		NSLog(@"%@", notification);
	}
}

- (void)monitoredActivityStarted:(NSNotification *)notification
{
	if ([[[notification object] description] isEqualToString:@"Copying messages"]) 
    {
		messageCopies++;
#ifdef GROWL_MAIL_DEBUG
		NSLog(@"Copying a message: messageCopies is now %i", messageCopies);
#endif
		if (messageCopies <= 0)
			GMShutDownGrowlMailAndWarn(@"Number of message-copying operations overflowed. How on earth did you accomplish starting more than 2 billion copying operations at a time?!");
	}
}

- (void)monitoredActivityEnded:(NSNotification *)notification
{
	if ([[[notification object] description] isEqualToString:@"Copying messages"]) 
    {
		if (messageCopies <= 0)
			GMShutDownGrowlMailAndWarn(@"Number of message-copying operations went below 0. It is not possible to have a negative number of copying operations!");
		messageCopies--;
#ifdef GROWL_MAIL_DEBUG
		NSLog(@"Finished copying a message: messageCopies is now %i", messageCopies);
#endif
	}
}

#pragma mark NSApplication Notifications

- (void) backgroundOnlyActivate:(NSNotification*)sender 
{
#pragma unused(sender)
	shouldNotify = NO;
}

- (void) backgroundOnlyResign:(NSNotification*)sender 
{
#pragma unused(sender)
	shouldNotify = YES;
}

#pragma mark Preferences

- (void) configureForBackgroundOnly:(BOOL)enabled
{
	if(enabled) 
    {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundOnlyActivate:) name:NSApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundOnlyResign:) name:NSApplicationDidResignActiveNotification object:nil];
	}	
	else {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];		
	}
}

- (BOOL) isAccountEnabled:(id)account
{
	BOOL isEnabled = YES;
	NSDictionary *accountSettings = [self.userDefaultsController.defaults objectForKey:@"GMAccounts"];
	if (accountSettings) 
    {
		NSNumber *value = [accountSettings objectForKey:[account path]];
		if (value)
			isEnabled = [value boolValue];
	}
	return isEnabled;
}

- (void) setAccount:(id)account enabled:(BOOL)yesOrNo
{
	NSDictionary *accountSettings = [self.userDefaultsController.defaults objectForKey:@"GMAccounts"];
	NSMutableDictionary *newSettings = [[accountSettings mutableCopy] autorelease];
	if (!newSettings)
		newSettings = [NSMutableDictionary dictionaryWithCapacity:1U];
	[newSettings setObject:[NSNumber numberWithBool:yesOrNo] forKey:[account path]];
	[self.userDefaultsController.defaults setObject:newSettings forKey:@"GMAccounts"];
}

#pragma mark Accessors

- (BOOL) isBackgroundOnlyEnabled 
{
	NSNumber *backgroundNum = [self.userDefaultsController.defaults objectForKey:@"GMBackgroundOnly"];
	return (backgroundNum ? [backgroundNum boolValue] : NO);
}

- (BOOL) isEnabled 
{
	NSNumber *enabledNum = [self.userDefaultsController.defaults objectForKey:@"GMEnableGrowlMailBundle"];
    return enabledNum ? [enabledNum boolValue] : YES;
}
- (GrowlMailSummaryMode) summaryMode 
{
	NSNumber *summaryModeNum = [self.userDefaultsController.defaults objectForKey:@"GMSummaryMode"];
	return summaryModeNum ? [summaryModeNum intValue] : GrowlMailSummaryModeAutomatic;
}

- (BOOL) inboxOnly 
{
	NSNumber *inboxOnlyNum = [self.userDefaultsController.defaults objectForKey:@"GMInboxOnly"];
	return inboxOnlyNum ? [inboxOnlyNum boolValue] : YES;
}

- (NSString *) titleFormat 
{
	NSString *titleFormat = [self.userDefaultsController.defaults stringForKey:@"GMTitleFormat"];
	return titleFormat ? titleFormat : @"(%account) %sender";
}

- (NSString *) descriptionFormat 
{
	NSString *descriptionFormat = [self.userDefaultsController.defaults stringForKey:@"GMDescriptionFormat"];
	return descriptionFormat ? descriptionFormat : @"%subject\n%body";
}

#pragma mark Panic buttons

//This is a suicide pill. GrowlMail calls this function any time it detects a change in Mail's implementation, such as a missing method or an object of the wrong class.
void GMShutDownGrowlMailAndWarn(NSString *specificWarning) 
{
	NSLog(NSLocalizedString(@"WARNING: Mail is not behaving in the way that GrowlMail expects. This is probably because GrowlMail is incompatible with the version of Mail you're using. GrowlMail will now turn itself off. Please check the Growl website for a new version. If you're a programmer and want to debug this error, run gdb, load Mail, set a breakpoint on %s, and run.", /*comment*/ nil), __PRETTY_FUNCTION__);
	if (specificWarning)
		NSLog(@"Furthermore, the caller provided a more specific message: %@", specificWarning);
    NSLog(@"%@", [NSThread callStackSymbols]);
    
	[sharedNotifier shutDownGrowlMail];

	//Prevent ourselves from re-enabling later.
	notifierEnabled = NO;
}

#pragma mark Spelunking

- (void)informationSpew
{
    for(id account in [NSClassFromString(GM_MailAccount) mailAccounts])
    {
        NSLog(@"%@", [account allMailboxes]);
    }
    
    NSLog(@"%@", [NSClassFromString(GM_MailAccount) smartMailboxes]);
}

@end
