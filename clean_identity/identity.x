%config(generator=internal);
// CleanIdentity optional identity-cleanup hooks.
// These hooks are UI-only: post data and comment text remain untouched.
// TikTok internal class names vary by version, so hooks fail open if a class/key is absent.
#import "CleanIdentityPrefs.h"
#import <objc/runtime.h>
#import <math.h>
#import <objc/message.h>

static char kCleanIdentityHiddenKey;
static char kCleanCreatorLikedBadgeKey;

static UIView *CleanIdentityViewForKey(id object, NSString *key) {
    if (!object || !key) return nil;
    @try {
        id result = [object valueForKey:key];
        return [result isKindOfClass:[UIView class]] ? (UIView *)result : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

// Restore only views that CleanIdentity itself hid. Do not reveal UI hidden by TikTok.
static void CleanIdentitySetHidden(UIView *view, BOOL shouldHide) {
    if (!view) return;
    BOOL hiddenByCleanIdentity = [objc_getAssociatedObject(view, &kCleanIdentityHiddenKey) boolValue];
    if (shouldHide) {
        if (!view.hidden) {
            view.hidden = YES;
            objc_setAssociatedObject(view, &kCleanIdentityHiddenKey, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (hiddenByCleanIdentity) {
        view.hidden = NO;
        objc_setAssociatedObject(view, &kCleanIdentityHiddenKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Remember which privacy control owns a hidden comment view. TikTok may
// reconfigure that same view and call setHidden:NO when cells are recycled.
static char kCleanCommentAvatarGuardKey;
static char kCleanCommentNameGuardKey;
static BOOL CleanIdentityWithinCommentUI(UIView *view);

static void CleanIdentitySetCommentHidden(UIView *view, BOOL hide, BOOL isName) {
    if (!view) return;
    const void *key = isName ? (const void *)&kCleanCommentNameGuardKey
                             : (const void *)&kCleanCommentAvatarGuardKey;
    objc_setAssociatedObject(view, key, hide ? @YES : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CleanIdentitySetHidden(view, hide);
}

// TikTok's AWECommentPanelCell is a UITableView, not an individual row.
// Newer TikTok builds also wrap avatars inside image views rather than exposing
// a stable avatarView property on the outer comment container.
static BOOL CleanIdentityCommentAvatarCandidate(UIView *candidate, UIView *row) {
    if (![candidate isKindOfClass:[UIImageView class]] || !candidate.superview) return NO;
    CGRect rect = [candidate convertRect:candidate.bounds toView:row];
    CGFloat width = CGRectGetWidth(rect), height = CGRectGetHeight(rect);
    if (width < 18.0 || width > 82.0 || height < 18.0 || height > 82.0) return NO;
    if (fabs(width - height) > 12.0) return NO;
    // Only the small leading avatar in a comment row. Do not hide pictures,
    // stickers, reaction buttons or images attached to the comment body.
    CGFloat left = CGRectGetMinX(rect), top = CGRectGetMinY(rect);
    if (left < -3.0 || left > 110.0 || top < -3.0 ||
        top > MAX(70.0, CGRectGetHeight(row.bounds))) return NO;
    if (left > 42.0) {
        // Replies are indented. Their smaller round avatars must not be
        // confused with square stickers or photo replies in the comment body.
        CGFloat radius = MAX(candidate.layer.cornerRadius,
                             candidate.superview.layer.cornerRadius);
        NSString *className = NSStringFromClass([candidate class]);
        NSString *parentClass = NSStringFromClass([candidate.superview class]);
        BOOL avatarClass = [className rangeOfString:@"Avatar"
                                                  options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [parentClass rangeOfString:@"Avatar"
                                      options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (!avatarClass && radius < MIN(width, height) * 0.27) return NO;
    }
    return YES;
}

// A reply is indented further than a top-level comment. Find its muted
// username label next to the avatar, without hiding its darker comment text.
static BOOL CleanIdentityLooksLikeUsernameLabel(UILabel *label) {
    if (!label || !label.text.length || label.text.length > 100 ||
        label.numberOfLines > 1 || label.font.pointSize < 10.0 ||
        label.font.pointSize > 18.0) return NO;
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    UIColor *color = [label.textColor resolvedColorWithTraitCollection:label.traitCollection];
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return NO;
    CGFloat brightest = MAX(red, MAX(green, blue));
    CGFloat darkest = MIN(red, MIN(green, blue));
    return brightest - darkest < 0.20 && brightest >= 0.35 && brightest <= 0.87;
}

static BOOL CleanIdentityMaskNameNearAvatar(UIView *view, UIWindow *window,
                                           CGRect avatar, NSUInteger depth) {
    if (!view || depth > 7) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CGRect frame = [label convertRect:label.bounds toView:window];
        BOOL nextToAvatar = CGRectGetMinX(frame) >= CGRectGetMaxX(avatar) + 2.0 &&
            CGRectGetMinX(frame) < CGRectGetMaxX(avatar) + 42.0 &&
            fabs(CGRectGetMidY(frame) - CGRectGetMidY(avatar)) < 23.0;
        if (nextToAvatar && CleanIdentityLooksLikeUsernameLabel(label)) {
            CleanIdentitySetCommentHidden(label, [CleanIdentityPrefs hideCommentUsernames], YES);
            return YES;
        }
    }
    for (UIView *child in view.subviews) {
        if (CleanIdentityMaskNameNearAvatar(child, window, avatar, depth + 1)) return YES;
    }
    return NO;
}

static void CleanIdentityMaskNearbyCommentName(UIImageView *avatarView) {
    if (!avatarView.window || !avatarView.superview) return;
    CGRect avatar = [avatarView convertRect:avatarView.bounds toView:avatarView.window];
    UIView *parent = avatarView.superview;
    // Search the closest comment sub-tree first. Do not look outside the
    // containing comment table or collection and risk changing unrelated UI.
    for (NSUInteger i = 0; parent && i < 9; i++, parent = parent.superview) {
        if ([parent isKindOfClass:[UITableView class]] ||
            [parent isKindOfClass:[UICollectionView class]]) break;
        if (CleanIdentityMaskNameNearAvatar(parent, avatarView.window, avatar, 0)) break;
    }
}

static void CleanIdentityScanCommentImages(UIView *view, UIView *row, NSUInteger depth) {
    if (!view || depth > 10) return;
    if (CleanIdentityCommentAvatarCandidate(view, row)) {
        CleanIdentitySetCommentHidden(view, [CleanIdentityPrefs hideCommentAvatars], NO);
        CleanIdentityMaskNearbyCommentName((UIImageView *)view);
    }
    for (UIView *child in view.subviews) {
        CleanIdentityScanCommentImages(child, row, depth + 1);
    }
}

static void CleanIdentityApplyCommentRow(UIView *row) {
    if (!row) return;
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(row, @"nameLabel"),
                                  [CleanIdentityPrefs hideCommentUsernames], YES);
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(row, @"avatarView"),
                                  [CleanIdentityPrefs hideCommentAvatars], NO);
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(row, @"avatarBorderView"),
                                  [CleanIdentityPrefs hideCommentAvatars], NO);
    CleanIdentityScanCommentImages(row, row, 0);
}

static BOOL CleanIdentityWithinCommentUI(UIView *view) {
    UIView *parent = view;
    for (NSUInteger n = 0; parent && n < 20; n++, parent = parent.superview) {
        NSString *name = NSStringFromClass([parent class]);
        if ([name rangeOfString:@"Comment" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL CleanIdentityWithinFeedUI(UIView *view, BOOL *avatarNamed) {
    BOOL feed = NO, avatar = NO;
    UIView *parent = view;
    for (NSUInteger n = 0; parent && n < 22; n++, parent = parent.superview) {
        NSString *name = NSStringFromClass([parent class]);
        if ([name rangeOfString:@"Avatar" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"UserHead" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            avatar = YES;
        }
        if ([name rangeOfString:@"Feed" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"PlayInteraction" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Aweme" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            feed = YES;
        }
    }
    if (avatarNamed) *avatarNamed = avatar;
    return feed;
}

// A creator-liked badge is a tiny circular photo/heart alongside the "Reply"
// action, not the regular comment avatar. Identify it by BOTH relative position
// and the adjacent Reply label, leaving stickers and like controls untouched.
static BOOL CleanIdentityIsReplyActionText(NSString *value) {
    if (!value.length) return NO;
    NSString *text = [value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [text caseInsensitiveCompare:@"Reply"] == NSOrderedSame ||
           [text caseInsensitiveCompare:@"Yanıtla"] == NSOrderedSame;
}

static BOOL CleanIdentityFindReplyActionNear(UIView *root, UIWindow *window,
                                            CGRect badge, NSUInteger depth) {
    if (!root || depth > 9) return NO;
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)root;
        NSString *title = label.text ?: label.attributedText.string;
        if (CleanIdentityIsReplyActionText(title)) {
            CGRect rect = [label convertRect:label.bounds toView:window];
            CGFloat horizontal = CGRectGetMidX(badge) - CGRectGetMaxX(rect);
            if (horizontal > -6.0 && horizontal < 96.0 &&
                fabs(CGRectGetMidY(badge) - CGRectGetMidY(rect)) < 18.0)
                return YES;
        }
    }
    for (UIView *child in root.subviews) {
        if (CleanIdentityFindReplyActionNear(child, window, badge, depth + 1))
            return YES;
    }
    return NO;
}

static BOOL CleanIdentityIsCreatorLikedBadge(UIImageView *image, CGRect badge) {
    CGFloat width = CGRectGetWidth(badge), height = CGRectGetHeight(badge);
    if (width < 9.0 || width > 40.0 || height < 9.0 || height > 40.0 ||
        fabs(width - height) > 11.0 ||
        !CleanIdentityWithinCommentUI(image)) return NO;

    UIView *ancestor = image.superview;
    for (NSUInteger i = 0; ancestor && i < 9; i++, ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:[UITableView class]] ||
            [ancestor isKindOfClass:[UICollectionView class]]) break;
        if (CleanIdentityFindReplyActionNear(ancestor, image.window, badge, 0))
            return YES;
    }
    return NO;
}

// Creator-liked is sometimes a portrait+heart container rather than a
// UIImageView. Match compact image widgets immediately following "Reply".
static char kCleanFooterBadgeKey;

static BOOL CleanIdentityContainsBadgeImage(UIView *view, NSUInteger depth) {
    if (!view || depth > 3) return NO;
    if ([view isKindOfClass:[UIImageView class]]) return YES;
    for (UIView *child in view.subviews)
        if (CleanIdentityContainsBadgeImage(child, depth + 1)) return YES;
    return NO;
}

static UIView *CleanIdentitySmallestBadgeWrapper(UIView *view, UIWindow *window) {
    UIView *selected = view;
    for (UIView *parent = view.superview; parent && parent != window;
         parent = parent.superview) {
        CGRect frame = [parent convertRect:parent.bounds toView:window];
        if (CGRectGetWidth(frame) > 48.0 || CGRectGetHeight(frame) > 48.0 ||
            CGRectGetWidth(frame) < 8.0 || CGRectGetHeight(frame) < 8.0)
            break;
        selected = parent;
    }
    return selected;
}

static BOOL CleanIdentityMaskAdjacentBadges(UIView *root, UIWindow *window,
                                           CGRect reply, NSUInteger depth) {
    if (!root || depth > 10) return NO;
    BOOL found = NO;
    for (UIView *child in root.subviews) {
        CGRect frame = [child convertRect:child.bounds toView:window];
        CGFloat dx = CGRectGetMidX(frame) - CGRectGetMaxX(reply);
        CGFloat dy = fabs(CGRectGetMidY(frame) - CGRectGetMidY(reply));
        CGFloat w = CGRectGetWidth(frame), h = CGRectGetHeight(frame);
        NSString *name = NSStringFromClass([child class]);
        BOOL named = [name rangeOfString:@"Avatar"
                                options:NSCaseInsensitiveSearch].location != NSNotFound ||
                     [name rangeOfString:@"CreatorLike"
                                options:NSCaseInsensitiveSearch].location != NSNotFound ||
                     [name rangeOfString:@"AuthorLike"
                                options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (dx >= -2.0 && dx <= 76.0 && dy < 20.0 &&
            w >= 9.0 && w <= 44.0 && h >= 9.0 && h <= 44.0 &&
            (named || CleanIdentityContainsBadgeImage(child, 3))) {
            UIView *wrapper = CleanIdentitySmallestBadgeWrapper(child, window);
            objc_setAssociatedObject(wrapper, &kCleanFooterBadgeKey,
                                     @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            CleanIdentitySetCommentHidden(wrapper, [CleanIdentityPrefs hideCommentAvatars], NO);
            found = YES;
            continue;
        }
        if (w > 44.0 && h >= 10.0 &&
            CGRectGetMinY(frame) < CGRectGetMaxY(reply) + 35.0 &&
            CGRectGetMaxY(frame) > CGRectGetMinY(reply) - 35.0)
            found |= CleanIdentityMaskAdjacentBadges(child, window, reply, depth + 1);
    }
    return found;
}

static void CleanIdentityMaskFooterBadgeFromReply(UILabel *label) {
    if (!label || !label.window || !CleanIdentityWithinCommentUI(label)) return;
    NSString *title = label.text ?: label.attributedText.string;
    if (!CleanIdentityIsReplyActionText(title)) return;
    UIWindow *window = label.window;
    CGRect frame = [label convertRect:label.bounds toView:window];
    CGFloat screenWidth = CGRectGetWidth(window.bounds);
    if (CGRectGetMinX(frame) < 0 || CGRectGetMaxX(frame) > screenWidth * 0.77 ||
        CGRectGetHeight(frame) < 8.0 || CGRectGetHeight(frame) > 44.0) return;
    UIView *parent = label.superview;
    // Walk outward until the badge sibling is within scope. Stop before the
    // comment table/collection to avoid hiding an unrelated row's controls.
    for (NSUInteger level = 0; parent && level < 8;
         level++, parent = parent.superview) {
        if ([parent isKindOfClass:[UITableView class]] ||
            [parent isKindOfClass:[UICollectionView class]]) break;
        CGRect rect = [parent convertRect:parent.bounds toView:window];
        if (CGRectGetMaxX(rect) > CGRectGetMaxX(frame) + 16.0 &&
            CleanIdentityMaskAdjacentBadges(parent, window, frame, 0))
            break;
    }
}

static BOOL CleanIdentityRefreshTaggedFooterBadge(UIImageView *image) {
    for (UIView *parent = image, *target = nil; parent && parent != image.window;
         parent = parent.superview) {
        if (objc_getAssociatedObject(parent, &kCleanFooterBadgeKey)) {
            target = parent;
            BOOL inComments = CleanIdentityWithinCommentUI(target);
            CleanIdentitySetCommentHidden(target,
                [CleanIdentityPrefs hideCommentAvatars] && inComments, NO);
            if (!inComments)
                objc_setAssociatedObject(target, &kCleanFooterBadgeKey, nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
    }
    return NO;
}

static BOOL CleanIdentityUpdateCreatorLikedBadge(UIImageView *image, CGRect frame) {
    BOOL match = CleanIdentityIsCreatorLikedBadge(image, frame);
    BOOL wasBadge = [objc_getAssociatedObject(image, &kCleanCreatorLikedBadgeKey) boolValue];
    if (!match && !wasBadge) return NO;
    UIView *view = image;
    // Hide the tiny avatar and overlaid heart as one compact widget.
    UIView *container = image.superview;
    if (container) {
        CGRect rect = [container convertRect:container.bounds toView:image.window];
        if (CGRectGetWidth(rect) >= CGRectGetWidth(frame) &&
            CGRectGetWidth(rect) <= 48.0 &&
            CGRectGetHeight(rect) >= CGRectGetHeight(frame) &&
            CGRectGetHeight(rect) <= 48.0)
            view = container;
    }
    CleanIdentitySetCommentHidden(view, match && [CleanIdentityPrefs hideCommentAvatars], NO);
    objc_setAssociatedObject(image, &kCleanCreatorLikedBadgeKey,
                             match ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return match;
}

// Newer TikTok builds put the author's name and the blue "Creator" marker
// in the same label or in adjacent labels above the actual reply text.
static BOOL CleanIdentityCreatorMarkerText(NSString *value) {
    if (!value.length) return NO;
    NSString *text = [value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [text caseInsensitiveCompare:@"Creator"] == NSOrderedSame ||
        [text rangeOfString:@" · Creator" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void CleanIdentityMaskCreatorHeaderLabels(UIView *root, UILabel *marker,
                                                 CGRect markerFrame, NSUInteger depth) {
    if (!root || depth > 7) return;
    if ([root isKindOfClass:[UILabel class]] && root != marker) {
        UILabel *other = (UILabel *)root;
        NSString *content = other.text ?: other.attributedText.string;
        CGRect rect = [other convertRect:other.bounds toView:marker.window];
        CGFloat distance = CGRectGetMinX(markerFrame) - CGRectGetMaxX(rect);
        if (content.length > 0 && content.length < 100 &&
            other.font.pointSize <= 18.0 && other.numberOfLines <= 1 &&
            distance >= -8.0 && distance < 175.0 &&
            fabs(CGRectGetMidY(markerFrame) - CGRectGetMidY(rect)) < 12.0) {
            CleanIdentitySetCommentHidden(other, [CleanIdentityPrefs hideCommentUsernames], YES);
        }
    }
    for (UIView *child in root.subviews)
        CleanIdentityMaskCreatorHeaderLabels(child, marker, markerFrame, depth + 1);
}

static void CleanIdentityApplyCreatorHeader(UILabel *label) {
    NSString *value = label.text ?: label.attributedText.string;
    BOOL marker = CleanIdentityCreatorMarkerText(value);
    BOOL previouslyHidden = [objc_getAssociatedObject(label, &kCleanIdentityHiddenKey) boolValue];
    if (!marker && !previouslyHidden) return;
    if (!label.window || !CleanIdentityWithinCommentUI(label)) {
        if (previouslyHidden) CleanIdentitySetCommentHidden(label, NO, YES);
        return;
    }
    if (!marker) {
        if (![CleanIdentityPrefs hideCommentUsernames])
            CleanIdentitySetCommentHidden(label, NO, YES);
        return;
    }
    CGRect rect = [label convertRect:label.bounds toView:label.window];
    CGFloat width = CGRectGetWidth(label.window.bounds);
    if (CGRectGetMinX(rect) < 0 || CGRectGetMinX(rect) > width * 0.75 ||
        CGRectGetHeight(rect) > 38.0 || label.font.pointSize > 19.0) return;
    CleanIdentitySetCommentHidden(label, [CleanIdentityPrefs hideCommentUsernames], YES);
    UIView *parent = label.superview;
    for (NSUInteger i = 0; parent && i < 5; i++, parent = parent.superview) {
        if ([parent isKindOfClass:[UITableView class]] ||
            [parent isKindOfClass:[UICollectionView class]]) break;
        CleanIdentityMaskCreatorHeaderLabels(parent, label, rect, 0);
    }
}

static void CleanIdentityApplyImageFallback(UIImageView *image) {
    BOOL hideComment = [CleanIdentityPrefs hideCommentAvatars];
    BOOL hideFeed = [CleanIdentityPrefs hideVideoAvatars];
    BOOL hideNames = [CleanIdentityPrefs hideCommentUsernames];
    BOOL hiddenByUs = [objc_getAssociatedObject(image, &kCleanIdentityHiddenKey) boolValue];
    BOOL wasCreatorBadge = [objc_getAssociatedObject(image, &kCleanCreatorLikedBadgeKey) boolValue];
    if (!hideComment && !hideFeed && !hideNames && !hiddenByUs && !wasCreatorBadge) return;
    UIWindow *window = image.window;
    if (!window || !image.superview) return;

    CGRect rect = [image convertRect:image.bounds toView:window];
    if (CleanIdentityRefreshTaggedFooterBadge(image)) return;
    // This distinct badge needs to return early; otherwise the generic
    // avatar fallback can immediately unhide the tiny creator-liked image.
    if ((hideComment || wasCreatorBadge) &&
        CleanIdentityUpdateCreatorLikedBadge(image, rect))
        return;
    CGFloat width = CGRectGetWidth(rect), height = CGRectGetHeight(rect);
    CGFloat screenWidth = CGRectGetWidth(window.bounds), screenHeight = CGRectGetHeight(window.bounds);
    if (width < 18.0 || width > 90.0 || fabs(width - height) > 12.0 ||
        screenWidth <= 0.0 || screenHeight <= 0.0) {
        if (hiddenByUs) CleanIdentitySetHidden(image, NO);
        return;
    }

    // Comment avatars remain on the leading edge of comment rows, even when
    // TikTok changes the private row subclass or image-view property.
    if (CGRectGetMinX(rect) >= 0.0 && CGRectGetMinX(rect) < screenWidth * 0.26 &&
        CleanIdentityWithinCommentUI(image)) {
        CleanIdentitySetCommentHidden(image, hideComment, NO);
        CleanIdentityMaskNearbyCommentName(image);
        return;
    }

    BOOL avatarNamed = NO;
    BOOL inFeed = CleanIdentityWithinFeedUI(image, &avatarNamed);
    CGFloat radius = 0.0;
    BOOL hasCircularMask = NO;
    UIView *roundAncestor = image;
    for (NSUInteger depth = 0; roundAncestor && depth < 4; depth++,
         roundAncestor = roundAncestor.superview) {
        radius = MAX(radius, roundAncestor.layer.cornerRadius);
        if (roundAncestor.layer.mask &&
            fabs(CGRectGetWidth(roundAncestor.bounds) -
                 CGRectGetHeight(roundAncestor.bounds)) < 12.0) {
            hasCircularMask = YES;
        }
    }
    BOOL roundImage = radius >= MIN(width, height) * 0.27 || hasCircularMask;
    BOOL inRightAvatarSpot = CGRectGetMinX(rect) > screenWidth * 0.78 &&
        CGRectGetMidY(rect) > screenHeight * 0.37 &&
        CGRectGetMidY(rect) < screenHeight * 0.60 &&
        width >= 24.0 && width <= 70.0;
    if ((inFeed || inRightAvatarSpot) && (avatarNamed || roundImage) &&
        CGRectGetMinX(rect) > screenWidth * 0.72 &&
        CGRectGetMidY(rect) > screenHeight * 0.15 &&
        CGRectGetMidY(rect) < screenHeight * 0.85) {
        CleanIdentitySetHidden(image, hideFeed);
        return;
    }
    if (hiddenByUs) CleanIdentitySetHidden(image, NO);
}

// Also called from BDImageView's own layout hook, because subclass overrides
// can bypass UIKit's inherited UIImageView method implementation.
void CleanIdentityProcessImage(UIImageView *image) {
    CleanIdentityApplyImageFallback(image);
}

static void CleanIdentityApplyCommentCell(UIView *cell) {
    BOOL hideNames = [CleanIdentityPrefs hideCommentUsernames];
    BOOL hideAvatars = [CleanIdentityPrefs hideCommentAvatars];
    // TikTok AWECommentPanelBaseCell exposes nameLabel, avatarView and
    // avatarBorderView in known versions. KVC protects newer versions.
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(cell, @"nameLabel"), hideNames, YES);
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(cell, @"avatarView"), hideAvatars, NO);
    CleanIdentitySetCommentHidden(CleanIdentityViewForKey(cell, @"avatarBorderView"), hideAvatars, NO);
    if ([cell isKindOfClass:[UITableView class]]) {
        for (UITableViewCell *row in ((UITableView *)cell).visibleCells) {
            CleanIdentityApplyCommentRow(row);
        }
    } else {
        CleanIdentityApplyCommentRow(cell);
    }
}

static BOOL CleanIdentityClassNameContains(id object, NSString *term) {
    if (!object || !term) return NO;
    NSString *name = NSStringFromClass([object class]);
    return name && [name rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL CleanIdentityIsElement(id element, NSString *name) {
    Class cls = NSClassFromString(name);
    return element && cls && [element isKindOfClass:cls];
}

static id CleanIdentityElementForRow(UIView *row) {
    @try {
        return [row valueForKey:@"element"];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

%hook AWECommentPanelCell
- (void)layoutSubviews {
    %orig;
    CleanIdentityApplyCommentCell((UIView *)self);
}
- (void)configWithComment:(id)comment {
    %orig;
    CleanIdentityApplyCommentCell((UIView *)self);
}
%end

// The creator-name button exists in known TikTok builds. Hide only its
// visible UI rather than editing the author model or the caption.
%hook AWEPlayInteractionAuthorUserNameButton
- (void)layoutSubviews {
    %orig;
    CleanIdentitySetHidden((UIView *)self, [CleanIdentityPrefs hideVideoUsernames]);
}
%end

// TikTok represents several right-side icons as model-backed element rows.
// Hide only the specific avatar/music rows, keeping likes and comments intact.
%hook AWEBaseElementView
- (void)layoutSubviews {
    %orig;
    id element = CleanIdentityElementForRow((UIView *)self);
    BOOL avatarRow = CleanIdentityIsElement(element, @"AWEPlayInteractionUserAvatarElement")
        || CleanIdentityIsElement(element, @"AWEPlayInteractionAvatarElement")
        || CleanIdentityIsElement(element, @"TTKPlayInteractionUserAvatarElement")
        || CleanIdentityClassNameContains(element, @"Avatar")
        || CleanIdentityClassNameContains(self, @"Avatar");
    BOOL musicRow = CleanIdentityIsElement(element, @"AWEPlayInteractionMusicElement")
        || CleanIdentityIsElement(element, @"AWEPlayInteractionMusicCoverElement")
        || CleanIdentityIsElement(element, @"TTKPlayInteractionMusicElement");
    if (avatarRow) {
        CleanIdentitySetHidden((UIView *)self, [CleanIdentityPrefs hideVideoAvatars]);
    } else if (musicRow) {
        CleanIdentitySetHidden((UIView *)self, [CleanIdentityPrefs hideMusicDisc]);
    }
}
%end

// Use the right-hand feed rail geometry only for the avatar-specific views.
// This avoids touching profile pages, comment stickers and the like/share rail.
static BOOL CleanIdentityIsRightFeedAvatar(UIView *view) {
    if (!view || !view.window || !view.superview) return NO;
    UIWindow *window = view.window;
    CGRect bounds = [view convertRect:view.bounds toView:window];
    CGFloat w = CGRectGetWidth(window.bounds), h = CGRectGetHeight(window.bounds);
    CGFloat diameter = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (w <= 0.0 || h <= 0.0) return NO;
    // The dedicated user-avatar view can include an extra follow/ring area,
    // so its bounds need not be perfectly square.
    NSString *name = NSStringFromClass([view class]);
    BOOL dedicatedAvatar = [name isEqualToString:@"AWEPlayInteractionUserAvatarView"] ||
        [name isEqualToString:@"AWEAdAvatarView"] ||
        [name isEqualToString:@"AWEPlayInteractionAvatarView"];
    BOOL plausibleSize = dedicatedAvatar
        ? (CGRectGetWidth(bounds) >= 24.0 && CGRectGetWidth(bounds) <= 112.0 &&
           CGRectGetHeight(bounds) >= 24.0 && CGRectGetHeight(bounds) <= 144.0)
        : (diameter >= 24.0 && diameter <= 90.0 &&
           fabs(CGRectGetWidth(bounds) - CGRectGetHeight(bounds)) <= 18.0);
    return plausibleSize &&
        CGRectGetMinX(bounds) > w * 0.71 &&
        CGRectGetMidY(bounds) > h * 0.30 &&
        CGRectGetMidY(bounds) < h * 0.67;
}

static void CleanIdentityUpdateFeedAvatarView(UIView *view) {
    if (CleanIdentityIsRightFeedAvatar(view) ||
        [objc_getAssociatedObject(view, &kCleanIdentityHiddenKey) boolValue]) {
        CleanIdentitySetHidden(view, [CleanIdentityPrefs hideVideoAvatars]);
    }
}

// TikTok's native right-rail avatar view. Unlike the follow-badge element,
// these views still display the profile picture after setHide: hides the badge.
%hook AWEAdAvatarView
- (void)layoutSubviews {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([CleanIdentityPrefs hideVideoAvatars] && CleanIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

// On newer TikTok feeds the profile photo is hosted in a dedicated
// AWEPlayInteractionUserAvatarView, separate from its follow-prompt/plus view.
// Only mask it when located at the video author's right-rail avatar position.
%hook AWEPlayInteractionUserAvatarView
- (void)layoutSubviews {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([CleanIdentityPrefs hideVideoAvatars] && CleanIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

%hook AWEPlayInteractionAvatarView
- (void)layoutSubviews {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([CleanIdentityPrefs hideVideoAvatars] && CleanIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

// Some recent TikTok versions render the creator avatar and follow badge in
// a dedicated container rather than through AWEBaseElementView.
%hook AWEPlayInteractionUserProfileContainerView
- (void)layoutSubviews {
    %orig;
    CleanIdentitySetHidden((UIView *)self, [CleanIdentityPrefs hideVideoAvatars]);
}
- (void)setHidden:(BOOL)hidden {
    if ([CleanIdentityPrefs hideVideoAvatars]) hidden = YES;
    %orig(hidden);
}
%end

// The optimized feed avatar element is separate from the regular one.
%hook AWEPlayInteractionUserAvatarOptElementElement
- (void)layoutElementView {
    %orig;
    if ([CleanIdentityPrefs hideVideoAvatars] && [(id)self respondsToSelector:@selector(setHide:)]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(setHide:), YES);
    }
}
%end

// Fallback for older builds where the music disc is its own UIView.
%hook AWEPlayInteractionMusicView
- (void)layoutSubviews {
    %orig;
    CleanIdentitySetHidden((UIView *)self, [CleanIdentityPrefs hideMusicDisc]);
}
%end

// Remove @mentions from displayed comment text only; the original TikTok
// comment model remains unmodified. Preserve attributed styles and provide
// reversible rendering when the switch is turned off or cells are reused.
static char kCleanMentionSourceKey;
static char kCleanMentionRenderedKey;
static char kCleanCommentTextRebindingKey;

static NSAttributedString *CleanIdentityRedactMentions(NSAttributedString *source) {
    if (!source.length) return nil;
    static NSRegularExpression *mentionRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mentionRegex = [NSRegularExpression regularExpressionWithPattern:
            @"(?<![\\p{L}\\p{M}\\p{N}._])@[\\p{L}\\p{M}\\p{N}_](?:[\\p{L}\\p{M}\\p{N}._-]*[\\p{L}\\p{M}\\p{N}_])?"
            options:0 error:NULL];
    });
    if (!mentionRegex) return nil;
    NSString *text = source.string;
    NSArray<NSTextCheckingResult *> *matches =
        [mentionRegex matchesInString:text options:0
                                range:NSMakeRange(0, text.length)];
    if (!matches.count) return nil;

    NSMutableAttributedString *edited = [source mutableCopy];
    // Reverse order keeps all original match ranges valid.
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSRange range = match.range;
        if (NSMaxRange(range) < text.length &&
            [text characterAtIndex:NSMaxRange(range)] == ' ') {
            range.length += 1; // avoid a double space in the remaining comment
        } else if (range.location > 0 && NSMaxRange(range) == text.length &&
                   [text characterAtIndex:range.location - 1] == ' ') {
            range.location -= 1;
            range.length += 1;
        }
        [edited deleteCharactersInRange:range];
    }
    return edited;
}

static void CleanIdentityApplyMentionMask(UILabel *label) {
    if (!label) return;
    NSAttributedString *source = objc_getAssociatedObject(label, &kCleanMentionSourceKey);
    NSAttributedString *rendered = objc_getAssociatedObject(label, &kCleanMentionRenderedKey);
    NSAttributedString *current = label.attributedText;
    BOOL wasRedacted = source && rendered && [current isEqualToAttributedString:rendered];

    // If TikTok assigned new text to a reused row, discard its old cache.
    if (source && !wasRedacted) {
        objc_setAssociatedObject(label, &kCleanMentionSourceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(label, &kCleanMentionRenderedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        source = nil;
    }

    BOOL enabled = [CleanIdentityPrefs hideCommentUsernames] &&
        label.window && CleanIdentityWithinCommentUI(label);
    if (!enabled) {
        if (wasRedacted) [label setAttributedText:source];
        objc_setAssociatedObject(label, &kCleanMentionSourceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(label, &kCleanMentionRenderedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (wasRedacted) return;
    if (!current.length || [current.string rangeOfString:@"@"].location == NSNotFound)
        return;
    NSAttributedString *masked = CleanIdentityRedactMentions(current);
    if (!masked || [masked isEqualToAttributedString:current]) return;

    objc_setAssociatedObject(label, &kCleanMentionSourceKey, [current copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(label, &kCleanMentionRenderedKey, masked, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [label setAttributedText:masked];
}

// Refresh rows before they are displayed and whenever TikTok reuses them.
// This is scoped to comment tables/collections, not the entire feed.
static char kCleanCommentRowRefreshingKey;

static BOOL CleanIdentityAnyCommentPrivacyEnabled(void) {
    return [CleanIdentityPrefs hideCommentUsernames] || [CleanIdentityPrefs hideCommentAvatars];
}

static void CleanIdentityRefreshCommentSubtree(UIView *view, NSUInteger depth) {
    if (!view || depth > 12) return;
    if ([view isKindOfClass:[UIImageView class]]) {
        CleanIdentityApplyImageFallback((UIImageView *)view);
    }
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CleanIdentityApplyCreatorHeader(label);
        CleanIdentityApplyMentionMask(label);
        CleanIdentityMaskFooterBadgeFromReply(label);
    }
    for (UIView *child in view.subviews)
        CleanIdentityRefreshCommentSubtree(child, depth + 1);
}

static void CleanIdentityRefreshCommentRow(UIView *row) {
    if (!row || !CleanIdentityAnyCommentPrivacyEnabled() ||
        !CleanIdentityWithinCommentUI(row) ||
        objc_getAssociatedObject(row, &kCleanCommentRowRefreshingKey)) return;
    objc_setAssociatedObject(row, &kCleanCommentRowRefreshingKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        CleanIdentityApplyCommentRow(row);
        CleanIdentityRefreshCommentSubtree(row, 0);
    } @finally {
        objc_setAssociatedObject(row, &kCleanCommentRowRefreshingKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Cells are reused for unrelated comments. Clear per-view guards before the
// next comment is bound, so an old hidden username cannot hide new body text.
static void CleanIdentityClearCommentReuseTags(UIView *view, NSUInteger depth) {
    if (!view || depth > 12) return;
    BOOL name = [objc_getAssociatedObject(view, &kCleanCommentNameGuardKey) boolValue];
    BOOL avatar = [objc_getAssociatedObject(view, &kCleanCommentAvatarGuardKey) boolValue];
    if (name || avatar) {
        objc_setAssociatedObject(view, &kCleanCommentNameGuardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kCleanCommentAvatarGuardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CleanIdentitySetHidden(view, NO);
    }
    objc_setAssociatedObject(view, &kCleanFooterBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kCleanCreatorLikedBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        NSAttributedString *source = objc_getAssociatedObject(view, &kCleanMentionSourceKey);
        NSAttributedString *rendered = objc_getAssociatedObject(view, &kCleanMentionRenderedKey);
        if (source && rendered &&
            [label.attributedText isEqualToAttributedString:rendered]) {
            objc_setAssociatedObject(label, &kCleanCommentTextRebindingKey, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [label setAttributedText:source];
            objc_setAssociatedObject(label, &kCleanCommentTextRebindingKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(view, &kCleanMentionSourceKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kCleanMentionRenderedKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIView *child in view.subviews)
        CleanIdentityClearCommentReuseTags(child, depth + 1);
}

// Comment headers are sometimes drawn by TikTok-specific UILabel subclasses
// that override layoutSubviews without passing through UILabel's implementation.
%hook TTTAttributedLabel
- (void)layoutSubviews {
    %orig;
    if ([CleanIdentityPrefs hideCommentUsernames] ||
        [objc_getAssociatedObject(self, &kCleanIdentityHiddenKey) boolValue])
        CleanIdentityApplyCreatorHeader((UILabel *)self);
    CleanIdentityApplyMentionMask((UILabel *)self);
    CleanIdentityMaskFooterBadgeFromReply((UILabel *)self);
}
%end

%hook TUXLabel
- (void)layoutSubviews {
    %orig;
    if ([CleanIdentityPrefs hideCommentUsernames] ||
        [objc_getAssociatedObject(self, &kCleanIdentityHiddenKey) boolValue])
        CleanIdentityApplyCreatorHeader((UILabel *)self);
    CleanIdentityApplyMentionMask((UILabel *)self);
    CleanIdentityMaskFooterBadgeFromReply((UILabel *)self);
}
%end

// Fallback for image-backed avatars on newer TikTok versions. This is limited
// to image views that are located in a comment/feed context and at an avatar
// position; the rest of the TikTok UI is left unchanged.
// Only look for Creator markers inside comment UI; avoid hiding a creator's
// profile text or ordinary comments that happen to mention the word.
%hook UILabel
// Process incoming labels before UIKit paints them, preventing a flash of
// the original @mention text when TikTok updates an existing comment.
- (void)setAttributedText:(NSAttributedString *)value {
    NSAttributedString *display = value;
    if (value.length && !objc_getAssociatedObject(self, &kCleanCommentTextRebindingKey) &&
        [CleanIdentityPrefs hideCommentUsernames] &&
        CleanIdentityWithinCommentUI((UIView *)self) &&
        [value.string rangeOfString:@"@"].location != NSNotFound) {
        NSAttributedString *redacted = CleanIdentityRedactMentions(value);
        if (redacted) {
            display = redacted;
            objc_setAssociatedObject(self, &kCleanMentionSourceKey, [value copy],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &kCleanMentionRenderedKey, display,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    %orig(display);
}

- (void)setText:(NSString *)value {
    NSString *display = value;
    NSAttributedString *original = nil;
    if (value.length && !objc_getAssociatedObject(self, &kCleanCommentTextRebindingKey) &&
        [CleanIdentityPrefs hideCommentUsernames] &&
        CleanIdentityWithinCommentUI((UIView *)self) &&
        [value rangeOfString:@"@"].location != NSNotFound) {
        original = [[NSAttributedString alloc] initWithString:value];
        NSAttributedString *masked = CleanIdentityRedactMentions(original);
        if (masked) display = masked.string;
        else original = nil;
    }
    %orig(display);
    if (original) {
        objc_setAssociatedObject(self, &kCleanMentionSourceKey, original,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kCleanMentionRenderedKey,
                                 [self.attributedText copy],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)layoutSubviews {
    %orig;
    if ([CleanIdentityPrefs hideCommentUsernames] ||
        [objc_getAssociatedObject(self, &kCleanIdentityHiddenKey) boolValue]) {
        CleanIdentityApplyCreatorHeader((UILabel *)self);
    }
    CleanIdentityApplyMentionMask((UILabel *)self);
    CleanIdentityMaskFooterBadgeFromReply((UILabel *)self);
}
- (void)didMoveToWindow {
    %orig;
    if ([CleanIdentityPrefs hideCommentUsernames] ||
        [objc_getAssociatedObject(self, &kCleanIdentityHiddenKey) boolValue]) {
        CleanIdentityApplyCreatorHeader((UILabel *)self);
    }
    CleanIdentityApplyMentionMask((UILabel *)self);
    CleanIdentityMaskFooterBadgeFromReply((UILabel *)self);
}
%end

// Privacy guard: only previously identified comment identity views are
// forced to remain invisible. This does not alter comment models or requests.
%hook UIView
- (void)setHidden:(BOOL)hidden {
    if (!hidden) {
        BOOL name = [objc_getAssociatedObject(self, &kCleanCommentNameGuardKey) boolValue];
        BOOL avatar = [objc_getAssociatedObject(self, &kCleanCommentAvatarGuardKey) boolValue];
        if ((name || avatar) && CleanIdentityWithinCommentUI((UIView *)self) &&
            ((name && [CleanIdentityPrefs hideCommentUsernames]) ||
             (avatar && [CleanIdentityPrefs hideCommentAvatars])))
            hidden = YES;
    }
    %orig(hidden);
}
%end

// Row lifecycle: ensure avatars, names, creator-liked badges and mentions
// are hidden during first render and on every on-screen cell refresh.
%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
}
- (void)prepareForReuse {
    CleanIdentityClearCommentReuseTags((UIView *)self, 0);
    %orig;
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
}
- (void)prepareForReuse {
    CleanIdentityClearCommentReuseTags((UIView *)self, 0);
    %orig;
}
%end

%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    if (CleanIdentityAnyCommentPrivacyEnabled() &&
        CleanIdentityWithinCommentUI((UIView *)self)) {
        for (UICollectionViewCell *cell in [self visibleCells])
            CleanIdentityRefreshCommentRow(cell);
    }
}
%end

%hook UIImageView
- (void)layoutSubviews {
    %orig;
    CleanIdentityApplyImageFallback((UIImageView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityApplyImageFallback((UIImageView *)self);
}
%end
