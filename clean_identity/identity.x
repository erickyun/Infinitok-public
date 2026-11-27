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

// Global avatar policy. Match semantic avatar types/properties, never size alone.
static char kCleanGlobalAvatarPropertyKey;
static char kCleanGlobalAvatarOwnedKey;
static char kCleanGlobalAvatarMutationKey;

static BOOL CleanGlobalAvatarName(UIView *view) {
    NSString *name = [NSStringFromClass([view class]) lowercaseString];
    if (![name containsString:@"avatar"] && ![name containsString:@"userhead"] &&
        ![name containsString:@"userportrait"] && ![name containsString:@"profilephoto"] &&
        ![name containsString:@"profilepicture"] && ![name containsString:@"headimage"])
        return NO;
    // Never hide an entire list, screen, edit panel, or unrelated row.
    for (NSString *part in @[@"cell", @"controller", @"table", @"collection", @"list",
                             @"editor", @"picker", @"setting", @"placeholderbutton"])
        if ([name containsString:part]) return NO;
    return [view isKindOfClass:[UIImageView class]] ||
        [name hasSuffix:@"avatar"] || [name hasSuffix:@"head"] ||
        [name hasSuffix:@"view"] || [name hasSuffix:@"image"] ||
        [name hasSuffix:@"imageview"] || [name hasSuffix:@"button"] ||
        [name hasSuffix:@"node"];
}

