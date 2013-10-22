#import "MailHeaders.h"

//Class-dumped, and slightly modified, by Peter Hosey on 2007-11-25 from Message.framework on Mac OS X 10.4.10 UB.
@class MFMailbox;

@interface MCMessage : NSObject
- (id)messageBody;
- (id)messageBodyIfAvailable;
- (MFMailbox*)mailbox;
- (NSString *)sender;
- (NSString *)senderDisplayName;
- (NSString *)subject;
- (BOOL)isJunk;
- (id)messageID;
- (BOOL)type;
@end

@interface MFLibrary : NSObject
+ (id)messageWithMessageID:(id)arg1;
+ (void)markMessageAsViewed:(id)arg1 viewedDate:(id)arg2;
@property BOOL isRead; // @synthesize isRead=_isRead;
@end

@interface MFAccount : NSObject
@end

@interface MFMailAccount : MFAccount
+ (id)mailAccounts;
+ (id)remoteAccounts;

+ (id)allMailboxes;
+ (id)archiveMailboxes;
+ (id)junkMailboxes;
+ (id)draftMailboxes;
+ (id)sentMessagesMailboxes;
+ (id)outboxMailboxes;
+ (id)trashMailboxes;
+ (id)inboxMailboxes;
+ (id)specialMailboxes;
+ (id)smartMailboxes;

@property(copy) NSString *displayName;
@end

@interface MFMailbox : NSObject
- (MFMailAccount *)account;
@property BOOL isSmartMailbox;
- (BOOL)isStore;
@end

@interface MFMessageStore : NSObject
- (BOOL)isSmartMailbox;
- (MFMailbox *)mailbox;
@end

@interface MFLibraryStore : MFMessageStore
@end

@interface MFRemoteStore : MFLibraryStore
@end

@interface MFLibraryIMAPStore : MFRemoteStore
@end

@interface MessageViewer : NSResponder
@end

@interface SingleMessageViewer : MessageViewer
+ (id)viewerForMessage:(id)arg1 hiddenCopies:(id)arg2 relatedMessages:(id)arg3 showRelatedMessages:(BOOL)arg4 showAllHeaders:(BOOL)arg5 expandedSelectedMailboxes:(id)arg6;
- (void)showAndMakeKey:(BOOL)arg1;
@end

