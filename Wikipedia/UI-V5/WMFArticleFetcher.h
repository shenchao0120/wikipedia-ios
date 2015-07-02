
#import <Foundation/Foundation.h>

@class MWKSite;
@class MWKTitle;

NS_ASSUME_NONNULL_BEGIN

typedef void (^ WMFArticleFetcherProgress)(CGFloat progress);

extern NSString* const WMFArticleFetchedNotification;
extern NSString* const WMFArticleFetchedKey;

@interface WMFArticleFetcher : NSObject

@property (nonatomic, strong, readonly) MWKDataStore* dataStore;

- (instancetype)initWithDataStore:(MWKDataStore*)dataStore;

- (AnyPromise*)fetchArticleForPageTitle:(MWKTitle*)pageTitle progress:(WMFArticleFetcherProgress)progress;

@end

NS_ASSUME_NONNULL_END