// Search can render avatars using plain image views; constrain the fallback
// to search UI and compact round portraits, not video covers or general images.
static BOOL CleanGlobalHasAny(NSString *name, NSArray<NSString *> *terms) {
    for (NSString *term in terms) if ([name containsString:term]) return YES;
    return NO;
}
static NSString *CleanGlobalClass(id object) {
    return object ? [NSStringFromClass([object class]) lowercaseString] : @"";
}
static NSUInteger CleanGlobalContext(UIView *view) {
    // search=1, profile=2, user/live row=4, editor=8, chat=16, shared card=32
    NSUInteger flags = 0;
    NSUInteger depth = 0;
    for (UIResponder *node = view; node && depth++ < 40; node = node.nextResponder) {
        NSString *name = CleanGlobalClass(node);
        if (CleanGlobalHasAny(name, @[@"search", @"popularlive", @"trendinglive"])) flags |= 1;
        if (CleanGlobalHasAny(name, @[@"profileheader", @"profilehead", @"profilebio",
                  @"profilesignature", @"profileuser", @"profileroot", @"profilehomeviewcontroller",
                  @"profileotherviewcontroller", @"profilepageviewcontroller", @"userprofileviewcontroller"])) flags |= 2;
        if (CleanGlobalHasAny(name, @[@"searchuser", @"usersearch", @"searchaccount",
                  @"userresult", @"accountresult", @"searchlive", @"livesearch",
                  @"popularlive", @"trendinglive", @"liveuser", @"liveauthor", @"liveanchor",
                  @"liveroomcard", @"livecard", @"liveitem", @"liverank"])) flags |= 4;
        if (CleanGlobalHasAny(name, @[@"profileedit", @"editprofile", @"avatarpicker",
                  @"searchbar", @"searchinput", @"searchtextfield"])) flags |= 8;
        if (CleanGlobalHasAny(name, @[@"aweim", @"ttkim", @"tiktokim", @"immessage",
                  @"chatcell", @"chatmessage", @"conversation", @"messagelist", @"directmessage",
                  @"timmessage", @"imflow", @"imchat", @"messagebasecell"])) flags |= 16;
        if (CleanGlobalHasAny(name, @[@"shareaweme", @"awemeshare", @"sharevideo", @"videoshare",
                  @"sharedvideo", @"sharecard", @"sharemessage", @"awememessage", @"video message",
                  @"videomessage", @"linkpreview", @"linkcard", @"messagecard", @"sharecontent",
                  @"awemecard", @"postcard", @"sharepost", @"sharelink"])) flags |= 32;
        if ([node isKindOfClass:[UIWindow class]]) break;
    }
    return flags;
}
static BOOL CleanGlobalSearchAvatar(UIView *view) {
    if (!view.superview || !view.window) return NO;
    BOOL imageView = [view isKindOfClass:[UIImageView class]];
    if (!imageView && (!view.layer.contents || view.subviews.count > 0 ||
                       [view isKindOfClass:[UIControl class]] ||
                       [view isKindOfClass:[UILabel class]])) return NO;
    NSUInteger context = CleanGlobalContext(view);
    if (!(context & 1) || (context & 8)) return NO;
    if (imageView) {
        UIImage *image = ((UIImageView *)view).image;
        if (image.renderingMode == UIImageRenderingModeAlwaysTemplate) return NO;
        if (!image && !view.layer.contents) return NO;
    }
    CGRect frame = [view convertRect:view.bounds toView:view.window];
    CGFloat w = CGRectGetWidth(frame), h = CGRectGetHeight(frame);
    if (w < 10.0 || h < 10.0 || w > 100.0 || h > 100.0 ||
        fabs(w-h) > MAX(5.0, MIN(w,h)*0.20)) return NO;
    BOOL round = NO;
    for (UIView *p = view; p && p != view.window; p = p.superview) {
        CGFloat pw = CGRectGetWidth(p.bounds), ph = CGRectGetHeight(p.bounds);
        if (pw > w+20.0 || ph > h+20.0) break;
        if (p.layer.cornerRadius >= MIN(w,h)*0.30 ||
            (p.layer.mask && fabs(pw-ph)<12.0)) round = YES;
    }
    if (!round) return NO;
    if (CleanGlobalHasAny(CleanGlobalClass(view), @[@"icon", @"emoji", @"sticker",
                       @"cover", @"thumbnail", @"badge", @"logo", @"button"])) return NO;
    if ((context & 4) || CGRectGetMinX(frame) < CGRectGetWidth(view.window.bounds)*0.30) return YES;
    // Popular LIVE portraits may sit over a card rather than at its leading edge.
    if (w > 58.0 || h > 58.0) return NO;
    for (UIView *p = view.superview; p && p != view.window; p = p.superview) {
        NSString *name = CleanGlobalClass(p);
        if ([p isKindOfClass:[UICollectionViewCell class]] ||
            [p isKindOfClass:[UITableViewCell class]] ||
            CleanGlobalHasAny(name, @[@"searchcard", @"searchitem", @"livecard", @"liveroom",
                                      @"searchresult", @"searchsuggest"])) return YES;
        if ([p isKindOfClass:[UIScrollView class]]) break;
    }
    return NO;
}
// Shared TikTok videos in DMs can draw the author's small portrait in an
// otherwise generic image view or a leaf backed by CALayer. Keep the video
// preview, sender's message, play button and sticker/media attachment intact.
static BOOL CleanGlobalChatCardAvatar(UIView *view) {
    if (!view.window || !view.superview) return NO;
    NSUInteger context = CleanGlobalContext(view);
    if (!(context & 16) || (context & 8)) return NO;
    BOOL imageView = [view isKindOfClass:[UIImageView class]];
    if (!imageView && (!view.layer.contents || view.subviews.count ||
                       [view isKindOfClass:[UIControl class]] ||
                       [view isKindOfClass:[UILabel class]])) return NO;
    if (imageView) {
        UIImage *image = ((UIImageView *)view).image;
        if (image && (image.renderingMode == UIImageRenderingModeAlwaysTemplate ||
                      image.isSymbolImage)) return NO;
        if (!image && !view.layer.contents) return NO;
    }

    CGRect frame = [view convertRect:view.bounds toView:view.window];
    CGFloat w = CGRectGetWidth(frame), h = CGRectGetHeight(frame);
    if (w < 8 || h < 8 || w > 56 || h > 56 ||
        fabs(w-h) > MAX(4.0, MIN(w,h)*0.20)) return NO;

    BOOL round = NO;
    for (UIView *p = view; p && p != view.window; p = p.superview) {
        NSString *name = CleanGlobalClass(p);
        if (CleanGlobalHasAny(name, @[@"emoji", @"sticker", @"reaction", @"playbutton",
                     @"playicon", @"voicemessage", @"audioicon", @"statusicon",
                     @"readreceipt", @"deliveryicon", @"videocover", @"thumbnail"])) return NO;
        CGFloat pw = CGRectGetWidth(p.bounds), ph = CGRectGetHeight(p.bounds);
        if (pw > w+16 || ph > h+16) break;
        if (p.layer.cornerRadius >= MIN(w,h)*0.35 ||
            (p.layer.mask && fabs(pw-ph) <= 5.0)) round = YES;
    }
    if (!round) return NO;
    // Prefer a named shared-video/link card. Some releases use generic
    // message cells instead: require the portrait to be tiny in a bubble
    // that also contains a substantially larger image (the shared preview).
    if (context & 32) return YES;
    if (w > 42 || h > 42) return NO;
    for (UIView *p = view.superview; p && p != view.window; p = p.superview) {
        if ([p isKindOfClass:[UIScrollView class]]) break;
        NSString *name = CleanGlobalClass(p);
        if ([p isKindOfClass:[UITableViewCell class]] ||
            [p isKindOfClass:[UICollectionViewCell class]] ||
            CleanGlobalHasAny(name, @[@"messagebasecell", @"messagecell", @"messagebubble", @"chatcell"])) {
            NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:p];
            NSUInteger visited = 0;
            while (pending.count && visited++ < 180) {
                UIView *child = pending.lastObject;
                [pending removeLastObject];
                CGRect b = child.bounds;
                if (child != view && CGRectGetWidth(b) >= 75 && CGRectGetHeight(b) >= 75 &&
                    ([child isKindOfClass:[UIImageView class]] || child.layer.contents)) return YES;
                [pending addObjectsFromArray:child.subviews];
            }
            break;
        }
    }
    return NO;
}

