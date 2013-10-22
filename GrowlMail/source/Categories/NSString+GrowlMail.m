//
//  NSString+GrowlMail.m
//  GrowlMail
//
//  Created by rudy on 10/18/13.
//  Copyright (c) 2013 Rudy Richter. All rights reserved.
//

#import "NSString+GrowlMail.h"

@implementation NSString (GrowlMail_KeywordReplacing)

- (NSString *) stringByReplacingKeywords:(NSArray *)keywords
                              withValues:(NSArray *)values
{
	NSParameterAssert([keywords count] == [values count]);
	NSMutableString *str = [[self mutableCopy] autorelease];
    
	NSEnumerator *keywordsEnum = [keywords objectEnumerator], *valuesEnum = [values objectEnumerator];
	NSString *keyword, *value;
	while ((keyword = [keywordsEnum nextObject]) && (value = [valuesEnum nextObject]))
    {
		[str replaceOccurrencesOfString:keyword
		                     withString:value
		                        options:0
		                          range:NSMakeRange(0, [str length])];
	}
	return str;
}

@end

@implementation NSMutableString (GrowlMail_LineOrientedTruncation)

- (void) trimStringToFirstNLines:(NSUInteger)n
{
	NSRange range;
	NSUInteger end = 0U;
	NSUInteger length;
    
	range.location = 0;
	range.length = 0;
	for (NSUInteger i = 0U; i < n; ++i)
		[self getLineStart:NULL end:&range.location contentsEnd:&end forRange:range];
    
	length = [self length];
	if (length > end)
		[self deleteCharactersInRange:NSMakeRange(end, length - end)];
}

@end
