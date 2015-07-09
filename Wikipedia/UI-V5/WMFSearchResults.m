
#import "WMFSearchResults.h"

NS_ASSUME_NONNULL_BEGIN

@interface WMFSearchResults ()

@property (nonatomic, copy, readwrite) NSString* searchTerm;
@property (nonatomic, strong, readwrite) NSArray* articles;
@property (nonatomic, copy, nullable, readwrite) NSString* searchSuggestion;

@end

@implementation WMFSearchResults

- (instancetype)initWithSearchTerm:(NSString*)searchTerm articles:(nullable NSArray*)articles searchSuggestion:(nullable NSString*)suggestion {
    self = [super init];
    if (self) {
        self.searchTerm       = searchTerm;
        self.articles         = articles ? : @[];
        self.searchSuggestion = suggestion;
    }
    return self;
}

- (nullable NSString*)displayTitle {
    return self.searchTerm;
}

- (NSUInteger)articleCount {
    return [self.articles count];
}

- (MWKArticle*)articleForIndexPath:(NSIndexPath*)indexPath {
    return self.articles[indexPath.row];
}

- (NSIndexPath*)indexPathForArticle:(MWKArticle * __nonnull)article{
    NSUInteger index = [self.articles indexOfObjectPassingTest:^BOOL(MWKArticle *obj, NSUInteger idx, BOOL *stop) {
        if ([article.title isEqualToTitle:obj.title]) {
            return YES;
            *stop = YES;
        }
        return NO;
    }];
    
    if(index == NSNotFound){
        return nil;
    }
    
    return [NSIndexPath indexPathForItem:index inSection:0];
}

- (BOOL)canDeleteItemAtIndexpath:(NSIndexPath*)indexPath {
    return NO;
}

- (BOOL)noResults {
    return (self.searchTerm && [self.articles count] == 0);
}

@end

NS_ASSUME_NONNULL_END
