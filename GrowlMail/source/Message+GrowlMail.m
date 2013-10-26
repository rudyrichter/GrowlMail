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

#import "GrowlMail.h"
#import "GrowlMailNotifier.h"
#import "NSString+GrowlMail.h"
#import "Message+GrowlMail.h"
#import "MailHeaders.h"
#import "MessageFrameworkHeaders.h"

#import <AddressBook/AddressBook.h>
#import <Growl/Growl.h>
#import <objc/objc-runtime.h>

void GMShowNotificationPart1(id self, SEL _cmd);
void GMShowNotificationPart2(id self, SEL _cmd, id messageBody);

@implementation GrowlMessage

+ (void)load
{
    Class mailMessageClass = NSClassFromString(GM_Message);
    
    class_addMethod(mailMessageClass, @selector(GMShowNotificationPart1), (IMP)GMShowNotificationPart1, "v@:");
    class_addMethod(mailMessageClass, @selector(GMShowNotificationPart2:), (IMP)GMShowNotificationPart2, "v@:@");
}

void GMShowNotificationPart1(id self, SEL _cmd)
{
	@autoreleasepool
    {
        id messageBody = nil;
        
        GrowlMailNotifier *notifier = [GrowlMailNotifier sharedNotifier];
        NSString *titleFormat = [notifier titleFormat];
        NSString *descriptionFormat = [notifier descriptionFormat];
        
        if ([titleFormat rangeOfString:@"%body"].location != NSNotFound ||
			[descriptionFormat rangeOfString:@"%body"].location != NSNotFound)
        {
            /* We will need the body */
            messageBody = [self messageBodyIfAvailable];
            int nonBlockingAttempts = 0;
            while (!messageBody && nonBlockingAttempts < 3)
            {
                /* No message body available yet, but we need one */
                nonBlockingAttempts++;
                [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(0.5 * nonBlockingAttempts)]];
                
                /* We'd prefer to let whatever Mail process might want the message body get it on its own terms rather than blocking on this thread */
                messageBody = [self messageBodyIfAvailable];
            }
            
            /* Already tried three times (3 seconds); this time, block this thread to get it. */
            if (!messageBody) 
                messageBody = [self messageBody];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(GMShowNotificationPart2:) withObject:messageBody];
        });
    };
}


void GMShowNotificationPart2(MCMessage *self, SEL _cmd, id messageBody)
{
	NSString *account = (NSString *)[[[self mailbox] account] displayName];
	NSString *sender = [self senderDisplayName];
	NSString *senderAddress = [self sender];
	NSString *subject = (NSString *)[self subject];
	NSString *body = @"";
	GrowlMailNotifier *notifier = [GrowlMailNotifier sharedNotifier];
	NSString *titleFormat = [notifier titleFormat];
	NSString *descriptionFormat = [notifier descriptionFormat];
    
	if (messageBody) 
    {
		NSString *originalBody = nil;
		if ([messageBody respondsToSelector:@selector(attributedString)])
			originalBody = [[messageBody attributedString] string];
		if (originalBody) 
        {
			NSMutableString *transformedBody = [[[originalBody stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy] autorelease];
			NSUInteger lengthWithoutWhitespace = [transformedBody length];
			[transformedBody trimStringToFirstNLines:4U];
			NSUInteger length = [transformedBody length];
			if (length > 200U) 
            {
				[transformedBody deleteCharactersInRange:NSMakeRange(200U, length - 200U)];
				length = 200U;
			}
			if (length != lengthWithoutWhitespace)
				[transformedBody appendString:[NSString stringWithUTF8String:"\xE2\x80\xA6"]];
			body = (NSString *)transformedBody;
		} 
	}

	NSArray *keywords = @[@"%sender", @"%subject", @"%body", @"%account"];
	NSArray *values = @[(sender ? : @""), (subject ? : @""), (body ? : @""), (account ? : @"")];
	NSString *title = [titleFormat stringByReplacingKeywords:keywords withValues:values];
	NSString *description = [descriptionFormat stringByReplacingKeywords:keywords withValues:values];

	ABSearchElement *personSearch = [ABPerson searchElementForProperty:kABEmailProperty
																 label:nil
																   key:nil
																 value:senderAddress
															comparison:kABEqualCaseInsensitive];

	NSArray *matchArray = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:personSearch];
    __block NSData *image = nil;
    [matchArray enumerateObjectsUsingBlock:^(ABPerson *person, NSUInteger idx, BOOL *stop) {
        image = [person imageData];
        if(image)
            *stop = YES;
    }];
    
	//no matches in the Address Book with an icon, so use Mail's icon instead.
	if (!image)
		image = [[NSImage imageNamed:@"NSApplicationIcon"] TIFFRepresentation];

	NSString *notificationName;
	if ([self isJunk] || ([[NSClassFromString(GM_MailAccount) junkMailboxes] containsObject:[self mailbox]]))
    {
		notificationName = NEW_JUNK_MAIL_NOTIFICATION;
	} 
    else 
    {
		if ([self respondsToSelector:@selector(type)] && [self type] == MESSAGE_TYPE_NOTE) 
        {
			notificationName = NEW_NOTE_NOTIFICATION;
		} 
        else 
        {
			notificationName = NEW_MAIL_NOTIFICATION;
		}
	}

	NSString *clickContext = [self messageID];

	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:notificationName
								   iconData:image
								   priority:0
								   isSticky:NO
							   clickContext:clickContext];	// non-nil click context

	[notifier didFinishNotificationForMessage:self];
}

@end
