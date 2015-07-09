

#import "WMFArticleListTranstion.h"
#import "WMFScrollViewTopPanGestureRecognizer.h"

@interface WMFArticleListTranstion ()<UIGestureRecognizerDelegate>

@property (nonatomic, weak, readwrite) UIViewController* presentingViewController;
@property (nonatomic, weak, readwrite) UIViewController* presentedViewController;
@property (nonatomic, weak, readwrite) UIScrollView* scrollView;

@property (nonatomic, assign, readwrite) BOOL isPresented;
@property (nonatomic, assign, readwrite) BOOL isDismissing;
@property (nonatomic, assign, readwrite) BOOL isPresenting;

@property (strong, nonatomic) WMFScrollViewTopPanGestureRecognizer* dismissGestureRecognizer;
@property (assign, nonatomic) BOOL interactionInProgress;

@property (assign, nonatomic) CGFloat totalCardAnimationDistance;

@end

@implementation WMFArticleListTranstion

- (instancetype)initWithPresentingViewController:(UIViewController*)presentingViewController presentedViewController:(UIViewController*)presentedViewController contentScrollView:(UIScrollView*)scrollView {
    self = [super init];
    if (self) {
        _dismissInteractively     = YES;
        _presentingViewController = presentingViewController;
        _presentedViewController  = presentedViewController;
        _scrollView               = scrollView;
        [self addDismissGestureRecognizer];
    }
    return self;
}

- (void)setDismissInteractively:(BOOL)dismissInteractively {
    _dismissInteractively = dismissInteractively;
    [self addDismissGestureRecognizer];
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController*)presented presentingController:(UIViewController*)presenting sourceController:(UIViewController*)source {
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController*)dismissed {
    return self;
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator {
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator {
    if (self.dismissInteractively) {
        return self;
    }
    return nil;
}

#pragma mark - UIViewAnimatedTransistioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return self.nonInteractiveDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    if (self.isPresented) {
        [self animateDismiss:transitionContext];
    } else {
        [self animatePresentation:transitionContext];
    }
}

#pragma mark - UIViewControllerInteractiveTransitioning

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    [super startInteractiveTransition:transitionContext];
    self.interactionInProgress = YES;
}

- (CGFloat)completionSpeed {
    return (1 - self.percentComplete) * 1.5;
}

- (UIViewAnimationCurve)completionCurve {
    return UIViewAnimationCurveEaseOut;
}

#pragma mark - Animation

