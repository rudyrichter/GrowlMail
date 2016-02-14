#import "MailHeaders.h"

//Class-dumped, and slightly modified, by Peter Hosey on 2007-11-25 from Message.framework on Mac OS X 10.4.10 UB.
@class MFMailbox;

@interface MCMessage : NSObject
@property (nonatomic, readonly, copy) NSString *stringForBodyContent;
@property (nonatomic, readonly, strong) id messageBody;
@property (nonatomic, readonly, strong) id messageBodyIfAvailable;
@property (nonatomic, readonly, strong) MFMailbox *mailbox;
@property (nonatomic, readonly, copy) NSString *sender;
@property (nonatomic, readonly, copy) NSString *senderIfAvailable;
@property (nonatomic, readonly, copy) NSString *senderDisplayName;
@property (nonatomic, readonly, copy) NSArray *to;
@property (nonatomic, readonly, copy) NSString *subject;
@property (nonatomic, getter=isJunk, readonly) BOOL junk;
@property (nonatomic, readonly, strong) id messageID;
@property (nonatomic, readonly) BOOL type;
@end

@interface MFLibrary : NSObject
+ (id)messageWithMessageID:(id)arg1;
+ (void)markMessageAsViewed:(id)arg1 viewedDate:(id)arg2;
@property BOOL isRead; // @synthesize isRead=_isRead;
@end

@interface MFAccount : NSObject
@end

@interface MFMailAccount : MFAccount
+ (instancetype)mailAccounts;
+ (id)remoteAccounts;
+ (NSArray *)_activeAccountsFromArray:(NSArray *)accountsArray;

@property (nonatomic, readonly, strong) id rootMailbox;
@property (nonatomic, readonly, strong) id primaryMailbox;
@property (nonatomic, readonly, strong) id allMailboxes;
- (id)_outboxMailboxCreateIfNeeded:(BOOL)arg1;
- (id)archiveMailboxCreateIfNeeded:(BOOL)arg1;
- (id)trashMailboxCreateIfNeeded:(BOOL)arg1;
- (id)sentMessagesMailboxCreateIfNeeded:(BOOL)arg1;
- (id)junkMailboxCreateIfNeeded:(BOOL)arg1;
- (id)draftsMailboxCreateIfNeeded:(BOOL)arg1;
@property (nonatomic, readonly, strong) id allMailMailbox;
@property (nonatomic, readonly, strong) id _notesMailboxUnlessUsingLocal;
@property (nonatomic, readonly, strong) id _todosMailboxUnlessUsingLocal;
@property (nonatomic, readonly, strong) id notesMailbox;
@property (nonatomic, readonly, strong) id todosMailbox;

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

@property (nonatomic, readonly, copy) NSString *uniqueId;
@property (nonatomic, getter=isGmailAccount, readonly) BOOL gmailAccount;
@property(copy) NSString *displayName;
@end

@interface MFMailbox : NSObject
+ (instancetype)mailboxWithPersistentIdentifier:(id)arg1;
@property (nonatomic, readonly, strong) id persistenceIdentifier;
@property (nonatomic, readonly, strong) id mailboxName;
@property (nonatomic, readonly, strong) id realFullPath;
@property (nonatomic, readonly, strong) MFMailAccount *account;
@property BOOL isSmartMailbox;
@property (nonatomic, getter=isStore, readonly) BOOL store;
@property (nonatomic, getter=isInbox, readonly) BOOL inbox;
@property (nonatomic, readonly, copy) NSString *uuid;
@property (nonatomic, readonly, copy) NSString *labelName;
@end

@interface MFMessageStore : NSObject
@property (nonatomic, getter=isSmartMailbox, readonly) BOOL smartMailbox;
@property (nonatomic, readonly, strong) MFMailbox *mailbox;
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
+ (instancetype)viewerForMessage:(id)arg1 hiddenCopies:(id)arg2 relatedMessages:(id)arg3 showRelatedMessages:(BOOL)arg4 showAllHeaders:(BOOL)arg5 expandedSelectedMailboxes:(id)arg6;
@end
