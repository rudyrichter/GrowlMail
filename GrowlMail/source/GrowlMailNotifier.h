/*
 Copyright (c) 2011-2014, Rudy Richter.
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


#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

#define NEW_MAIL_NOTIFICATION		@"New mail"
#define NEW_JUNK_MAIL_NOTIFICATION	@"New junk mail"

/*!	@brief	Summary mode constants
 *
 *	GrowlMail can post two kinds of notifications: One notification for every message the user receives, or a summary notification that lists only the number of messages the user received on a single account.
 *
 *	@par	The GMSummaryMode user default contains a number that specifies how GrowlMail should post notifications: always as single-message notifications, always as a summary, or automatically chosen based on number of messages added to the store in a single operation.
 */
typedef NS_ENUM(NSInteger, GrowlMailSummaryMode)
{
	/*!	@brief	Automatically use summary mode or not based on how many messages the user receives within a span of time
	 */
	GrowlMailSummaryModeAutomatic = 0,
	/*!	@brief	Always post one notification per message
	 */
	GrowlMailSummaryModeDisabled = 1,
	/*!	@brief	Always post a summary notification per account
	 */
	GrowlMailSummaryModeAlways = 2
};

/*!	@brief	Object that posts GrowlMail notifications
 *
 *	This is a singleton object because the current Growl API can only handle one delegate at a time.
 */
@interface GrowlMailNotifier : NSObject <GrowlApplicationBridgeDelegate>

/*!	@brief	Return the One True \c GrowlMailNotifier Instance, creating it if necessary.
 */
+ (instancetype) sharedNotifier;

/*!	@brief	Creates or retains, then returns, the One True \c GrowlMailNotifier instance.
 *
 *	If the shared instance does not yet exist, this method makes the receiver the shared instance and initializes it.
 *	If the shared instance does already exist, this method releases the receiver, then returns the shared instance.
 *	Either way, it then returns the shared instance.
 *
 *	@par	This method will return \c nil if the suicide pill has previously been invoked.
 *
 *	@return	The One True GrowlMailNotifier instance, or \c nil.
 */
- (instancetype) init;

@property (nonatomic, getter=isEnabled, readonly) BOOL enabled;
@property (nonatomic, readonly) GrowlMailSummaryMode summaryMode;
/*!	@brief	Only post notifications for messages added to an account's inbox, not to other mailboxes (folders).
 */
@property (nonatomic, readonly) BOOL inboxOnly;

/*!	@brief	Returns the correct format string for Growl notification titles.
 *
 *	The returned format is only useful for single-message notifications. Summary notifications do not use this format.
 */
@property (nonatomic, readonly, copy) NSString *titleFormat;
/*!	@brief	Returns the correct format string for Growl notification descriptions.
 *
 *	The returned format is only useful for single-message notifications. Summary notifications do not use this format.
 */
@property (nonatomic, readonly, copy) NSString *descriptionFormat;

/*!	@brief	Return whether the given account is enabled for notifications
 *
 *	@return	\c YES if GrowlMail will post notifications for this account; \c NO if it won't.
 */
- (BOOL)isAccountEnabled:(id)account;

/*!	@brief	Change whether the given account is enabled for notifications
 *
 *	@param	account	The account to enable or disable.
 *	@param	yesOrNo	If \c YES, post notifications for messages for \a account in the future; if \c NO, don't post notifications for messages for that account.
 */
- (void) setAccount:(id)account enabled:(BOOL)enabled;
- (NSCellStateValue) accountState:(id)account;
- (NSArray *)mailboxesForAccount:(id)account;
@property (nonatomic, readonly, copy) NSArray *enabledRemoteAccounts;

/*!	@brief	Determine whether the notifier only notifies while the app is in the background.
 *
 *	This getter is backed by a user default. <code>configureForBackgroundOnly:</code> is <em>not</em> its inverse, as it does not set the user default.
 *
 *	@return	\c YES if this object will only notify while the application is in the background; \c NO if it will notify whether the app is in the background or not.
 */
@property (nonatomic, getter=isBackgroundOnlyEnabled, readonly) BOOL backgroundOnlyEnabled;
/*!	@brief	Tell the notifier to update its notification registrations for suspend/resume events.
 *
 *	This method does not set the user default that backs \c isBackgroundOnlyEnabled, so it is not that method's inverse.
 *
 *	@param	enabled	\c YES if this object should only notify while the application is in the background; \c NO if it should notify whether the app is in the background or not.
 */
- (void) configureForBackgroundOnly:(BOOL)enabled;

@property (nonatomic, readonly, copy) NSString *applicationNameForGrowl;
@property (nonatomic, readonly, copy) NSImage *applicationIconForGrowl;
- (void) growlNotificationWasClicked:(NSString *)clickContext;
@property (nonatomic, readonly, copy) NSDictionary *registrationDictionaryForGrowl;

- (void)didFinishNotificationForMessage:(id /*Message **/)message;
- (void)newMessagesReceived:(NSArray *)messages forMailboxes:(NSArray *)mailboxes;


@property (nonatomic, strong) NSUserDefaultsController *userDefaultsController;

/*!	@brief	Disable GrowlMail and print a warning message
 *
 *	GrowlMail is paranoid about changes in Mail's behavior. Whenever it detects such a change, it calls this function, which removes GrowlMail's notification-observer registrations and stops it from posting Growl notifications. We call it the “suicide pill”.
 *
 *	@param	specificWarning	Additional information to add to the warning message. Can be \c nil.
 */
void GMShutDownGrowlMailAndWarn(NSString *specificWarning);
@end