- (void)animatePresentation:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIView* containerView = [transitionContext containerView];

    UIViewController* presentingVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController* presentedVC   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    UIView* presentingView = presentingVC.view;
    UIView* presentedView   = presentedVC.view;

    //Setup presentedView
    CGRect presentedViewFrame = [transitionContext finalFrameForViewController:presentedVC];
    presentedView.frame = presentedViewFrame;
    presentedView.alpha = 0.0;

    UIView* dismissedView = self.transitioningViewBlock();

    //Setup snapshot of presented card
    UIView* snapshotView = [dismissedView snapshotViewAfterScreenUpdates:YES];
    CGRect dismissedSnapshotFrame = [containerView convertRect:dismissedView.frame fromView:dismissedView.superview];
    CGRect presentedSnapshotFrame = dismissedSnapshotFrame;
    presentedSnapshotFrame.origin.y = presentedViewFrame.origin.y + self.presentCardOffset;

    //How far the animation moves (used to compute percentage for the interactive portion)
    self.totalCardAnimationDistance = dismissedSnapshotFrame.origin.y - presentedViewFrame.origin.y;

    //Setup snapshot of overlapping cards
    CGRect dismissedSnapshotFrameAdjustedForPresentingView = [presentingView convertRect:dismissedView.frame fromView:dismissedView.superview];
    CGRect overlappingCardsSnapshotFrame     = CGRectMake(0, dismissedSnapshotFrameAdjustedForPresentingView.origin.y + self.offsetOfNextOverlappingCard, CGRectGetWidth(presentingView.bounds), CGRectGetHeight(presentingView.bounds));
    UIView* overlappingCardsSnapshot                 = [presentingView resizableSnapshotViewFromRect:overlappingCardsSnapshotFrame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];

    CGRect dismissedOverlappingCardsFrame  = CGRectMake(0, dismissedSnapshotFrame.origin.y + self.offsetOfNextOverlappingCard, CGRectGetWidth(presentingView.bounds), CGRectGetHeight(presentingView.bounds));
    CGRect middleOverlappingCardsFrame = CGRectOffset(overlappingCardsSnapshot.frame, 0, -30);
    CGRect presentedOverlappingCardsFrame = CGRectOffset(overlappingCardsSnapshot.frame, 0, CGRectGetHeight(containerView.frame) - overlappingCardsSnapshot.frame.origin.y);
    

    snapshotView.frame = dismissedSnapshotFrame;
    overlappingCardsSnapshot.frame  = dismissedOverlappingCardsFrame;

    //Add views to the container
    [containerView addSubview:presentedView];
    [containerView addSubview:snapshotView];
    [containerView addSubview:overlappingCardsSnapshot];

    self.isPresenting = YES;
    [UIView animateKeyframesWithDuration:self.nonInteractiveDuration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:1.0 animations:^{
            snapshotView.frame = presentedSnapshotFrame;
        }];

        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.25 animations:^{
            overlappingCardsSnapshot.frame = middleOverlappingCardsFrame;
        }];


        [UIView addKeyframeWithRelativeStartTime:0.25 relativeDuration:0.75 animations:^{
            overlappingCardsSnapshot.frame = presentedOverlappingCardsFrame;
        }];
    } completion:^(BOOL finished) {
        presentedView.alpha = 1.0;

        self.isPresenting = NO;
        self.isPresented = ![transitionContext transitionWasCancelled];

        [snapshotView removeFromSuperview];
        [overlappingCardsSnapshot removeFromSuperview];

        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

- (void)animateDismiss:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIView* containerView = [transitionContext containerView];

    UIViewController* presentingVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* presentedVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    UIView* presentingView = presentingVC.view;
    UIView* presentedView = presentedVC.view;
    
    CGRect presentedViewFrame = [transitionContext initialFrameForViewController:presentedVC];
    presentedView.alpha = 0.0;

    UIView* dismissedView = self.transitioningViewBlock();

    //Setup snapshot of presented card
    UIView* snapshotView = [presentedView snapshotViewAfterScreenUpdates:YES];
    CGRect dismissedSnapshotFrame = CGRectZero;
    if(dismissedView){
        dismissedSnapshotFrame = [containerView convertRect:dismissedView.frame fromView:dismissedView.superview];
    }else{
        dismissedSnapshotFrame = CGRectOffset(containerView.frame, 0, CGRectGetHeight(containerView.frame));
    }
    CGRect presentedSnapshotFrame = presentedView.frame;
    presentedSnapshotFrame.origin.y = presentedViewFrame.origin.y + self.presentCardOffset;
    
    //How far the animation moves (used to compute percentage for the interactive portion)
    self.totalCardAnimationDistance = dismissedSnapshotFrame.origin.y - presentedViewFrame.origin.y;

    //Setup snapshot of overlapping cards
    CGRect dismissedSnapshotFrameAdjustedForPresentingView = [presentingView convertRect:dismissedView.frame fromView:dismissedView.superview];
    CGRect overlappingCardsSnapshotFrame     = CGRectMake(0, dismissedSnapshotFrameAdjustedForPresentingView.origin.y + self.offsetOfNextOverlappingCard, CGRectGetWidth(presentingView.bounds), CGRectGetHeight(presentingView.bounds));
    UIView* overlappingCardsSnapshot                 = [presentingView resizableSnapshotViewFromRect:overlappingCardsSnapshotFrame afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
    
    CGRect dismissedOverlappingCardsFrame  = CGRectMake(0, dismissedSnapshotFrame.origin.y + self.offsetOfNextOverlappingCard, CGRectGetWidth(presentingView.bounds), CGRectGetHeight(presentingView.bounds));
    CGRect middleOverlappingCardsFrame = CGRectOffset(overlappingCardsSnapshot.frame, 0, -30);
    CGRect presentedOverlappingCardsFrame = CGRectOffset(overlappingCardsSnapshot.frame, 0, CGRectGetHeight(containerView.frame) - overlappingCardsSnapshot.frame.origin.y);

    snapshotView.frame = presentedSnapshotFrame;
    overlappingCardsSnapshot.frame  = presentedOverlappingCardsFrame;

    //Add views to the container
    [containerView addSubview:snapshotView];
    [containerView addSubview:overlappingCardsSnapshot];

    self.isDismissing = YES;
    [UIView animateKeyframesWithDuration:self.nonInteractiveDuration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:1.0 animations:^{
            snapshotView.frame = dismissedSnapshotFrame;
        }];

        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.75 animations:^{
            overlappingCardsSnapshot.frame = middleOverlappingCardsFrame;
        }];


        [UIView addKeyframeWithRelativeStartTime:0.75 relativeDuration:0.25 animations:^{
            overlappingCardsSnapshot.frame = dismissedOverlappingCardsFrame;
        }];
    } completion:^(BOOL finished) {
        if ([transitionContext transitionWasCancelled]) {
            presentedView.alpha = 1.0;
        }

        self.isDismissing = NO;
        self.isPresented = [transitionContext transitionWasCancelled];

        [snapshotView removeFromSuperview];
        [overlappingCardsSnapshot removeFromSuperview];

        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

#pragma mark - Gesture

- (void)addDismissGestureRecognizer {
    if (!self.dismissGestureRecognizer) {
        self.dismissGestureRecognizer          = (id)[[WMFScrollViewTopPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissGesture:)];
        self.dismissGestureRecognizer.delegate = self;
        [self.presentedViewController.view addGestureRecognizer:self.dismissGestureRecognizer];
        [self.dismissGestureRecognizer setScrollview:self.scrollView];
    }
}

- (void)removeDismissGestureRecognizer {
    if (self.dismissGestureRecognizer) {
        [self.presentedViewController.view removeGestureRecognizer:self.dismissGestureRecognizer];
        self.dismissGestureRecognizer.delegate = nil;
        self.dismissGestureRecognizer          = nil;
    }
}

- (void)handleDismissGesture:(UIPanGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint translation     = [recognizer translationInView:recognizer.view];
            BOOL swipeIsTopToBottom = translation.y > 0;
            if (swipeIsTopToBottom) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            break;
        }

        case UIGestureRecognizerStateChanged: {
            if (self.interactionInProgress) {
                CGPoint distanceTraveled = [recognizer translationInView:recognizer.view];
                CGFloat percent          = distanceTraveled.y / self.totalCardAnimationDistance;
                if (percent > 0.99) {
                    percent = 0.99;
                }
                [self updateInteractiveTransition:percent];
            }
            break;
        }

        case UIGestureRecognizerStateEnded: {
            if (self.percentComplete >= 0.33) {
                [self finishInteractiveTransition];
                return;
            }

            BOOL fastSwipe = [recognizer velocityInView:recognizer.view].y > self.totalCardAnimationDistance;

            if (fastSwipe) {
                [self finishInteractiveTransition];
                return;
            }

            [self cancelInteractiveTransition];

            break;
        }

        default:
            [self cancelInteractiveTransition];
            break;
    }
}

@end
