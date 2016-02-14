/*
 Copyright (c) 2011-2016, Rudy Richter.
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
#import "MailHeaders.h"
#import "MessageFrameworkHeaders.h"
#import "GMUserDefaults.h"
#import "GMPreferenceConstants.h"

#import <objc/objc-runtime.h>

#define AUTO_THRESHOLD	10
#define	MAX_NOTIFICATION_THREADS	5

static int activeNotificationThreads = 0;
static GrowlMailNotifier *sharedNotifier = nil;
static BOOL notifierEnabled = YES;

@interface GrowlMailNotifier ()

@property (nonatomic, strong) NSMutableArray *recentNotifications;
@property (nonatomic) BOOL shouldNotify;

@property (nonatomic, strong) id mailFetchFinished;

@end

@implementation GrowlMailNotifier

#pragma mark Panic buttons

//The purpose of this method is to shut down GrowlMail completely: we should not be notified of any messages, nor notify the user of any messages, after this message is called.
- (void) shutDownGrowlMail 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSClassFromString(@"GrowlApplicationBridge") setGrowlDelegate:nil];
}

#pragma mark The circle of life

+ (GrowlMailNotifier*) sharedNotifier 
{
	if (!sharedNotifier) 
    {
		//-init and -dealloc will each assign to sharedNotifier.
		sharedNotifier = [[GrowlMailNotifier alloc] init];
	}
	return sharedNotifier;
}

- (instancetype) init 
{
	if (sharedNotifier) 
    {
		return sharedNotifier;
	}

	//No shared notifier yet; someone is trying to create one. If we previously disabled ourselves, abort this attempt.
	if (!notifierEnabled) 
    {
		return nil;
	}

	if((self = [super init])) 
    {
		NSNumber *automatic = [NSNumber numberWithInt:GrowlMailSummaryModeAutomatic];
		NSDictionary *defaultsDictionary = @{GMPrefTitleFormat:GMDefaultTitleFormat,
                                              GMPrefGMDescriptionFormat:GMDefaultDescriptionFormat,
                                              GMPrefGMSummaryMode:automatic,
                                              GMPrefEnabled:@YES,
                                              GMPrefInboxOnlyMode:@NO,
                                              GMPrefBackgroundOnlyMode:@YES};
        
        GMUserDefaults *defaults = [[GMUserDefaults alloc] initWithPersistentDomainName:[NSBundle bundleForClass:[self class]].bundleIdentifier];
        defaults.registeredDefaults = defaultsDictionary;
        
        //make sure our shared user defaults controller is set to use our domain for preferences
        self.userDefaultsController = [[NSUserDefaultsController alloc] initWithDefaults:defaults initialValues:defaultsDictionary];
        [self.userDefaultsController setAppliesImmediately:YES];
        
		[NSClassFromString(@"GrowlApplicationBridge") setGrowlDelegate:self];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageStoreDidAddMessages:) name:@"MessageStoreMessagesAdded" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gmailLabelsSet:) name:@"LibraryMessagesGmailLabelsChangedNotification" object:nil];
        
        __weak typeof(self) weakSelf = self;
        self.mailFetchFinished = [[NSNotificationCenter defaultCenter] addObserverForName:@"MailAccountFetchCompleted" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            typeof(self) strongSelf = weakSelf;
            if(strongSelf != nil)
            {
                [strongSelf.recentNotifications removeAllObjects];
            }
        }];
        
		//If the user wants to they can disable notifications for when Mail.app is in the foreground
		
		_shouldNotify = YES;
		if([self isBackgroundOnlyEnabled])
			_shouldNotify = !NSApp.active;
		[self configureForBackgroundOnly:[self isBackgroundOnlyEnabled]];
        self.recentNotifications = [NSMutableArray array];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self.mailFetchFinished];

    
	sharedNotifier = nil;

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
	if (clickContext.length) 
    {
        Class libraryClass = NSClassFromString(GM_Library);
        Class singleMessageViewerClass = NSClassFromString(GM_SingleMessageViewer);
        Class messageViewerClass = NSClassFromString(GM_MessageViewer);
        Class messageClass = NSClassFromString(GM_Message);
        Class mailboxClass = NSClassFromString(GM_Mailbox);
        Class mailAccountClass = NSClassFromString(GM_MailAccount);
        
        //Make sure we have all the methods we need.
        if (!class_getClassMethod(singleMessageViewerClass, @selector(viewerForMessage:hiddenCopies:showRelatedMessages:expandedSelectedMailboxes:)))
			GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to +viewerForMessage:hiddenCopies:showRelatedMessages:expandedSelectedMailboxes:");
        if (!class_getClassMethod(singleMessageViewerClass, @selector(existingSingleMessageViewerForMessage:)))
            GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to +existingSingleMessageViewerForMessage:");
        if(!class_getClassMethod(libraryClass, @selector(markMessageAsViewed:viewedDate:)))
            GMShutDownGrowlMailAndWarn(@"Library does not respond to +markMessageAsViewed:viewedDate:");
        if(!class_getClassMethod(libraryClass, @selector(messageWithMessageID:)))
            GMShutDownGrowlMailAndWarn(@"Library does not respond to +messageWithMessageID:");
        if (!class_getClassMethod(messageViewerClass, @selector(frontmostMessageViewerWithOptions:)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to +frontmostMessageViewerWithOptions:");
        if (!class_getClassMethod(messageViewerClass, @selector(newDefaultMessageViewer)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to +newDefaultMessageViewer");

        if (!class_getInstanceMethod(messageClass, @selector(mailbox)))
            GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to -mailbox");
        if (!class_getInstanceMethod(singleMessageViewerClass, @selector(showAndMakeKey:)))
			GMShutDownGrowlMailAndWarn(@"SingleMessageViewer does not respond to -showAndMakeKey:");
        if (!class_getInstanceMethod(messageViewerClass, @selector(showAndMakeKey:)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to -showAndMakeKey:");
        if (!class_getInstanceMethod(messageViewerClass, @selector(revealMessage:inMailbox:forceMailboxSelection:)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to -revealMessage:inMailbox:forceMailboxSelection:");
        if (!class_getInstanceMethod(mailboxClass, @selector(account)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to -account");
        if (!class_getInstanceMethod(mailAccountClass, @selector(archiveMailboxCreateIfNeeded:)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to -archiveMailboxCreateIfNeeded:");
        if (!class_getInstanceMethod(mailAccountClass, @selector(inboxMailboxCreateIfNeeded:)))
            GMShutDownGrowlMailAndWarn(@"MessageViewer does not respond to -inboxMailboxCreateIfNeeded:");


        
        id message = [libraryClass messageWithMessageID:clickContext];
        id messageViewer = nil;
        if([[self.userDefaultsController.defaults objectForKey:GMPrefMessagesRevealedInMainWindow] boolValue])
        {
            id mailbox = [message mailbox];
            messageViewer = [messageViewerClass frontmostMessageViewerWithOptions:0];
            if(messageViewer == nil)
            {
                messageViewer = [messageViewerClass newDefaultMessageViewer];
            }
            //gmail test
            if([[[mailbox account] archiveMailboxCreateIfNeeded:NO] isEqualTo:mailbox] == YES)
            {
                mailbox = [[message account] inboxMailboxCreateIfNeeded:NO];
            }
            [messageViewer revealMessage:message inMailbox:mailbox forceMailboxSelection:NO];
        }
        else
        {
            messageViewer = [singleMessageViewerClass existingViewerShowingMessage:message];
            if(messageViewer == nil || [messageViewer isMemberOfClass:messageViewerClass])
            {
                messageViewer = [singleMessageViewerClass viewerForMessage:message hiddenCopies:nil showRelatedMessages:NO expandedSelectedMailboxes:nil];
            }
            [libraryClass markMessageAsViewed:message viewedDate:[NSDate date]];
        }
        [NSApp activateIgnoringOtherApps:YES];
        [messageViewer showAndMakeKey:YES];
	}
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	// Register our ticket with Growl
	NSArray *allowedNotifications = @[NEW_MAIL_NOTIFICATION,
		NEW_JUNK_MAIL_NOTIFICATION];
	NSDictionary *humanReadableNames = @{NEW_MAIL_NOTIFICATION: NSLocalizedStringFromTableInBundle(@"New mail", nil, GMGetGrowlMailBundle(), ""),
										NEW_JUNK_MAIL_NOTIFICATION: NSLocalizedStringFromTableInBundle(@"New junk mail", nil, GMGetGrowlMailBundle(), "")};
	NSArray *defaultNotifications = @[NEW_MAIL_NOTIFICATION];

	NSDictionary *ticket = @{GROWL_NOTIFICATIONS_ALL: allowedNotifications,
		GROWL_NOTIFICATIONS_DEFAULT: defaultNotifications,
		GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES: humanReadableNames,
                            GROWL_APP_NAME: [self applicationNameForGrowl]};

	return ticket;
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
		[NSThread detachNewThreadSelector:NSSelectorFromString(@"GMShowNotificationPart1")
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
    Class MailBox_Class = NSClassFromString(GM_Mailbox);
	if (![self isEnabled])
        return;
    
	if(!_shouldNotify && [self isBackgroundOnlyEnabled])
        return;
    
	id store = notification.object;
	if (!store)
		GMShutDownGrowlMailAndWarn([NSString stringWithFormat:@"'%@' notification has no object", notification.name]);
    
	NSDictionary *userInfo = notification.userInfo;
	if (!userInfo)
        GMShutDownGrowlMailAndWarn(@"Notification had no userInfo");
    
    //we return if they were added during Mail.app launching.
    if([userInfo[@"MessageStoreMessagesAddedDuringOpen"] boolValue])
        return;
    
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s called: %@", __PRETTY_FUNCTION__, notification.userInfo);
#endif
    NSArray *mailboxes = nil;
    id mailBox = nil;
    if([store respondsToSelector:@selector(mailbox)])
    {
        mailBox = [store performSelector:@selector(mailbox)];
    }
    if([mailBox respondsToSelector:@selector(isStore)] && [mailBox respondsToSelector:@selector(isSmartMailbox)])
        if([mailBox isStore] && ![mailBox isSmartMailbox])
            mailboxes = @[mailBox];
    
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Adding messages to mailboxes %@", __PRETTY_FUNCTION__, mailboxes);
#endif
    
	//As of Tiger, it's normal for about half of these notifications to not have any mailboxes. We simply ignore the notification in this case.
	if (!(mailboxes && mailboxes.count))
        return;
    
	NSArray *messages = userInfo[@"messages"];
	if (!messages)
        GMShutDownGrowlMailAndWarn(@"Notification's userInfo has no messages");
	
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Mail added messages [1] to mailboxes [2].\n[1]: %@\n[2]: %@", __PRETTY_FUNCTION__, messages, mailboxes);
#endif
    NSMutableArray *disabledMessages = [NSMutableArray array];
    [messages enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![self isAccountEnabled:[obj mailbox]])
        {
            [disabledMessages addObject:obj];
        }
    }];
    
    //note which mailboxes are enabled
    NSMutableArray *enabledMailboxes = [NSMutableArray array];
    [mailboxes enumerateObjectsUsingBlock:^(id mailbox, NSUInteger idx, BOOL *stop)
    {
        if([mailbox isKindOfClass:MailBox_Class])
        {
            if([self isAccountEnabled:mailbox])
            {
                [enabledMailboxes addObject:mailbox];
                *stop = YES;
            }
        }
    }];

    
    NSArray *singularMailbox = nil;
    if(enabledMailboxes.count)
        singularMailbox = @[enabledMailboxes.firstObject];
    if(disabledMessages.count == 0 && singularMailbox.count)
        [self newMessagesReceived:messages forMailboxes:singularMailbox];
}

- (void)newMessagesReceived:(NSArray *)messages forMailboxes:(NSArray *)mailboxes
{
    NSUInteger count = messages.count;
    Class MailAccount_class = NSClassFromString(GM_MailAccount);
	Class Message_class = NSClassFromString(GM_Message);
	GrowlMailSummaryMode summaryMode = [self summaryMode];
    
	if (summaryMode == GrowlMailSummaryModeAutomatic) 
    {
		if (count >= AUTO_THRESHOLD)
			summaryMode = GrowlMailSummaryModeAlways;
		else
			summaryMode = GrowlMailSummaryModeDisabled;
	}

#ifdef GROWL_MAIL_DEBUG
//	NSLog(@"Got %d new messages. Summary mode was %d and is now %d", (int)count, (int)[self summaryMode], (int)summaryMode);
#endif

	switch (summaryMode)
    {
		default:
		case GrowlMailSummaryModeDisabled: 
        {
            [messages enumerateObjectsUsingBlock:^(id message, NSUInteger idx, BOOL *stop)
            {
                if (![message isKindOfClass:Message_class])
                    GMShutDownGrowlMailAndWarn([NSString stringWithFormat:@"Message in notification was not a Message; it is %@", message]);

                id mailbox = (mailboxes ? mailboxes.firstObject : [message mailbox]);
				if ([self inboxOnly] && ![[MailAccount_class inboxMailboxes] containsObject:mailbox])
                    return;
                
                if (![message respondsToSelector:@selector(isRead)] || ![message isRead])
                {
                    BOOL shouldNotify = YES;
                    if([message respondsToSelector:@selector(messageID)])
                    {
                        id messageID = [message messageID];
                        if(![self.recentNotifications containsObject:messageID])
                        {
                            [self.recentNotifications addObject:messageID];
                        }
                        else
                        {
                            shouldNotify = NO;
                        }
                        
                    }
                    
                    if(shouldNotify)
                    {
                        [[self class] showNotificationForMessage:message];
                    }
                    
                }
            }];
			break;
		}
		case GrowlMailSummaryModeAlways: 
        {
			if (!class_getClassMethod(MailAccount_class, @selector(mailAccounts)))
				GMShutDownGrowlMailAndWarn(@"MailAccount does not respond to +mailAccounts");
			if (!class_getInstanceMethod(Message_class, @selector(mailbox)))
				GMShutDownGrowlMailAndWarn(@"Message does not respond to -mailbox");

			NSArray *accounts = [MailAccount_class mailAccounts];
			NSUInteger accountsCount = accounts.count;
			NSCountedSet *accountSummary = [NSCountedSet setWithCapacity:accountsCount];
			NSCountedSet *accountJunkSummary = [NSCountedSet setWithCapacity:accountsCount];
			NSArray *junkMailboxes = [MailAccount_class junkMailboxes];
            [messages enumerateObjectsUsingBlock:^(id message, NSUInteger idx, BOOL *stop)
            {
                id mailbox = [message mailbox];
				if ([self inboxOnly] && [[MailAccount_class inboxMailboxes] containsObject:mailbox])
                {
                    id account = [mailbox account];
                    if ([self isAccountEnabled:account])
                    {
                        if (([message isJunk]) || [junkMailboxes containsObject:[message mailbox]])
                            [accountJunkSummary addObject:account];
                        else
                            [accountSummary addObject:account];
                    }
                }
            }];
            
			NSString *title = NSLocalizedStringFromTableInBundle(@"New mail", NULL, GMGetGrowlMailBundle(), "");
			NSString *titleJunk = NSLocalizedStringFromTableInBundle(@"New junk mail", NULL, GMGetGrowlMailBundle(), "");
			__block NSString *description = nil;

			[accountSummary enumerateObjectsUsingBlock:^(id account, BOOL *stop) {
                if ([self isAccountEnabled:account])
                {
                    NSUInteger summaryCount = [accountSummary countForObject:account];
                    if (summaryCount)
                    {
                        if (summaryCount == 1)
                        {
                            description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n 1 new mail", NULL, GMGetGrowlMailBundle(), "%@ is an account name"), [account displayName]];
                        }
                        else
                        {
                            description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n %u new mails", NULL, GMGetGrowlMailBundle(), "%@ is an account name; %u becomes a number"), [account displayName], summaryCount];
                        }
                        [NSClassFromString(@"GrowlApplicationBridge") notifyWithTitle:title
                                                    description:description
                                               notificationName:NEW_MAIL_NOTIFICATION
                                                       iconData:nil
                                                       priority:0
                                                       isSticky:NO
                                                   clickContext:@""];	// non-nil click context
                    }
                }

            }];

            [accountJunkSummary enumerateObjectsUsingBlock:^(id account, BOOL *stop) {
                if ([self isAccountEnabled:account])
                {
                    NSUInteger summaryCount = [accountJunkSummary countForObject:account];
                    if (summaryCount)
                    {
                        if (summaryCount == 1)
                        {
                            description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n 1 new mail", NULL, GMGetGrowlMailBundle(), "%@ is an account name"), [account displayName]];
                        } else {
                            description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ \n %u new mails", NULL, GMGetGrowlMailBundle(), "%@ is an account name; %u becomes a number"), [account displayName], summaryCount];
                        }
                        [NSClassFromString(@"GrowlApplicationBridge") notifyWithTitle:titleJunk
                                                    description:description
                                               notificationName:NEW_JUNK_MAIL_NOTIFICATION
                                                       iconData:nil
                                                       priority:0
                                                       isSticky:NO
                                                   clickContext:@""];	// non-nil click context
                    }
                }
            }];
			break;
		}
	}
}

- (void)gmailLabelsSet:(NSNotification*)notification
{
    Class MailBox_Class = NSClassFromString(GM_Mailbox);
	id store = notification.object;
	if (!store)
		GMShutDownGrowlMailAndWarn([NSString stringWithFormat:@"'%@' notification has no object", notification.name]);
    
	NSDictionary *userInfo = notification.userInfo;
	if (!userInfo)
        GMShutDownGrowlMailAndWarn(@"Notification had no userInfo");
    
    //we return if we receive this notification but it doesn't have gmailLabelChanges, since that's entirely not what we're expecting based on 10.9.0 behavior.
    NSDictionary *gmailLabelChanges = userInfo[@"gmailLabelChanges"];
    if(!gmailLabelChanges)
    {
        return;
    }
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s called: %@", __PRETTY_FUNCTION__, notification.userInfo);
#endif
    __block NSSet *mailboxes = gmailLabelChanges[@"MessageAddLabels"];
    
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Labeling messages for mailboxes %@", __PRETTY_FUNCTION__, mailboxes);
#endif
    
	if (!mailboxes || !mailboxes.count)
        return;
    
	NSArray *messages = userInfo[@"messages"];
	if (!messages)
        GMShutDownGrowlMailAndWarn(@"Notification's userInfo has no messages");
	
#ifdef GROWL_MAIL_DEBUG
	NSLog(@"%s: Mail added messages [1] to mailboxes [2].\n[1]: %@\n[2]: %@", __PRETTY_FUNCTION__, messages, mailboxes);
#endif
    NSMutableArray *disabledMessages = [NSMutableArray array];
    [messages enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![self isAccountEnabled:[obj mailbox]])
        {
            [disabledMessages addObject:obj];
        }
    }];
    
    //note which mailboxes are enabled
    NSMutableArray *enabledMailboxes = [NSMutableArray array];
    [mailboxes enumerateObjectsUsingBlock:^(id mailbox, BOOL *stop)
     {
         if([mailbox isKindOfClass:MailBox_Class])
         {
             if([self isAccountEnabled:mailbox])
             {
                 [enabledMailboxes addObject:mailbox];
                 *stop = YES;
             }
         }
     }];
    
    NSArray *singularMailbox = nil;
    __block id mailboxToSave = nil;
    if(enabledMailboxes.count)
        singularMailbox = @[enabledMailboxes.firstObject];
    if(!singularMailbox)
        [mailboxes enumerateObjectsUsingBlock:^(id mailbox, BOOL *stop) {
            if([[mailbox account] isGmailAccount])
            {
                if([[mailbox labelName] isEqualToString:@"\\Inbox"])
                {
                    mailboxToSave = mailbox;
                    *stop = YES;
                }
            }
        }];
    if(mailboxToSave)
        singularMailbox = @[mailboxToSave];
    if(disabledMessages.count == 0 && singularMailbox.count)
        [self newMessagesReceived:messages forMailboxes:singularMailbox];
    else if(disabledMessages.count && singularMailbox.count)
        [self newMessagesReceived:disabledMessages forMailboxes:singularMailbox];
}

- (void)showAllNotifications:(NSNotification *)notification
{
	if (([notification.name rangeOfString:@"NSWindow"].location == NSNotFound) &&
		([notification.name rangeOfString:@"NSMouse"].location == NSNotFound) &&
		([notification.name rangeOfString:@"_NSThread"].location == NSNotFound)) 
    {
		NSLog(@"%@", notification);
	}
}

#pragma mark NSApplication Notifications

- (void) backgroundOnlyActivate:(NSNotification*)sender 
{
#pragma unused(sender)
	_shouldNotify = NO;
}

- (void) backgroundOnlyResign:(NSNotification*)sender 
{
#pragma unused(sender)
	_shouldNotify = YES;
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

- (NSCellStateValue) accountState:(id)account
{
	NSCellStateValue state = NSOnState;
    
    BOOL accountEnabled = [self isAccountEnabled:account];
    if([account isKindOfClass:NSClassFromString(GM_MailAccount)])
    {
        __block BOOL allEnabled = YES;
        __block BOOL anyEnabled = NO;
        NSArray *mailboxes = nil;
        if([account respondsToSelector:@selector(allMailboxes)])
            mailboxes = [account allMailboxes];

        [mailboxes enumerateObjectsUsingBlock:^(id mailbox, NSUInteger idx, BOOL *stop) {
            if(![self isAccountEnabled:mailbox])
                allEnabled = NO;
            else
                anyEnabled = YES;
        }];
        
        state = (allEnabled ? NSOnState : (anyEnabled ? NSMixedState : NSOffState));
    }
    else if ([account isKindOfClass:NSClassFromString(GM_Mailbox)])
    {
        state = accountEnabled;
    }
    return state;
}

- (BOOL)isAccountEnabled:(id)account
{
    BOOL isEnabled = YES;
    NSNumber *value = nil;
    
    NSDictionary *accountSettings = [self.userDefaultsController.defaults objectForKey:GMPrefMailAccounts];
	if (accountSettings)
    {
        if([account respondsToSelector:@selector(uniqueId)])
            value = accountSettings[[account uniqueId]];
        else if([account respondsToSelector:@selector(uuid)])
            value = accountSettings[[account uuid]];
        if (value)
            isEnabled = value.boolValue;
    }
    else
    {
        [self setAccount:account enabled:isEnabled];
    }
    
return isEnabled;
}

- (void) setAccount:(id)account enabled:(BOOL)enabled
{
	NSDictionary *accountSettings = [self.userDefaultsController.defaults objectForKey:@"GMAccounts"];
    NSMutableDictionary *newSettings = [accountSettings mutableCopy];
	if (!newSettings)
		newSettings = [NSMutableDictionary dictionary];
    
    NSString *key = nil;
    
    if([account isKindOfClass:NSClassFromString(GM_MailAccount)])
    {
        NSArray *mailboxes = nil;
        if([account respondsToSelector:@selector(allMailboxes)])
            mailboxes = [account allMailboxes];

        [mailboxes enumerateObjectsUsingBlock:^(id mailbox, NSUInteger idx, BOOL *stop)
        {
            NSString *mailboxKey = nil;
            if([mailbox respondsToSelector:@selector(uuid)])
                mailboxKey = [mailbox uuid];
            NSLog(@"%@ %@", [mailbox displayName], mailboxKey);
            if(mailboxKey.length > 0)
            {
                newSettings[mailboxKey] = @(enabled);
            }
        }];
        if ([account respondsToSelector:@selector(uniqueId)])
            key = [account uniqueId];
        else if ([account respondsToSelector:@selector(identifier)])
        {
            key = [account identifier];
        }
    }
    else if ([account isKindOfClass:NSClassFromString(GM_Mailbox)])
    {
        if([account respondsToSelector:@selector(uuid)])
            key = [account uuid];
    }
    
    if(key)
    {
        newSettings[key] = @(enabled);
    }
    else
    {
        NSLog(@"account: %@", account);
    }
    [self.userDefaultsController.defaults setObject:newSettings forKey:@"GMAccounts"];
}

#pragma mark Accessors

- (BOOL) isBackgroundOnlyEnabled 
{
	NSNumber *backgroundNum = [self.userDefaultsController.defaults objectForKey:@"GMBackgroundOnly"];
	return (backgroundNum ? backgroundNum.boolValue : NO);
}

- (BOOL) isEnabled 
{
	NSNumber *enabledNum = [self.userDefaultsController.defaults objectForKey:@"GMEnableGrowlMailBundle"];
    return enabledNum ? enabledNum.boolValue : YES;
}
- (GrowlMailSummaryMode) summaryMode 
{
	NSNumber *summaryModeNum = [self.userDefaultsController.defaults objectForKey:@"GMSummaryMode"];
	return summaryModeNum ? summaryModeNum.intValue : GrowlMailSummaryModeAutomatic;
}

- (BOOL) inboxOnly
{
	NSNumber *inboxOnlyNum = [self.userDefaultsController.defaults objectForKey:@"GMInboxOnly"];
	return inboxOnlyNum ? inboxOnlyNum.boolValue : YES;
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

#pragma mark - Mail support

- (NSArray *)mailboxesForAccount:(id)account
{
    NSMutableArray *mailboxes = [NSMutableArray array];
    if([account respondsToSelector:@selector(allMailboxes)])
        [mailboxes addObjectsFromArray:[account allMailboxes]];
    
    if([account respondsToSelector:@selector(rootMailbox)])
        [mailboxes removeObject:[account rootMailbox]];
    
    return mailboxes;
}

- (NSArray *)enabledRemoteAccounts
{
    Class mailAccountClass = NSClassFromString(GM_MailAccount);
    NSArray *remoteAccounts = [mailAccountClass remoteAccounts];
    
    return [mailAccountClass _activeAccountsFromArray:remoteAccounts];
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
