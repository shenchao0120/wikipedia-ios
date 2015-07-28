
#import "WMFArticleFetcher.h"
#import "AFHTTPRequestOperationManager+WMFConfig.h"
#import "WMFArticleRequestSerializer.h"
#import "WMFArticleResponseSerializer.h"
#import "Wikipedia-Swift.h"
#import "PromiseKit.h"
#import "MWNetworkActivityIndicatorManager.h"
#import "WMFArticleParsing.h"

//Tried not to do it, but we need it for the useage reports BOOL
//Plan to refactor settings into an another object, then we can remove this.
#import "SessionSingleton.h"

NS_ASSUME_NONNULL_BEGIN

@interface WMFArticleBaseFetcher ()

@property (nonatomic, strong) AFHTTPRequestOperationManager* operationManager;
@property (nonatomic, strong) NSMutableDictionary* operationsKeyedByTitle;
@property (nonatomic, strong) dispatch_queue_t operationsQueue;

@end

@implementation WMFArticleBaseFetcher

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.operationsKeyedByTitle = [NSMutableDictionary dictionary];
        NSString* queueID = [NSString stringWithFormat:@"org.wikipedia.articlefetcher.accessQueue.%@", [[NSUUID UUID] UUIDString]];
        self.operationsQueue = dispatch_queue_create([queueID cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
        AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager wmf_createDefaultManager];
        manager.requestSerializer = [WMFArticlePreviewRequestSerializer serializer];
        manager.responseSerializer = [WMFArticleResponseSerializer serializer];
        self.operationManager      = manager;
    }
    return self;
}

- (WMFArticleRequestSerializer*)requestSerializer{
    
    return [self.operationManager.requestSerializer isKindOfClass:[WMFArticlePreviewRequestSerializer class]] ? self.operationManager.requestSerializer : nil;
}

#pragma mark - Fetching

- (id)serializedArticleWithTitle:(MWKTitle*)title response:(NSDictionary*)response{
    
    return response;
}

- (void)fetchArticleForPageTitle:(MWKTitle*)pageTitle useDesktopURL:(BOOL)useDeskTopURL progress:(WMFProgressHandler __nullable)progress resolver:(PMKResolver)resolve{
    
    if (!pageTitle.text || !pageTitle.site.language) {
        resolve([NSError wmf_errorWithType:WMFErrorTypeStringMissingParameter userInfo:nil]);
    }
    
    [self updateRequestSerializerMCCMNCHeader];
    
    NSURL* url = useDeskTopURL ? [pageTitle.site apiEndpoint] : [pageTitle.site mobileApiEndpoint];
    
    AFHTTPRequestOperation* operation = [self.operationManager GET:url.absoluteString parameters:pageTitle success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary* JSON = responseObject;
        dispatchOnBackgroundQueue(^{
            
            [self untrackOperationForTitle:pageTitle];
            [[MWNetworkActivityIndicatorManager sharedManager] pop];
            resolve([self serializedArticleWithTitle:pageTitle response:JSON]);
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        if([url isEqual:[pageTitle.site mobileApiEndpoint]] && [error shouldFallbackToDesktopURLError]){
            
            [self fetchArticleForPageTitle:pageTitle useDesktopURL:YES progress:progress resolver:resolve];
            
        }else{
            
            [self untrackOperationForTitle:pageTitle];
            
            [[MWNetworkActivityIndicatorManager sharedManager] pop];
            resolve(error);
        }
    }];
    
    __block CGFloat downloadProgress = 0.0;
    
    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        if (totalBytesExpectedToRead > 0) {
            downloadProgress = (CGFloat)(totalBytesRead / totalBytesExpectedToRead);
        } else {
            downloadProgress += 0.05;
        }
        
        if (progress) {
            progress(downloadProgress);
        }
    }];
    
    [self trackOperation:operation forTitle:pageTitle];
}

#pragma mark - Operation Tracking

