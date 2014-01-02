//
//  NSString+GrowlMail.h
//  GrowlMail
//
//  Created by rudy on 10/18/13.
//  Copyright (c) 2013-2014 Rudy Richter. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GrowlMail_KeywordReplacing)

- (NSString *) stringByReplacingKeywords:(NSArray *)keywords withValues:(NSArray *)values;

@end

@interface NSMutableString (GrowlMail_LineOrientedTruncation)

- (void) trimStringToFirstNLines:(NSUInteger)n;

@end
