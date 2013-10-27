#import "MailHeaders.h"

//Class-dumped, and slightly modified, by Peter Hosey on 2007-11-25 from Message.framework on Mac OS X 10.4.10 UB.
@class MFMailbox;

@interface MCMessage : NSObject
- (NSString *)stringForBodyContent;
- (id)messageBody;
- (id)messageBodyIfAvailable;
- (MFMailbox*)mailbox;
- (NSString *)sender;
- (NSString *)senderIfAvailable;
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
+ (NSArray *)_activeAccountsFromArray:(NSArray *)accountsArray;

- (id)rootMailbox;
- (id)primaryMailbox;
- (id)allMailboxes;
- (id)_outboxMailboxCreateIfNeeded:(BOOL)arg1;
- (id)archiveMailboxCreateIfNeeded:(BOOL)arg1;
- (id)trashMailboxCreateIfNeeded:(BOOL)arg1;
- (id)sentMessagesMailboxCreateIfNeeded:(BOOL)arg1;
- (id)junkMailboxCreateIfNeeded:(BOOL)arg1;
- (id)draftsMailboxCreateIfNeeded:(BOOL)arg1;
- (id)allMailMailbox;
- (id)_notesMailboxUnlessUsingLocal;
- (id)_todosMailboxUnlessUsingLocal;
- (id)notesMailbox;
- (id)todosMailbox;

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

- (NSString *)uniqueId;
- (BOOL)isGmailAccount;
@property(copy) NSString *displayName;
@end

@interface MFMailbox : NSObject
+ (id)mailboxWithPersistentIdentifier:(id)arg1;
- (id)persistenceIdentifier;
- (id)mailboxName;
- (id)realFullPath;
- (MFMailAccount *)account;
@property BOOL isSmartMailbox;
- (BOOL)isStore;
- (BOOL)isInbox;
- (NSString *)uuid;
- (NSString *)labelName;
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
- (void)revealMessage:(id)arg1 inMailbox:(id)arg2 forceMailboxSelection:(BOOL)arg3;
+ (id)frontmostMessageViewerWithOptions:(unsigned long long)arg1;
+ (id)newDefaultMessageViewer;
- (void)showAndMakeKey:(BOOL)arg1;
@end

@interface SingleMessageViewer : MessageViewer
+ (id)viewerForMessage:(id)arg1 hiddenCopies:(id)arg2 relatedMessages:(id)arg3 showRelatedMessages:(BOOL)arg4 showAllHeaders:(BOOL)arg5 expandedSelectedMailboxes:(id)arg6;
@end
