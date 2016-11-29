@import AppKit;

#import "FConvenience.h"

@implementation NSUserDefaults (Subscripts)
- (id)objectForKeyedSubscript:(id)aKey
{
    return [self objectForKey:aKey];
}
- (void)setObject:(id)aObj forKeyedSubscript:(id)aKey
{
    [self setObject:aObj forKey:aKey];
}
@end
