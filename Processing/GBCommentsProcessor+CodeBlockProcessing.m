//
//  GBCommentsProcessor+CodeBlockProcessing.m
//  appledoc
//
//  Created by Jody Hagins on 9/6/15.
//  Copyright (c) 2015 Gentle Bytes. All rights reserved.
//

#import "GBCommentsProcessor+CodeBlockProcessing.h"
#import "RegexKitLite.h"

@implementation GBCommentsProcessor (CodeBlockProcessing)

/**
 Fetch any source-code-block components from @a string

 This method will search @a string for any recognized source-code-blocks.  A block will be any text between doxygen style @code/@endcode markers or any text between markdown markers ``` or ~~~.

 This is not a top-level marker, and will be parsed from within another comment block.

 The beginning and ending markers must each be on a new line, with nothing else but whitespace on that line.

 @param string the text in which to search for source-code-blocks

 @return an array of dictionaries, where each dictionary contains six key-value pairs.

 - begin the token marking the beginning of the code block
 - end the token marking the end of the code block
 - prefix all the text before the start of the code block, including the line containing the begining marker
 - postfix all the text after the code block, including the line containing the ending marker
 - code all the text between the begining and ending markers
 - range the range for the code text, relative to the original @a string
 */
- (NSArray*)codeComponentsInString:(NSString*)string {
    NSRange searchRange = NSMakeRange(0, [string length]);
    NSMutableArray *result = [[NSMutableArray alloc] init];

    NSString *pattern = @"\\r?\\n(([ \\t]*(~~~|```|@code)[ \\t]*)\\r?\\n[\\s\\S]*?\\r?\\n([ \\t]*(\\3|@endcode)[ \\t]*)\\r?\\n)";
    NSArray *components = [string arrayOfDictionariesByMatchingRegex:pattern withKeysAndCaptures:@"code", 1, @"prefix", 2, @"begin", 3, @"postfix", 4, @"end", 5, nil];
    for (NSDictionary *d in components) {
        NSString *begin = [d objectForKey:@"begin"];
        NSString *end = [d objectForKey:@"end"];
        if (([begin isEqualToString:@"@code"] && [end isEqualToString:@"@endcode"]) || [begin isEqualToString:end]) {
            NSString *body = [d objectForKey:@"code"];
            NSRange range = [string rangeOfString:body options:0 range:searchRange];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:d];
            [dict setObject:[NSValue valueWithRange:range] forKey:@"range"];
            [result addObject:[dict copy]];
        }
    }
    return [result copy];
}

/**
 Do the link component and the code component overlap?

 @param link a reference-link component
 @param a source-code-block component

 @return YES if the link component shares any text in common with the source-code-block component.
 */
- (BOOL)linkComponent:(NSDictionary*)link overlapsCodeComponent:(NSDictionary*)code {
    NSRange linkRange = [[link objectForKey:@"range"] rangeValue];
    NSUInteger linkBegin = linkRange.location;
    NSUInteger linkEnd = linkRange.location + linkRange.length;

    NSRange codeRange = [[code objectForKey:@"range"] rangeValue];
    NSUInteger codeBegin = codeRange.location;
    NSUInteger codeEnd = codeRange.location + codeRange.length;
    return (linkBegin >= codeBegin && linkBegin < codeEnd) || (linkEnd > codeBegin && linkEnd <= codeEnd);
}

/**
 Fetch any reference link components from @a string

 This method will search @a string for any recognized reference links - something roughly of the form [foo](bar).

 @param string the text in which to search for reference links
 @param codeComponents the source-code-block component that have already been found for this same @a string.  Any link found within the known soucre-code blocks will be ignored and not included in the resulting array of components.

 @return an array of dictionaries, where each dictionary contains two key-value pairs.

 - "link" all the text matching as a link reference
 - "range" the range for the link text, relative to the original @a string
 */
- (NSArray*)linkComponentsInString:(NSString*)string withCodeComponents:(NSArray*)codeComponents {
    NSRange searchRange = NSMakeRange(0, [string length]);
    NSMutableArray *result = [[NSMutableArray alloc] init];

    NSString *pattern = @"(\\[.+?\\]\\(.+?\\))";
    NSArray *components = [string arrayOfDictionariesByMatchingRegex:pattern withKeysAndCaptures:@"link", 1, nil];
    for (NSDictionary *d in components) {
        NSString *body = [d objectForKey:@"link"];
        NSRange range = [string rangeOfString:body options:0 range:searchRange];
        NSDictionary *link = @{@"link":body, @"range":[NSValue valueWithRange:range]};
        BOOL overlaps = NO;
        for (NSDictionary *code in codeComponents) {
            if ([self linkComponent:link overlapsCodeComponent:code]) {
                overlaps = YES;
                break;
            }
        }
        if (!overlaps) {
            [result addObject:link];
        }
    }
    return result;
}

/**
 Merge the two sets of components so that they are in sorted order, relative to their range location

 @param codeComponents the array of soucrec-code-block components
 @param linkComponents the array of reference-link components

 @return An array containing both code and link components, sorted by range location
 */
- (NSArray*)mergeCodeComponents:(NSArray*)codeComponents linkComponents:(NSArray*)linkComponents {
    return [[codeComponents arrayByAddingObjectsFromArray:linkComponents] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSRange range1 = [[obj1 objectForKey:@"range"] rangeValue];
        NSRange range2 = [[obj2 objectForKey:@"range"] rangeValue];
        return (range1.location < range2.location
                ? NSOrderedAscending
                : (range1.location == range2.location
                   ? NSOrderedSame
                   : NSOrderedDescending));
    }];
}


// See header file for documenetation
- (NSArray*)codeAndLinkComponentsInString:(NSString*)string {
    NSArray *codeComponents = [self codeComponentsInString:string];
    NSArray *linkComponents = [self linkComponentsInString:string withCodeComponents:codeComponents];
    return [self mergeCodeComponents:codeComponents linkComponents:linkComponents];
}

@end