static BOOL CleanGlobalIdentityText(UIView *view) {
    if (![view isKindOfClass:[UILabel class]] &&
        !([view isKindOfClass:[UITextView class]] && !((UITextView *)view).editable)) return NO;
    NSUInteger context = CleanGlobalContext(view);
    if (!(context & 19) || (context & 8)) return NO;
    for (UIView *p = view; p && p != view.window; p = p.superview) {
        NSString *name = CleanGlobalClass(p);
        if (CleanGlobalHasAny(name, @[@"username", @"nickname", @"displayname",
                  @"authorname", @"accountname", @"profilename", @"useridlabel"])) return YES;
        if ((context & 2) && CleanGlobalHasAny(name, @[@"profilebio", @"profilesignature",
                  @"profiledescription", @"userbio", @"usersignature", @"bioview",
                  @"biocomponent", @"signaturecomponent", @"signaturelabel", @"biolabel",
                  @"biotext", @"signaturetext", @"userdescription", @"personaldescription"])) return YES;
        if ([p isKindOfClass:[UITableViewCell class]] ||
            [p isKindOfClass:[UICollectionViewCell class]] || CGRectGetHeight(p.bounds)>170.0) break;
    }
    return NO;
}

static BOOL CleanGlobalAvatarCandidate(UIView *view) {
    if (!view || [view isKindOfClass:[UIWindow class]]) return NO;
    if ([objc_getAssociatedObject(view, &kCleanGlobalAvatarPropertyKey) boolValue] ||
        CleanGlobalAvatarName(view)) return YES;
    return CleanGlobalSearchAvatar(view) || CleanGlobalChatCardAvatar(view) || CleanGlobalIdentityText(view);
}