- (AFHTTPRequestOperation*)trackedOperationForTitle:(MWKTitle*)title{
    
    if([title.text length] == 0){
        return nil;
    }
    
    __block AFHTTPRequestOperation* op = nil;
    
    dispatch_sync(self.operationsQueue, ^{
        
        op = self.operationsKeyedByTitle[title.text];
    });
    
    return op;
}


- (void)trackOperation:(AFHTTPRequestOperation*)operation forTitle:(MWKTitle*)title{
    
    if([title.text length] == 0){
        return;
    }
    
    dispatch_sync(self.operationsQueue, ^{
        
        self.operationsKeyedByTitle[title] = operation;
    });
}

#pragma mark - Query / Cancel Operations

- (void)untrackOperationForTitle:(MWKTitle*)title{
    
    dispatch_sync(self.operationsQueue, ^{
        
        [self.operationsKeyedByTitle removeObjectForKey:title];
    });
}


- (BOOL)isFetchingArticleForTitle:(MWKTitle*)pageTitle{
    
    return [self trackedOperationForTitle:pageTitle] != nil;
}

- (void)cancelFetchForPageTitle:(MWKTitle*)pageTitle{
    
    if([pageTitle.text length] == 0){
        return;
    }
    
    __block AFHTTPRequestOperation* op = nil;
    
    dispatch_sync(self.operationsQueue, ^{
        
        op = self.operationsKeyedByTitle[pageTitle.text];
    });
    
    [op cancel];
}

- (void)cancelAllFetches{
    
    [self.operationManager.operationQueue cancelAllOperations];
}


#pragma mark - MCCMNC Header

- (void)updateRequestSerializerMCCMNCHeader{
    
    if([SessionSingleton sharedInstance].shouldSendUsageReports){
        [self requestSerializer].shouldSendMCCMNCheader = YES;
    }else{
        [self requestSerializer].shouldSendMCCMNCheader = NO;
    }
}

@end

@implementation WMFArticlePreviewFetcher

- (AnyPromise*)fetchArticlePreviewForPageTitle:(MWKTitle*)pageTitle progress:(WMFProgressHandler __nullable)progress{
    
    NSAssert(pageTitle.text != nil, @"Title text nil");
    NSAssert(self.operationManager != nil, @"Manager nil");
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        
        [self fetchArticleForPageTitle:pageTitle useDesktopURL:NO progress:progress resolver:resolve];
    }];
    
}


@end


@interface WMFArticleFetcher ()

@property (nonatomic, strong, readwrite) MWKDataStore* dataStore;

@end

@implementation WMFArticleFetcher

- (instancetype)initWithDataStore:(MWKDataStore*)dataStore {
    self = [super init];
    if (self) {
        self.operationManager.requestSerializer = [WMFArticleRequestSerializer serializer];
        self.operationManager.responseSerializer = [WMFArticleResponseSerializer serializer];
        self.dataStore = dataStore;
    }
    return self;
}

- (id)serializedArticleWithTitle:(MWKTitle*)title response:(NSDictionary*)response{
    
    MWKArticle* article = [self.dataStore articleWithTitle:title];
    @try {
        [article importMobileViewJSON:response];
        [article save];
        
        for (int section = 0; section < [article.sections count]; section++) {
            (void)article.sections[section].images;             // hack
            WMFInjectArticleWithImagesFromSection(article, article.sections[section].text, section);
        }
        
        // Update article and section image data.
        // Reminder: don't recall article save here as it expensively re-writes all section html.
        [article saveWithoutSavingSectionText];
        return article;
        
    }@catch (NSException* e) {
        NSLog(@"%@", e);
        return [NSError wmf_serializeArticleErrorWithReason:[e reason]];
    }
}


- (AnyPromise*)fetchArticleForPageTitle:(MWKTitle*)pageTitle progress:(WMFProgressHandler __nullable)progress {
    
    NSAssert(pageTitle.text != nil, @"Title text nil");
    NSAssert(self.dataStore != nil, @"Store nil");
    NSAssert(self.operationManager != nil, @"Manager nil");
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        
        [self fetchArticleForPageTitle:pageTitle useDesktopURL:NO progress:progress resolver:resolve];
    }];
}

@end


NS_ASSUME_NONNULL_END