static void CleanGlobalAvatarApply(UIView *view) {
    if (!view || objc_getAssociatedObject(view, &kCleanGlobalAvatarMutationKey)) return;
    BOOL owned = [objc_getAssociatedObject(view, &kCleanGlobalAvatarOwnedKey) boolValue];
    BOOL hide = [CleanIdentityPrefs hideAllAvatars] && CleanGlobalAvatarCandidate(view);
    if (!hide && !owned) return;
    objc_setAssociatedObject(view, &kCleanGlobalAvatarMutationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hide && !view.hidden) {
        objc_setAssociatedObject(view, &kCleanGlobalAvatarOwnedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.hidden = YES;
    } else if (!hide && owned) {
        objc_setAssociatedObject(view, &kCleanGlobalAvatarOwnedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.hidden = NO;
    }
    objc_setAssociatedObject(view, &kCleanGlobalAvatarMutationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Also invoked by the existing BDImageView hook in Tweak.x: some versions
// bypass UIImageView's inherited layout implementation.
void CleanIdentityRefreshGlobalAvatar(UIView *view) {
    if (!view || !view.window) return;
    CleanGlobalAvatarApply(view);
}

// Discover generic UIImageViews exposed through explicitly avatar-related getters.
// Works without a dimension threshold and without scanning all circular images.
static void CleanGlobalAvatarDiscover(UIView *owner) {
    if (![CleanIdentityPrefs hideAllAvatars] || !owner) return;
    NSString *className = NSStringFromClass([owner class]);
    if ([className hasPrefix:@"UI"] || [className hasPrefix:@"_UI"]) return;
    static NSArray<NSString *> *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[@"avatarView", @"avatarImageView", @"userAvatarView", @"userAvatarImageView",
                 @"profileAvatarView", @"profileImageView", @"profilePhotoView", @"headImageView",
                 @"headView", @"userHeadView", @"userHeadImageView", @"authorAvatarView",
                 @"authorAvatarImageView", @"smallAvatarView", @"largeAvatarView",
                 @"miniAvatarView", @"avatarBorderView", @"avatarButton", @"avatarContainerView",
                 @"senderAvatarView", @"receiverAvatarView", @"friendAvatarView", @"coverAvatarView", @"avatar", @"avatarImage", @"userAvatar",
                 @"headImage", @"headImageButton", @"avatarIconView", @"avatarContentView",
                 @"avatarWrapperView", @"smallAvatarImageView", @"miniAvatarImageView",
                 @"liveAvatarView", @"liveUserAvatarView", @"anchorAvatarView", @"hostAvatarView",
                 @"portraitView", @"userPortraitView", @"profilePictureView", @"userHeadImage",
                 @"creatorAvatarView", @"creatorAvatarImageView", @"creatorHeadView",
                 @"shareAuthorAvatarView", @"shareUserAvatarView", @"sharedVideoAvatarView",
                 @"videoAuthorAvatarView", @"cardAvatarView", @"cardAvatarImageView",
                 @"authorHeadImageView", @"authorHeadView", @"userIconImageView"];
    });
    for (NSString *key in keys) {
        if (![owner respondsToSelector:NSSelectorFromString(key)]) continue;
        UIView *target = CleanIdentityViewForKey(owner, key);
        if (!target || target == owner || ![target isDescendantOfView:owner]) continue;
        if ([target isKindOfClass:[UITableViewCell class]] || [target isKindOfClass:[UICollectionViewCell class]]) continue;
        objc_setAssociatedObject(target, &kCleanGlobalAvatarPropertyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CleanGlobalAvatarApply(target);
    }

    NSUInteger context = CleanGlobalContext(owner);
    if (!(context & 19) || (context & 8)) return;
    static NSArray<NSString *> *nameKeys;
    static NSArray<NSString *> *bioKeys;
    static dispatch_once_t textOnce;
    dispatch_once(&textOnce, ^{
        nameKeys = @[@"nameLabel", @"nicknameLabel", @"nickNameLabel", @"userNameLabel",
                     @"usernameLabel", @"displayNameLabel", @"authorNameLabel", @"accountNameLabel",
                     @"profileNameLabel", @"uniqueIdLabel", @"uniqueIDLabel", @"userIdLabel",
                     @"userIDLabel", @"nickNameView", @"nicknameView", @"userNameView", @"usernameView",
                     @"creatorNameLabel", @"videoAuthorNameLabel", @"authorNicknameLabel",
                     @"shareAuthorNameLabel", @"conversationNameLabel", @"conversationTitleLabel"];
        bioKeys = @[@"bioLabel", @"bioTextView", @"bioView", @"signatureLabel", @"signatureTextView",
                    @"signatureView", @"profileDescriptionLabel", @"profileDescriptionView",
                    @"userDescriptionLabel", @"userBioLabel", @"bioTextLabel",
                    @"signatureTextLabel", @"descriptionTextView", @"userSignatureLabel"];
    });
    NSMutableArray<NSString *> *textKeys = [nameKeys mutableCopy];
    if (context & 2) [textKeys addObjectsFromArray:bioKeys];
    for (NSString *key in textKeys) {
        if (![owner respondsToSelector:NSSelectorFromString(key)]) continue;
        UIView *target = CleanIdentityViewForKey(owner, key);
        if (!target || target == owner || ![target isDescendantOfView:owner]) continue;
        if (![target isKindOfClass:[UILabel class]] &&
            !([target isKindOfClass:[UITextView class]] && !((UITextView *)target).editable) &&
            !CleanGlobalIdentityText(target)) continue;
        objc_setAssociatedObject(target, &kCleanGlobalAvatarPropertyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CleanGlobalAvatarApply(target);
    }
}

// A search row may use a plain label with no identity-specific class name.
// Find the closest short label next to its positively identified avatar.
static void CleanGlobalSearchCollect(UIView *view, NSMutableArray<UIView *> *avatars,
                                     NSMutableArray<UILabel *> *labels, NSUInteger depth) {
    if (!view || depth > 14) return;
    if (CleanGlobalAvatarName(view) || CleanGlobalSearchAvatar(view)) {
        CGRect b = view.bounds;
        if (CGRectGetWidth(b) >= 10 && CGRectGetWidth(b) <= 112 &&
            CGRectGetHeight(b) >= 10 && CGRectGetHeight(b) <= 112)
            [avatars addObject:view];
    }
    if ([view isKindOfClass:[UILabel class]]) [labels addObject:(UILabel *)view];
    for (UIView *child in view.subviews) CleanGlobalSearchCollect(child, avatars, labels, depth+1);
}
static BOOL CleanGlobalSearchNameLabel(UILabel *label) {
    NSString *value = label.text ?: label.attributedText.string;
    if (!value.length || value.length > 100 || label.numberOfLines > 1 ||
        label.font.pointSize < 9 || label.font.pointSize > 24) return NO;
    NSString *lower = [value lowercaseString];
    if ([lower isEqualToString:@"live"] || [lower isEqualToString:@"follow"] ||
        [lower isEqualToString:@"following"] || [lower isEqualToString:@"creator"] ||
        [lower isEqualToString:@"canlı"] || [lower isEqualToString:@"takip et"] ||
        CleanGlobalHasAny(lower, @[@"followers", @"following", @"viewers", @"takipçi", @"izleyici"])) return NO;
    if ([value rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location == NSNotFound)
        return NO;
    return !CleanGlobalHasAny(CleanGlobalClass(label), @[@"count", @"badge", @"status", @"time",
                                                         @"button", @"metric", @"statistic"]);
}
static void CleanGlobalSearchNamesInRow(UIView *row) {
    if (![CleanIdentityPrefs hideAllAvatars] || !row.window) return;
    NSUInteger context = CleanGlobalContext(row);
    if (!(context & 1) || (context & 8)) return;
    // Only a compact result cell; never a search page, search bar, or whole list.
    if (![row isKindOfClass:[UITableViewCell class]] &&
        ![row isKindOfClass:[UICollectionViewCell class]]) return;
    NSMutableArray<UIView *> *avatars = [NSMutableArray array];
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    CleanGlobalSearchCollect(row, avatars, labels, 0);
    for (UIView *avatar in avatars) {
        CGRect a = [avatar convertRect:avatar.bounds toView:row];
        UILabel *best = nil;
        CGFloat bestScore = CGFLOAT_MAX;
        for (UILabel *label in labels) {
            if (!CleanGlobalSearchNameLabel(label)) continue;
            CGRect l = [label convertRect:label.bounds toView:row];
            CGFloat dx = CGRectGetMinX(l) - CGRectGetMaxX(a);
            CGFloat dy = fabs(CGRectGetMidY(l)-CGRectGetMidY(a));
            BOOL adjacent = dx >= -3 && dx <= 45 && dy <= MAX(20, CGRectGetHeight(a)*0.55);
            CGFloat below = CGRectGetMinY(l)-CGRectGetMaxY(a);
            BOOL vertical = (context & 4) && below >= -3 && below <= 25 &&
                fabs(CGRectGetMidX(l)-CGRectGetMidX(a)) <= MAX(25, CGRectGetWidth(a)*0.65);
            if (!adjacent && !vertical) continue;
            CGFloat score = adjacent ? fabs(dx)+dy : fabs(below)+fabs(CGRectGetMidX(l)-CGRectGetMidX(a));
            if (score < bestScore) { bestScore = score; best = label; }
        }
        if (best) {
            objc_setAssociatedObject(best, &kCleanGlobalAvatarPropertyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            CleanGlobalAvatarApply(best);
        }
    }
}

// Direct-message shared video cards: match the footer inside the preview,
// not the sender's message text or the AI-generated disclosure.
static BOOL CleanChatTextIsDisclosure(NSString *value) {
    NSString *t = [[value ?: @"" lowercaseString] stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return CleanGlobalHasAny(t, @[@"ai-generated", @"ai generated", @"generated by ai",
                                  @"yapay zeka", @"yapay zekâ", @"ki-generiert", @"ai gegenereerd"]);
}
static BOOL CleanChatIsRound(UIView *v) {
    CGFloat w = CGRectGetWidth(v.bounds), h = CGRectGetHeight(v.bounds);
    if (w < 8 || h < 8 || w > 52 || h > 52 ||
        fabs(w-h) > MAX(3.0, MIN(w,h)*0.16)) return NO;
    if (v.layer.cornerRadius >= MIN(w,h)*0.30 || v.layer.mask) return YES;
    return NO;
}
static void CleanChatMarkView(UIView *v) {
    if (!v) return;
    objc_setAssociatedObject(v, &kCleanGlobalAvatarPropertyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CleanGlobalAvatarApply(v);
}
static void CleanChatCollectViews(UIView *v, NSMutableArray<UIView *> *nodes, NSUInteger depth) {
    if (!v || depth > 18 || nodes.count >= 350) return;
    [nodes addObject:v];
    for (UIView *child in v.subviews) CleanChatCollectViews(child, nodes, depth+1);
}
static BOOL CleanChatIsMessageRow(UIView *v) {
    if (!v) return NO;
    if ([v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UICollectionViewCell class]]) return YES;
    Class base = NSClassFromString(@"AWEIMMessageBaseCellView");
    return (base && [v isKindOfClass:base]) ||
        CleanGlobalHasAny(CleanGlobalClass(v), @[@"messagecell", @"messagebasecell", @"chatcell", @"messagebubble"]);
}
static BOOL CleanChatIsCardMedia(UIView *v) {
    CGFloat w = CGRectGetWidth(v.bounds), h = CGRectGetHeight(v.bounds);
    if (w < 88 || h < 105 || w > 350 || h > 510 || h/w < 1.0 || h/w > 2.5) return NO;
    if ([v isKindOfClass:[UIImageView class]]) return YES;
    NSString *n = CleanGlobalClass(v);
    return v.layer.contents || CleanGlobalHasAny(n, @[@"videocover", @"awemecard", @"sharecard",
                                @"shareaweme", @"videoimage", @"videopreview", @"linkpreview"]);
}
static void CleanChatMaskSharedCard(UIView *row) {
    if (![CleanIdentityPrefs hideAllAvatars] || !row.window ||
        !(CleanGlobalContext(row) & 16) || !CleanChatIsMessageRow(row)) return;
    NSMutableArray<UIView *> *nodes = [NSMutableArray array];
    CleanChatCollectViews(row, nodes, 0);
    for (UIView *media in nodes) {
        if (!CleanChatIsCardMedia(media)) continue;
        CGRect card = [media convertRect:media.bounds toView:row];
        if (CGRectIsEmpty(card)) continue;
        CGFloat bottom = CGRectGetMaxY(card);
        for (UIView *item in nodes) {
            if (item == media || item == row) continue;
            CGRect rect = [item convertRect:item.bounds toView:row];
            CGFloat w = CGRectGetWidth(rect), h = CGRectGetHeight(rect);
            CGFloat left = CGRectGetMinX(rect)-CGRectGetMinX(card);
            CGFloat midY = CGRectGetMidY(rect);
            BOOL footer = midY >= bottom-36 && midY <= bottom+10 &&
                left >= -3 && left < CGRectGetWidth(card)-8 &&
                CGRectGetMaxX(rect) <= CGRectGetMaxX(card)+6;
            if (footer && [item isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)item;
                NSString *value = label.text ?: label.attributedText.string;
                if (value.length && value.length <= 100 && !CleanChatTextIsDisclosure(value) &&
                    label.numberOfLines <= 1 && h >= 8 && h <= 34 &&
                    label.font.pointSize <= 23 && left <= 75 &&
                    !CleanGlobalHasAny(CleanGlobalClass(item), @[@"duration", @"timestamp", @"status", @"count"]))
                    CleanChatMarkView(item);
            }
            if (footer && w >= 7 && w <= 34 && h >= 7 && h <= 34 &&
                fabs(w-h) <= 5 && left <= 38 &&
                ![item isKindOfClass:[UILabel class]] && ![item isKindOfClass:[UIControl class]] &&
                ([item isKindOfClass:[UIImageView class]] || item.layer.contents || CleanChatIsRound(item)))
                CleanChatMarkView(item);

            // Empty circular sender placeholders remain after the portrait
            // itself has been hidden. Only circles immediately outside a
            // detected message card, near its vertical centre, qualify.
            BOOL outside = (CGRectGetMaxX(rect) <= CGRectGetMinX(card)+3 &&
                            CGRectGetMinX(card)-CGRectGetMaxX(rect) <= 18) ||
                           (CGRectGetMinX(rect) >= CGRectGetMaxX(card)-3 &&
                            CGRectGetMinX(rect)-CGRectGetMaxX(card) <= 18);
            if (outside && fabs(midY-CGRectGetMidY(card)) <= 32 && w >= 16 && w <= 48 &&
                CleanChatIsRound(item) && ![item isKindOfClass:[UILabel class]] &&
                ![item isKindOfClass:[UIControl class]]) CleanChatMarkView(item);
        }
    }
}

static void CleanChatMaskHeader(UIView *root) {
    if (![CleanIdentityPrefs hideAllAvatars] || !root.window ||
        !(CleanGlobalContext(root) & 16)) return;
    NSMutableArray<UIView *> *nodes = [NSMutableArray array];
    CleanChatCollectViews(root, nodes, 0);
    for (UIView *v in nodes) {
        if (![v isKindOfClass:[UILabel class]]) continue;
        UILabel *label = (UILabel *)v;
        NSString *t = label.text ?: label.attributedText.string;
        if (!t.length || t.length > 100 || label.numberOfLines > 1) continue;
        CGRect r = [v convertRect:v.bounds toView:root.window];
        CGFloat top = root.window.safeAreaInsets.top;
        CGFloat width = CGRectGetWidth(root.window.bounds);
        if (CGRectGetMidY(r) < top+3 || CGRectGetMidY(r) > top+65 ||
            CGRectGetMinX(r) < 30 || CGRectGetMaxX(r) > width-32 ||
            label.font.pointSize < 12 || label.font.pointSize > 25) continue;
        // Reject anything belonging to message rows or input controls.
        BOOL skip = NO;
        for (UIView *p = v; p && p != root; p = p.superview) {
            if (CleanChatIsMessageRow(p) || [p isKindOfClass:[UIScrollView class]]) { skip = YES; break; }
        }
        if (!skip) CleanChatMarkView(v);
    }
}

static void CleanGlobalAvatarWalk(UIView *view, NSUInteger depth, BOOL clear) {
    if (!view || depth > 25) return;
    if (clear) {
        objc_setAssociatedObject(view, &kCleanGlobalAvatarPropertyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if ([objc_getAssociatedObject(view, &kCleanGlobalAvatarOwnedKey) boolValue]) {
            objc_setAssociatedObject(view, &kCleanGlobalAvatarMutationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kCleanGlobalAvatarOwnedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            view.hidden = NO;
            objc_setAssociatedObject(view, &kCleanGlobalAvatarMutationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        CleanGlobalAvatarDiscover(view);
        CleanGlobalAvatarApply(view);
    }
    for (UIView *child in view.subviews) CleanGlobalAvatarWalk(child, depth + 1, clear);
    if (!clear && depth == 0) {
        CleanGlobalSearchNamesInRow(view);
        CleanChatMaskSharedCard(view);
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
    CleanGlobalAvatarApply(image);
    if ([CleanIdentityPrefs hideAllAvatars] && CleanGlobalAvatarCandidate(image)) return;
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
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        CleanGlobalAvatarDiscover((UIView *)self);
        CleanGlobalAvatarApply((UIView *)self);
    }
}
- (void)layoutSubviews {
    %orig;
    CleanGlobalAvatarApply((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if (!hidden && !objc_getAssociatedObject(self, &kCleanGlobalAvatarMutationKey) &&
        [CleanIdentityPrefs hideAllAvatars] && CleanGlobalAvatarCandidate((UIView *)self)) {
        objc_setAssociatedObject(self, &kCleanGlobalAvatarOwnedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hidden = YES;
    }
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
    if ([CleanIdentityPrefs hideAllAvatars]) CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
    if ([CleanIdentityPrefs hideAllAvatars] && self.window &&
        (CleanGlobalContext((UIView *)self) & 19))
        CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
- (void)prepareForReuse {
    CleanIdentityClearCommentReuseTags((UIView *)self, 0);
    CleanGlobalAvatarWalk((UIView *)self, 0, YES);
    %orig;
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
    if ([CleanIdentityPrefs hideAllAvatars]) CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityRefreshCommentRow((UIView *)self);
    if ([CleanIdentityPrefs hideAllAvatars] && self.window &&
        (CleanGlobalContext((UIView *)self) & 19))
        CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
- (void)prepareForReuse {
    CleanIdentityClearCommentReuseTags((UIView *)self, 0);
    CleanGlobalAvatarWalk((UIView *)self, 0, YES);
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
- (void)setImage:(UIImage *)image {
    %orig(image);
    if ([CleanIdentityPrefs hideAllAvatars] && self.window)
        CleanGlobalAvatarApply((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    CleanIdentityApplyImageFallback((UIImageView *)self);
}
- (void)didMoveToWindow {
    %orig;
    CleanIdentityApplyImageFallback((UIImageView *)self);
}
%end

%hook AWEIMMessageBaseCellView
- (void)layoutSubviews {
    %orig;
    if ([CleanIdentityPrefs hideAllAvatars] && self.window)
        CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
- (void)didMoveToWindow {
    %orig;
    if ([CleanIdentityPrefs hideAllAvatars] && self.window)
        CleanGlobalAvatarWalk((UIView *)self, 0, NO);
}
%end

// Profile headers and other screens whose custom views bypass UIView layout.
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([CleanIdentityPrefs hideAllAvatars] && self.isViewLoaded)
        CleanGlobalAvatarWalk(self.view, 0, NO);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([CleanIdentityPrefs hideAllAvatars] && self.isViewLoaded &&
        (CleanGlobalContext(self.view) & 19))
        CleanGlobalAvatarWalk(self.view, 0, NO);
    if ([CleanIdentityPrefs hideAllAvatars] && self.isViewLoaded &&
        CleanGlobalHasAny(CleanGlobalClass(self), @[@"conversationcontroller", @"chatviewcontroller", @"messagelistviewcontroller"]))
        CleanChatMaskHeader(self.view);
}
- (void)viewDidLayoutSubviews {
    %orig;
    if ([CleanIdentityPrefs hideAllAvatars] && self.isViewLoaded &&
        CleanGlobalHasAny(CleanGlobalClass(self), @[@"conversationcontroller", @"chatviewcontroller", @"messagelistviewcontroller"]))
        CleanChatMaskHeader(self.view);
}
%end
