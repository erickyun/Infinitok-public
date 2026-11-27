#import "TikTokHeaders.h"
#import "InfinitokLog.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <string.h>

NSArray *jailbreakPaths;

static NSString *InfinitokVideoDownloadFilename(AWEAwemeBaseViewController *rootVC, NSString *extension) {
    NSString *username = rootVC.model.author.socialName.length > 0 ? rootVC.model.author.socialName
                        : rootVC.model.author.nickname.length > 0 ? rootVC.model.author.nickname
                        : rootVC.model.itemID.length > 0 ? rootVC.model.itemID
                        : @"unknown";
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    });
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    return [NSString stringWithFormat:@"@%@_feed_%@.%@", username, timestamp, extension.length > 0 ? extension : @"mp4"];
}

static void InfinitokDownloadHDVideo(id caller, AWEAwemeBaseViewController *rootVC) {
    NSString *itemID = rootVC.model.itemID;
    if (itemID.length == 0) {
        return;
    }
    NSString *hdExtension = [rootVC.model.video.playURL bestURLtoDownloadFormat] ?: @"mp4";
    [caller setFileextension:hdExtension];
    [caller setIsVideoDownload:true];
    [caller setPendingVideoFilename:InfinitokVideoDownloadFilename(rootVC, hdExtension)];

    NSString *watchURL = [NSString stringWithFormat:@"https://www.tiktok.com/@_/video/%@", itemID];
    NSString *encodedWatchURL = [watchURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://tikwm.com/api/?url=%@&hd=1", encodedWatchURL]];
    if (!apiURL) {
        return;
    }

    JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    hud.textLabel.text = @"Fetching HD link";
    [caller setHud:hud];
    [hud showInView:topMostController().view];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:apiURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *hdURL = nil;
            if (data && !error) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSDictionary *videoData = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
                NSString *hdplay = [videoData isKindOfClass:[NSDictionary class]] ? videoData[@"hdplay"] : nil;
                if ([hdplay isKindOfClass:[NSString class]] && hdplay.length > 0) {
                    NSString *fullURLString = [hdplay hasPrefix:@"http"] ? hdplay : [NSString stringWithFormat:@"https://tikwm.com%@", hdplay];
                    hdURL = [NSURL URLWithString:fullURLString];
                }
            }
            if (!hdURL) {
                [hud dismissAnimated:true];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HD Download Failed"
                                                                                message:@"Couldn't get an HD link from tikwm right now. Try again later, or use the regular Download option."
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [topMostController() presentViewController:alert animated:true completion:nil];
                return;
            }
            hud.textLabel.text = @"Downloading";
            BHDownload *dwManager = [[BHDownload alloc] init];
            [dwManager setDelegate:caller];
            [dwManager downloadFileWithURL:hdURL];
        });
    }];
    [task resume];
}

static AWENewFeedTableViewController *InfinitokFindFeedController(UIViewController *start) {
    UIViewController *current = start;
    for (int i = 0; i < 6 && current; i++) {
        if ([current isKindOfClass:%c(AWENewFeedTableViewController)]) {
            return (AWENewFeedTableViewController *)current;
        }
        current = current.parentViewController;
    }
    return nil;
}

static void InfinitokPresentFromRight(UIViewController *presenter, UIViewController *toPresent) {
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.type = kCATransitionPush;
    transition.subtype = kCATransitionFromRight;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [presenter.view.window.layer addAnimation:transition forKey:kCATransition];
    toPresent.modalPresentationStyle = UIModalPresentationFullScreen;
    [presenter presentViewController:toPresent animated:false completion:nil];
}

static NSString *InfinitokFormattedFakeCount(NSString *userDefaultsKey) {
    NSString *stringValue = [[NSUserDefaults standardUserDefaults] stringForKey:userDefaultsKey];
    if (stringValue.length == 0) {
        return nil;
    }
    double value = [stringValue doubleValue];
    if (value >= 1e9) {
        return [NSString stringWithFormat:@"%.1fB", value / 1e9];
    } else if (value >= 1e6) {
        return [NSString stringWithFormat:@"%.1fM", value / 1e6];
    } else if (value >= 1e3) {
        return [NSString stringWithFormat:@"%.1fk", value / 1e3];
    }
    return [NSString stringWithFormat:@"%.0f", value];
}

static UIViewController *InfinitokTopVC(UIViewController *vc);

static UIWindow *sInfinitokAlertWindow = nil;
static void showConfirmationWithCancel(void (^okHandler)(void), void (^cancelHandler)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes)
            if ([sc isKindOfClass:[UIWindowScene class]] && sc.activationState == UISceneActivationStateForegroundActive) { scene = (UIWindowScene *)sc; break; }
        if (!scene) { if (okHandler) okHandler(); return; }
        UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
        w.windowLevel = UIWindowLevelAlert + 1;
        w.rootViewController = [UIViewController new];
        w.backgroundColor = [UIColor clearColor];
        sInfinitokAlertWindow = w;
        [w makeKeyAndVisible];
        void (^done)(void) = ^{ sInfinitokAlertWindow.hidden = YES; sInfinitokAlertWindow = nil; };
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Infinitok" message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) {
            done(); if (cancelHandler) cancelHandler();
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            done(); if (okHandler) okHandler();
        }]];
        [w.rootViewController presentViewController:a animated:YES completion:nil];
    });
}
static void showConfirmation(void (^okHandler)(void)) {
    showConfirmationWithCancel(okHandler, nil);
}

static CFAbsoluteTime sInfinitokRepostBypassUntil = 0;

static BOOL InfinitokAskSync(NSString *msg) {
    if (![NSThread isMainThread]) return YES;
    UIWindowScene *scene = nil;
    for (UIScene *sc in [UIApplication sharedApplication].connectedScenes)
        if ([sc isKindOfClass:[UIWindowScene class]] && sc.activationState == UISceneActivationStateForegroundActive) { scene = (UIWindowScene *)sc; break; }
    if (!scene) return YES;
    UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
    w.windowLevel = UIWindowLevelAlert + 1;
    w.rootViewController = [UIViewController new];
    w.backgroundColor = [UIColor clearColor];
    [w makeKeyAndVisible];
    __block int decision = 0;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Infinitok" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) { decision = 2; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { decision = 1; }]];
    [w.rootViewController presentViewController:a animated:YES completion:nil];
    while (decision == 0) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    w.hidden = YES;
    return decision == 1;
}

static BOOL InfinitokRepostCancelled(const char *origin) {
    if (![BHIManager confirmRepost]) return NO;
    if (CFAbsoluteTimeGetCurrent() < sInfinitokRepostBypassUntil) return NO;
    ITDebug("repost", @"%s fired — asking", origin);
    BOOL ok = InfinitokAskSync(@"Are you sure you want to repost?");
    ITDebug("repost", @"%s answer=%@", origin, ok ? @"yes" : @"no");
    if (ok) sInfinitokRepostBypassUntil = CFAbsoluteTimeGetCurrent() + 6.0;
    return !ok;
}

static BOOL InfinitokConfirmRepost(const char *origin, void (^proceed)(void)) { return NO; }

static IMP InfinitokReplaceInstance(Class cls, SEL sel, id block);
static id InfinitokObj(id o, NSString *sel);
static void InfinitokSetObj(id o, NSString *key, id val);
static BOOL InfinitokFirstTime(NSString *key);

static void InfinitokAutoClearHistory(void) {
    if (![BHIManager autoClearHistory]) {
        return;
    }

    Class managerClass = NSClassFromString(@"TTKSearchHistoryManager");
    if (![managerClass respondsToSelector:@selector(sharedManager)]) {
        return;
    }
    @try {
        id manager = [managerClass performSelector:@selector(sharedManager)];
        if (!manager) {
            return;
        }
        for (NSString *name in @[@"newDeleteAllSearchWord", @"deleteAllSearchWord"]) {
            SEL sel = NSSelectorFromString(name);
            if ([manager respondsToSelector:sel]) {
                [manager performSelector:sel];
            }
        }
        SEL clearForKey = NSSelectorFromString(@"clearHistoryForHistoryKey:");
        SEL historyKey = NSSelectorFromString(@"searchHistoryKey");
        if ([manager respondsToSelector:clearForKey] && [manager respondsToSelector:historyKey]) {
            id key = [manager performSelector:historyKey];
            if (key) {
                [manager performSelector:clearForKey withObject:key];
            }
        }
    } @catch (NSException *exception) {
        ITDebug("history", @"clear failed: %@", exception.reason);
    }
}

static IMP InfinitokReplaceInstance(Class cls, SEL sel, id block);

@interface InfinitokVaultViewController : UITableViewController
@property (nonatomic, strong) NSMutableArray<NSString *> *items;
@end

@implementation InfinitokVaultViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Media Vault";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self reloadItems];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadItems];
}
- (NSString *)vaultDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject stringByAppendingPathComponent:@"InfinitokVault"];
}
- (void)reloadItems {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self vaultDirectory] error:nil];
    self.items = [contents mutableCopy] ?: [NSMutableArray array];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = self.items[indexPath.row];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    NSString *path = [[self vaultDirectory] stringByAppendingPathComponent:self.items[indexPath.row]];
    NSURL *url = [NSURL fileURLWithPath:path];
    [BHIManager showSaveVC:@[url]];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return true;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *path = [[self vaultDirectory] stringByAppendingPathComponent:self.items[indexPath.row]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [self.items removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}
@end

@interface InfinitokDownloadHandler : NSObject <BHDownloadDelegate>
@property (nonatomic, copy) void (^completionBlock)(NSURL *filePath, NSString *fileName);
@property (nonatomic, copy) void (^errorBlock)(NSError *error);
@property (nonatomic, strong) JGProgressHUD *hud;
@end

@implementation InfinitokDownloadHandler
- (void)downloadProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHIManager getDownloadingPersent:progress];
}
- (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    if (self.completionBlock) {
        self.completionBlock(filePath, fileName);
    }
}
- (void)downloadDidFailureWithError:(NSError *)error {
    if (self.errorBlock) {
        self.errorBlock(error);
    }
}
@end

static id InfinitokFindModelLikeIvar(id object, NSUInteger depth) {
    if (!object || depth > 1) {
        return nil;
    }

    id found = nil;
    id fallbackContainer = nil;

    for (Class currentClass = [object class]; currentClass && currentClass != [UIViewController class] && currentClass != [NSObject class]; currentClass = class_getSuperclass(currentClass)) {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        if (!ivars) {
            continue;
        }

        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *typeEncoding = ivar_getTypeEncoding(ivars[i]);
            if (!typeEncoding || typeEncoding[0] != '@' || typeEncoding[1] != '"') {
                continue;
            }
            NSString *typeStr = [NSString stringWithUTF8String:typeEncoding];

            NSUInteger endQuote = [typeStr rangeOfString:@"\"" options:0 range:NSMakeRange(2, typeStr.length - 2)].location;
            if (endQuote == NSNotFound) {
                continue;
            }
            NSString *ivarClassName = [typeStr substringWithRange:NSMakeRange(2, endQuote - 2)];
            NSUInteger genericMarker = [ivarClassName rangeOfString:@"<"].location;
            if (genericMarker != NSNotFound) {
                ivarClassName = [ivarClassName substringToIndex:genericMarker];
            }

            BOOL looksLikeModel = [ivarClassName rangeOfString:@"model" options:NSCaseInsensitiveSearch].location != NSNotFound
                                || [ivarClassName rangeOfString:@"aweme" options:NSCaseInsensitiveSearch].location != NSNotFound
                                || [ivarClassName rangeOfString:@"story" options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL looksLikeContainer = [ivarClassName rangeOfString:@"context" options:NSCaseInsensitiveSearch].location != NSNotFound
                                   || [ivarClassName rangeOfString:@"viewmodel" options:NSCaseInsensitiveSearch].location != NSNotFound;

            if (looksLikeModel) {
                id value = object_getIvar(object, ivars[i]);
                if (value) {
                    ITDebug("story", @"found model-like ivar %s (type %@) on %@ (declared on %@)", ivar_getName(ivars[i]), ivarClassName, NSStringFromClass([object class]), NSStringFromClass(currentClass));
                    found = value;
                    break;
                }
            } else if (looksLikeContainer && !fallbackContainer) {
                fallbackContainer = object_getIvar(object, ivars[i]);
            }
        }
        free(ivars);
        if (found) {
            break;
        }
    }

    if (found) {
        return found;
    }
    if (fallbackContainer) {
        return InfinitokFindModelLikeIvar(fallbackContainer, depth + 1);
    }
    return nil;
}

static id InfinitokFindStoryModel(id root) {
    if (!root) {
        return nil;
    }

    NSArray *directCandidates = @[@"model", @"currentAweme", @"awemeModel", @"cellModel", @"contentModel", @"currentModel", @"dataModel", @"detailModel", @"storyModel", @"currentStoryModel", @"currentStory", @"story", @"playingStoryModel", @"storyItemModel", @"richContentModel"];
    for (NSString *name in directCandidates) {
        SEL selector = NSSelectorFromString(name);
        if ([root respondsToSelector:selector]) {
            id value = [root performSelector:selector];
            if (value) {
                return value;
            }
        }
    }
    NSArray *containerCandidates = @[@"viewModel", @"pageContext", @"context"];
    for (NSString *name in containerCandidates) {
        SEL selector = NSSelectorFromString(name);
        if (![root respondsToSelector:selector]) {
            continue;
        }
        id container = [root performSelector:selector];
        if (!container) {
            continue;
        }
        for (NSString *innerName in directCandidates) {
            SEL innerSelector = NSSelectorFromString(innerName);
            if ([container respondsToSelector:innerSelector]) {
                id value = [container performSelector:innerSelector];
                if (value) {
                    return value;
                }
            }
        }
    }

    id ivarResult = InfinitokFindModelLikeIvar(root, 0);
    if (ivarResult) {
        return ivarResult;
    }

    ITDebug("story", @"exhausted all lookups on %@ — dumping ivars for diagnosis:", NSStringFromClass([root class]));
    for (Class currentClass = [root class]; currentClass && currentClass != [UIViewController class] && currentClass != [NSObject class]; currentClass = class_getSuperclass(currentClass)) {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        if (!ivars) {
            continue;
        }
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *typeEncoding = ivar_getTypeEncoding(ivars[i]);
            ITDebug("story", @"  [%@] %s : %s", NSStringFromClass(currentClass), ivar_getName(ivars[i]), typeEncoding ?: "?");
        }
        free(ivars);
    }

    return nil;
}

static NSString *InfinitokHideUIButtonMode(void) {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"hide_ui_button_mode"];
    if ([mode isEqualToString:@"all"] || [mode isEqualToString:@"this_video"]) {
        return mode;
    }
    return @"menu";
}

static NSString *InfinitokURLExtensionFromPath(NSString *urlString);

static NSURL *InfinitokStoryDownloadURL(UIViewController *vc, NSString **extOut) {
    NSMutableArray *models = [NSMutableArray array];
    void (^add)(id) = ^(id o) { if (o && ![models containsObject:o]) [models addObject:o]; };
    id root = InfinitokFindStoryModel(vc);
    id viaRoot = root;
    for (NSString *k in @[@"currentPlayingStory", @"currentStory", @"playingStory"]) {
        id v = InfinitokObj(root, k); if (v) { add(v); }
    }
    add(root);
    for (NSString *k in @[@"model", @"currentAweme", @"awemeModel", @"currentModel", @"story"]) add(InfinitokObj(vc, k));
    for (Class c = [vc class]; c && c != [UIViewController class]; c = class_getSuperclass(c)) {
        unsigned int n = 0; Ivar *iv = class_copyIvarList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            const char *t = ivar_getTypeEncoding(iv[i]);
            if (t && t[0] == '@' && t[1] == '"' && (strstr(t, "Aweme") || strstr(t, "Story"))) add(object_getIvar(vc, iv[i]));
        }
        free(iv);
    }
    for (id m in [models copy]) for (NSString *k in @[@"currentPlayingStory", @"aweme", @"awemeModel", @"story"]) add(InfinitokObj(m, k));
    ITLog("story", @"download: %lu candidate models on %@ (root %@)", (unsigned long)models.count, NSStringFromClass([vc class]), NSStringFromClass([viaRoot class]));
    NSMutableArray *urlModels = [NSMutableArray array];
    for (id m in models) {
        id video = InfinitokObj(m, @"video");
        if (video) {
            for (NSString *k in @[@"playURL", @"h264URL", @"playAddr", @"playAddrH264", @"playAddrBytevc1", @"downloadURL", @"downloadAddr"]) {
                id u = InfinitokObj(video, k); if (u) [urlModels addObject:u];
            }
            id br = InfinitokObj(video, @"bitrateModels");
            if ([br isKindOfClass:[NSArray class]]) for (id b in br) { id u = InfinitokObj(b, @"playURL"); if (u) [urlModels addObject:u]; }
        }
        for (NSString *k in @[@"images", @"photoAlbum", @"imageAlbum", @"storyPhoto"]) {
            id im = InfinitokObj(m, k);
            if ([im isKindOfClass:[NSArray class]]) { id f = [im firstObject]; id u = InfinitokObj(f, @"originalURL") ?: InfinitokObj(f, @"urlList") ?: f; if (u) [urlModels addObject:u]; }
        }
        ITLog("story", @"download: model %@ video=%@", NSStringFromClass([m class]), video ? NSStringFromClass([video class]) : @"nil");
    }
    for (id u in urlModels) {
        NSArray *list = [u isKindOfClass:[NSArray class]] ? u : InfinitokObj(u, @"originURLList");
        if (![list isKindOfClass:[NSArray class]] || !list.count) list = InfinitokObj(u, @"URLList") ?: InfinitokObj(u, @"urlList");
        if (![list isKindOfClass:[NSArray class]] || !list.count) continue;
        NSString *best = nil;
        for (NSString *x in list) if ([x isKindOfClass:[NSString class]] && [x containsString:@"video_mp4"]) best = x;
        if (!best) best = [list.firstObject isKindOfClass:[NSString class]] ? list.firstObject : nil;
        NSURL *url = best ? [NSURL URLWithString:best] : nil;
        if (!url) continue;
        NSString *ext = InfinitokURLExtensionFromPath(best);
        if ([best containsString:@"video_mp4"] || [best containsString:@"mime_type=video"]) ext = @"mp4";
        if (extOut) *extOut = ext ?: @"mp4";
        ITLog("story", @"download: using %@ (%@)", best, ext);
        return url;
    }
    ITLog("story", @"download: no URL found in %lu url models", (unsigned long)urlModels.count);
    return nil;
}

static void InfinitokAddStoryDownloadButton(UIViewController *controller) {
    if (![BHIManager storyDownload]) {
        return;
    }
    UIView *host = controller.view;
    if (!host || [host viewWithTag:997]) {
        return;
    }

    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.tag = 997;
    downloadButton.translatesAutoresizingMaskIntoConstraints = false;
    [downloadButton setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"] forState:UIControlStateNormal];
    downloadButton.tintColor = [UIColor whiteColor];

    __weak UIViewController *weakController = controller;
    [downloadButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        UIViewController *strongController = weakController;
        if (!strongController) {
            return;
        }
        NSString *fileExtension = nil;
        NSURL *downloadableURL = InfinitokStoryDownloadURL(strongController, &fileExtension);
        if (!downloadableURL) {
            [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"No story download URL found." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
            return;
        }

        BHDownload *dwManager = [[BHDownload alloc] init];
        JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        hud.textLabel.text = @"Downloading";
        [hud showInView:topMostController().view];

        InfinitokDownloadHandler *handler = [InfinitokDownloadHandler new];
        handler.hud = hud;
        handler.completionBlock = ^(NSURL *filePath, NSString *fileName) {
            NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
            NSString *ext = fileExtension ?: @"mp4";
            NSURL *newFilePath = [[NSURL fileURLWithPath:docPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext]];
            [[NSFileManager defaultManager] moveItemAtURL:filePath toURL:newFilePath error:nil];
            [hud dismiss];
            if ([BHIManager shareSheet]) {
                [BHIManager showSaveVC:@[newFilePath]];
            } else {
                [BHIManager saveMedia:newFilePath fileExtension:ext];
            }
        };
        handler.errorBlock = ^(NSError *error) {
            [hud dismiss];
        };
        [dwManager setDelegate:handler];
        objc_setAssociatedObject(dwManager, @selector(infinitokDownloadHandler), handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [dwManager downloadFileWithURL:downloadableURL];
    }] forControlEvents:UIControlEventTouchUpInside];

    [host addSubview:downloadButton];
    [NSLayoutConstraint activateConstraints:@[
        [downloadButton.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:90],
        [downloadButton.leadingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.leadingAnchor constant:10],
        [downloadButton.widthAnchor constraintEqualToConstant:30],
        [downloadButton.heightAnchor constraintEqualToConstant:30],
    ]];
}

static void InfinitokAddStoryViewCountLabelAttempt(UIViewController *controller, int attemptsRemaining) {
    if (![BHIManager storyViewCount]) {
        return;
    }
    UIView *host = controller.view;
    if (!host || [host viewWithTag:996]) {
        return;
    }
    id model = InfinitokFindStoryModel(controller);
    if (!model) {

        if (attemptsRemaining > 0) {
            __weak UIViewController *weakController = controller;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *strongController = weakController;
                if (strongController) {
                    InfinitokAddStoryViewCountLabelAttempt(strongController, attemptsRemaining - 1);
                }
            });
            return;
        }
        ITDebug("story", @"no model found on %@ via any candidate property after retrying", NSStringFromClass([controller class]));
        return;
    }
    UILabel *countLabel = [UILabel new];
    countLabel.tag = 996;
    countLabel.translatesAutoresizingMaskIntoConstraints = false;
    countLabel.textColor = [UIColor whiteColor];
    countLabel.numberOfLines = 0;
    countLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    countLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.6];
    countLabel.shadowOffset = CGSizeMake(0, 1);
    [host addSubview:countLabel];
    [NSLayoutConstraint activateConstraints:@[
        [countLabel.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:130],
        [countLabel.leadingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.leadingAnchor constant:10],
    ]];

    __weak UIViewController *weakController = controller;
    __weak UILabel *weakLabel = countLabel;
    void (^refresh)(void) = ^{
        UIViewController *c = weakController;
        UILabel *l = weakLabel;
        if (!c || !l) return;
        id root = InfinitokFindStoryModel(c);
        if (!root) return;
        id current = [root respondsToSelector:@selector(currentPlayingStory)] ? [root performSelector:@selector(currentPlayingStory)] : root;
        NSNumber *(^countOf)(id) = ^NSNumber *(id story) {
            id stats = [story respondsToSelector:@selector(statistics)] ? [story performSelector:@selector(statistics)] : nil;
            if ([stats respondsToSelector:@selector(playCount)]) return [stats valueForKey:@"playCount"];
            if ([stats respondsToSelector:@selector(viewCount)]) return [stats valueForKey:@"viewCount"];
            return nil;
        };
        NSString *text = nil;
        id userStory = [root respondsToSelector:@selector(userStory)] ? [root performSelector:@selector(userStory)] : nil;
        NSArray *stories = [userStory respondsToSelector:@selector(stories)] ? [userStory performSelector:@selector(stories)] : nil;
        if ([stories isKindOfClass:[NSArray class]] && stories.count > 1) {
            NSInteger playing = -1;
            @try { playing = [[userStory valueForKey:@"playingIndex"] integerValue]; } @catch (__unused id e) {}
            NSMutableArray *lines = [NSMutableArray array];
            NSUInteger i = 0;
            for (id s in stories) {
                NSNumber *n = countOf(s);
                BOOL isCurrent = (s == current) || ((NSInteger)i == playing && current == nil);
                [lines addObject:[NSString stringWithFormat:@"%@Story %lu: %@ views", @"", (unsigned long)(i + 1), n ?: @"–"]];
                i++;
            }
            text = [lines componentsJoinedByString:@"\n"];
        } else {
            NSNumber *n = countOf(current);
            if (n) text = [NSString stringWithFormat:@"%@ views", n];
        }
        if (text && ![l.text isEqualToString:text]) {
            l.text = text;
            ITDebug("story", @"view counts updated: %@", [text stringByReplacingOccurrencesOfString:@"\n" withString:@" | "]);
        }
    };
    refresh();
    [NSTimer scheduledTimerWithTimeInterval:0.6 repeats:YES block:^(NSTimer *timer) {
        if (!weakLabel || !weakLabel.superview || !weakController) { [timer invalidate]; return; }
        refresh();
    }];
}

static void InfinitokAddStoryViewCountLabel(UIViewController *controller) {

    InfinitokAddStoryViewCountLabelAttempt(controller, 6);
}

%hook AppDelegate
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"InfinitokFirstRun"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"InfinitokFirstRun" forKey:@"InfinitokFirstRun"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_ads"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"download_button"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"remove_elements_button"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"show_porgress_bar"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"save_profile"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"copy_profile_information"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"extended_bio"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"extendedComment"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"save_comment_media"];
    }
    [BHIManager cleanCache];

    if ([BHIManager autoClearHistory]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            InfinitokAutoClearHistory();
        });
    }
    return true;
}

static BOOL isAuthenticationShowed = FALSE;
static BOOL InfinitokChatsUnlocked = NO;
static BOOL InfinitokFavoritesUnlocked = NO;
- (void)applicationDidBecomeActive:(id)arg1 {
  %orig;

  if ([BHIManager appLock] && !isAuthenticationShowed) {
    UIViewController *rootController = [[self window] rootViewController];
    SecurityViewController *securityViewController = [SecurityViewController new];
    securityViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [rootController presentViewController:securityViewController animated:YES completion:nil];
    isAuthenticationShowed = TRUE;
  }
}

- (void)applicationWillEnterForeground:(id)arg1 {
  %orig;
  isAuthenticationShowed = FALSE;
  InfinitokChatsUnlocked = NO;
  InfinitokFavoritesUnlocked = NO;
}
%end

%hook AWEPlayInteractionProgressManager
- (BOOL)isShowStableProgressSlider {
    if ([BHIManager persistentProgressSlider]) {
        return YES;
    }
    return %orig;
}
- (BOOL)progressBarDraggable {
    if ([BHIManager persistentProgressSlider]) {
        return YES;
    }
    return %orig;
}
- (BOOL)progressBarVisible {
    if ([BHIManager persistentProgressSlider]) {
        return YES;
    }
    return %orig;
}
%end

%hook AWEPlayInteractionAuthorElement
- (BOOL)shouldShowTimeStampLabel {
    if ([BHIManager exactTimestamp]) {
        return YES;
    }
    return %orig;
}
%end

static BOOL InfinitokViewBelongsToOwnSettingsUI(UIView *view) {
    UIResponder *responder = view;
    NSUInteger hops = 0;
    while (responder && hops < 40) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            NSString *className = NSStringFromClass([responder class]);
            if ([className isEqualToString:@"ViewController"] ||
                [className isEqualToString:@"CountryTable"] ||
                [className isEqualToString:@"LiveActions"] ||
                [className isEqualToString:@"PlaybackSpeed"] ||
                [className isEqualToString:@"ContributorsViewController"] ||
                [className isEqualToString:@"AppIconViewController"] ||
                [className isEqualToString:@"SecurityViewController"]) {
                return YES;
            }
        }
        responder = [responder nextResponder];
        hops++;
    }
    return NO;
}

%hook UIView
- (void)setBackgroundColor:(UIColor *)color {
    if (![BHIManager oledMode] || !color || [color isEqual:[UIColor clearColor]] || InfinitokViewBelongsToOwnSettingsUI(self)) {
        %orig(color);
        return;
    }
    CGFloat white = 0, alpha = 0;
    if ([color getWhite:&white alpha:&alpha]) {
        if (white < 0.3) {
            ITDebug("oled", @"darkened %@ backgroundColor (white=%.2f) to pure black", NSStringFromClass([self class]), white);
            %orig([UIColor colorWithWhite:0 alpha:alpha]);
            return;
        }
    }
    %orig(color);
}
- (void)layoutSubviews {
    %orig;
    if (![BHIManager oledMode] || InfinitokViewBelongsToOwnSettingsUI(self)) {
        return;
    }
    UIColor *bg = self.backgroundColor;
    if (!bg) {
        return;
    }
    CGFloat white = 0, alpha = 0;
    if ([bg getWhite:&white alpha:&alpha] && white < 0.3) {

        self.backgroundColor = [UIColor colorWithWhite:0 alpha:alpha];
    }
}
%end

%hook UITableView
- (void)setBackgroundColor:(UIColor *)color {
    if (![BHIManager oledMode] || !color || [color isEqual:[UIColor clearColor]] || InfinitokViewBelongsToOwnSettingsUI(self)) {
        %orig(color);
        return;
    }
    CGFloat white = 0, alpha = 0;
    if ([color getWhite:&white alpha:&alpha] && white < 0.3) {
        ITDebug("oled", @"darkened UITableView backgroundColor (white=%.2f) to pure black", white);
        %orig([UIColor colorWithWhite:0 alpha:alpha]);
        return;
    }
    %orig(color);
}
%end

%hook UITableViewCell
- (void)setBackgroundColor:(UIColor *)color {
    if (![BHIManager oledMode] || !color || [color isEqual:[UIColor clearColor]] || InfinitokViewBelongsToOwnSettingsUI(self)) {
        %orig(color);
        return;
    }
    CGFloat white = 0, alpha = 0;
    if ([color getWhite:&white alpha:&alpha] && white < 0.3) {

        ITDebug("oled", @"darkened UITableViewCell backgroundColor (white=%.2f) to pure black", white);
        %orig([UIColor colorWithWhite:0 alpha:alpha]);
        return;
    }
    %orig(color);
}
%end

%hook TTKCommentPanelViewController
- (void)viewDidLoad {
    %orig;
    if ([BHIManager oledMode]) {
        ITDebug("oled", @"forced TTKCommentPanelViewController view backgroundColor to black");
        self.view.backgroundColor = [UIColor blackColor];
    }
}
%end

%hook UIScrollView
- (void)setDecelerationRate:(UIScrollViewDecelerationRate)rate {
    if ([BHIManager fasterFeedScrolling]) {
        %orig(UIScrollViewDecelerationRateFast);
        return;
    }
    %orig;
}
%end

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if ([BHIManager customAccentColor]) {
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"custom_accent_color_value"];
        UIColor *color = colorData ? [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:colorData error:nil] : nil;
        if (color) {
            self.tintColor = color;
        }
    }
}
%end

%hook UITextField
- (UIKeyboardAppearance)keyboardAppearance {
    if ([BHIManager oledMode]) {
        return UIKeyboardAppearanceDark;
    }
    return %orig;
}
%end

%hook UITextView
- (UIKeyboardAppearance)keyboardAppearance {
    if ([BHIManager oledMode]) {
        return UIKeyboardAppearanceDark;
    }
    return %orig;
}
%end

%hook UIKBBackdropView
- (void)setBackgroundColor:(UIColor *)color {
    if (![BHIManager oledMode] || !color || [color isEqual:[UIColor clearColor]]) {
        %orig(color);
        return;
    }

    CGFloat white = 0, alpha = 0;
    if ([color getWhite:&white alpha:&alpha] && white < 0.3) {
        ITDebug("oled", @"darkened UIKBBackdropView backgroundColor (white=%.2f) to pure black", white);
        %orig([UIColor colorWithWhite:0 alpha:alpha]);
        return;
    }
    %orig(color);
}
%end

%hook TTKMediaSpeedControlService
- (void)setPlaybackRate:(CGFloat)arg1 {
    NSNumber *speed = [BHIManager selectedSpeed];
    if (![BHIManager speedEnabled] || [speed isEqualToNumber:@1]) {
        return %orig;
    }
    if ([BHIManager speedEnabled]) {
        if ([BHIManager selectedSpeed]) {
            return %orig([speed floatValue]);
        }
    } else {
        return %orig;
    }
}
%end

%hook AWEUserWorkCollectionViewCell
- (void)configWithModel:(id)arg1 isMine:(BOOL)arg2 {
    %orig;
    if ([BHIManager videoLikeCount] || [BHIManager videoUploadDate]) {
        for (int i = 0; i < [[self.contentView subviews] count]; i ++) {
            UIView *j = [[self.contentView subviews] objectAtIndex:i];
            if (j.tag == 1001) {
                [j removeFromSuperview];
            }
            else if (j.tag == 1002) {
                [j removeFromSuperview];
            }
        }

        AWEAwemeModel *model = [self model];
        AWEAwemeStatisticsModel *statistics = [model statistics];
        NSNumber *createTime = [model createTime];
        NSNumber *likeCount = [statistics diggCount];
        NSString *likeCountFormatted = [self formattedNumber:[likeCount integerValue]];
        NSString *formattedDate = [self formattedDateStringFromTimestamp:[createTime doubleValue]];

        UILabel *likeCountLabel = [UILabel new];
        likeCountLabel.text = likeCountFormatted;
        likeCountLabel.textColor = [UIColor whiteColor];
        likeCountLabel.font = [UIFont boldSystemFontOfSize:13.0];
        likeCountLabel.tag = 1001;
        [likeCountLabel setTranslatesAutoresizingMaskIntoConstraints:false];

        UIImageView *heartImage = [UIImageView new];
        heartImage.image = [UIImage systemImageNamed:@"heart"];
        heartImage.tintColor = [UIColor whiteColor];
        [heartImage setTranslatesAutoresizingMaskIntoConstraints:false];

        UILabel *uploadDateLabel = [UILabel new];
        uploadDateLabel.text = formattedDate;
        uploadDateLabel.textColor = [UIColor whiteColor];
        uploadDateLabel.font = [UIFont boldSystemFontOfSize:13.0];
        uploadDateLabel.tag = 1002;
        [uploadDateLabel setTranslatesAutoresizingMaskIntoConstraints:false];

        UIImageView *clockImage = [UIImageView new];
        clockImage.image = [UIImage systemImageNamed:@"clock"];
        clockImage.tintColor = [UIColor whiteColor];
        [clockImage setTranslatesAutoresizingMaskIntoConstraints:false];

        for (int i = 0; i < [[self.contentView subviews] count]; i ++) {
            UIView *j = [[self.contentView subviews] objectAtIndex:i];
            if (j.tag == 1001) {
                [j removeFromSuperview];
            }
            else if (j.tag == 1002) {
                [j removeFromSuperview];
            }
        }
        if ([BHIManager videoLikeCount]) {
        [self.contentView addSubview:heartImage];
        [NSLayoutConstraint activateConstraints:@[
                [heartImage.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:110],
                [heartImage.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:4],
                [heartImage.widthAnchor constraintEqualToConstant:16],
                [heartImage.heightAnchor constraintEqualToConstant:16],
            ]];
        [self.contentView addSubview:likeCountLabel];
        [NSLayoutConstraint activateConstraints:@[
                [likeCountLabel.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:109],
                [likeCountLabel.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:23],
                [likeCountLabel.widthAnchor constraintEqualToConstant:200],
                [likeCountLabel.heightAnchor constraintEqualToConstant:16],
            ]];
        }
        if ([BHIManager videoUploadDate]) {
        [self.contentView addSubview:clockImage];
        [NSLayoutConstraint activateConstraints:@[
                [clockImage.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:128],
                [clockImage.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:4],
                [clockImage.widthAnchor constraintEqualToConstant:16],
                [clockImage.heightAnchor constraintEqualToConstant:16],
            ]];
        [self.contentView addSubview:uploadDateLabel];
        [NSLayoutConstraint activateConstraints:@[
                [uploadDateLabel.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:127],
                [uploadDateLabel.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:23],
                [uploadDateLabel.widthAnchor constraintEqualToConstant:200],
                [uploadDateLabel.heightAnchor constraintEqualToConstant:16],
            ]];
        }
    }
}
%new - (NSString *)formattedNumber:(NSInteger)number {

    if ([BHIManager exactViewCount]) {
        return [NSString stringWithFormat:@"%ld", (long)number];
    }
    if (number >= 1000000) {
        return [NSString stringWithFormat:@"%.1fm", number / 1000000.0];
    } else if (number >= 1000) {
        return [NSString stringWithFormat:@"%.1fk", number / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)number];
    }

}
%new - (NSString *)formattedDateStringFromTimestamp:(NSTimeInterval)timestamp {

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd.MM.yy";
    return [dateFormatter stringFromDate:date];

}
%end

%hook TTKProfileRootView
- (void)layoutSubviews {
    %orig;
    if ([BHIManager profileVideoCount]){
        TTKProfileOtherViewController *rootVC = [self yy_viewController];
        AWEUserModel *user = [rootVC user];
        NSNumber *userVideoCount = [user visibleVideosCount];
        if (userVideoCount){
            UILabel *userVideoCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,2,100,20.5)];
            userVideoCountLabel.text = [NSString stringWithFormat:@"Video Count: %@", userVideoCount];
            userVideoCountLabel.font = [UIFont systemFontOfSize:9.0];
            [self addSubview:userVideoCountLabel];
        }
    }
}
%end

#import <Photos/Photos.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

static NSData *InfinitokAnimatedDataForView(UIView *v, UIImage *base) {
    NSMutableArray *objs = [NSMutableArray array];
    if (v) { [objs addObject:v]; id im = InfinitokObj(v, @"image"); if (im) [objs addObject:im]; id cur = InfinitokObj(v, @"currentImage"); if (cur) [objs addObject:cur]; }
    if (base) [objs addObject:base];
    for (id o in objs) for (NSString *k in @[@"animatedImageData", @"bd_animatedImageData", @"originalData", @"imageData", @"data"]) {
        id d = InfinitokObj(o, k);
        if ([d isKindOfClass:[NSData class]] && [(NSData *)d length] > 64) {
            CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
            size_t n = src ? CGImageSourceGetCount(src) : 0; if (src) CFRelease(src);
            if (n > 1) return d;
        }
    }
    return nil;
}

static NSData *InfinitokGIFFromData(NSData *d) {
    if (d.length > 6 && memcmp(d.bytes, "GIF8", 4) == 0) return d;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    if (!src) return nil;
    size_t n = CGImageSourceGetCount(src);
    if (n < 2) { CFRelease(src); return nil; }
    NSMutableData *out = [NSMutableData data];
    CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)out, kUTTypeGIF, n, NULL);
    NSDictionary *gp = @{(__bridge id)kCGImagePropertyGIFDictionary: @{(__bridge id)kCGImagePropertyGIFLoopCount: @0}};
    CGImageDestinationSetProperties(dst, (__bridge CFDictionaryRef)gp);
    for (size_t i = 0; i < n; i++) {
        CGImageRef f = CGImageSourceCreateImageAtIndex(src, i, NULL);
        if (!f) continue;
        double delay = 0.1;
        NSDictionary *pr = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(src, i, NULL));
        for (id key in @[(__bridge id)kCGImagePropertyGIFDictionary, (__bridge id)kCGImagePropertyPNGDictionary, @"{WebP}"]) {
            NSDictionary *sub = pr[key];
            NSNumber *dv = sub[(__bridge id)kCGImagePropertyGIFUnclampedDelayTime] ?: sub[(__bridge id)kCGImagePropertyGIFDelayTime] ?: sub[@"UnclampedDelayTime"] ?: sub[@"DelayTime"];
            if (dv && dv.doubleValue > 0.01) { delay = dv.doubleValue; break; }
        }
        NSDictionary *fp = @{(__bridge id)kCGImagePropertyGIFDictionary: @{(__bridge id)kCGImagePropertyGIFDelayTime: @(delay)}};
        CGImageDestinationAddImage(dst, f, (__bridge CFDictionaryRef)fp);
        CGImageRelease(f);
    }
    BOOL ok = CGImageDestinationFinalize(dst);
    CFRelease(dst); CFRelease(src);
    return ok ? out : nil;
}
static void InfinitokSaveGIFData(NSData *gif, void (^done)(BOOL ok)) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus st) {
        if (st != PHAuthorizationStatusAuthorized && st != PHAuthorizationStatusLimited) { dispatch_async(dispatch_get_main_queue(), ^{ done(NO); }); return; }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *rq = [PHAssetCreationRequest creationRequestForAsset];
            PHAssetResourceCreationOptions *o = [[PHAssetResourceCreationOptions alloc] init];
            o.uniformTypeIdentifier = (__bridge NSString *)kUTTypeGIF;
            [rq addResourceWithType:PHAssetResourceTypePhoto data:gif options:o];
        } completionHandler:^(BOOL ok, NSError *e) { dispatch_async(dispatch_get_main_queue(), ^{ done(ok); }); }];
    }];
}

static BOOL InfinitokSaveAllowedForView(UIView *v) {
    for (UIView *p = v.superview; p; p = p.superview) {
        NSString *cn = NSStringFromClass([p class]);
        if (!([cn hasPrefix:@"AWEIM"] || [cn containsString:@"IMMessage"] || [cn containsString:@"ChatCell"] || [cn hasPrefix:@"TIM"])) continue;
        if (![BHIManager saveDMMedia]) return NO;
        if (v.bounds.size.width < 60 || v.bounds.size.height < 60) return NO;
        for (NSString *k in @[@"Text", @"Avatar", @"Reply", @"Reaction"]) if ([cn containsString:k]) return NO;
        for (NSString *k in @[@"Image", @"Sticker", @"Photo", @"Emoji", @"Gif", @"GIF", @"Meme", @"Picture", @"Media"]) if ([cn containsString:k]) return YES;

    }

    for (UIView *p = v.superview; p; p = p.superview) {
        NSString *cn = NSStringFromClass([p class]);
        if ([cn hasPrefix:@"AWEIM"] || [cn containsString:@"IMMessage"] || [cn containsString:@"ChatCell"] || [cn hasPrefix:@"TIM"]) return NO;
    }
    return YES;
}

extern void CleanIdentityRefreshGlobalAvatar(UIView *view);

%hook BDImageView
- (void)layoutSubviews {
    %orig;
    CleanIdentityRefreshGlobalAvatar((UIView *)self);
    if ([BHIManager profileSave] || [BHIManager saveCommentMedia] || [BHIManager saveDMMedia]) {
        if (!InfinitokSaveAllowedForView(self)) return;
        [self addHandleLongPress];
    }
}
%new - (void)addHandleLongPress {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.3;

    longPress.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self addGestureRecognizer:longPress];
}
%new - (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    if (!InfinitokSaveAllowedForView(self)) return;
    UIImage *image = [self bd_baseImage];
    ITDebug("save-media", @"BDImageView long-press — bd_baseImage=%@ (class=%@)", image ? @"present" : @"nil", NSStringFromClass([self class]));
    if (!image) {

        [%c(AWEUIAlertView) showAlertWithTitle:@"Can't Save" description:@"This item isn't a plain image yet (it may be animated or still loading), so it can't be saved this way." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
        return;
    }
    NSData *animData = InfinitokAnimatedDataForView(self, image);
    NSData *gifData = animData ? InfinitokGIFFromData(animData) : nil;
    if (!gifData && image.images.count > 1) {
        NSMutableData *out = [NSMutableData data];
        CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)out, kUTTypeGIF, image.images.count, NULL);
        CGImageDestinationSetProperties(dst, (__bridge CFDictionaryRef)@{(__bridge id)kCGImagePropertyGIFDictionary: @{(__bridge id)kCGImagePropertyGIFLoopCount: @0}});
        double dl = MAX(0.02, image.duration / image.images.count);
        for (UIImage *f in image.images) if (f.CGImage) CGImageDestinationAddImage(dst, f.CGImage, (__bridge CFDictionaryRef)@{(__bridge id)kCGImagePropertyGIFDictionary: @{(__bridge id)kCGImagePropertyGIFDelayTime: @(dl)}});
        if (CGImageDestinationFinalize(dst)) gifData = out;
        CFRelease(dst);
    }
    ITLog("save-media", @"animated data=%@ gif=%lu", animData ? @"yes" : @"no", (unsigned long)gifData.length);
    [%c(AWEUIAlertView) showAlertWithTitle:(gifData ? @"Save animation" : @"Save image") description:(gifData ? @"Do you want to save this animated image as a GIF" : @"Do you want to save this image") image:nil actionButtonTitle:@"Yes" cancelButtonTitle:@"No" actionBlock:^{
        if (gifData) { InfinitokSaveGIFData(gifData, ^(BOOL ok) { if (!ok) UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil); }); return; }
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
  } cancelBlock:^{}];
}
%new - (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSLog(@"Error saving image: %@", error.localizedDescription);
    } else {
        NSLog(@"Image successfully saved to Photos app");
    }
}
%end

%hook AWEUserNameLabel
- (void)layoutSubviews {
    %orig;
    if ([BHIManager fakeVerified]) {
        UIViewController *current = self.yy_viewController;
        for (int i = 0; i < 6 && current; i++) {
            if ([current isKindOfClass:%c(TTKProfileHomeViewController)]) {
                [self addVerifiedIcon:true];
                break;
            }
            current = current.parentViewController;
        }
    }
}
%end

%hook TTTAttributedLabel
- (void)layoutSubviews {
    %orig;
    if ([BHIManager profileCopy] || [BHIManager copyCommentWithoutUsername] || [BHIManager translateComments]){
        [self addHandleLongPress];
    }
}
%new - (void)addHandleLongPress {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.3;
    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    NSString *originalText = [self text];
    if (originalText.length == 0) {
        return;
    }
    NSString *copyText = originalText;
    if ([BHIManager copyCommentWithoutUsername] && [copyText hasPrefix:@"@"]) {

        NSRange spaceRange = [copyText rangeOfString:@" "];
        if (spaceRange.location != NSNotFound) {
            copyText = [copyText substringFromIndex:spaceRange.location + 1];
        }
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIPasteboard generalPasteboard] setString:copyText];
    }]];

    if ([BHIManager translateComments]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Translate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self infinitokTranslateInPlace:originalText];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [topMostController() presentViewController:sheet animated:true completion:nil];
}

static void InfinitokFetchTranslation(NSString *originalText, void (^completion)(NSString *translated)) {
    NSString *escaped = [originalText stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    NSArray *rawPreferredLanguages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    if (![rawPreferredLanguages isKindOfClass:[NSArray class]] || rawPreferredLanguages.count == 0) {
        rawPreferredLanguages = [NSLocale preferredLanguages];
    }
    NSString *targetLang = [rawPreferredLanguages.firstObject componentsSeparatedByString:@"-"].firstObject ?: @"en";
    NSString *urlString = [NSString stringWithFormat:@"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=%@&dt=t&q=%@", targetLang, escaped];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            return;
        }
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![json isKindOfClass:[NSArray class]]) {
            return;
        }

        NSArray *sentenceChunks = [json firstObject];
        if (![sentenceChunks isKindOfClass:[NSArray class]]) {
            return;
        }
        NSMutableString *translated = [NSMutableString string];
        for (NSArray *chunk in sentenceChunks) {
            if ([chunk isKindOfClass:[NSArray class]] && chunk.count > 0 && [chunk[0] isKindOfClass:[NSString class]]) {
                [translated appendString:chunk[0]];
            }
        }
        if (translated.length == 0) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(translated);
        });
    }];
    [task resume];
}

%new - (void)infinitokTranslateInPlace:(NSString *)originalText {
    __weak __typeof(self) weakSelf = self;
    InfinitokFetchTranslation(originalText, ^(NSString *translated) {
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf setText:translated];
        }
    });
}
%end

%hook TTKSettingsBaseCellPlugin
- (void)didSelectItemAtIndex:(NSInteger)index {
    if ([self.itemModel.identifier isEqualToString:@"infinitok_settings"]) {
        UINavigationController *InfinitokSettings = [[UINavigationController alloc] initWithRootViewController:[[ViewController alloc] init]];
        InfinitokPresentFromRight(topMostController(), InfinitokSettings);
    } else {
        return %orig;
    }
}
%end

%hook AWESettingsNormalSectionViewModel
- (void)viewDidLoad {
    %orig;
    ITLog("boot", @"AWESettingsNormalSectionViewModel.viewDidLoad sectionIdentifier=%@", self.sectionIdentifier);
    if ([self.sectionIdentifier isEqualToString:@"account"]) {
        [self addInfinitokSettingsRowIfNeeded];
    }
}
- (void)setModelsArray:(NSArray *)modelsArray {
    %orig;
    if ([self.sectionIdentifier isEqualToString:@"account"]) {
        [self addInfinitokSettingsRowIfNeeded];
    }
}
%new - (void)addInfinitokSettingsRowIfNeeded {

    for (id existingModel in self.modelsArray) {
        if ([existingModel isKindOfClass:%c(TTKSettingsBaseCellPlugin)]) {
            AWESettingItemModel *existingItem = [(TTKSettingsBaseCellPlugin *)existingModel itemModel];
            if ([existingItem.identifier isEqualToString:@"infinitok_settings"]) {
                return;
            }
        }
    }

    if (!%c(TTKSettingsBaseCellPlugin) || !%c(AWESettingItemModel)) {
        ITError("boot", @"cannot add Infinitok settings row: TTKSettingsBaseCellPlugin=%@ AWESettingItemModel=%@",
                 %c(TTKSettingsBaseCellPlugin) ? @"OK" : @"MISSING", %c(AWESettingItemModel) ? @"OK" : @"MISSING");
        return;
    }

    TTKSettingsBaseCellPlugin *InfinitokSettingsPluginCell = [[%c(TTKSettingsBaseCellPlugin) alloc] initWithPluginContext:self.context];

    AWESettingItemModel *InfinitokSettingsItemModel = [[%c(AWESettingItemModel) alloc] initWithIdentifier:@"infinitok_settings"];
    [InfinitokSettingsItemModel setTitle:@"Infinitok settings"];
    [InfinitokSettingsItemModel setDetail:@"Infinitok settings"];
    UIImage *grayGearIcon = [[UIImage systemImageNamed:@"infinity"] imageWithTintColor:[UIColor systemGrayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    [InfinitokSettingsItemModel setIconImage:grayGearIcon];
    [InfinitokSettingsItemModel setType:99];

    [InfinitokSettingsPluginCell setItemModel:InfinitokSettingsItemModel];

    [self insertModel:InfinitokSettingsPluginCell atIndex:0 animated:false];
    ITLog("boot", @"inserted Infinitok settings row into section %@", self.sectionIdentifier);
}
%end

static const void *InfinitokTabBarGestureMarkerKey(void) {
    static const char key = 0;
    return &key;
}

%hook UITabBar
- (void)didMoveToWindow {
    %orig;
    if (self.window && ![objc_getAssociatedObject(self, InfinitokTabBarGestureMarkerKey()) boolValue]) {
        objc_setAssociatedObject(self, InfinitokTabBarGestureMarkerKey(), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(infinitokTabBarLongPressed:)];
        longPress.minimumPressDuration = 2.0;
        [self addGestureRecognizer:longPress];
    }
}
%new - (void)infinitokTabBarLongPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    ITLog("boot", @"Infinitok Settings opened via tab bar long-press fallback");
    UINavigationController *InfinitokSettings = [[UINavigationController alloc] initWithRootViewController:[[ViewController alloc] init]];
    InfinitokPresentFromRight(topMostController(), InfinitokSettings);
}
%end

static NSURL *InfinitokResolveSafariDestinationURL(id viewController, NSURL *originURL) {
    NSURL *candidateURL = originURL;

    if (!candidateURL && [viewController respondsToSelector:@selector(originURLList)]) {
        NSArray<NSString *> *urlList = [viewController originURLList];
        NSString *firstURLString = urlList.firstObject;
        if (firstURLString) {
            candidateURL = [NSURL URLWithString:firstURLString];
            ITDebug("safari", @"originURL was nil, fell back to originURLList first entry: %@", firstURLString);
        }
    }

    if (!candidateURL) {
        NSArray<NSString *> *extraCandidates = @[@"url", @"pageURL", @"entryURL", @"containerURL", @"linkURL", @"schemaURL"];
        for (NSString *name in extraCandidates) {
            SEL selector = NSSelectorFromString(name);
            if (![viewController respondsToSelector:selector]) {
                continue;
            }
            id value = [viewController performSelector:selector];
            NSURL *url = [value isKindOfClass:[NSURL class]] ? value : ([value isKindOfClass:[NSString class]] ? [NSURL URLWithString:value] : nil);
            if (url) {
                candidateURL = url;
                ITDebug("safari", @"originURL/originURLList were empty, fell back to %@: %@", name, url);
                break;
            }
        }
    }

    if (!candidateURL) {
        ITDebug("safari", @"no originURL or originURLList available on %@, leaving in-app browser as-is", NSStringFromClass([viewController class]));
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:candidateURL resolvingAgainstBaseURL:NO];
    NSString *searchValue = nil;
    for (NSURLQueryItem *queryItem in components.queryItems) {
        if ([queryItem.name isEqualToString:@"url"]) {
            searchValue = queryItem.value;
            break;
        }
    }

    if (!searchValue) {
        NSString *rawString = candidateURL.absoluteString;
        NSError *regexError = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[?&]url=([^&]+)" options:0 error:&regexError];
        NSTextCheckingResult *match = [regex firstMatchInString:rawString options:0 range:NSMakeRange(0, rawString.length)];
        if (match && match.numberOfRanges > 1) {
            NSString *rawValue = [rawString substringWithRange:[match rangeAtIndex:1]];
            searchValue = [rawValue stringByRemovingPercentEncoding] ?: rawValue;
            ITDebug("safari", @"NSURLComponents missed the url= param, regex fallback found: %@", searchValue);
        }
    }

    NSURL *resolved = searchValue ? [NSURL URLWithString:searchValue] : candidateURL;
    ITDebug("safari", @"resolved Safari destination on %@: %@", NSStringFromClass([viewController class]), resolved);
    return resolved;
}

static const void *InfinitokSafariHandledKey(void) {
    static const char key = 0;
    return &key;
}

static BOOL InfinitokTryRedirectToSafari(id viewController) {
    if (!viewController) {
        return NO;
    }
    if ([objc_getAssociatedObject(viewController, InfinitokSafariHandledKey()) boolValue]) {
        return YES;
    }

    NSURL *originURL = [viewController respondsToSelector:@selector(originURL)] ? [viewController originURL] : nil;
    NSURL *destinationURL = InfinitokResolveSafariDestinationURL(viewController, originURL);
    if (!destinationURL) {
        return NO;
    }

    objc_setAssociatedObject(viewController, InfinitokSafariHandledKey(), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[UIApplication sharedApplication] openURL:destinationURL options:@{} completionHandler:nil];

    if ([viewController respondsToSelector:@selector(didTapCloseButton)]) {
        [viewController performSelector:@selector(didTapCloseButton)];
    } else if ([viewController isKindOfClass:[UIViewController class]]) {
        UIViewController *vc = (UIViewController *)viewController;
        if (vc.navigationController) {
            [vc.navigationController popViewControllerAnimated:NO];
        } else {
            [vc dismissViewControllerAnimated:NO completion:nil];
        }
    }
    return YES;
}

%hook SparkViewController
- (void)viewWillAppear:(BOOL)animated {
    if ([BHIManager alwaysOpenSafari]) {
        ITDebug("safari", @"SparkViewController viewWillAppear — class=%@", NSStringFromClass([self class]));
        if (InfinitokTryRedirectToSafari(self)) {
            return;
        }
    }
    %orig;
}
%end

%hook SparkWebViewController
- (void)viewWillAppear:(BOOL)animated {
    if ([BHIManager alwaysOpenSafari]) {
        ITDebug("safari", @"SparkWebViewController viewWillAppear — class=%@", NSStringFromClass([(id)self class]));
        if (InfinitokTryRedirectToSafari(self)) {
            return;
        }
    }
    %orig;
}
%end

static NSURL *InfinitokExtractSafariURLFromRouterString(NSString *routerURLString) {
    if (![routerURLString isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *lowered = routerURLString.lowercaseString;

    if ([lowered rangeOfString:@"://webview"].location == NSNotFound) {
        return nil;
    }
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[?&]url=([^&]+)" options:0 error:&regexError];
    NSTextCheckingResult *match = [regex firstMatchInString:routerURLString options:0 range:NSMakeRange(0, routerURLString.length)];
    if (!match || match.numberOfRanges < 2) {
        return nil;
    }
    NSString *rawValue = [routerURLString substringWithRange:[match rangeAtIndex:1]];
    NSString *decoded = [rawValue stringByRemovingPercentEncoding] ?: rawValue;
    NSURL *url = [NSURL URLWithString:decoded];
    NSString *scheme = url.scheme.lowercaseString;

    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        return nil;
    }
    return url;
}

%hook AWERouter
+ (void)transferWithSourceView:(UIView *)sourceView URLString:(NSString *)URLString {

    ITDebug("safari", @"AWERouter transferWithSourceView:URLString: called with: %@", URLString);
    if ([BHIManager alwaysOpenSafari]) {
        NSURL *safariURL = InfinitokExtractSafariURLFromRouterString(URLString);
        if (safariURL) {
            ITDebug("safari", @"intercepted AWERouter navigation (%@), opening in Safari instead: %@", URLString, safariURL);
            [[UIApplication sharedApplication] openURL:safariURL options:@{} completionHandler:nil];
            return;
        }
    }
    %orig;
}
%end

%hook AWEWebViewController
- (void)viewWillAppear:(BOOL)animated {
    if ([BHIManager alwaysOpenSafari] && InfinitokTryRedirectToSafari(self)) {
        return;
    }
    %orig;
}
%end

static const unsigned int kInfinitokMaxSelectorScanPatches = 25;

static const unsigned int kInfinitokBioLinkMaxScanPatches = 150;

static void InfinitokForceBioLinkSafariRedirect(void) {

    if (![BHIManager alwaysOpenSafari]) {
        return;
    }
    SEL newSel = @selector(textView:shouldInteractWithURL:inRange:interaction:);
    SEL oldSel = @selector(textView:shouldInteractWithURL:inRange:);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    unsigned int patchedCount = 0;
    for (unsigned int i = 0; i < classCount && patchedCount < kInfinitokBioLinkMaxScanPatches; i++) {
        Class cls = classes[i];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        Method newMethod = NULL, oldMethod = NULL;
        for (unsigned int m = 0; m < methodCount; m++) {
            SEL name = method_getName(methods[m]);
            if (name == newSel) newMethod = methods[m];
            if (name == oldSel) oldMethod = methods[m];
        }
        free(methods);
        if (newMethod) {
            __block IMP orig = NULL;
            IMP replacement = imp_implementationWithBlock(^BOOL(id self, UITextView *textView, NSURL *URL, NSRange range, NSInteger interaction) {
                ITDebug("safari", @"[%@ textView:shouldInteractWithURL:inRange:interaction:] url=%@", NSStringFromClass([self class]), URL);
                if ([BHIManager alwaysOpenSafari] && URL && ([URL.scheme.lowercaseString isEqualToString:@"http"] || [URL.scheme.lowercaseString isEqualToString:@"https"])) {
                    ITDebug("safari", @"redirecting bio-link tap to Safari: %@", URL);
                    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
                    return NO;
                }
                return orig ? ((BOOL (*)(id, SEL, UITextView *, NSURL *, NSRange, NSInteger))orig)(self, newSel, textView, URL, range, interaction) : YES;
            });
            orig = method_setImplementation(newMethod, replacement);
            patchedCount++;
        }
        if (oldMethod) {
            __block IMP orig = NULL;
            IMP replacement = imp_implementationWithBlock(^BOOL(id self, UITextView *textView, NSURL *URL, NSRange range) {
                ITDebug("safari", @"[%@ textView:shouldInteractWithURL:inRange:] url=%@", NSStringFromClass([self class]), URL);
                if ([BHIManager alwaysOpenSafari] && URL && ([URL.scheme.lowercaseString isEqualToString:@"http"] || [URL.scheme.lowercaseString isEqualToString:@"https"])) {
                    ITDebug("safari", @"redirecting bio-link tap to Safari (legacy delegate method): %@", URL);
                    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
                    return NO;
                }
                return orig ? ((BOOL (*)(id, SEL, UITextView *, NSURL *, NSRange))orig)(self, oldSel, textView, URL, range) : YES;
            });
            orig = method_setImplementation(oldMethod, replacement);
            patchedCount++;
        }
    }
    free(classes);
    if (patchedCount >= kInfinitokBioLinkMaxScanPatches) {
        ITError("safari", @"bio-link UITextViewDelegate scan hit the %u-match patch cap — stopping early", kInfinitokBioLinkMaxScanPatches);
    } else {
        ITDebug("safari", @"bio-link UITextViewDelegate methods patched on %u class(es)", patchedCount);
    }
}

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (![BHIManager alwaysOpenSafari]) {
        return;
    }
    NSString *className = NSStringFromClass([self class]);
    BOOL looksLikeWebView = [className rangeOfString:@"WebView" options:NSCaseInsensitiveSearch].location != NSNotFound
                          || [className rangeOfString:@"Browser" options:NSCaseInsensitiveSearch].location != NSNotFound;
    if (!looksLikeWebView) {
        return;
    }
    if (![self respondsToSelector:@selector(originURL)] && ![self respondsToSelector:@selector(originURLList)]) {
        return;
    }
    InfinitokTryRedirectToSafari(self);
}
%end

static NSString *InfinitokRegionField(NSString *api, NSString *field, NSString *orig, BOOL lowercase) {
    if (![BHIManager regionChangingEnabled]) {
        return orig;
    }
    NSDictionary *selectedRegion = [BHIManager selectedRegion];
    NSString *value = selectedRegion[field];
    if (![value isKindOfClass:[NSString class]] || value.length == 0) {
        return orig;
    }
    return lowercase ? [value lowercaseString] : value;
}

static NSString *InfinitokRegionCode(NSString *api, NSString *orig, BOOL lowercase) {
    return InfinitokRegionField(api, @"code", orig, lowercase);
}

%hook CTCarrier
- (NSString *)mobileCountryCode {
    id origValue = %orig;
    return InfinitokRegionField(@"CTCarrier.mobileCountryCode", @"mcc", origValue, NO);
}

- (void)setIsoCountryCode:(NSString *)arg1 {
    %orig(InfinitokRegionCode(@"CTCarrier.setIsoCountryCode", arg1, NO));
}

- (NSString *)isoCountryCode {
    id origValue = %orig;
    return InfinitokRegionCode(@"CTCarrier.isoCountryCode", origValue, NO);
}

- (NSString *)mobileNetworkCode {
    id origValue = %orig;
    return InfinitokRegionField(@"CTCarrier.mobileNetworkCode", @"mnc", origValue, NO);
}
%end

%hook TTKStoreRegionService
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TTKStoreRegionService.storeRegion", origValue, YES);
}
- (id)getStoreRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TTKStoreRegionService.getStoreRegion", origValue, YES);
}
- (void)setStoreRegion:(id)arg1 {
    %orig(InfinitokRegionCode(@"TTKStoreRegionService.setStoreRegion", arg1, YES));
}

- (BOOL)isUserSelectedRegion {
    if ([BHIManager regionChangingEnabled] && [BHIManager selectedRegion]) {
        return YES;
    }
    return %orig;
}
%end
%hook TIKTOKRegionManager
+ (NSString *)systemRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.systemRegion", origValue, NO);
}
+ (id)region {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.region", origValue, NO);
}
+ (id)localRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.localRegion", origValue, NO);
}
+ (id)carrierRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.carrierRegion", origValue, NO);
}
+ (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.storeRegion", origValue, NO);
}
+ (id)currentRegionV2 {
    id origValue = %orig;
    return InfinitokRegionCode(@"TIKTOKRegionManager.currentRegionV2", origValue, NO);
}
+ (id)mccmnc {
    if ([BHIManager regionChangingEnabled]) {
        NSDictionary *selectedRegion = [BHIManager selectedRegion];
        if (selectedRegion[@"mcc"] && selectedRegion[@"mnc"]) {
            return [NSString stringWithFormat:@"%@%@", selectedRegion[@"mcc"], selectedRegion[@"mnc"]];
        }
    }
    return %orig;
}

+ (BOOL)isRegion:(id)region {
    NSString *code = InfinitokRegionCode(@"TIKTOKRegionManager.isRegion", nil, NO);
    if (code && [region isKindOfClass:[NSString class]]) {
        return [region caseInsensitiveCompare:code] == NSOrderedSame;
    }
    return %orig;
}
+ (BOOL)isInRegions:(id)regions {
    NSString *code = InfinitokRegionCode(@"TIKTOKRegionManager.isInRegions", nil, NO);
    if (code && [regions isKindOfClass:[NSArray class]]) {
        for (id region in (NSArray *)regions) {
            if ([region isKindOfClass:[NSString class]] && [region caseInsensitiveCompare:code] == NSOrderedSame) {
                return YES;
            }
        }
        return NO;
    }
    return %orig;
}
%end

%hook TTKSADeviceInfoHelpers
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TTKSADeviceInfoHelpers.storeRegion", origValue, YES);
}
%end
%hook TikTokEPRDeviceInfoHelpers
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TikTokEPRDeviceInfoHelpers.storeRegion", origValue, YES);
}
%end
%hook TTKLifeGuardDeviceInfo
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"TTKLifeGuardDeviceInfo.storeRegion", origValue, YES);
}
%end
%hook HybridContext
- (id)region {
    id origValue = %orig;
    return InfinitokRegionCode(@"HybridContext.region", origValue, NO);
}
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"HybridContext.storeRegion", origValue, YES);
}
%end
%hook IESForestRequestParameters
- (id)region {
    id origValue = %orig;
    return InfinitokRegionCode(@"IESForestRequestParameters.region", origValue, NO);
}
- (id)storeRegion {
    id origValue = %orig;
    return InfinitokRegionCode(@"IESForestRequestParameters.storeRegion", origValue, YES);
}
%end

%hook TTKPassportAppStoreRegionModel
- (id)storeRegion {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return [selectedRegion[@"code"] lowercaseString];
        }
        return %orig;
    }
    return %orig;
}
- (void)setStoreRegion:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig([selectedRegion[@"code"] lowercaseString]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
- (void)setLocalizedCountryName:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig(selectedRegion[@"name"]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
- (id)localizedCountryName {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return selectedRegion[@"name"];
        }
        return %orig;
    }
    return %orig;
}
%end

%hook ATSRegionCacheManager
- (id)getRegion {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return [selectedRegion[@"code"] lowercaseString];
        }
        return %orig;
    }
    return %orig;
}
- (id)storeRegionFromCache {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return [selectedRegion[@"code"] lowercaseString];
        }
        return %orig;
    }
    return %orig;
}
- (id)storeRegionFromTTNetNotification:(id)arg1 {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return [selectedRegion[@"code"] lowercaseString];
        }
        return %orig;
    }
    return %orig;
}
- (void)setRegion:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig([selectedRegion[@"code"] lowercaseString]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
- (id)region {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return [selectedRegion[@"code"] lowercaseString];
        }
        return %orig;
    }
    return %orig;
}
%end

%hook TTKStoreRegionModel
- (id)storeRegion {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return selectedRegion[@"code"];
        }
        return %orig;
    }
    return %orig;
}
- (void)setStoreRegion:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig(selectedRegion[@"code"]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
%end

%hook TTInstallIDManager
- (id)currentAppRegion {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return selectedRegion[@"code"];
        }
        return %orig;
    }
    return %orig;
}
- (void)setCurrentAppRegion:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig(selectedRegion[@"code"]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
%end

%hook BDInstallGlobalConfig
- (id)currentAppRegion {
 if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return selectedRegion[@"code"];
        }
        return %orig;
    }
    return %orig;
}
- (void)setCurrentAppRegion:(id)arg1 {
    if ([BHIManager regionChangingEnabled]) {
        if ([BHIManager selectedRegion]) {
            NSDictionary *selectedRegion = [BHIManager selectedRegion];
            return %orig(selectedRegion[@"code"]);
        }
        return %orig(arg1);
    }
    return %orig(arg1);
}
%end

%hook ACCCreationPublishAction
- (BOOL)is_open_hd {
    if ([BHIManager uploadHD]) {
        return 1;
    }
    return %orig;
}
- (void)setIs_open_hd:(BOOL)arg1 {
    if ([BHIManager uploadHD]) {
        %orig(1);
    }
    else {
        return %orig;
    }
}
- (BOOL)is_have_hd {
    if ([BHIManager uploadHD]) {
        return 1;
    }
    return %orig;
}
- (void)setIs_have_hd:(BOOL)arg1 {
    if ([BHIManager uploadHD]) {
        %orig(1);
    }
    else {
        return %orig;
    }
}

%end

static BOOL InfinitokModelLooksLikeAd(id model) {
    if (!model) {
        return NO;
    }
    NSArray<NSString *> *adFlagSelectors = @[@"isAds", @"isAd", @"isAdItem", @"isAdsOrPseudoAds", @"isPromoted"];
    for (NSString *selectorName in adFlagSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![model respondsToSelector:selector]) {
            continue;
        }
        NSMethodSignature *signature = [model methodSignatureForSelector:selector];
        if (!signature || strcmp(signature.methodReturnType, @encode(BOOL)) != 0) {
            continue;
        }
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = selector;
        [invocation invokeWithTarget:model];
        BOOL result = NO;
        [invocation getReturnValue:&result];
        if (result) {
            ITDebug("ads", @"%@ flagged as ad via %@", NSStringFromClass([model class]), selectorName);
            return YES;
        }
    }
    return NO;
}

%hook AWEAwemeModel
- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
    id orig = %orig;
    return [BHIManager hideAds] && InfinitokModelLooksLikeAd(self) ? nil : orig;
}
- (id)init {
    id orig = %orig;
    return [BHIManager hideAds] && InfinitokModelLooksLikeAd(self) ? nil : orig;
}

- (BOOL)progressBarDraggable {
    return [BHIManager progressBar] || %orig;
}
- (BOOL)progressBarVisible {
    return [BHIManager progressBar] || %orig;
}
- (void)live_callInitWithDictyCategoryMethod:(id)arg1 {
    if (![BHIManager disableLive]) {
        %orig;
    }
}
+ (id)liveStreamURLJSONTransformer {
    if ([BHIManager disableLive]) {
        return nil;
    }
    return %orig;
}
+ (id)relatedLiveJSONTransformer {
    if ([BHIManager disableLive]) {
        return nil;
    }
    return %orig;
}
+ (id)rawModelFromLiveRoomModel:(id)arg1 {
    if ([BHIManager disableLive]) {
        return nil;
    }
    return %orig;
}
+ (id)aweLiveRoom_subModelPropertyKey {
    if ([BHIManager disableLive]) {
        return nil;
    }
    return %orig;
}
%end

%hook AWEAwemeDetailAdController
- (id)adModel {
    return [BHIManager hideAds] ? nil : %orig;
}
%end

%hook AWEDetailAdController
- (id)adModel {
    return [BHIManager hideAds] ? nil : %orig;
}
%end

%hook AWEFeedAdController
- (id)adModel {
    return [BHIManager hideAds] ? nil : %orig;
}
%end

%hook AWEProfileAdController
- (id)adModel {
    return [BHIManager hideAds] ? nil : %orig;
}
%end

%hook TTKAdDetailController
- (id)adModel {
    return [BHIManager hideAds] ? nil : %orig;
}
%end

%hook AWEPlayInteractionWarningElementView
- (id)warningImage {
    if ([BHIManager disableWarnings]) {
        return nil;
    }
    return %orig;
}
- (id)warningLabel {
    if ([BHIManager disableWarnings]) {
        return nil;
    }
    return %orig;
}
%end

%hook TUXLabel
- (void)setText:(NSString*)arg1 {
    if ([BHIManager showUsername]) {
        if ([[[self superview] superview] isKindOfClass:%c(AWEPlayInteractionAuthorUserNameButton)]){
            AWEFeedCellViewController *rootVC = [[[self superview] superview] yy_viewController];
            AWEAwemeModel *model = rootVC.model;
            AWEUserModel *authorModel = model.author;
            NSString *nickname = authorModel.nickname;
            NSString *username = authorModel.socialName;
            %orig(username);
        }else {
            %orig;
        }
    }else {
        %orig;
    }
}
%end

%hook AWENewFeedTableViewController
- (BOOL)disablePullToRefreshGestureRecognizer {
    if ([BHIManager disablePullToRefresh]){
        return 1;
    }
    return %orig;
}

%end

%hook AWEPlayVideoPlayerController
- (void)playerWillLoopPlaying:(id)arg1 {
    if ([BHIManager autoPlay]) {
        AWENewFeedTableViewController *feed = InfinitokFindFeedController(self.container);
        if (feed) {
            [feed scrollToNextVideo];
            return;
        }
    }
    %orig;
}
- (BOOL)loop {
    if ([BHIManager stopPlay]) {
        return 0;
    }
    return %orig;
}
- (void)setLoop:(BOOL)arg1 {
    if ([BHIManager stopPlay]) {
        %orig(0);
    }else {
        %orig;
    }
}
%end

%hook TTKMediaVideoPlayerController
- (void)playerWillLoopPlaying:(id)arg1 {
    if ([BHIManager autoPlay]) {
        AWENewFeedTableViewController *feed = InfinitokFindFeedController(self.container);
        if (feed) {
            [feed scrollToNextVideo];
            return;
        }
    }
    %orig;
}
- (BOOL)loop {
    if ([BHIManager stopPlay]) {
        return 0;
    }
    return %orig;
}
- (void)setLoop:(BOOL)arg1 {
    if ([BHIManager stopPlay]) {
        %orig(0);
    }else {
        %orig;
    }
}
%end

%hook AWEMaskInfoModel
- (BOOL)showMask {
    if ([BHIManager disableUnsensitive]) {
        return 0;
    }
    return %orig;
}
- (void)setShowMask:(BOOL)arg1 {
    if ([BHIManager disableUnsensitive]) {
        %orig(0);
    }
    else {
        %orig;
    }
}
%end

%hook AWEAwemeACLItem
- (void)setWatermarkType:(NSUInteger)arg1 {
    if ([BHIManager removeWatermark]){
        %orig(1);
    }
    else {
        %orig;
    }

}
- (NSUInteger)watermarkType {
    if ([BHIManager removeWatermark]){
        return 1;
    }
    return %orig;
}
%end

%hook AWEPlayInteractionUserAvatarElement
- (void)onFollowViewClicked:(id)sender {
    if ([BHIManager followConfirmation]) {
        showConfirmation(^{
            %orig;
        });
    } else {
        return %orig;
    }
}
%end

static BOOL gInfinitokViewingOwnProfile = NO;

static BOOL InfinitokIsOwnProfile(id component) {
    id context = nil;
    @try {
        if ([component respondsToSelector:@selector(profileContext)]) {
            context = [component valueForKey:@"profileContext"];
        }
        if (!context && [component respondsToSelector:@selector(delegate)]) {
            id delegate = [component valueForKey:@"delegate"];
            if ([delegate respondsToSelector:@selector(profileContext)]) {
                context = [delegate valueForKey:@"profileContext"];
            }
        }
        if (!context) {
            return gInfinitokViewingOwnProfile;
        }
        BOOL isOwn = NO;
        id isCurrentUser = [context valueForKey:@"isCurrentUser"];
        if ([isCurrentUser isKindOfClass:[NSNumber class]]) {
            isOwn = [isCurrentUser boolValue];
        } else {
            NSString *userID = [context valueForKey:@"userID"];
            NSString *loginID = [context valueForKey:@"currentLoginUserID"];
            isOwn = userID.length > 0 && [userID isEqualToString:loginID];
        }
        gInfinitokViewingOwnProfile = isOwn;
        return isOwn;
    } @catch (NSException *exception) {
        return gInfinitokViewingOwnProfile;
    }
}

static BOOL InfinitokShouldFakeStats(id component) {
    return [BHIManager fakeChangesEnabled] && InfinitokIsOwnProfile(component);
}

%hook TTKProfileBaseComponentModel

- (NSDictionary *)bizData {
	if ([BHIManager fakeChangesEnabled]) {
		NSDictionary *originalData = %orig;
		NSMutableDictionary *modifiedData = [originalData mutableCopy];

		NSNumber *fakeFollowingCount = [self numberFromUserDefaultsForKey:@"following_count"];
		NSNumber *fakeFollowersCount = [self numberFromUserDefaultsForKey:@"follower_count"];

		BOOL isLikeComponent = [self.componentID isEqualToString:@"relation_info_like"] || [self.componentID isEqualToString:@"user_like_count"] || [self.componentID isEqualToString:@"relation_info_likes"];
		if (InfinitokShouldFakeStats(self) && [self.componentID isEqualToString:@"relation_info_follower"]) {
			modifiedData[@"follower_count"] = fakeFollowersCount ?: @0;
			modifiedData[@"formatted_number"] = [self formattedStringFromNumber:fakeFollowersCount ?: @0];
		} else if (InfinitokShouldFakeStats(self) && [self.componentID isEqualToString:@"relation_info_following"]) {
			modifiedData[@"following_count"] = fakeFollowingCount ?: @0;
			modifiedData[@"formatted_number"] = [self formattedStringFromNumber:fakeFollowingCount ?: @0];
		} else if (InfinitokShouldFakeStats(self) && isLikeComponent) {
			NSNumber *fakeLikesCount = [self numberFromUserDefaultsForKey:@"like_count"];
			modifiedData[@"like_count"] = fakeLikesCount ?: @0;
			modifiedData[@"formatted_number"] = [self formattedStringFromNumber:fakeLikesCount ?: @0];
		}
		return [modifiedData copy];
	}
	if ([BHIManager exactFollowerCount] && [self.componentID isEqualToString:@"relation_info_follower"]) {
		NSDictionary *originalData = %orig;
		NSMutableDictionary *modifiedData = [originalData mutableCopy];
		NSNumber *realCount = modifiedData[@"follower_count"];
		if (realCount) {

			modifiedData[@"formatted_number"] = [NSString stringWithFormat:@"%@", realCount];
		}
		return [modifiedData copy];
	}
	return %orig;
}

- (NSArray *)components {
	if ([BHIManager fakeVerified]) {
		NSArray *originalComponents = %orig;
		if ([self.componentID isEqualToString:@"user_account_base_info"] && originalComponents.count == 1) {
			NSMutableArray *modifiedComponents = [originalComponents mutableCopy];
			TTKProfileBaseComponentModel *fakeVerify = [%c(TTKProfileBaseComponentModel) new];
			fakeVerify.componentID = @"user_account_verify";
			fakeVerify.name = @"user_account_verify";
			[modifiedComponents addObject:fakeVerify];
			return [modifiedComponents copy];
		}
	}
	return %orig;
}

%new - (NSNumber *)numberFromUserDefaultsForKey:(NSString *)key {
    NSString *stringValue = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return (stringValue.length > 0) ? @([stringValue doubleValue]) : @0;
}

%new - (NSString *)formattedStringFromNumber:(NSNumber *)number {
    if (!number) return @"0";

    double value = [number doubleValue];
    if (value == 0) return @"0";

    NSString *formattedString;
    if (value >= 1e9) {
        formattedString = [NSString stringWithFormat:@"%.1fB", value / 1e9];
    } else if (value >= 1e6) {
        formattedString = [NSString stringWithFormat:@"%.1fM", value / 1e6];
    } else if (value >= 1e3) {
        formattedString = [NSString stringWithFormat:@"%.1fk", value / 1e3];
    } else {
        formattedString = [NSString stringWithFormat:@"%.0f", value];
    }

    return formattedString;
}

%end

%hook TTKProfileExternalUserRelationInfoFollowerComponent
- (void)updateUI {
    %orig;
    if (InfinitokShouldFakeStats(self)) {
        NSString *fakeText = InfinitokFormattedFakeCount(@"follower_count");
        if (fakeText) {
            self.countLabel.text = fakeText;
        }
    }
}
%end

%hook TTKProfileExternalUserRelationInfoFollowingComponent
- (void)updateUI {
    %orig;
    if (InfinitokShouldFakeStats(self)) {
        NSString *fakeText = InfinitokFormattedFakeCount(@"following_count");
        if (fakeText) {
            self.countLabel.text = fakeText;
        }
    }
}
%end

%hook TTKProfileUserRelationInfoItemComponent
- (void)updateUI {
    %orig;
    NSInteger index = [self p_getCurrentItemIndex];
    if (index == 2 && InfinitokShouldFakeStats(self)) {
        NSString *fakeText = InfinitokFormattedFakeCount(@"like_count");
        if (fakeText) {
            self.countLabel.text = fakeText;
        }
    }
}
%end

%hook TTKProfileExternalUserRelationInfoLikeComponent
- (void)updateUI {
    %orig;
    if (InfinitokShouldFakeStats(self)) {
        NSString *fakeText = InfinitokFormattedFakeCount(@"like_count");
        if (fakeText) {
            self.countLabel.text = fakeText;
        }
    }
}

- (id)p_getCountStr {
    if (InfinitokShouldFakeStats(self)) {
        NSString *fakeText = InfinitokFormattedFakeCount(@"like_count");
        if (fakeText) {
            return fakeText;
        }
    }
    return %orig;
}
- (BOOL)p_shouldShowLikeCount {
    if (InfinitokShouldFakeStats(self) && InfinitokFormattedFakeCount(@"like_count")) {
        return YES;
    }
    return %orig;
}
%end

%hook TTKProfileHomeViewController
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)headerView forSection:(NSInteger)section {
    %orig;
    if ([BHIManager fakeChangesEnabled] || [BHIManager fakeVerified]) {
        [headerView setNeedsLayout];
        [headerView layoutIfNeeded];
    }
}
%end

%hook TTKProfileRootView
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)headerView forSection:(NSInteger)section {
    %orig;
    if ([BHIManager fakeChangesEnabled] || [BHIManager fakeVerified]) {
        [headerView setNeedsLayout];
        [headerView layoutIfNeeded];
    }
}
%end

%hook AWEFeedVideoButton

- (void)_onTouchUpInside {
    NSString *iconName = self.imageNameString;
    BOOL isLikeButton = iconName.length > 0 && [iconName rangeOfString:@"Like" options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL currentlyLiked = isLikeButton && [iconName rangeOfString:@"Red" options:NSCaseInsensitiveSearch].location != NSNotFound;
    ITDebug("like", @"AWEFeedVideoButton tapped — imageNameString=%@ isLikeButton=%@ currentlyLiked=%@ likeConfirmation=%@",
            iconName, isLikeButton ? @"YES" : @"NO", currentlyLiked ? @"YES" : @"NO", [BHIManager likeConfirmation] ? @"YES" : @"NO");
    if ([BHIManager likeConfirmation] && isLikeButton && !currentlyLiked) {

        __weak __typeof(self) weakSelf = self;
        showConfirmation(^{
            __typeof(self) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.window) {
                ITDebug("like", @"confirmed like action skipped — button no longer on screen (recycled?)");
                return;
            }
            %orig;
        });
    } else {
        %orig;
    }
}
%end

%hook AWECollectionButton
- (void)_onTouchUpInside {
    BOOL selected = ((UIControl *)self).selected;
    ITDebug("like", @"AWECollectionButton tapped — selected=%@ confirmFavorite=%@", selected ? @"YES" : @"NO", [BHIManager confirmFavorite] ? @"YES" : @"NO");
    if ([BHIManager confirmFavorite] && !selected) {
        __weak __typeof(self) weakSelf = self;
        showConfirmation(^{
            __typeof(self) strongSelf = weakSelf;
            if (!strongSelf || !((UIView *)strongSelf).window) {
                return;
            }
            %orig;
        });
    } else {
        %orig;
    }
}
%end

%hook TTKFeedInteractionLikeManager
- (void)doubleTapLikeWithAnimation:(id)arg1 {
    if ([BHIManager likeConfirmation]) {
        showConfirmation(^{
            %orig;
        });
    } else {
        %orig;
    }
}
%end

%hook TTKPersonalAdsPopup
- (BOOL)canShow:(id)arg1 context:(id)arg2 {
    if ([BHIManager hideAds]) {
        return NO;
    }
    return %orig;
}
%end
%hook TTKPersonalAdsOptimizationPopup
- (BOOL)canShow:(id)arg1 context:(id)arg2 {
    if ([BHIManager hideAds]) {
        return NO;
    }
    return %orig;
}
%end

%hook UIApplication
- (void)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event {
    NSString *actionName = NSStringFromSelector(action);

    NSArray *repostCandidates = @[@"upvoteButtonClicked:", @"onRepostViewClicked:", @"repostButtonTapped:", @"onRepostButtonClicked:", @"didTapRepostButton:", @"onRepostClicked:"];
    NSArray *favoriteCandidates = @[@"onCollectViewClicked:", @"onFavoriteViewClicked:", @"didTapCollectButton:", @"collectButtonTapped:", @"onCollectButtonClicked:"];

    NSArray *commentSendCandidates = @[@"onSendButtonClicked:", @"sendCommentButtonTapped:", @"didTapSendButton:", @"postCommentButtonTapped:", @"onCommentSendClicked:", @"sendCommentButtonClicked:"];

    if ([repostCandidates containsObject:actionName] && InfinitokConfirmRepost("sendAction", ^{
        %orig;
    })) {
        return;
    }

    if ([actionName rangeOfString:@"repost" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [actionName rangeOfString:@"upvote" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        ITDebug("repost", @"sendAction: saw repost/upvote-like selector not in candidate list: %@", actionName);
    }
    if ([BHIManager confirmFavorite] && [favoriteCandidates containsObject:actionName]) {
        showConfirmation(^{
            %orig;
        });
        return;
    }
    if ([BHIManager confirmSendComment] && [commentSendCandidates containsObject:actionName]) {
        showConfirmation(^{
            %orig;
        });
        return;
    }
    %orig;
}
%end

%hook TTKRepostButtonView
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents {
    if ((controlEvents & UIControlEventTouchUpInside)) {
        ITDebug("repost", @"TTKRepostButtonView sendActionsForControlEvents fired — confirmRepost=%@", [BHIManager confirmRepost] ? @"YES" : @"NO");
    }
    if ((controlEvents & UIControlEventTouchUpInside) && InfinitokConfirmRepost("view", ^{
        %orig;
    })) return;
    %orig;
}
%end
%hook TTKLiveRepostButtonView
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents {
    if ((controlEvents & UIControlEventTouchUpInside)) {
        ITDebug("repost", @"TTKLiveRepostButtonView sendActionsForControlEvents fired — confirmRepost=%@", [BHIManager confirmRepost] ? @"YES" : @"NO");
    }
    if ((controlEvents & UIControlEventTouchUpInside) && InfinitokConfirmRepost("view", ^{
        %orig;
    })) return;
    %orig;
}
%end

%hook TTKPlayInteractionUpvoteManager
- (void)onUpvoteButtonClicked {
    ITDebug("repost", @"TTKPlayInteractionUpvoteManager onUpvoteButtonClicked fired — confirmRepost=%@", [BHIManager confirmRepost] ? @"YES" : @"NO");
    if (InfinitokConfirmRepost("UpvoteManager onUpvoteButtonClicked", ^{
        %orig;
    })) return;
    %orig;
}
%end

%hook TTKRepostButtonView
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ITDebug("repost", @"TTKRepostButtonView touchesEnded fired — confirmRepost=%@", [BHIManager confirmRepost] ? @"YES" : @"NO");
    if (InfinitokConfirmRepost("view", ^{
        %orig;
    })) return;
    %orig;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ITDebug("repost", @"TTKRepostButtonView touchesCancelled fired (a gesture recognizer likely claimed this touch first)");
    %orig;
}
%end
%hook TTKPlayInteractionUpvoteElement
- (void)buttonClicked {
    if (InfinitokConfirmRepost("UpvoteElement buttonClicked", ^{
        %orig;
    })) return;
    %orig;
}
%end

%hook TTKUpvoteShareChannel
- (void)shareWithCompletion:(id)completion {
    if (InfinitokConfirmRepost("UpvoteShareChannel shareWithCompletion:", ^{
        %orig(completion);
    })) return;
    %orig;
}
%end

%hook TTKLiveRepostButtonView
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ITDebug("repost", @"TTKLiveRepostButtonView touchesEnded fired — confirmRepost=%@", [BHIManager confirmRepost] ? @"YES" : @"NO");
    if (InfinitokConfirmRepost("view", ^{
        %orig;
    })) return;
    %orig;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ITDebug("repost", @"TTKLiveRepostButtonView touchesCancelled fired (a gesture recognizer likely claimed this touch first)");
    %orig;
}
%end

%hook AWEPlayInteractionDescriptionElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideCaption]) {
        self.hidden = YES;
    }
}
%end
%hook AWEPlayInteractionCommentElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideCommentsButton]) {
        self.hidden = YES;
    }
}
%end
%hook AWEPlayInteractionLikeElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideLikesButton]) {
        self.hidden = YES;
    }
}
%end
%hook AWEPlayInteractionMusicElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideMusic]) {
        self.hidden = YES;
    }
}
%end
%hook AWEPlayInteractionMusicInfoElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideMusic]) {
        self.hidden = YES;
    }
}
%end
%hook AWEPlayInteractionShareElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideShareButton]) {
        self.hidden = YES;
    }
}
%end
%hook TTKSearchEntranceButton
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideSearchButton]) {
        self.hidden = YES;
    }
}
%end

%hook AWEPlayInteractionDummyDownloadBarElement
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideDownloadButtonNative]) {
        ((UIView *)self).hidden = YES;
    }
}
%end

%hook AWETabBarPlusButton
- (void)layoutSubviews {
    %orig;
    if ([BHIManager hideVideoButton]) {
        ((UIView *)self).hidden = YES;
    }
}
- (void)didMoveToWindow {
    %orig;
    if ([BHIManager hideVideoButton]) {
        ((UIView *)self).hidden = YES;
    }
}
%end

static const void *InfinitokAIGCSkipHandledKey(void) {
    static const char key = 0;
    return &key;
}
%hook AWEPlayInteractionAIGCLabelElement
- (void)layoutSubviews {
    %orig;
    UIView *thisView = (UIView *)self;
    if (!thisView.hidden && thisView.superview) {

        if ([BHIManager hideAIVideos] && ![objc_getAssociatedObject(self, InfinitokAIGCSkipHandledKey()) boolValue]) {
            UIResponder *responder = thisView;
            while ((responder = [responder nextResponder])) {
                if ([responder isKindOfClass:%c(AWENewFeedTableViewController)]) {
                    objc_setAssociatedObject(self, InfinitokAIGCSkipHandledKey(), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    AWENewFeedTableViewController *rootVC = (AWENewFeedTableViewController *)responder;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [rootVC scrollToNextVideo];
                    });
                    break;
                }
            }
        }
    } else {
        objc_setAssociatedObject(self, InfinitokAIGCSkipHandledKey(), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end

%hook UICollectionViewCell
- (void)didMoveToSuperview {
    %orig;
    if ([BHIManager hideAccountSuggestions]) {
        NSString *className = NSStringFromClass([self class]);
        if ([[className lowercaseString] containsString:@"suggest"] || [[className lowercaseString] containsString:@"recommend"]) {
            self.hidden = YES;
        }
    }
    if ([BHIManager showOnlyFavorites]) {
        UIResponder *responder = self;
        while (responder) {
            if ([responder isKindOfClass:%c(AWEFavoriteAwemeViewController)]) {
                NSString *className = NSStringFromClass([self class]);
                NSString *lowerName = [className lowercaseString];
                if ([lowerName containsString:@"sound"] || [lowerName containsString:@"music"] || [lowerName containsString:@"hashtag"] || [lowerName containsString:@"user"]) {
                    self.hidden = YES;
                }
                break;
            }
            responder = responder.nextResponder;
        }
    }
}
%end

%hook AWECommentPanelBaseCell
- (BOOL)shouldShowTranslateButton {
    if ([BHIManager translateComments]) {
        return YES;
    }
    return %orig;
}
- (BOOL)shouldAddTranslateLabel {
    if ([BHIManager translateComments]) {
        return YES;
    }
    return %orig;
}
- (BOOL)shouldShowCommentTranslationLabel {
    if ([BHIManager translateComments]) {
        return YES;
    }
    return %orig;
}
%end

%hook AWECommentPanelCell
- (void)onLikeAction:(id)arg1 {
    if ([BHIManager likeCommentConfirmation]) {
        showConfirmation(^{
            %orig;
        });
    } else {
        return %orig;
    }
}
- (void)onDislikeAction:(id)arg1 {
    if ([BHIManager dislikeCommentConfirmation]) {
        showConfirmation(^{
            %orig;
        });
    } else {
        return %orig;
    }
}
%end

%hook AWEUserModel
%new - (BOOL)infinitokIsSignedInUser {
    if (![BHIManager fakeChangesEnabled]) {
        return NO;
    }
    NSString *userID = [self respondsToSelector:@selector(userID)] ? [self userID] : nil;
    if (userID.length == 0) {
        return NO;
    }
    id currentUser = [%c(AWEUser) respondsToSelector:@selector(currentUser)] ? [%c(AWEUser) currentUser] : nil;
    NSString *currentID = [currentUser respondsToSelector:@selector(userID)] ? [currentUser userID] : nil;
    if (currentID.length == 0) {

        ITDebug("fakestats", @"no signed-in userID from AWEUser (%@)", NSStringFromClass([currentUser class]));
        return gInfinitokViewingOwnProfile;
    }
    return [userID isEqualToString:currentID];
}
- (NSNumber *)followerCount {
    if ([self infinitokIsSignedInUser]) {
        NSString *fakeCountString = [[NSUserDefaults standardUserDefaults] stringForKey:@"follower_count"];
        if (fakeCountString.length > 0) {
            return @([fakeCountString integerValue]);
        }
    }
    return %orig;
}
- (NSNumber *)followingCount {
    if ([self infinitokIsSignedInUser]) {
        NSString *fakeCountString = [[NSUserDefaults standardUserDefaults] stringForKey:@"following_count"];
        if (fakeCountString.length > 0) {
            return @([fakeCountString integerValue]);
        }
    }
    return %orig;
}
%end

%hook AWETextInputController
- (NSUInteger)maxLength {
    if ([BHIManager extendedComment]) {
        return 2200;
    }

    return %orig;
}
%end
%hook AWEPlayVideoPlayerController
- (void)containerDidFullyDisplayWithReason:(NSInteger)arg1 {
    if ([[[self container] parentViewController] isKindOfClass:%c(AWENewFeedTableViewController)] && ([BHIManager skipRecommendations] || [BHIManager hideAIVideos])) {
        AWENewFeedTableViewController *rootVC = [[self container] parentViewController];
        AWEAwemeModel *currentModel = [rootVC currentAweme];
        if ([BHIManager skipRecommendations] && [currentModel isUserRecommendBigCard]) {
            [rootVC scrollToNextVideo];
        } else if ([BHIManager hideAIVideos] && [currentModel aigcLabelType] != 0) {

            [rootVC scrollToNextVideo];
        } else {
            %orig;
        }
    }else {
        %orig;
    }
}
%end
%hook AWEProfileEditTextViewController
- (NSInteger)maxTextLength {
    if ([BHIManager extendedBio]) {
        return 222;
    }

    return %orig;
}
%end
static char kInfinitokFlagRegionKey;

static NSString *InfinitokFlagEmoji(NSString *countryCode) {
    NSString *upper = [countryCode uppercaseString];
    if (upper.length != 2) {
        return nil;
    }
    uint32_t first = [upper characterAtIndex:0] + 0x1F1E6 - 'A';
    uint32_t second = [upper characterAtIndex:1] + 0x1F1E6 - 'A';
    NSString *emoji = [[NSString alloc] initWithBytes:&first length:4 encoding:NSUTF32LittleEndianStringEncoding];
    return [emoji stringByAppendingString:[[NSString alloc] initWithBytes:&second length:4 encoding:NSUTF32LittleEndianStringEncoding]];
}

static BOOL InfinitokApplyRegionBadge(UIView *authorView, NSString *region) {
    UILabel *label = (UILabel *)[authorView viewWithTag:666];
    NSString *emoji = [BHIManager showRegionBadge] ? InfinitokFlagEmoji(region) : nil;
    if (emoji.length == 0) {
        label.text = nil;
        label.hidden = YES;
        return NO;
    }
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 39.5, 20.5)];
        label.tag = 666;
        label.textColor = [UIColor whiteColor];
        [authorView addSubview:label];
    }
    label.hidden = NO;
    label.text = [NSString stringWithFormat:@"%@ •", emoji];
    [label sizeToFit];
    return YES;
}

static UIView *InfinitokLiveAuthorView(UIView *start) {
    Class authorViewClass = objc_getClass("AWEPlayInteractionAuthorView");
    for (UIView *view = start; view; view = view.superview) {
        if ([view isKindOfClass:authorViewClass]) {
            return view;
        }
    }
    return nil;
}

%hook AWEPlayInteractionAuthorElement
- (void)updateWithModel:(id)model {
    %orig;
    UIView *authorView = self.authorView;
    if (!authorView) {
        return;
    }
    AWEAwemeModel *aweme = (AWEAwemeModel *)model;
    NSString *region = [aweme respondsToSelector:@selector(region)] ? aweme.region : nil;

    UIView *target = InfinitokLiveAuthorView(self.containerView) ?: InfinitokLiveAuthorView(self.stackView) ?: authorView;
    objc_setAssociatedObject(target, &kInfinitokFlagRegionKey, region, OBJC_ASSOCIATION_COPY_NONATOMIC);
    InfinitokApplyRegionBadge(target, region);

    [target setNeedsLayout];
    [target layoutIfNeeded];
}
%end

%hook AWEPlayInteractionAuthorView
- (void)layoutSubviews {
    %orig;
    if (![BHIManager showRegionBadge]) {
        [[self viewWithTag:666] removeFromSuperview];
        return;
    }

    NSString *countryID = objc_getAssociatedObject(self, &kInfinitokFlagRegionKey);
    if (!InfinitokApplyRegionBadge(self, countryID)) {
        return;
    }
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIStackView class]]) {
            CGRect frame = subview.frame;
            frame.origin.x = 39.5;
            subview.frame = frame;

            [subview setNeedsLayout];
            [subview layoutIfNeeded];
        }
    }
}
%end
%hook TIKTOKProfileHeaderView
- (id)initWithFrame:(CGRect)arg1 {
    self = %orig;
    if ([BHIManager profileCopy]) {
        [self addHandleLongPress];
    }
    return self;
}
%end

%hook AWELiveFeedEntranceView

- (void)layoutSubviews {
    %orig;
}
- (void)setHidden:(BOOL)hidden {
    if ([BHIManager hideLiveButton]) {
        %orig(YES);
        return;
    }
    %orig(hidden);
}
- (void)switchStateWithTapped:(BOOL)arg1 {
    if (![BHIManager liveActionEnabled] || [BHIManager selectedLiveAction] == 0) {
        %orig;
    } else if ([BHIManager liveActionEnabled] && [[BHIManager selectedLiveAction] intValue] == 1) {
        UINavigationController *InfinitokSettings = [[UINavigationController alloc] initWithRootViewController:[[ViewController alloc] init]];
        InfinitokPresentFromRight(topMostController(), InfinitokSettings);
    } else if ([BHIManager liveActionEnabled] && [[BHIManager selectedLiveAction] intValue] == 2) {
        PlaybackSpeed *playbackSpeed = [[PlaybackSpeed alloc] init];
        UINavigationController *playbackNav = [[UINavigationController alloc] initWithRootViewController:playbackSpeed];
        InfinitokPresentFromRight(topMostController(), playbackNav);
    }
    else {
        %orig;
    }

}
%end

static NSString *InfinitokURLExtensionFromPath(NSString *urlString) {
    if (urlString.length == 0) {
        return nil;
    }
    if ([urlString containsString:@"video_mp4"] || [urlString containsString:@"/video/tos/"]) {
        return @"mp4";
    }
    NSString *lastComponent = urlString.stringByRemovingPercentEncoding ?: urlString;
    if ([lastComponent containsString:@"noop.image"]) {
        return @"jpeg";
    }
    if ([lastComponent containsString:@"noop.jpeg"]) {
        return @"jpeg";
    }
    if ([lastComponent containsString:@"noop.png"]) {
        return @"png";
    }
    NSString *pathExtension = lastComponent.pathExtension.lowercaseString;
    static NSSet *knownExtensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownExtensions = [NSSet setWithArray:@[@"jpg", @"jpeg", @"png", @"webp", @"heic", @"heif", @"gif", @"mp4", @"mov", @"mp3", @"m4a", @"aac", @"wav"]];
    });
    if (pathExtension.length > 0 && [knownExtensions containsObject:pathExtension]) {
        return [pathExtension isEqualToString:@"jpg"] ? @"jpeg" : pathExtension;
    }
    return nil;
}

static NSString *InfinitokDownloadedFileExtension(NSString *downloadedExtension, NSURL *sourceURL, NSString *fallbackExtension) {
    static NSSet *knownExtensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownExtensions = [NSSet setWithArray:@[@"jpg", @"jpeg", @"png", @"webp", @"heic", @"heif", @"gif", @"tiff", @"bmp", @"mp4", @"mov", @"mp3", @"m4a", @"aac", @"wav"]];
    });
    NSString *ext = downloadedExtension.pathExtension.lowercaseString;
    if (ext.length > 0 && [knownExtensions containsObject:ext]) {
        return [ext isEqualToString:@"jpg"] ? @"jpeg" : ext;
    }
    NSString *fromURL = InfinitokURLExtensionFromPath(sourceURL.absoluteString);
    if (fromURL) {
        return fromURL;
    }
    NSString *fallback = fallbackExtension.pathExtension.lowercaseString;
    if (fallback.length == 0) {
        fallback = (fallbackExtension ?: @"").lowercaseString;
    }
    if (fallback.length > 0 && [knownExtensions containsObject:fallback]) {
        return [fallback isEqualToString:@"jpg"] ? @"jpeg" : fallback;
    }
    return nil;
}

static void InfinitokSaveDownloadedFile(NSURL *filePath, NSString *extension) {
    NSArray *audioExtensions = @[@"mp3", @"aac", @"wav", @"m4a", @"ogg", @"flac", @"aiff", @"wma"];
    if ([BHIManager shareSheet] || [audioExtensions containsObject:extension]) {
        [BHIManager showSaveVC:@[filePath]];
    }
    else {
        [BHIManager saveMedia:filePath fileExtension:extension];
    }
}

static UIMenu *InfinitokPhotoDownloadMenu(AWEAwemeBaseViewController *rootVC, id cell) {
    NSArray <AWEPhotoAlbumPhoto *> *photos = rootVC.model.photoAlbum.photos;
    if (photos.count == 0) {
        return nil;
    }
    NSMutableArray <UIMenu *> *sections = [NSMutableArray array];
    if (photos.count > 0) {
        NSMutableArray <UIAction *> *photosActions = [NSMutableArray array];
        for (int i = 0; i < (int)photos.count; i++) {
            NSString *title = [NSString stringWithFormat:@"Download Photo %d", i + 1];
            UIAction *action = [UIAction actionWithTitle:title
                                                   image:[UIImage systemImageNamed:@"photo.fill"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
                                                    [cell downloadPhotos:rootVC photoIndex:i];
            }];
            [photosActions addObject:action];
        }
        UIAction *allPhotosAction = [UIAction actionWithTitle:@"Download All Photos"
                                                image:[UIImage systemImageNamed:@"photo.fill"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
                                                [cell downloadPhotos:rootVC];
        }];
        [photosActions addObject:allPhotosAction];
        [sections addObject:[UIMenu menuWithTitle:@"Download Photos Menu" children:photosActions]];
    }
    UIAction *musicAction = [UIAction actionWithTitle:@"Download Music"
                                            image:[UIImage systemImageNamed:@"music.note"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [cell downloadMusic:rootVC];
    }];
    UIAction *copyMusicAction = [UIAction actionWithTitle:@"Copy Music link"
                                            image:[UIImage systemImageNamed:@"link"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [cell copyMusic:rootVC];
    }];
    UIAction *copyDescAction = [UIAction actionWithTitle:@"Copy Decription"
                                            image:[UIImage systemImageNamed:@"note.text"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [cell copyDecription:rootVC];
    }];
    [sections addObject:[UIMenu menuWithTitle:@"Downloads Menu" children:@[musicAction]]];
    [sections addObject:[UIMenu menuWithTitle:@"Copy Menu" children:@[copyMusicAction, copyDescAction]]];
    return [UIMenu menuWithTitle:@"" children:sections];
}

%hook AWEFeedViewTemplateCell
%property (nonatomic, strong) JGProgressHUD *hud;
%property(nonatomic, assign) BOOL elementsHidden;
%property (nonatomic, retain) NSString *fileextension;
%property (nonatomic, retain) UIProgressView *progressView;
%property (nonatomic, assign) BOOL isVideoDownload;
%property (nonatomic, retain) NSString *pendingVideoFilename;
%property (nonatomic, retain) NSArray *pendingPhotoSourceURLs;
- (void)configWithModel:(id)model {
    %orig;
    self.elementsHidden = [BHIManager hideElementsGlobally];
    if ([BHIManager downloadButton]){
        [self addDownloadButton];
    }
    if ([BHIManager hideElementButton]) {
        [self addHideElementButton];
        [self applyGlobalHideStateIfNeeded];
    }
}
- (void)configureWithModel:(id)model {
    %orig;
    self.elementsHidden = [BHIManager hideElementsGlobally];
    if ([BHIManager downloadButton]){
        [self addDownloadButton];
    }
    if ([BHIManager hideElementButton]) {
        [self addHideElementButton];
        [self applyGlobalHideStateIfNeeded];
    }
}
%new - (void)addDownloadButton {
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [downloadButton setTag:998];
    [downloadButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [downloadButton addTarget:self action:@selector(downloadButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    [downloadButton setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    if (![self viewWithTag:998]) {
        [downloadButton setTintColor:[UIColor whiteColor]];
        [self addSubview:downloadButton];

        NSLayoutConstraint *horizontalConstraint = [BHIManager buttonsOnRight] ?
            [downloadButton.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-10] :
            [downloadButton.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:10];
        [NSLayoutConstraint activateConstraints:@[
            [downloadButton.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:90],
            horizontalConstraint,
            [downloadButton.widthAnchor constraintEqualToConstant:44],
            [downloadButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
}
%new - (void)downloadHDVideo:(AWEAwemeBaseViewController *)rootVC {
    InfinitokDownloadHDVideo(self, rootVC);
}
%new - (void)downloadVideo:(AWEAwemeBaseViewController *)rootVC {
    NSString *as = rootVC.model.itemID;
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
    self.fileextension = [rootVC.model.video.playURL bestURLtoDownloadFormat];
    self.isVideoDownload = true;
    self.pendingVideoFilename = InfinitokVideoDownloadFilename(rootVC, self.fileextension);
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}
%new - (void)downloadPhotos:(AWEAwemeBaseViewController *)rootVC photoIndex:(unsigned long)index {
    self.isVideoDownload = false;
    NSArray <AWEPhotoAlbumPhoto *> *photos = rootVC.model.photoAlbum.photos;
    if (index >= photos.count) {
        return;
    }
    AWEPhotoAlbumPhoto *currentPhoto = [photos objectAtIndex:index];
    NSURL *downloadableURL = [currentPhoto.originPhotoURL bestURLtoDownload];
    self.fileextension = [currentPhoto.originPhotoURL bestURLtoDownloadFormat];
    self.pendingPhotoSourceURLs = @[downloadableURL ?: [NSURL new]];
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}

%new - (void)downloadPhotos:(AWEAwemeBaseViewController *)rootVC {
    self.isVideoDownload = false;
    NSArray <AWEPhotoAlbumPhoto *> *photos = rootVC.model.photoAlbum.photos;
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];

    for (AWEPhotoAlbumPhoto *currentPhoto in photos) {
        NSURL *downloadableURL = [currentPhoto.originPhotoURL bestURLtoDownload];
        if (downloadableURL) {
            [fileURLs addObject:downloadableURL];
        }
    }
    if (fileURLs.count == 0) {
        return;
    }

    self.fileextension = [photos.lastObject.originPhotoURL bestURLtoDownloadFormat];
    self.pendingPhotoSourceURLs = fileURLs;

    BHMultipleDownload *dwManager = [[BHMultipleDownload alloc] init];
    [dwManager setDelegate:self];
    [dwManager downloadFiles:fileURLs];
    self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    self.hud.textLabel.text = @"Downloading";
    [self.hud showInView:topMostController().view];

}
%new - (void)downloadMusic:(AWEAwemeBaseViewController *)rootVC {
    NSString *as = rootVC.model.itemID;
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
    self.fileextension = @"mp3";
    self.isVideoDownload = false;
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}
%new - (void)copyMusic:(AWEAwemeBaseViewController *)rootVC {
    NSURL *downloadableURL = [((AWEMusicModel *)rootVC.model.music).playURL bestURLtoDownload];
    if (downloadableURL) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [downloadableURL absoluteString];
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"Could Not Copy Music." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void)copyVideo:(AWEAwemeBaseViewController *)rootVC {
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
    if (downloadableURL) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [downloadableURL absoluteString];
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"The video dosen't have music to download." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void)copyDecription:(AWEAwemeBaseViewController *)rootVC {
    NSString *video_description = rootVC.model.music_songName;
    if (video_description) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = video_description;
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"The video dosen't have music to download." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void) downloadButtonHandler:(UIButton *)sender {
    AWEAwemeBaseViewController *rootVC = self.viewController;
    if ([rootVC isKindOfClass:%c(AWEFeedCellViewController)]) {

        UIMenu *photoMenu = InfinitokPhotoDownloadMenu(rootVC, self);
        if (photoMenu) {
            [sender setMenu:photoMenu];
            sender.showsMenuAsPrimaryAction = YES;
            return;
        }

         UIAction *action1 = [UIAction actionWithTitle:@"Download Video"
                                            image:[UIImage systemImageNamed:@"film"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadVideo:rootVC];
    }];
        UIAction *action0 = [UIAction actionWithTitle:@"Download HD Video"
                                            image:[UIImage systemImageNamed:@"film"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadHDVideo:rootVC];
    }];
    UIAction *action2 = [UIAction actionWithTitle:@"Download Music"
                                            image:[UIImage systemImageNamed:@"music.note"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadMusic:rootVC];
    }];
    UIAction *action3 = [UIAction actionWithTitle:@"Copy Music link"
                                            image:[UIImage systemImageNamed:@"link"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyMusic:rootVC];
    }];
    UIAction *action4 = [UIAction actionWithTitle:@"Copy Video link"
                                            image:[UIImage systemImageNamed:@"link"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyVideo:rootVC];
    }];
    UIAction *action5 = [UIAction actionWithTitle:@"Copy Decription"
                                            image:[UIImage systemImageNamed:@"note.text"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyDecription:rootVC];
    }];
    UIMenu *downloadMenu = [UIMenu menuWithTitle:@"Downloads Menu"
                                        children:@[action1, action0,action2]];
    UIMenu *copyMenu = [UIMenu menuWithTitle:@"Copy Menu"
                                        children:@[action3, action4, action5]];
    UIMenu *mainMenu = [UIMenu menuWithTitle:@"" children:@[downloadMenu, copyMenu]];
    [sender setMenu:mainMenu];
    sender.showsMenuAsPrimaryAction = YES;
    } else if ([self.viewController isKindOfClass:%c(TTKPhotoAlbumDetailCellController)]) {
        TTKPhotoAlbumDetailCellController *rootVC = self.viewController;
        UIMenu *photoMenu = InfinitokPhotoDownloadMenu(rootVC, self);
        if (photoMenu) {
            [sender setMenu:photoMenu];
            sender.showsMenuAsPrimaryAction = YES;
        }
    } else if ([self.viewController isKindOfClass:%c(TTKPhotoAlbumFeedCellController)]) {
        TTKPhotoAlbumFeedCellController *rootVC = self.viewController;
        UIMenu *photoMenu = InfinitokPhotoDownloadMenu(rootVC, self);
        if (photoMenu) {
            [sender setMenu:photoMenu];
            sender.showsMenuAsPrimaryAction = YES;
        }
    }
}
%new - (void)addHideElementButton {
    UIButton *hideElementButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [hideElementButton setTag:999];
    [hideElementButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [hideElementButton addTarget:self action:@selector(hideElementButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    UIImageSymbolConfiguration *hideElementButtonSymbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    if (self.elementsHidden) {
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.circle.fill" withConfiguration:hideElementButtonSymbolConfig] forState:UIControlStateNormal];
    } else {
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.slash.circle.fill" withConfiguration:hideElementButtonSymbolConfig] forState:UIControlStateNormal];
    }

    if (![self viewWithTag:999]) {
        [hideElementButton setTintColor:[UIColor whiteColor]];
        [self addSubview:hideElementButton];

        NSLayoutConstraint *horizontalConstraint = [BHIManager buttonsOnRight] ?
            [hideElementButton.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-10] :
            [hideElementButton.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:10];
        [NSLayoutConstraint activateConstraints:@[
            [hideElementButton.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:50],
            horizontalConstraint,
            [hideElementButton.widthAnchor constraintEqualToConstant:44],
            [hideElementButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
}
%new - (void)applyGlobalHideStateIfNeeded {
    if (!self.elementsHidden) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.elementsHidden) {
            return;
        }
        AWEAwemeBaseViewController *rootVC = strongSelf.viewController;
        if ([rootVC.interactionController isKindOfClass:%c(TTKFeedInteractionLegacyMainContainerElement)]) {
            [(TTKFeedInteractionLegacyMainContainerElement *)rootVC.interactionController hideAllElements:true exceptArray:nil];
        }
        UIButton *hideElementButton = (UIButton *)[strongSelf viewWithTag:999];
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.circle.fill"] forState:UIControlStateNormal];
    });
}
%new - (void)setElementsHiddenState:(BOOL)hidden sender:(UIButton *)sender {
    AWEAwemeBaseViewController *rootVC = self.viewController;
    if ([rootVC.interactionController isKindOfClass:%c(TTKFeedInteractionLegacyMainContainerElement)]) {
        TTKFeedInteractionLegacyMainContainerElement *interactionController = rootVC.interactionController;
        self.elementsHidden = hidden;
        [interactionController hideAllElements:hidden exceptArray:nil];
        [sender setImage:[UIImage systemImageNamed:(hidden ? @"eye.circle.fill" : @"eye.slash.circle.fill") withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    }
}
%new - (void)hideElementButtonHandler:(UIButton *)sender {
    BOOL currentlyHidden = self.elementsHidden;
    NSString *mode = InfinitokHideUIButtonMode();

    if ([mode isEqualToString:@"all"]) {
        [[NSUserDefaults standardUserDefaults] setBool:!currentlyHidden forKey:@"hide_elements_globally"];
        [self setElementsHiddenState:!currentlyHidden sender:sender];
        return;
    }
    if ([mode isEqualToString:@"this_video"]) {
        [self setElementsHiddenState:!currentlyHidden sender:sender];
        return;
    }

    NSString *thisVideoTitle = currentlyHidden ? @"Show for This Video" : @"Hide for This Video";
    NSString *allVideosTitle = currentlyHidden ? @"Show for All Videos" : @"Hide for All Videos";

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:thisVideoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf setElementsHiddenState:!currentlyHidden sender:sender];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:allVideosTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:!currentlyHidden forKey:@"hide_elements_globally"];
        [weakSelf setElementsHiddenState:!currentlyHidden sender:sender];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (is_iPad()) {
        sheet.popoverPresentationController.sourceView = sender;
        sheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    [topMostController() presentViewController:sheet animated:true completion:nil];
}

%new - (void)downloaderProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHIManager getDownloadingPersent:progress];
}
%new - (void)downloaderDidFinishDownloadingAllFiles:(NSMutableArray<NSURL *> *)downloadedFilePaths {
    [self.hud dismiss];
    if ([BHIManager shareSheet]) {
        [BHIManager showSaveVC:downloadedFilePaths];
    }
    else {

        for (NSURL *url in downloadedFilePaths) {
            NSString *ext = InfinitokDownloadedFileExtension(url.pathExtension, url, self.fileextension) ?: @"jpeg";
            [BHIManager saveMedia:url fileExtension:ext];
        }
    }
}
%new - (void)downloaderDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
        if (error.code != 999) {
            [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"Download failed. Please try again." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
        }
    }
}

%new - (void)downloadProgress:(float)progress {
    self.progressView.progress = progress;
    self.hud.detailTextLabel.text = [BHIManager getDownloadingPersent:progress];
    self.hud.tapOutsideBlock = ^(JGProgressHUD * _Nonnull HUD) {
        self.hud.textLabel.text = @"Backgrounding ✌️";
        [self.hud dismissAfterDelay:0.4];
    };
}
%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];

    NSString *ext = InfinitokDownloadedFileExtension(fileName, self.pendingPhotoSourceURLs.firstObject, self.fileextension) ?: self.fileextension;

    NSString *builtFilename = (self.isVideoDownload && self.pendingVideoFilename.length > 0)
        ? self.pendingVideoFilename
        : [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:builtFilename];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    self.isVideoDownload = false;
    self.pendingVideoFilename = nil;
    self.pendingPhotoSourceURLs = nil;
    [self.hud dismiss];
    InfinitokSaveDownloadedFile(newFilePath, ext);
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
        if (error.code != 999) {
            [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"Download failed. Please try again." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
        }
    }
}
%end

%hook AWEAwemeDetailTableViewCell
%property (nonatomic, strong) JGProgressHUD *hud;
%property(nonatomic, assign) BOOL elementsHidden;
%property (nonatomic, retain) UIProgressView *progressView;
%property (nonatomic, retain) NSString *fileextension;
%property (nonatomic, assign) BOOL isVideoDownload;
%property (nonatomic, retain) NSString *pendingVideoFilename;
%property (nonatomic, retain) NSArray *pendingPhotoSourceURLs;
- (void)configWithModel:(id)model {
    %orig;
    self.elementsHidden = [BHIManager hideElementsGlobally];
    if ([BHIManager downloadButton]){
        [self addDownloadButton];
    }
    if ([BHIManager hideElementButton]) {
        [self addHideElementButton];
        [self applyGlobalHideStateIfNeeded];
    }
}
- (void)configureWithModel:(id)model {
    %orig;
    self.elementsHidden = [BHIManager hideElementsGlobally];
    if ([BHIManager downloadButton]){
        [self addDownloadButton];
    }
    if ([BHIManager hideElementButton]) {
        [self addHideElementButton];
        [self applyGlobalHideStateIfNeeded];
    }
}
%new - (void)addDownloadButton {
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [downloadButton setTag:998];
    [downloadButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [downloadButton addTarget:self action:@selector(downloadButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    [downloadButton setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    if (![self viewWithTag:998]) {
        [downloadButton setTintColor:[UIColor whiteColor]];
        [self addSubview:downloadButton];

        NSLayoutConstraint *horizontalConstraint = [BHIManager buttonsOnRight] ?
            [downloadButton.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-10] :
            [downloadButton.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:10];
        [NSLayoutConstraint activateConstraints:@[
            [downloadButton.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:90],
            horizontalConstraint,
            [downloadButton.widthAnchor constraintEqualToConstant:44],
            [downloadButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
}
%new - (void)downloadHDVideo:(AWEAwemeBaseViewController *)rootVC {
    InfinitokDownloadHDVideo(self, rootVC);
}
%new - (void)downloadVideo:(AWEAwemeBaseViewController *)rootVC {
    NSString *as = rootVC.model.itemID;
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
        self.fileextension = [rootVC.model.video.playURL bestURLtoDownloadFormat];
        self.isVideoDownload = true;
        self.pendingVideoFilename = InfinitokVideoDownloadFilename(rootVC, self.fileextension);
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}
%new - (void)downloadMusic:(AWEAwemeBaseViewController *)rootVC {
    NSString *as = rootVC.model.itemID;
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
        self.fileextension = @"mp3";
        self.isVideoDownload = false;
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}
%new - (void)downloadPhotos:(AWEAwemeBaseViewController *)rootVC photoIndex:(unsigned long)index {
    self.isVideoDownload = false;
    NSArray <AWEPhotoAlbumPhoto *> *photos = rootVC.model.photoAlbum.photos;
    if (index >= photos.count) {
        return;
    }
    AWEPhotoAlbumPhoto *currentPhoto = [photos objectAtIndex:index];
    NSURL *downloadableURL = [currentPhoto.originPhotoURL bestURLtoDownload];
    self.fileextension = [currentPhoto.originPhotoURL bestURLtoDownloadFormat];
    self.pendingPhotoSourceURLs = @[downloadableURL ?: [NSURL new]];
    if (downloadableURL) {
        BHDownload *dwManager = [[BHDownload alloc] init];
        [dwManager downloadFileWithURL:downloadableURL];
        [dwManager setDelegate:self];
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.textLabel.text = @"Downloading";
        [self.hud showInView:topMostController().view];
    }
}
%new - (void)downloadPhotos:(AWEAwemeBaseViewController *)rootVC {
    self.isVideoDownload = false;
    NSArray <AWEPhotoAlbumPhoto *> *photos = rootVC.model.photoAlbum.photos;
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];

    for (AWEPhotoAlbumPhoto *currentPhoto in photos) {
        NSURL *downloadableURL = [currentPhoto.originPhotoURL bestURLtoDownload];
        if (downloadableURL) {
            [fileURLs addObject:downloadableURL];
        }
    }
    if (fileURLs.count == 0) {
        return;
    }
    self.fileextension = [photos.lastObject.originPhotoURL bestURLtoDownloadFormat];
    self.pendingPhotoSourceURLs = fileURLs;

    BHMultipleDownload *dwManager = [[BHMultipleDownload alloc] init];
    [dwManager setDelegate:self];
    [dwManager downloadFiles:fileURLs];
    self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    self.hud.textLabel.text = @"Downloading";
    [self.hud showInView:topMostController().view];
}
%new - (void)copyMusic:(AWEAwemeBaseViewController *)rootVC {
    NSURL *downloadableURL = [((AWEMusicModel *)rootVC.model.music).playURL bestURLtoDownload];
    if (downloadableURL) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [downloadableURL absoluteString];
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"The video dosen't have music to download." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void)copyVideo:(AWEAwemeBaseViewController *)rootVC {
    NSURL *downloadableURL = [rootVC.model.video.playURL bestURLtoDownload];
    if (downloadableURL) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [downloadableURL absoluteString];
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"The video dosen't have music to download." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void)copyDecription:(AWEAwemeBaseViewController *)rootVC {
    NSString *video_description = rootVC.model.music_songName;
    if (video_description) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = video_description;
    } else {
        [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"The video dosen't have music to download." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
    }
}
%new - (void)showPostStats:(AWEAwemeBaseViewController *)rootVC {
    AWEAwemeModel *model = rootVC.model;
    AWEAwemeStatisticsModel *statistics = [model statistics];
    NSString *postedDate = @"-";
    if (model.createTime) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[model.createTime doubleValue]];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm";
        postedDate = [formatter stringFromDate:date];
    }
    NSString *stats = [NSString stringWithFormat:
        @"Video ID: %@\nLikes: %@\nComments: %@\nShares: %@\nPlays: %@\nSaves: %@\nPosted: %@",
        model.itemID ?: @"-",
        [statistics diggCount] ?: @0,
        [statistics commentCount] ?: @0,
        [statistics shareCount] ?: @0,
        [statistics playCount] ?: @0,
        [statistics collectCount] ?: @0,
        postedDate
    ];
    [%c(AWEUIAlertView) showAlertWithTitle:@"Post Stats" description:stats image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
}
%new - (void) downloadButtonHandler:(UIButton *)sender {
    AWEAwemeBaseViewController *rootVC = self.viewController;

    UIMenu *detailPhotoMenu = InfinitokPhotoDownloadMenu(rootVC, self);
    if (detailPhotoMenu) {
        [sender setMenu:detailPhotoMenu];
        sender.showsMenuAsPrimaryAction = YES;
        return;
    }

    if ([rootVC.interactionController isKindOfClass:%c(TTKFeedInteractionLegacyMainContainerElement)]) {

     UIAction *action1 = [UIAction actionWithTitle:@"Download Video"
                                            image:[UIImage systemImageNamed:@"film"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadVideo:rootVC];
    }];
    UIAction *action0 = [UIAction actionWithTitle:@"Download HD Video"
                                            image:[UIImage systemImageNamed:@"film"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadHDVideo:rootVC];
    }];
    UIAction *action2 = [UIAction actionWithTitle:@"Download Music"
                                            image:[UIImage systemImageNamed:@"music.note"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self downloadMusic:rootVC];
    }];
    UIAction *action3 = [UIAction actionWithTitle:@"Copy Music link"
                                            image:[UIImage systemImageNamed:@"link"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyMusic:rootVC];
    }];
    UIAction *action4 = [UIAction actionWithTitle:@"Copy Video link"
                                            image:[UIImage systemImageNamed:@"link"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyVideo:rootVC];
    }];
    UIAction *action5 = [UIAction actionWithTitle:@"Copy Decription"
                                            image:[UIImage systemImageNamed:@"note.text"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
                                            [self copyDecription:rootVC];
    }];
    UIMenu *downloadMenu = [UIMenu menuWithTitle:@"Downloads Menu"
                                        children:@[action1, action0,action2]];
    UIMenu *copyMenu = [UIMenu menuWithTitle:@"Copy Menu"
                                        children:@[action3, action4, action5]];
    NSMutableArray *rootMenuChildren = [@[downloadMenu, copyMenu] mutableCopy];
    if ([BHIManager postStats]) {
        UIAction *statsAction = [UIAction actionWithTitle:@"Post Stats"
                                                image:[UIImage systemImageNamed:@"chart.bar"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
                                                [self showPostStats:rootVC];
        }];
        [rootMenuChildren addObject:statsAction];
    }
    UIMenu *mainMenu = [UIMenu menuWithTitle:@"" children:rootMenuChildren];
    [sender setMenu:mainMenu];
    sender.showsMenuAsPrimaryAction = YES;
    }
}
%new - (void)addHideElementButton {
    UIButton *hideElementButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [hideElementButton setTag:999];
    [hideElementButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [hideElementButton addTarget:self action:@selector(hideElementButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    UIImageSymbolConfiguration *hideElementButtonSymbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    if (self.elementsHidden) {
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.circle.fill" withConfiguration:hideElementButtonSymbolConfig] forState:UIControlStateNormal];
    } else {
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.slash.circle.fill" withConfiguration:hideElementButtonSymbolConfig] forState:UIControlStateNormal];
    }

    if (![self viewWithTag:999]) {
        [hideElementButton setTintColor:[UIColor whiteColor]];
        [self addSubview:hideElementButton];

        NSLayoutConstraint *horizontalConstraint = [BHIManager buttonsOnRight] ?
            [hideElementButton.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-10] :
            [hideElementButton.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:10];
        [NSLayoutConstraint activateConstraints:@[
            [hideElementButton.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:50],
            horizontalConstraint,
            [hideElementButton.widthAnchor constraintEqualToConstant:44],
            [hideElementButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
}
%new - (void)applyGlobalHideStateIfNeeded {
    if (!self.elementsHidden) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.elementsHidden) {
            return;
        }
        AWEAwemeBaseViewController *rootVC = strongSelf.viewController;
        if ([rootVC.interactionController isKindOfClass:%c(TTKFeedInteractionLegacyMainContainerElement)]) {
            [(TTKFeedInteractionLegacyMainContainerElement *)rootVC.interactionController hideAllElements:true exceptArray:nil];
        }
        UIButton *hideElementButton = (UIButton *)[strongSelf viewWithTag:999];
        [hideElementButton setImage:[UIImage systemImageNamed:@"eye.circle.fill"] forState:UIControlStateNormal];
    });
}
%new - (void)setElementsHiddenState:(BOOL)hidden sender:(UIButton *)sender {
    AWEAwemeBaseViewController *rootVC = self.viewController;
    if ([rootVC.interactionController isKindOfClass:%c(TTKFeedInteractionLegacyMainContainerElement)]) {
        TTKFeedInteractionLegacyMainContainerElement *interactionController = rootVC.interactionController;
        self.elementsHidden = hidden;
        [interactionController hideAllElements:hidden exceptArray:nil];
        [sender setImage:[UIImage systemImageNamed:(hidden ? @"eye.circle.fill" : @"eye.slash.circle.fill") withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    }
}
%new - (void)hideElementButtonHandler:(UIButton *)sender {
    BOOL currentlyHidden = self.elementsHidden;
    NSString *mode = InfinitokHideUIButtonMode();

    if ([mode isEqualToString:@"all"]) {
        [[NSUserDefaults standardUserDefaults] setBool:!currentlyHidden forKey:@"hide_elements_globally"];
        [self setElementsHiddenState:!currentlyHidden sender:sender];
        return;
    }
    if ([mode isEqualToString:@"this_video"]) {
        [self setElementsHiddenState:!currentlyHidden sender:sender];
        return;
    }

    NSString *thisVideoTitle = currentlyHidden ? @"Show for This Video" : @"Hide for This Video";
    NSString *allVideosTitle = currentlyHidden ? @"Show for All Videos" : @"Hide for All Videos";

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:thisVideoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf setElementsHiddenState:!currentlyHidden sender:sender];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:allVideosTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:!currentlyHidden forKey:@"hide_elements_globally"];
        [weakSelf setElementsHiddenState:!currentlyHidden sender:sender];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (is_iPad()) {
        sheet.popoverPresentationController.sourceView = sender;
        sheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    [topMostController() presentViewController:sheet animated:true completion:nil];
}

%new - (void)downloaderProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHIManager getDownloadingPersent:progress];
}
%new - (void)downloaderDidFinishDownloadingAllFiles:(NSMutableArray<NSURL *> *)downloadedFilePaths {
    [self.hud dismiss];
    if ([BHIManager shareSheet]) {
        [BHIManager showSaveVC:downloadedFilePaths];
    }
    else {

        for (NSURL *url in downloadedFilePaths) {
            NSString *ext = InfinitokDownloadedFileExtension(url.pathExtension, url, self.fileextension) ?: @"jpeg";
            [BHIManager saveMedia:url fileExtension:ext];
        }
    }
}
%new - (void)downloaderDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
        if (error.code != 999) {
            [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"Download failed. Please try again." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
        }
    }
}
%new - (void)downloadProgress:(float)progress {
        self.hud.tapOutsideBlock = ^(JGProgressHUD * _Nonnull HUD) {
        self.hud.textLabel.text = @"Backgrounding ✌️";
        [self.hud dismissAfterDelay:0.4];
    };
    self.progressView.progress = progress;
    self.hud.detailTextLabel.text = [BHIManager getDownloadingPersent:progress];
}
%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];

    NSString *ext = InfinitokDownloadedFileExtension(fileName, self.pendingPhotoSourceURLs.firstObject, self.fileextension) ?: self.fileextension;

    NSString *builtFilename = (self.isVideoDownload && self.pendingVideoFilename.length > 0)
        ? self.pendingVideoFilename
        : [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:builtFilename];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    self.isVideoDownload = false;
    self.pendingVideoFilename = nil;
    self.pendingPhotoSourceURLs = nil;
    [self.hud dismiss];
    InfinitokSaveDownloadedFile(newFilePath, ext);
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
        if (error.code != 999) {
            [%c(AWEUIAlertView) showAlertWithTitle:@"Infinitok" description:@"Download failed. Please try again." image:nil actionButtonTitle:@"OK" cancelButtonTitle:nil actionBlock:nil cancelBlock:nil];
        }
    }
}
%end

%hook TTKProfileViewsVisitor
- (void)reportProfileView {
    if ([BHIManager visitProfilesPrivately]) {
        return;
    }
    %orig;
}
%end

%hook TTKStoryNetworkService
+ (void)reportStoryViewedWithStoryID:(NSString *)storyID uid:(NSString *)uid completion:(id)completion {
    if ([BHIManager watchStoriesAnonymously]) {
        return;
    }
    %orig;
}
+ (void)reportStoryViewedWithStoryID:(NSString *)storyID uid:(NSString *)uid unlocked:(BOOL)unlocked completion:(id)completion {
    if ([BHIManager watchStoriesAnonymously]) {
        return;
    }
    %orig;
}
%end

%hook TTKStoryMarkReadService
- (void)markAsRead:(id)arg1 {
    if ([BHIManager watchStoriesAnonymously]) {
        return;
    }
    %orig;
}
%end

%hook TIMMessageMarkAsReadOperator
- (void)markAsRead:(id)arg1 {
    if ([BHIManager readChatsAnonymously]) {
        return;
    }
    %orig;
}
%end

%hook AWEIMMessageReadComponent
- (void)p_markReadSyncToServerWithMessage:(id)message {
    if ([BHIManager readChatsAnonymously]) {
        return;
    }
    %orig;
}
%end

%hook TIMInputStatusManager
- (void)sendInputStatusWithConversationID:(id)conversationID inputStatus:(NSInteger)inputStatus {
    if ([BHIManager hideTypingIndicator]) {
        return;
    }
    %orig;
}
%end

%hook TIMOMessage
- (BOOL)isRecalled {
    BOOL orig = %orig;
    if ([BHIManager antiDeleteMessages]) {
        if (orig) {
            ITDebug("anti-delete", @"isRecalled suppressed (orig=YES) for message %p", self);
        }
        return NO;
    }
    return orig;
}
- (id)content {
    if ([BHIManager antiDeleteMessages]) {
        id cached = objc_getAssociatedObject(self, @selector(content));
        if (cached) {
            return cached;
        }

    }
    id value = %orig;
    if ([BHIManager antiDeleteMessages] && value) {
        objc_setAssociatedObject(self, @selector(content), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return value;
}
%end

%hook TIMMessageDeleter
- (void)commitDeleteForMessageID:(NSString *)messageID conversationID:(NSString *)conversationID expectedDeleteToken:(id)expectedDeleteToken initiatingUserID:(NSString *)initiatingUserID sendToServer:(BOOL)sendToServer {
    if ([BHIManager antiDeleteMessages]) {
        ITDebug("anti-delete", @"commitDeleteForMessageID:%@ suppressed", messageID);
        return;
    }
    %orig;
}
%end
%hook TIMMessageUpdater
- (void)localMarkMessageAsRecalledWithMessageID:(NSString *)messageID conversationID:(NSString *)conversationID recallUID:(NSString *)recallUID completion:(id)completion {
    if ([BHIManager antiDeleteMessages]) {
        id dynamicSelf = self;
        SEL keepContentSel = @selector(localMarkMessageAsRecalledKeepContentWithMessageID:conversationID:recallUID:completion:);
        if ([dynamicSelf respondsToSelector:keepContentSel]) {
            ITDebug("anti-delete", @"localMarkMessageAsRecalledWithMessageID:%@ redirected to the keep-content variant", messageID);
            NSMethodSignature *sig = [dynamicSelf methodSignatureForSelector:keepContentSel];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
            invocation.selector = keepContentSel;
            invocation.target = dynamicSelf;
            [invocation setArgument:&messageID atIndex:2];
            [invocation setArgument:&conversationID atIndex:3];
            [invocation setArgument:&recallUID atIndex:4];
            [invocation setArgument:&completion atIndex:5];
            [invocation invoke];
            return;
        }
        ITDebug("anti-delete", @"%@ does not respond to the keep-content variant, falling back to original (content will still be cleared)", NSStringFromClass([dynamicSelf class]));
    }
    %orig;
}
- (void)permanentlyClearRecalledContentForMessageID:(NSString *)messageID conversationID:(NSString *)conversationID {
    if ([BHIManager antiDeleteMessages]) {
        ITDebug("anti-delete", @"permanentlyClearRecalledContentForMessageID:%@ suppressed", messageID);
        return;
    }
    %orig;
}
%end

%hook AWEIMMessageListViewController
- (void)willDeleteMessage:(id)message {
    if ([BHIManager dmDeleteConfirmation]) {
        showConfirmation(^{
            %orig;
        });
        return;
    }
    %orig;
}
%end

%hook AWEIMConversationController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([BHIManager lockChats] && !InfinitokChatsUnlocked) {
        SecurityViewController *securityViewController = [SecurityViewController new];
        securityViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self presentViewController:securityViewController animated:YES completion:nil];
        InfinitokChatsUnlocked = YES;
    }
}
%end

%hook AWEFavoriteAwemeViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([BHIManager lockFavorites] && !InfinitokFavoritesUnlocked) {
        SecurityViewController *securityViewController = [SecurityViewController new];
        securityViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self presentViewController:securityViewController animated:YES completion:nil];
        InfinitokFavoritesUnlocked = YES;
    }
}
%end

%hook AWEFeedRootViewController
- (void)handleTabBarSelectedRefresh {
    if ([BHIManager disableFeedRefresh]) {
        return;
    }
    %orig;
}
%end
%hook TTKFeedRootViewController
- (void)handleTabBarSelectedRefresh {
    if ([BHIManager disableFeedRefresh]) {
        return;
    }
    %orig;
}
%end

%hook AWEUserService

- (BOOL)canShowThirdPartyPhoneBindingPopup {
    if ([BHIManager disablePhoneBindingPopup]) {
        return NO;
    }
    return %orig;
}
- (BOOL)canShowThirdPartyPhoneBindingPopupForPage:(NSInteger)page {
    if ([BHIManager disablePhoneBindingPopup]) {
        return NO;
    }
    return %orig(page);
}
%end

%hook AWESettingLoginOrSwitchCellPlugin
- (void)didTapLogoutOneClickLogin {
    if ([BHIManager fastLogout]) {
        NSArray *candidateSelectors = @[@"performLogout", @"logout", @"confirmLogout", @"doLogout"];
        for (NSString *name in candidateSelectors) {
            SEL sel = NSSelectorFromString(name);
            if ([self respondsToSelector:sel]) {
                [self performSelector:sel];
                return;
            }
        }
    }
    %orig;
}
- (void)didTapLogoutSettingItem {
    if ([BHIManager fastLogout]) {
        NSArray *candidateSelectors = @[@"performLogout", @"logout", @"confirmLogout", @"doLogout"];
        for (NSString *name in candidateSelectors) {
            SEL sel = NSSelectorFromString(name);
            if ([self respondsToSelector:sel]) {
                [self performSelector:sel];
                return;
            }
        }
    }
    %orig;
}
%end

%hook TTKRichContentDetailViewController
- (void)viewDidLoad {
    %orig;
    InfinitokAddStoryDownloadButton(self);
    InfinitokAddStoryViewCountLabel(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *b = [self.view viewWithTag:997];
    if (b) [self.view bringSubviewToFront:b];
}
%end
%hook AWEURLModel
%new - (NSString *)bestURLtoDownloadFormat {
    NSString *bestURLFormat;
    for (NSString *url in self.originURLList) {
        if ([url containsString:@"video_mp4"]) {
            bestURLFormat = @"mp4";
        } else if ([url containsString:@".jpeg"] || [url containsString:@".jpg"]) {
            bestURLFormat = @"jpeg";
        } else if ([url containsString:@".png"]) {
            bestURLFormat = @"png";
        } else if ([url containsString:@".webp"]) {
            bestURLFormat = @"webp";
        } else if ([url containsString:@".heic"] || [url containsString:@".heif"]) {
            bestURLFormat = @"heic";
        } else if ([url containsString:@".mp3"]) {
            bestURLFormat = @"mp3";
        } else if ([url containsString:@".m4a"]) {
            bestURLFormat = @"m4a";
        }
    }

    if (bestURLFormat == nil) {
        bestURLFormat = InfinitokURLExtensionFromPath(self.originURLList.firstObject) ?: @"mp4";
    }

    return bestURLFormat;
}
%new - (NSURL *)bestURLtoDownload {
    NSURL *bestURL;

    for (NSString *url in self.originURLList) {
        if ([url containsString:@"video_mp4"]) {
            bestURL = [NSURL URLWithString:url];
        }
    }
    for (NSString *url in self.originURLList) {
        if ([url containsString:@".jpeg"] || [url containsString:@".jpg"] || [url containsString:@".png"]) {
            bestURL = [NSURL URLWithString:url];
        }
    }
    for (NSString *url in self.originURLList) {
        if ([url containsString:@".mp3"]) {
            bestURL = [NSURL URLWithString:url];
        }
    }

    if (bestURL == nil) {
        bestURL = [NSURL URLWithString:[self.originURLList firstObject]];
    }

    return bestURL;
}
%end

%hook TTKFeedFYPBottomRightTakoEntranceComponent
- (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(NSString *)referString playlistPreviousPage:(id)playlistPreviousPage {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked shouldShowTakoEntrance... on TTKFeedFYPBottomRightTakoEntranceComponent");
        return NO;
    }
    return %orig;
}
- (BOOL)isTakoEntranceCurrentlyShown {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked isTakoEntranceCurrentlyShown on TTKFeedFYPBottomRightTakoEntranceComponent");
        return NO;
    }
    return %orig;
}
- (void)componentMount {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked componentMount on TTKFeedFYPBottomRightTakoEntranceComponent");
        return;
    }
    %orig;
}
%end
%hook TTKFeedRightTakoElement
- (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(NSString *)referString playlistPreviousPage:(id)playlistPreviousPage {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked shouldShowTakoEntrance... on TTKFeedRightTakoElement");
        return NO;
    }
    return %orig;
}
- (BOOL)isTakoEntranceCurrentlyShown {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked isTakoEntranceCurrentlyShown on TTKFeedRightTakoElement");
        return NO;
    }
    return %orig;
}
%end

static const void *InfinitokTakoMarkerKey(void) {
    static const char key = 0;
    return &key;
}

%hook FeedTabCornerTakoItem
- (BOOL)canShowWithPosition:(NSInteger)position {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked canShowWithPosition: on FeedTabCornerTakoItem");
        return NO;
    }
    return %orig;
}
- (UIView *)customView {
    UIView *view = %orig;
    if ([BHIManager hideTakoButton] && view) {
        ITDebug("tako", @"force-hid customView on FeedTabCornerTakoItem");
        view.hidden = true;
        view.alpha = 0;

        objc_setAssociatedObject(view, InfinitokTakoMarkerKey(), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}
%end

%hook TTKFeedDetailTakoButton
- (void)componentMount {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked componentMount on TTKFeedDetailTakoButton");
        return;
    }
    %orig;
}
- (void)loadComponentView {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked loadComponentView on TTKFeedDetailTakoButton");
        return;
    }
    %orig;
}
%end

%hook TikTokTakoService
+ (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(NSString *)referString playlistPreviousPage:(id)playlistPreviousPage {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked shouldShowTakoEntrance... on TikTokTakoService");
        return NO;
    }
    return %orig;
}
+ (BOOL)shouldShowTakoEntranceForGeneralCondition {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked shouldShowTakoEntranceForGeneralCondition on TikTokTakoService");
        return NO;
    }
    return %orig;
}
+ (BOOL)shouldShowFYPTabOrSearchInflowTakoEntrance {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked shouldShowFYPTabOrSearchInflowTakoEntrance on TikTokTakoService");
        return NO;
    }
    return %orig;
}
+ (BOOL)enableTakoEntranceFlag {
    if ([BHIManager hideTakoButton]) {
        ITDebug("tako", @"blocked enableTakoEntranceFlag on TikTokTakoService");
        return NO;
    }
    return %orig;
}
%end

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if ([BHIManager hideTakoButton] && self.window) {
        NSString *className = NSStringFromClass([self class]);
        BOOL matchesByName = [className rangeOfString:@"tako" options:NSCaseInsensitiveSearch].location != NSNotFound;
        BOOL matchesByMarker = [objc_getAssociatedObject(self, InfinitokTakoMarkerKey()) boolValue];
        if (matchesByName || matchesByMarker) {
            ITDebug("tako", @"force-hid %@ view %@", matchesByMarker ? @"marked" : @"stray", className);
            self.hidden = true;
            self.alpha = 0;
        }
    }
}
%end

%hook NSFileManager
-(BOOL)fileExistsAtPath:(id)arg1 {
	for (NSString *file in jailbreakPaths) {
		if ([arg1 isEqualToString:file]) {
			return NO;
		}
	}
	return %orig;
}
-(BOOL)fileExistsAtPath:(id)arg1 isDirectory:(BOOL*)arg2 {
	for (NSString *file in jailbreakPaths) {
		if ([arg1 isEqualToString:file]) {
			return NO;
		}
	}
	return %orig;
}
%end
%hook BDADeviceHelper
+(bool)isJailBroken {
	return NO;
}
%end

%hook UIDevice
+(bool)btd_isJailBroken {
	return NO;
}
%end

%hook TTInstallUtil
+(bool)isJailBroken {
	return NO;
}
%end

%hook AppsFlyerUtils
+(bool)isJailbrokenWithSkipAdvancedJailbreakValidation:(bool)arg2 {
	return NO;
}
%end

%hook PIPOIAPStoreManager
-(bool)_pipo_isJailBrokenDeviceWithProductID:(id)arg2 orderID:(id)arg3 {
	return NO;
}
%end

%hook IESLiveDeviceInfo
+(bool)isJailBroken {
	return NO;
}
%end

%hook PIPOStoreKitHelper
-(bool)isJailBroken {
	return NO;
}
%end

%hook BDInstallNetworkUtility
+(bool)isJailBroken {
	return NO;
}
%end

%hook TTAdSplashDeviceHelper
+(bool)isJailBroken {
	return NO;
}
%end

%hook GULAppEnvironmentUtil
+(bool)isFromAppStore {
	return YES;
}
+(bool)isAppStoreReceiptSandbox {
	return NO;
}
+(bool)isAppExtension {
	return YES;
}
%end

%hook FBSDKAppEventsUtility
+(bool)isDebugBuild {
	return NO;
}
%end

%hook AWEAPMManager
+(id)signInfo {
	return @"AppStore";
}
%end

%hook NSBundle
-(id)pathForResource:(id)arg1 ofType:(id)arg2 {
	if ([arg2 isEqualToString:@"mobileprovision"]) {
		return nil;
	}
	return %orig;
}
%end
%hook AWESecurity
- (void)resetCollectMode {
	return;
}
%end
%hook MSManagerOV
- (id)setMode {
	return (id (^)(id)) ^{
	};
}
%end

%hook MSConfigOV
- (id)setMode {
	return (id (^)(id)) ^{
	};
}
%end

static BOOL InfinitokFirstTime(NSString *key);
static void InfinitokForceBoolSelectorExcludingReceivers(NSString *selectorName, NSSet<NSString *> *excludedReceiverClassNames, BOOL (^shouldForce)(void)) {
    SEL sel = NSSelectorFromString(selectorName);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    unsigned int patchedCount = 0;
    for (unsigned int i = 0; i < classCount && patchedCount < kInfinitokMaxSelectorScanPatches; i++) {
        Class cls = classes[i];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        BOOL declaresIt = NO;
        for (unsigned int m = 0; m < methodCount; m++) {
            if (method_getName(methods[m]) == sel) {
                declaresIt = YES;
                break;
            }
        }
        free(methods);
        if (!declaresIt) {
            continue;
        }
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) {
            continue;
        }
        __block IMP orig = NULL;
        IMP replacement = imp_implementationWithBlock(^BOOL(id self) {
            BOOL was = orig ? ((BOOL (*)(id, SEL))orig)(self, sel) : NO;

            NSString *receiverName = NSStringFromClass([self class]);
            if (excludedReceiverClassNames && ([excludedReceiverClassNames containsObject:receiverName] ||
                ([excludedReceiverClassNames containsObject:@"*Profile*"] && [receiverName containsString:@"Profile"] && ![receiverName containsString:@"Adaptation"]))) {
                if (InfinitokFirstTime([NSString stringWithFormat:@"ex|%@|%@|%d", selectorName, receiverName, was])) ITDebug("landscape", @"%@ queried by excluded receiver %@ — left stock (orig=%d)", selectorName, receiverName, was);
                return was;
            }
            BOOL force = shouldForce();
            if (InfinitokFirstTime([NSString stringWithFormat:@"gq|%@|%@|%d|%d", NSStringFromClass([self class]), selectorName, was, force])) ITDebug("experiments", @"[%@ %@] orig=%d forced=%d", NSStringFromClass([self class]), selectorName, was, force);
            return force ? YES : was;
        });
        orig = method_setImplementation(method, replacement);
        patchedCount++;
    }
    free(classes);
    if (patchedCount >= kInfinitokMaxSelectorScanPatches) {
        ITError("experiments", @"%@ hit the %u-match patch cap — this selector name matches far more classes than expected, stopping early", selectorName, kInfinitokMaxSelectorScanPatches);
    } else {
        ITDebug("experiments", @"%@ patched on %u class(es)", selectorName, patchedCount);
    }
}

static void InfinitokForceBoolSelectorEverywhere(NSString *selectorName, BOOL (^shouldForce)(void)) {
    InfinitokForceBoolSelectorExcludingReceivers(selectorName, nil, shouldForce);
}

static void InfinitokForceIntegerSelectorEverywhere(NSString *selectorName, NSInteger forcedValue, BOOL (^shouldForce)(void)) {
    SEL sel = NSSelectorFromString(selectorName);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    unsigned int patchedCount = 0;
    for (unsigned int i = 0; i < classCount && patchedCount < kInfinitokMaxSelectorScanPatches; i++) {
        Class cls = classes[i];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        BOOL declaresIt = NO;
        for (unsigned int m = 0; m < methodCount; m++) {
            if (method_getName(methods[m]) == sel) {
                declaresIt = YES;
                break;
            }
        }
        free(methods);
        if (!declaresIt) {
            continue;
        }
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) {
            continue;
        }
        __block IMP orig = NULL;
        IMP replacement = imp_implementationWithBlock(^NSInteger(id self) {
            NSInteger was = orig ? ((NSInteger (*)(id, SEL))orig)(self, sel) : 0;
            BOOL force = shouldForce();
            ITDebug("experiments", @"[%@ %@] orig=%ld forced=%@", NSStringFromClass([self class]), selectorName, (long)was, force ? [NSString stringWithFormat:@"%ld", (long)forcedValue] : @"no");
            return force ? forcedValue : was;
        });
        orig = method_setImplementation(method, replacement);
        patchedCount++;
    }
    free(classes);
    if (patchedCount >= kInfinitokMaxSelectorScanPatches) {
        ITError("experiments", @"%@ hit the %u-match patch cap — this selector name matches far more classes than expected, stopping early", selectorName, kInfinitokMaxSelectorScanPatches);
    } else {
        ITDebug("experiments", @"%@ patched on %u class(es)", selectorName, patchedCount);
    }
}

%hook AWEIMConfigManager
- (BOOL)isVoiceMessageEntranceEnabled {
    if ([BHIManager enableVoiceMessages]) {
        return YES;
    }
    return %orig;
}
%end

static void InfinitokForceIntegerSetterEverywhere(NSString *selectorName, NSInteger forcedValue, BOOL (^shouldForce)(void)) {
    SEL sel = NSSelectorFromString(selectorName);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    unsigned int patchedCount = 0;
    for (unsigned int i = 0; i < classCount && patchedCount < kInfinitokMaxSelectorScanPatches; i++) {
        Class cls = classes[i];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        BOOL declaresIt = NO;
        for (unsigned int m = 0; m < methodCount; m++) {
            if (method_getName(methods[m]) == sel) { declaresIt = YES; break; }
        }
        free(methods);
        if (!declaresIt) continue;
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) continue;
        __block IMP orig = NULL;
        IMP replacement = imp_implementationWithBlock(^(id self, NSInteger value) {
            NSInteger stored = shouldForce() ? forcedValue : value;
            ITDebug("experiments", @"[%@ %@%ld] storing %ld", NSStringFromClass([self class]), selectorName, (long)value, (long)stored);
            if (orig) ((void (*)(id, SEL, NSInteger))orig)(self, sel, stored);
        });
        orig = method_setImplementation(method, replacement);
        patchedCount++;
    }
    free(classes);
    ITDebug("experiments", @"%@ (setter) patched on %u class(es)", selectorName, patchedCount);
}

static void InfinitokForceBoolClassSelectorEverywhere(NSString *selectorName, BOOL (^shouldForce)(void)) {
    SEL sel = NSSelectorFromString(selectorName);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    unsigned int patchedCount = 0;
    for (unsigned int i = 0; i < classCount && patchedCount < kInfinitokMaxSelectorScanPatches; i++) {
        Class meta = object_getClass(classes[i]);
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(meta, &methodCount);
        Method found = NULL;
        for (unsigned int m = 0; m < methodCount; m++) {
            if (method_getName(methods[m]) == sel) { found = methods[m]; break; }
        }
        free(methods);
        if (!found) continue;
        __block IMP orig = NULL;
        IMP replacement = imp_implementationWithBlock(^BOOL(id self) {
            BOOL was = orig ? ((BOOL (*)(id, SEL))orig)(self, sel) : NO;
            BOOL force = shouldForce();
            ITDebug("experiments", @"[+%@ %@] orig=%d forced=%d", NSStringFromClass(self), selectorName, was, force);
            return force ? NO : was;
        });
        orig = method_setImplementation(found, replacement);
        patchedCount++;
    }
    free(classes);
    ITDebug("experiments", @"%@ (class method) patched on %u class(es)", selectorName, patchedCount);
}

static void InfinitokForceRemoveAccountLimit(void) {

    if (![BHIManager removeAccountLimit]) {
        return;
    }

    InfinitokForceBoolClassSelectorEverywhere(@"isForbiddenByAccountLimitRule", ^BOOL{ return [BHIManager removeAccountLimit]; });
    InfinitokForceIntegerSetterEverywhere(@"setMaxLoginedAccounts:", 99, ^BOOL{ return [BHIManager removeAccountLimit]; });
    for (NSString *getter in @[@"maxLoginedAccounts", @"maxAccountNumber", @"maxCountOfMultiLoginAccount"]) {
        InfinitokForceIntegerSelectorEverywhere(getter, 99, ^BOOL{ return [BHIManager removeAccountLimit]; });
    }
}

%hook AWEABTestManager
+ (BOOL)boolValueForKey:(NSString *)key defaultValue:(BOOL)defaultValue {
    static NSSet<NSString *> *profileKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        profileKeys = [NSSet setWithArray:@[
            @"ProfileUIRedesign", @"ProfileRedesign", @"ProfilePageRedesign",
            @"ProfileV2", @"ProfileNewEntrance", @"ProfileViewNew",
        ]];
    });

    if (InfinitokDebugLoggingEnabled() && key.length) {
        static NSMutableSet<NSString *> *seenKeys;
        static dispatch_once_t seenOnce;
        dispatch_once(&seenOnce, ^{ seenKeys = [NSMutableSet set]; });
        NSString *lower = key.lowercaseString;
        if ([lower containsString:@"repost"] || [lower containsString:@"profile"] || [lower containsString:@"landscape"]) {
            BOOL firstSighting;
            @synchronized (seenKeys) {
                firstSighting = ![seenKeys containsObject:key];
                if (firstSighting) [seenKeys addObject:key];
            }
            if (firstSighting) {
                ITDebug("experiments", @"AWEABTestManager boolValueForKey: saw key '%@' (default=%d)", key, defaultValue);
            }
        }
    }
    if ([BHIManager forceNewProfileUI] && key && [profileKeys containsObject:key]) {
        ITDebug("experiments", @"AWEABTestManager boolValueForKey:%@ forced=YES (profile UI)", key);
        return YES;
    }
    return %orig;
}
%end

static __thread BOOL sInfinitokResolvingProfileBackground;

static BOOL InfinitokReturnTypeIsOneOf(Method m, const char *allowed) {
    char *rt = method_copyReturnType(m);
    BOOL ok = rt && rt[0] && strchr(allowed, rt[0]) != NULL;
    free(rt);
    return ok;
}

static IMP InfinitokInstallProfileHook(Class cls, SEL sel, const char *returnTypes, id replacementBlock) {
    if (!cls || !sel) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { ITDebug("profilebg", @"%@ missing-method %@", NSStringFromClass(cls), NSStringFromSelector(sel)); return NULL; }
    if (method_getNumberOfArguments(m) != 2 || !InfinitokReturnTypeIsOneOf(m, returnTypes)) {
        ITDebug("profilebg", @"%@ %@ incompatible-signature", NSStringFromClass(cls), NSStringFromSelector(sel));
        return NULL;
    }
    IMP orig = method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(replacementBlock);
    BOOL declaredHere = NO;
    unsigned int n = 0;
    Method *list = class_copyMethodList(cls, &n);
    for (unsigned int i = 0; i < n; i++) {
        if (method_getName(list[i]) == sel) { declaredHere = YES; break; }
    }
    free(list);
    if (declaredHere) {
        method_setImplementation(m, replacement);
    } else if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(m))) {
        imp_removeBlock(replacement);
        return NULL;
    }
    ITDebug("profilebg", @"%@ %@ installed", NSStringFromClass(cls), NSStringFromSelector(sel));
    return orig;
}

static void InfinitokInstallProfileBackgroundHooks(void) {

    {
        Class abTest = objc_getClass("TTKABTest");
        SEL sel = NSSelectorFromString(@"profileBgInAllowList");
        __block IMP orig = NULL;
        orig = InfinitokInstallProfileHook(abTest ? object_getClass(abTest) : Nil, sel, "qQlLiIBcC", ^NSInteger(id self) {
            if ([BHIManager profileBackgroundEnabled]) return 1;
            return orig ? ((NSInteger (*)(id, SEL))orig)(self, sel) : 0;
        });
    }

    {
        Class model = objc_getClass("TTKProfileComponentResponseModel");
        SEL sel = NSSelectorFromString(@"profileBackground");
        __block IMP orig = NULL;
        orig = InfinitokInstallProfileHook(model, sel, "@", ^id(id self) {
            id result = orig ? ((id (*)(id, SEL))orig)(self, sel) : nil;
            if (result || !sInfinitokResolvingProfileBackground || ![BHIManager profileBackgroundEnabled]) {
                return result;
            }
            Class base = objc_getClass("TTKProfileBaseComponentModel");
            if (!base || ![base instancesRespondToSelector:@selector(setBizData:)]) return result;
            id blank = [[base alloc] init];
            if (!blank) return result;
            [blank setBizData:@{ @"profile_bg_info": @{} }];
            return blank;
        });
    }

    {
        Class editor = objc_getClass("TIKTOKProfileEditMainViewController");
        SEL sel = NSSelectorFromString(@"p_resolveProfileBackgroundSnapshot");
        __block IMP orig = NULL;
        orig = InfinitokInstallProfileHook(editor, sel, "v", ^(id self) {
            BOOL previous = sInfinitokResolvingProfileBackground;
            sInfinitokResolvingProfileBackground = YES;
            @try {
                if (orig) ((void (*)(id, SEL))orig)(self, sel);
            } @finally {
                sInfinitokResolvingProfileBackground = previous;
            }
        });
    }
}

static IMP InfinitokReplaceInstance(Class cls, SEL sel, id block);
static BOOL InfinitokFirstTime(NSString *key) {
    static NSMutableSet *seen; static NSLock *lock; static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet set]; lock = [NSLock new]; });
    [lock lock]; BOOL fresh = ![seen containsObject:key]; if (fresh) [seen addObject:key]; [lock unlock];
    return fresh;
}

static void InfinitokTrace(NSString *tag, NSString *cn, NSString *sn, BOOL meta) {
    Class c = NSClassFromString(cn);
    Class target = meta && c ? object_getClass(c) : c;
    SEL sel = NSSelectorFromString(sn);
    Method m = target ? class_getInstanceMethod(target, sel) : NULL;
    if (!m) { ITLog("trace", @"[%@] %@ %@ missing", tag, cn, sn); return; }
    char *rt = method_copyReturnType(m); char t = rt ? rt[0] : 0; if (rt) free(rt);
    if (!strchr("BcqQlLiI@v", t)) { ITLog("trace", @"[%@] %@ %@ skipped (return type %c)", tag, cn, sn, t); return; }
    NSString *tg = [tag copy];
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(target, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6) {
        uintptr_t r = orig ? ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, a1, a2, a3, a4, a5, a6) : 0;
        uintptr_t shown = (t == 'B' || t == 'c') ? (r & 0xff) : r;
        NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%lu", tg, cn, sn, (t == '@' || t == 'v') ? 0UL : (unsigned long)shown];
        if (InfinitokFirstTime(key)) ITDebug("trace", @"[%@] %@%@ %@ called on %@ args=%p,%p ret=%@", tg, meta ? @"+" : @"-", cn, sn, NSStringFromClass([self_ class]), (void *)a1, (void *)a2, t == '@' ? (r ? NSStringFromClass([(__bridge id)(void *)r class]) : @"nil") : (t == 'v' ? @"void" : [NSString stringWithFormat:@"%lu", (unsigned long)shown]));
        return r;
    });
    ITLog("trace", @"[%@] tracing %@%@ %@", tag, meta ? @"+" : @"-", cn, sn);
}

static void InfinitokForceABClassMethod(NSString *selectorName, NSInteger value, BOOL (^enabled)(void)) {
    Class abTest = objc_getClass("TTKABTest");
    SEL sel = NSSelectorFromString(selectorName);
    __block IMP orig = NULL;
    orig = InfinitokInstallProfileHook(abTest ? object_getClass(abTest) : Nil, sel, "qQlLiIBcC", ^NSInteger(id self) {
        NSInteger was = orig ? ((NSInteger (*)(id, SEL))orig)(self, sel) : 0;
        BOOL f = enabled();
        if (InfinitokFirstTime([NSString stringWithFormat:@"ab|%@|%ld|%d", selectorName, (long)was, f])) ITDebug("experiments", @"AB +%@ queried: orig=%ld forced=%@", selectorName, (long)was, f ? [NSString stringWithFormat:@"%ld", (long)value] : @"no");
        return f ? value : was;
    });
    ITDebug("experiments", @"TTKABTest +%@ %@", selectorName, orig ? @"hooked" : @"NOT hooked (class/selector missing or signature mismatch)");
}

static void InfinitokForceBoolMethod(NSString *clsName, NSString *selName, BOOL meta, BOOL (^gate)(void)) {
    Class cls = NSClassFromString(clsName);
    if (!cls) { ITDebug("landscape", @"pad gate: class %@ missing", clsName); return; }
    SEL sel = NSSelectorFromString(selName);
    Class target = meta ? object_getClass(cls) : cls;
    Method m = class_getInstanceMethod(target, sel);
    if (!m) { ITDebug("landscape", @"pad gate: %@ %@ missing", clsName, selName); return; }
    char *rt = method_copyReturnType(m);
    BOOL ok = rt && (rt[0] == 'B' || rt[0] == 'c');
    if (rt) free(rt);
    if (!ok) { ITDebug("landscape", @"pad gate: %@ %@ is not BOOL-returning", clsName, selName); return; }
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(target, sel, ^BOOL(id self_) {
        BOOL was = orig ? ((BOOL (*)(id, SEL))orig)(self_, sel) : NO;
        BOOL f = gate();
        if (InfinitokFirstTime([NSString stringWithFormat:@"gate|%@|%@|%d|%d", clsName, selName, was, f])) ITDebug("landscape", @"gate %@ %@ queried: orig=%d forced=%d", clsName, selName, was, f);
        return f ? YES : was;
    });
    ITDebug("landscape", @"pad gate forced: %@ %@", clsName, selName);
}

static void InfinitokLGDump(UIView *v, int depth, NSMutableString *out) {
    if (depth > 4) return;
    for (UIView *sv in v.subviews) {
        [out appendFormat:@"%*s%@ %@ r=%.0f\n", depth * 2, "", NSStringFromClass([sv class]), NSStringFromCGRect(sv.frame), sv.layer.cornerRadius];
        InfinitokLGDump(sv, depth + 1, out);
    }
}

static BOOL InfinitokIsGlassBar(UIView *bar) {
    for (UIView *sv in bar.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        if ([cn containsString:@"_UITabBarItemPlatterView"] || [cn containsString:@"UILiquidLensView"] || [cn containsString:@"VisualProvider_Floating"]) return YES;
        for (UIView *s2 in sv.subviews) {
            NSString *c2 = NSStringFromClass([s2 class]);
            if ([c2 containsString:@"UILiquidLensView"] || [c2 containsString:@"VisualProvider_Floating"]) return YES;
        }
    }
    return NO;
}
static const CGFloat kInfinitokPhoneBarWidth = 440.0;
static CGRect InfinitokPhoneSizedBarFrame(CGRect f) {
    if (f.size.width > kInfinitokPhoneBarWidth + 20) {
        f.origin.x += (f.size.width - kInfinitokPhoneBarWidth) / 2.0;
        f.size.width = kInfinitokPhoneBarWidth;
    }
    return f;
}

static __weak UIView *sInfinitokLastSelBtn;
static CFAbsoluteTime sInfinitokIndTime;
static BOOL sInfinitokInIndicator;
static void InfinitokLGWinDump(UIView *v, int depth, UIWindow *w, NSMutableString *out) {
    if (depth > 14) return;
    for (UIView *sv in v.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        BOOL hit = [cn containsString:@"Tab"] || [cn containsString:@"Lens"] || [cn containsString:@"Platter"] || [cn containsString:@"Selection"] || [cn containsString:@"Glass"];
        if (hit) [out appendFormat:@"%*s%@ win=%@ hidden=%d alpha=%.2f\n", depth, "", cn, NSStringFromCGRect([sv convertRect:sv.bounds toView:w]), sv.hidden, sv.alpha];
        InfinitokLGWinDump(sv, depth + 1, w, out);
    }
}
static void InfinitokLGScheduleWinDump(UIView *bar) {
    for (NSNumber *delay in @[@10, @30]) {
        if (!InfinitokFirstTime([NSString stringWithFormat:@"lg|win|%@", delay])) continue;
        __weak UIView *wb = bar;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.intValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *b = wb; UIWindow *w = b.window; if (!w) return;
            NSMutableString *d = [NSMutableString stringWithFormat:@"window dump +%@s: bar=%@ window=%@ items=%lu selectedIdx=%ld\n", delay, NSStringFromCGRect([b convertRect:b.bounds toView:w]), NSStringFromCGRect(w.bounds), (unsigned long)([b isKindOfClass:[UITabBar class]] ? ((UITabBar *)b).items.count : 0), (long)([b isKindOfClass:[UITabBar class]] && ((UITabBar *)b).selectedItem ? [((UITabBar *)b).items indexOfObject:((UITabBar *)b).selectedItem] : -1)];
            InfinitokLGWinDump(w, 0, w, d);
            ITLog("glassbar", @"%@", d);
        });
    }
}
static void InfinitokLGCollectButtons(UIView *v, int depth, NSMutableArray *out) {
    if (depth > 3) return;
    for (UIView *sv in v.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        if ([cn containsString:@"TabBarButton"] || [cn containsString:@"TabBarPlusButton"]) { [out addObject:sv]; continue; }
        InfinitokLGCollectButtons(sv, depth + 1, out);
    }
}

static UIView *InfinitokFindLens(UIView *v, int depth) {
    if (depth > 4) return nil;
    for (UIView *sv in v.subviews) {
        if ([NSStringFromClass([sv class]) isEqualToString:@"_UILiquidLensView"]) return sv;
        UIView *r = InfinitokFindLens(sv, depth + 1); if (r) return r;
    }
    return nil;
}
static void InfinitokHideNativePlatters(UIView *v, int depth) {
    if (depth > 3) return;
    for (UIView *sv in v.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        if ([cn containsString:@"_UITabBarItemPlatterView"]) {

            static Class hooked = Nil;
            if (!hooked) {
                hooked = object_getClass(sv);
                SEL sa = NSSelectorFromString(@"setAlpha:");
                __block IMP ao = NULL;
                ao = InfinitokReplaceInstance(hooked, sa, ^(UIView *pv, CGFloat a) {
                    NSString *sc = NSStringFromClass([pv.superview class]);
                    if ([sc isEqualToString:@"TTKFakeTabBar"] || [sc isEqualToString:@"TTKTabBar"]) a = 0;
                    if (ao) ((void (*)(id, SEL, CGFloat))ao)(pv, sa, a);
                });
                SEL sh = NSSelectorFromString(@"setHidden:");
                __block IMP ho = NULL;
                ho = InfinitokReplaceInstance(hooked, sh, ^(UIView *pv, BOOL h) {
                    if (ho) ((void (*)(id, SEL, BOOL))ho)(pv, sh, h);
                });
                ITLog("glassbar", @"pinned native platter alpha (%@)", NSStringFromClass(hooked));
            }
            if (sv.alpha != 0) sv.alpha = 0;
            continue;
        }
        InfinitokHideNativePlatters(sv, depth + 1);
    }
}
static void InfinitokHideLensWide(UIView *v, UIWindow *w, CGRect barRect, int depth, NSMutableString *dump) {
    if (depth > 12) return;
    for (UIView *sv in v.subviews) {
        if (sv.tag == 0x1F17) continue;
        CGRect r = [sv convertRect:sv.bounds toView:w];
        if (!CGRectIntersectsRect(CGRectInset(r, -1, -1), barRect) && !CGRectIsEmpty(r)) continue;
        NSString *cn = NSStringFromClass([sv class]);
        BOOL lens = [cn containsString:@"_UITabSelectionView"] || [cn containsString:@"LiquidLensView"] || [cn containsString:@"ClearGlassView"] || [cn containsString:@"SDFView"] || [cn containsString:@"SDFElementView"] || [cn containsString:@"DestOutView"];
        if (dump && depth > 1 && r.size.width < barRect.size.width + 2) [dump appendFormat:@"%*s%@ %@ a=%.2f h=%d\n", depth, "", cn, NSStringFromCGRect(r), sv.alpha, sv.hidden];
        if (lens) { if (sv.alpha != 0) sv.alpha = 0; continue; }

        if ([cn isEqualToString:@"UIView"] && [NSStringFromClass([v class]) isEqualToString:@"_UIVisualEffectContentView"] && sv.bounds.size.width > 30 && sv.bounds.size.width < 220 && sv.bounds.size.height > 20 && sv.bounds.size.height < 60) {
            BOOL hasButtons = NO;
            for (UIView *sib in v.subviews) if ([NSStringFromClass([sib class]) containsString:@"TabBarButton"]) { hasButtons = YES; break; }
            if (hasButtons) { if (sv.alpha != 0) sv.alpha = 0; if (!sv.hidden) sv.hidden = YES; if (InfinitokFirstTime(@"lg|tikpill")) ITLog("glassbar", @"hid TikTok selection pill %@", NSStringFromCGRect(r)); continue; }
        }
        InfinitokHideLensWide(sv, w, barRect, depth + 1, dump);
    }
}
static void InfinitokFixLens(UIView *fake, UIView *tik) {
    if (!fake || !tik || [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) return;

    InfinitokHideNativePlatters(fake, 0);
    InfinitokHideNativePlatters(tik, 0);
    if (tik.window) {
        UIWindow *w = tik.window; CGRect barRect = [tik convertRect:tik.bounds toView:w];
        static int dumpsLeft = 4; static CFAbsoluteTime lastDump = 0;
        NSMutableString *dump = nil;
        CFAbsoluteTime nowT = CFAbsoluteTimeGetCurrent();
        if (dumpsLeft > 0 && nowT - lastDump > 4.0) { dump = [NSMutableString stringWithFormat:@"views over the bar %@:\n", NSStringFromCGRect(barRect)]; lastDump = nowT; dumpsLeft--; }
        InfinitokHideLensWide(w, w, barRect, 0, dump);
        if (dump) ITLog("glassbar", @"%@", dump);
    }
    UIView *lens = InfinitokFindLens(fake, 0);
    if (!lens || !lens.superview || lens.bounds.size.width < 1) return;
    NSMutableArray *real = [NSMutableArray array];
    id bb = InfinitokObj(tik, @"buttons");
    if (![bb isKindOfClass:[NSArray class]]) return;
    for (id b in bb) if ([b isKindOfClass:[UIView class]] && ![NSStringFromClass([b class]) containsString:@"Plus"]) [real addObject:b];
    NSInteger idx = -1;
    if ([fake isKindOfClass:[UITabBar class]]) {
        UITabBar *tb = (UITabBar *)fake;
        if (tb.selectedItem) idx = (NSInteger)[tb.items indexOfObject:tb.selectedItem];
        if (idx == (NSInteger)NSNotFound) idx = -1;
    }
    if (idx < 0 && real.count) {

        UIView *plat = lens.superview;
        CGFloat slotW = plat.bounds.size.width / (CGFloat)real.count;
        if (slotW > 1) idx = (NSInteger)floor(lens.center.x / slotW);
    }
    if (idx < 0 || idx >= (NSInteger)real.count) return;
    UIView *btn = real[idx];
    if (btn.hidden || btn.bounds.size.width < 1) return;

    if (lens.alpha != 0) lens.alpha = 0;
    UIView *host = btn.superview;
    if (!host) return;
    static const NSInteger kCapTag = 0x1F17;
    UIView *cap = [host viewWithTag:kCapTag];
    CGRect target = CGRectInset(btn.frame, 4, 2);
    if (!cap) {
        id eff = nil; Class gc = NSClassFromString(@"UIGlassEffect");
        if (gc) eff = [gc new];
        if (eff) {
            UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:(UIVisualEffect *)eff];
            cap = ev;
        } else {
            cap = [UIView new];
            cap.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
        }
        cap.tag = kCapTag; cap.userInteractionEnabled = NO;
        cap.layer.cornerRadius = target.size.height / 2; cap.layer.masksToBounds = YES;
        cap.frame = target;
        [host insertSubview:cap belowSubview:btn];
        if (InfinitokFirstTime(@"lg|capnew")) ITLog("glassbar", @"own capsule created (%@) under %@", gc ? @"UIGlassEffect" : @"flat", NSStringFromCGRect(target));
    }
    cap.layer.cornerRadius = target.size.height / 2;
    if (cap.superview != host || [host.subviews indexOfObject:cap] > [host.subviews indexOfObject:btn]) [host insertSubview:cap belowSubview:btn];
    if (!CGRectEqualToRect(cap.frame, target) && !cap.layer.animationKeys.count) {
        BOOL animate = cap.window != nil && fabs(cap.frame.origin.x - target.origin.x) > 1 && cap.frame.size.width > 1;
        if (animate) [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{ cap.frame = target; } completion:nil];
        else cap.frame = target;
    }
    if (InfinitokFirstTime([NSString stringWithFormat:@"lg|lens|%ld", (long)idx])) ITLog("glassbar", @"capsule: item=%ld target=%@ button=%@ host=%@", (long)idx, NSStringFromCGRect(target), NSStringFromClass([btn class]), NSStringFromClass([host class]));
}
static UIView *InfinitokSiblingOfClass(UIView *v, NSString *cn) {
    for (UIView *sv in v.superview.subviews) if (sv != v && [NSStringFromClass([sv class]) isEqualToString:cn]) return sv;
    return nil;
}
@interface InfinitokLensTicker : NSObject
@property (nonatomic, weak) UIView *fake;
@property (nonatomic, weak) UIView *tik;
@property (nonatomic, assign) CFAbsoluteTime until;
@property (nonatomic, strong) CADisplayLink *link;
+ (instancetype)shared;
- (void)kick:(UIView *)fake tik:(UIView *)tik;
@end
@implementation InfinitokLensTicker
+ (instancetype)shared { static InfinitokLensTicker *t; static dispatch_once_t o; dispatch_once(&o, ^{ t = [InfinitokLensTicker new]; }); return t; }
- (void)kick:(UIView *)fake tik:(UIView *)tik {
    if (!fake || !tik) return;
    self.fake = fake; self.tik = tik;
    self.until = CFAbsoluteTimeGetCurrent() + 0.9;
    if (!self.link) { self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)]; [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes]; }
}
- (void)tick:(CADisplayLink *)l {
    if (CFAbsoluteTimeGetCurrent() > self.until || !self.fake || !self.tik) { [l invalidate]; self.link = nil; return; }
    @try { InfinitokFixLens(self.fake, self.tik); } @catch (__unused id e) {}
}
@end
static BOOL InfinitokNativeBarFit(UIView *bar) {
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) return NO;
    if (InfinitokFirstTime(@"lg|dump")) {
        NSMutableString *d = [NSMutableString stringWithFormat:@"TTKTabBar frame=%@ bounds=%@ superview=%@ %@\n", NSStringFromCGRect(bar.frame), NSStringFromCGRect(bar.bounds), NSStringFromClass([bar.superview class]), NSStringFromCGRect(bar.superview.frame)];
        InfinitokLGDump(bar, 1, d);
        ITLog("glassbar", @"%@", d);
    }
    if (!InfinitokIsGlassBar(bar)) { if (InfinitokFirstTime(@"lg|noglass")) ITLog("glassbar", @"standard iPad bar (no liquid glass views) — leaving sizes alone"); return NO; }
    InfinitokLGScheduleWinDump(bar);
    CGRect f = bar.frame, n = InfinitokPhoneSizedBarFrame(f);
    if (!CGRectEqualToRect(f, n)) { bar.frame = n; if (InfinitokFirstTime(@"lg|fit")) ITLog("glassbar", @"liquid glass bar resized %@ -> %@", NSStringFromCGRect(f), NSStringFromCGRect(n)); }

    UIView *platter = nil;
    for (UIView *sv in bar.subviews) if ([NSStringFromClass([sv class]) containsString:@"_UITabBarItemPlatterView"]) { platter = sv; break; }

    NSMutableArray *btns = [NSMutableArray array];
    InfinitokLGCollectButtons(bar, 0, btns);
    if (!btns.count) { id bb = InfinitokObj(bar, @"buttons"); if ([bb isKindOfClass:[NSArray class]]) for (id b in bb) if ([b isKindOfClass:[UIView class]]) [btns addObject:b]; }
    if (!btns.count && bar.superview) InfinitokLGCollectButtons(bar.superview, 0, btns);
    if (btns.count || platter.bounds.size.width > 1) {
        static int dumps = 0;
        if (dumps < 2 && InfinitokFirstTime([NSString stringWithFormat:@"lg|dump2|%d", dumps])) {
            dumps++;
            NSMutableString *d = [NSMutableString stringWithFormat:@"late dump: bar=%@ buttons=%lu platter=%@\n", NSStringFromCGRect(bar.frame), (unsigned long)btns.count, platter ? NSStringFromCGRect(platter.frame) : @"nil"];
            InfinitokLGDump(bar, 1, d);
            for (UIView *b in btns) [d appendFormat:@"BTN %@ %@ sel=%d hidden=%d\n", NSStringFromClass([b class]), NSStringFromCGRect([bar convertRect:b.bounds fromView:b]), [b isKindOfClass:[UIControl class]] ? ((UIControl *)b).selected : -1, b.hidden];
            ITLog("glassbar", @"%@", d);
        }
    }
    NSMutableArray *vis = [NSMutableArray array];
    for (UIView *b in btns) if (!b.hidden && b.alpha > 0.01 && b.bounds.size.width > 1) [vis addObject:b];
    UIView *sel = nil;
    for (UIView *b in vis) if ([b isKindOfClass:[UIControl class]] && ((UIControl *)b).selected) { sel = b; break; }
    if (!sel && [bar isKindOfClass:[UITabBar class]]) {
        UITabBar *tb = (UITabBar *)bar;
        NSUInteger idx = tb.selectedItem ? [tb.items indexOfObject:tb.selectedItem] : NSNotFound;
        if (idx != NSNotFound && btns.count == tb.items.count && idx < btns.count) { UIView *b = btns[idx]; if (!b.hidden) sel = b; }
    }
    if (platter && sel) {

        CGFloat want = [bar convertPoint:CGPointMake(CGRectGetMidX(sel.bounds), 0) fromView:sel].x;
        CGFloat dx = want - platter.center.x;
        if (InfinitokFirstTime(@"lg|sel")) ITLog("glassbar", @"selection capsule center=%.0f wanted=%.0f shift=%.0f under %@", platter.center.x, want, dx, NSStringFromClass([sel class]));
    } else if (InfinitokFirstTime(@"lg|nosel")) ITLog("glassbar", @"selection: platter=%d selected=%d visible=%lu", platter != nil, sel != nil, (unsigned long)vis.count);
    { UIView *fk = InfinitokSiblingOfClass(bar, @"TTKFakeTabBar"); InfinitokFixLens(fk, bar); [[InfinitokLensTicker shared] kick:fk tik:bar]; }

    UIView *last = sInfinitokLastSelBtn;
    SEL us = NSSelectorFromString(@"updateLiquidGlassSelectionIndicatorWithSelectedButton:animated:");
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (last && last.superview && !sInfinitokInIndicator && now - sInfinitokIndTime > 0.15 && [bar respondsToSelector:us]) {
        sInfinitokIndTime = now; sInfinitokInIndicator = YES;
        @try { ((void (*)(id, SEL, id, BOOL))objc_msgSend)(bar, us, last, NO); } @catch (__unused id e) {}
        sInfinitokInIndicator = NO;
        if (InfinitokFirstTime(@"lg|ind")) ITLog("glassbar", @"re-applied selection indicator for %@ at %@", NSStringFromClass([last class]), NSStringFromCGRect([bar convertRect:last.bounds fromView:last]));
    }
    return YES;
}
static void InfinitokHideTabText(UIView *bar) {
    for (UIView *b in bar.subviews) {
        NSString *bc = NSStringFromClass([b class]);
        if (![bc containsString:@"TabBarButton"] && ![bc containsString:@"TabBarPlusButton"]) continue;
        for (UIView *sv in b.subviews) {
            if ([sv isKindOfClass:[UILabel class]] && [bc containsString:@"Plus"]) { sv.hidden = YES; continue; }
            if (![NSStringFromClass([sv class]) containsString:@"AnimationContentView"]) continue;
            for (UIView *l in sv.subviews) if ([l isKindOfClass:[UILabel class]]) l.hidden = YES;
        }
    }
}
static void InfinitokInstallTabBarFit(void) {
    Class bar = NSClassFromString(@"TTKTabBar");
    SEL ls = NSSelectorFromString(@"layoutSubviews");
    if (!bar || !class_getInstanceMethod(bar, ls)) { ITLog("glassbar", @"TTKTabBar layoutSubviews missing"); return; }
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(bar, ls, ^(UIView *v) {
        if (orig) ((void (*)(id, SEL))orig)(v, ls);
        static BOOL busy = NO;
        if (busy) return;

        static BOOL tripped = NO; static CFAbsoluteTime winStart = 0; static int passes = 0;
        CFAbsoluteTime t = CFAbsoluteTimeGetCurrent();
        if (t - winStart > 2.0) { winStart = t; passes = 0; }
        if (++passes > 60 && !tripped) { tripped = YES; ITLog("glassbar", @"layout storm detected (%d passes in 2s) — glass bar fit disabled for this session", passes); }
        if (tripped) return;
        busy = YES;
        BOOL native = InfinitokNativeBarFit(v);
        if (native || [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_tab_bar_text"]) InfinitokHideTabText(v);
        busy = NO;
    });
    ITLog("glassbar", @"hooked TTKTabBar layoutSubviews");

    SEL sf = NSSelectorFromString(@"setFrame:");
    __block IMP sorig = NULL;
    sorig = InfinitokReplaceInstance(bar, sf, ^(UIView *v, CGRect f) {
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && f.size.width > kInfinitokPhoneBarWidth + 20 && InfinitokIsGlassBar(v))
            f = InfinitokPhoneSizedBarFrame(f);
        if (sorig) ((void (*)(id, SEL, CGRect))sorig)(v, sf, f);
    });
    ITLog("glassbar", @"hooked TTKTabBar setFrame:");

    {
        Class fk = NSClassFromString(@"TTKFakeTabBar");
        SEL fl = NSSelectorFromString(@"layoutSubviews");
        if (fk && class_getInstanceMethod(fk, fl)) {
            __block IMP fo = NULL;
            fo = InfinitokReplaceInstance(fk, fl, ^(UIView *v) {
                if (fo) ((void (*)(id, SEL))fo)(v, fl);
                @try { UIView *tk = InfinitokSiblingOfClass(v, @"TTKTabBar"); InfinitokFixLens(v, tk); [[InfinitokLensTicker shared] kick:v tik:tk]; } @catch (__unused id e) {}
            });
            ITLog("glassbar", @"hooked TTKFakeTabBar layoutSubviews");
        }
    }

    {
        SEL us2 = NSSelectorFromString(@"updateLiquidGlassSelectionIndicatorWithSelectedButton:animated:");
        if (class_getInstanceMethod(bar, us2)) {
            __block IMP uo = NULL;
            uo = InfinitokReplaceInstance(bar, us2, ^(UIView *v, id btn, BOOL animated) {
                if ([btn isKindOfClass:[UIView class]]) {
                    sInfinitokLastSelBtn = btn;
                    if (InfinitokFirstTime(@"lg|upd")) ITLog("glassbar", @"indicator update for %@ frame=%@ in bar=%@", NSStringFromClass([btn class]), NSStringFromCGRect([btn frame]), NSStringFromCGRect(v.frame));
                }
                if (uo) ((void (*)(id, SEL, id, BOOL))uo)(v, us2, btn, animated);
            });
            ITLog("glassbar", @"hooked TTKTabBar indicator update");
        }
    }

    SEL ss = NSSelectorFromString(@"setSelectedItem:");
    if (class_getInstanceMethod(bar, ss)) {
        __block IMP so = NULL;
        so = InfinitokReplaceInstance(bar, ss, ^(UIView *v, id item) {
            if (so) ((void (*)(id, SEL, id))so)(v, ss, item);
            static BOOL pend = NO; if (!pend) { pend = YES; dispatch_async(dispatch_get_main_queue(), ^{ pend = NO; [v setNeedsLayout]; }); }
        });
    }
}

static void InfinitokForcePadGates(void) {
    InfinitokInstallTabBarFit();
}

static void InfinitokForceClassValue(NSString *cn, NSString *sn, uintptr_t value, BOOL (^gate)(void));
static void InfinitokInstallABExperiments(void) {

    InfinitokForceABClassMethod(@"tux_profile_icon_update", 1, ^BOOL{ return [BHIManager forceNewProfileUI]; });

    InfinitokForceABClassMethod(@"new_bottom_tab_icon2", 2, ^BOOL{ return [BHIManager forceNewProfileUI]; });

    {
        BOOL (^cr)(void) = ^BOOL{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"enable_comment_repost"]; };
        for (NSString *n in @[@"enableCommentRepost", @"enableCommentRepostInteraction", @"commentRepostEnabledAnyMode",
                              @"commentSupportRepostLegacy", @"commentSupportRepostInteraction", @"repostCommentTagOpt",
                              @"enableRepostAddDescText", @"repostSupportMention", @"repostAddMentionEntrance",
                              @"enableAudioCommentRepost", @"audioCommentRepost", @"repostSupportDigg", @"isRepostDiggEnabled",
                              @"repostSupportReply", @"isRepostReplyEnabled", @"repostAddMaf", @"isRepostTagRevampEnabled",
                              @"isRepostTextAllowAll", @"isRepostTextAllowFollowing", @"isRepostTextAllowMoreThanFriends",
                              @"repostTextAllowFollowing", @"isRepostBubbleAlsoRepostEnabled", @"fwtfRepostInteractionEnabled"])
            InfinitokForceABClassMethod(n, 1, cr);
        InfinitokForceClassValue(@"TTKCommentNewCellABTestConfig", @"repostCommentTagOpt", 1, cr);
        for (NSArray *g in @[@[@"TTKCommentRepostGuideManager", @"isEligible"], @[@"TTKCommentRepostGuideManager", @"canShowToday"]])
            InfinitokForceBoolMethod(g[0], g[1], NO, cr);
        for (NSArray *t in @[@[@"TTKCommentRepostTagRefreshComponent", @"handleRepostTextEntranceShowWithEvent:"],
                             @[@"TTKCommentRepostTagRefreshComponent", @"updateWithModel:"],
                             @[@"TTKCommentRepostGuideComponent", @"popControlShowDidLoadData:usingCache:"],
                             @[@"TTKCommentPanelSourceInfoComponent", @"p_repostCommentTargetCidForPageContext"]])
            InfinitokTrace(@"comment-repost", t[0], t[1], NO);
    }
    InfinitokForcePadGates();

}

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <libkern/OSAtomic.h>

static void InfinitokLogClassExists(const char *tag, NSArray<NSString *> *names) {
    for (NSString *n in names) {
        if (InfinitokDebugLoggingEnabled()) {
            NSString *_itMsg = [NSString stringWithFormat:@"%@ exists at launch: %@", n, NSClassFromString(n) ? @"YES" : @"NO"];
            os_log(InfinitokLogHandle(), "INFINITOK [%{public}s] %{public}s", tag, [_itMsg UTF8String]);
            InfinitokWriteDebugLogFile([NSString stringWithFormat:@"[%s] %@", tag, _itMsg]);
        }
    }
}

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

static NSString *InfinitokSafeDesc(id o, NSString *sel) {
    if (!o || !sel.length) return nil;
    SEL s = NSSelectorFromString(sel);
    Method m = class_getInstanceMethod(object_getClass(o), s);
    if (!m) return nil;
    char *rt = method_copyReturnType(m);
    char t = rt ? rt[0] : 0; if (rt) free(rt);
    @try {
        if (t == '@') { id v = ((id (*)(id, SEL))objc_msgSend)(o, s); return v ? [v description] : nil; }
        if (t == 'q' || t == 'l') return [NSString stringWithFormat:@"%lld", ((long long (*)(id, SEL))objc_msgSend)(o, s)];
        if (t == 'Q' || t == 'L') return [NSString stringWithFormat:@"%llu", ((unsigned long long (*)(id, SEL))objc_msgSend)(o, s)];
        if (t == 'i') return [NSString stringWithFormat:@"%d", ((int (*)(id, SEL))objc_msgSend)(o, s)];
        if (t == 'I') return [NSString stringWithFormat:@"%u", ((unsigned (*)(id, SEL))objc_msgSend)(o, s)];
    } @catch (__unused id e) {}
    return nil;
}
static id InfinitokObj(id o, NSString *sel) {
    if (!o || !sel.length) return nil;
    SEL s0 = NSSelectorFromString(sel);
    Method m0 = class_getInstanceMethod(object_getClass(o), s0);
    if (m0) { char *rt = method_copyReturnType(m0); BOOL isObj = rt && rt[0] == '@'; if (rt) free(rt); if (!isObj) return nil; }
    if (!o || !sel.length) return nil;
    SEL s = NSSelectorFromString(sel);
    if (![o respondsToSelector:s]) return nil;
    id (*f)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    return f(o, s);
}
static void InfinitokSetObj(id o, NSString *key, id val) {
    if (!o) return;
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]];
    if ([o respondsToSelector:NSSelectorFromString(setter)]) {
        @try { [o setValue:val forKey:key]; } @catch (__unused id e) {}
    }
}
static UIViewController *InfinitokTopVC(UIViewController *vc) {
    if (!vc) {
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) if (w.isKeyWindow) { vc = w.rootViewController; break; }
            if (vc) break;
        }
    }
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
static void InfinitokAlert(UIViewController *p, NSString *title, NSString *msg) {
    UIViewController *top = InfinitokTopVC(p);
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [top presentViewController:a animated:YES completion:nil];
}

static IMP InfinitokReplaceInstance(Class cls, SEL sel, id block) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP orig = method_getImplementation(m);
    class_replaceMethod(cls, sel, imp_implementationWithBlock(block), method_getTypeEncoding(m));
    return orig;
}

static void InfinitokForceClassValue(NSString *cn, NSString *sn, uintptr_t value, BOOL (^gate)(void)) {
    Class c = NSClassFromString(cn);
    SEL sel = NSSelectorFromString(sn);
    Class meta = c ? object_getClass(c) : nil;
    Method m = meta ? class_getInstanceMethod(meta, sel) : NULL;
    if (!m) { ITLog("comments", @"+[%@ %@] missing", cn, sn); return; }
    char *rt = method_copyReturnType(m); char t = rt ? rt[0] : 0; if (rt) free(rt);
    if (!strchr("BcqQlLiI", t)) { ITLog("comments", @"+[%@ %@] return type %c unsupported", cn, sn, t); return; }
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(meta, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6) {
        if (gate()) return value;
        return orig ? ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, a1, a2, a3, a4, a5, a6) : 0;
    });
    ITLog("comments", @"forced +[%@ %@] = %lu", cn, sn, (unsigned long)value);
}
static void InfinitokInstallFullComments(void) {
    BOOL (^on)(void) = ^BOOL{ return [BHIManager fullLengthComments]; };

    InfinitokForceClassValue(@"TTKCommentABCharacterLimit", @"isViewMoreEnable", 0, on);
    InfinitokForceClassValue(@"TTKCommentABCharacterLimit", @"viewMoreShowLineLimit", 100000, on);
    InfinitokForceClassValue(@"TTKCommentABCharacterLimit", @"viewMoreExpandLineLimit", 100000, on);
    InfinitokForceClassValue(@"TTKABTest", @"commentLongCommentExpand", 1, on);
    InfinitokForceClassValue(@"TTKCommentInputLongCommentOptConfig", @"maxInputLimit", 100000, on);
    InfinitokForceClassValue(@"TTKCommentInputLongCommentOptConfig", @"shouldShowTextExceedLimitHint", 0, on);

    Class cls = NSClassFromString(@"TTKConfigCenter");
    SEL sel = NSSelectorFromString(@"configValueForKey:");
    if (!cls) return;
    __block IMP orig = NULL;
    id (^blk)(id, id) = ^id(id self_, id key) {
        if ([BHIManager fullLengthComments] && [key isKindOfClass:[NSString class]] && [key isEqualToString:@"commentLongCommentExpand"]) return @YES;
        return orig ? ((id (*)(id, SEL, id))orig)(self_, sel, key) : nil;
    };
    if (class_getInstanceMethod(cls, sel)) orig = InfinitokReplaceInstance(cls, sel, blk);
    else if (class_getClassMethod(cls, sel)) orig = InfinitokReplaceInstance(object_getClass(cls), sel, blk);
}

static void InfinitokHideViewClass(NSString *name, BOOL (^cond)(void)) {
    Class cls = NSClassFromString(name);
    if (!cls) { ITLog("navhide", @"class %@ missing", name); return; }
    for (NSString *s in @[@"didMoveToWindow", @"layoutSubviews"]) {
        SEL sel = NSSelectorFromString(s);
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(cls, sel, ^(UIView *v) {
            if (orig) ((void (*)(id, SEL))orig)(v, sel);
            if (cond()) { v.hidden = YES; v.alpha = 0; v.userInteractionEnabled = NO; }
        });
    }
    ITLog("navhide", @"hooked %@", name);
}

static void InfinitokPinHidden(NSString *name, BOOL (^cond)(void)) {
    Class cls = NSClassFromString(name);
    if (!cls) return;
    SEL sh = NSSelectorFromString(@"setHidden:"), sa = NSSelectorFromString(@"setAlpha:");
    __block IMP oh = NULL, oa = NULL;
    oh = InfinitokReplaceInstance(cls, sh, ^(UIView *v, uintptr_t a) {
        ((void (*)(id, SEL, BOOL))oh)(v, sh, cond() ? YES : (BOOL)a);
    });
    oa = InfinitokReplaceInstance(cls, sa, ^(UIView *v, CGFloat a) {
        ((void (*)(id, SEL, CGFloat))oa)(v, sa, cond() ? 0 : a);
    });
}
static const void *kInfinitokTabHiddenKey = &kInfinitokTabHiddenKey;
static BOOL InfinitokTabIsPlus(UIView *b) {
    if ([NSStringFromClass([b class]) containsString:@"Plus"]) return YES;
    for (UIView *s in b.subviews) {
        if ([NSStringFromClass([s class]) containsString:@"Plus"]) return YES;
        for (UIView *s2 in s.subviews) if ([NSStringFromClass([s2 class]) containsString:@"Plus"]) return YES;
    }
    return NO;
}

static void InfinitokReflowTabBar(UIView *bar) {
    BOOL hidePlus = [BHIManager hideVideoButton], second = [BHIManager hideTabSlotSecond], last = [BHIManager hideTabSlotLast];
    if (!hidePlus && !second && !last) return;
    NSArray *src = nil;
    @try { id v = [bar valueForKey:@"buttons"]; if ([v isKindOfClass:[NSArray class]]) src = v; } @catch (__unused id e) {}
    NSMutableArray<UIView *> *all = [NSMutableArray array];
    for (id v in src) if ([v isKindOfClass:[UIView class]]) [all addObject:v];
    if (all.count < 3) {
        [all removeAllObjects];
        for (UIView *s in bar.subviews) {
            NSString *n = NSStringFromClass([s class]);
            if ([n containsString:@"TabBarButton"] || [n containsString:@"PlusButton"]) [all addObject:s];
        }
    }
    NSMutableArray<UIView *> *cand = [NSMutableArray array];
    for (UIView *v in all) {
        BOOL ours = [objc_getAssociatedObject(v, kInfinitokTabHiddenKey) boolValue];
        if (!v.hidden || ours) [cand addObject:v];
    }
    if (cand.count < 3) return;
    [cand sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) { return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending; }];
    NSMutableSet *remove = [NSMutableSet set];
    if (hidePlus) for (UIView *v in cand) if (InfinitokTabIsPlus(v)) [remove addObject:v];
    if (second && cand.count > 1 && ![remove containsObject:cand[1]] && !InfinitokTabIsPlus(cand[1])) [remove addObject:cand[1]];
    if (last && !InfinitokTabIsPlus(cand.lastObject)) [remove addObject:cand.lastObject];
    NSMutableArray<UIView *> *keep = [NSMutableArray array];
    for (UIView *v in cand) {
        BOOL r = [remove containsObject:v];
        objc_setAssociatedObject(v, kInfinitokTabHiddenKey, @(r), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        v.hidden = r;
        if (!r) [keep addObject:v];
    }
    if (!keep.count) return;
    CGFloat w = bar.bounds.size.width / keep.count;
    CGFloat i = 0;
    for (UIView *v in keep) {
        CGRect f = v.frame;
        v.frame = CGRectMake(i * w, f.origin.y, w, f.size.height);
        i++;
    }
}

static void InfinitokInstallNavHiding(void) {
    InfinitokHideViewClass(@"TTKSearchEntranceButton", ^BOOL{ return [BHIManager hideSearchButton]; });
    InfinitokHideViewClass(@"TTKCommentSearchEntranceButton", ^BOOL{ return [BHIManager hideSearchButton]; });
    InfinitokHideViewClass(@"TikTokFeedTabControl", ^BOOL{ return [BHIManager hideFeedTabs]; });
    for (NSString *vn in @[@"TTKVisualSearchTagView", @"TTKVisualSearchTagContainerView", @"TTKVisualSearchEntityDotView",
                           @"TTKVisualSearchTipsContainerView", @"TTKPhotoCommentVisualSearchEntryView", @"TTKVisualSearchPhantomView",
                           @"TTKVisualSearchShimmerContourView", @"TTKVisualSearchFullSizeElement", @"_TtC16TikTokSearchImpl23SearchImageTagComponent"]) {
        InfinitokHideViewClass(vn, ^BOOL{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_find_similar"]; });
        InfinitokPinHidden(vn, ^BOOL{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_find_similar"]; });
    }
    InfinitokPinHidden(@"TikTokFeedTabControl", ^BOOL{ return [BHIManager hideFeedTabs]; });
    {
        Class c = NSClassFromString(@"TikTokFeedTabControl");
        SEL sel = NSSelectorFromString(@"didMoveToSuperview");
        if (c) { __block IMP o = NULL; o = InfinitokReplaceInstance(c, sel, ^(UIView *v) {
            if (o) ((void (*)(id, SEL))o)(v, sel);
            if ([BHIManager hideFeedTabs]) { v.hidden = YES; v.alpha = 0; }
        }); }
    }
    Class bar = NSClassFromString(@"TTKTabBar");
    if (bar) {
        SEL sel = NSSelectorFromString(@"layoutSubviews");
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(bar, sel, ^(UIView *v) {
            if (orig) ((void (*)(id, SEL))orig)(v, sel);
            InfinitokReflowTabBar(v);
        });
        ITLog("navhide", @"hooked TTKTabBar layoutSubviews");
    } else {
        ITLog("navhide", @"TTKTabBar missing");
    }
}

static NSString *InfinitokFontDir(void) {
    NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [base stringByAppendingPathComponent:@"Infinitok/Fonts"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
static void InfinitokInstallFontSwizzles(void) {
    NSString *name = [BHIManager customFontName];
    if (!name.length) return;
    Class meta = object_getClass([UIFont class]);
    NSArray *sels = @[@"systemFontOfSize:", @"boldSystemFontOfSize:", @"italicSystemFontOfSize:"];
    for (NSString *s in sels) {
        SEL sel = NSSelectorFromString(s);
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(meta, sel, ^UIFont *(id self_, CGFloat size) {
            UIFont *o = ((UIFont *(*)(id, SEL, CGFloat))orig)(self_, sel, size);
            UIFont *f = [UIFont fontWithName:name size:size];
            return f ?: o;
        });
    }
    {
        SEL sel = NSSelectorFromString(@"systemFontOfSize:weight:");
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(meta, sel, ^UIFont *(id self_, CGFloat size, CGFloat weight) {
            UIFont *o = ((UIFont *(*)(id, SEL, CGFloat, CGFloat))orig)(self_, sel, size, weight);
            UIFont *f = [UIFont fontWithName:name size:size];
            return f ?: o;
        });
    }
    {
        SEL sel = NSSelectorFromString(@"preferredFontForTextStyle:");
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(meta, sel, ^UIFont *(id self_, id style) {
            UIFont *o = ((UIFont *(*)(id, SEL, id))orig)(self_, sel, style);
            UIFont *f = o ? [UIFont fontWithName:name size:o.pointSize] : nil;
            return f ?: o;
        });
    }

    BOOL (^replaceable)(UIFont *) = ^BOOL(UIFont *f) {
        if (!f) return NO;
        NSString *n = f.fontName.lowercaseString;
        for (NSString *bad in @[@"icon", @"emoji", @"symbol", @"glyph", @"awesome", @"sficon", @"tux"]) if ([n containsString:bad]) return NO;
        return ![f.fontName isEqualToString:name];
    };
    {
        SEL sel = NSSelectorFromString(@"fontWithName:size:");
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(meta, sel, ^UIFont *(id self_, NSString *n, CGFloat size) {
            UIFont *o = ((UIFont *(*)(id, SEL, id, CGFloat))orig)(self_, sel, n, size);
            if (!o || [n isEqualToString:name] || !replaceable(o)) return o;
            UIFont *f = ((UIFont *(*)(id, SEL, id, CGFloat))orig)(self_, sel, name, size);
            return f ?: o;
        });
    }
    {
        SEL sel = NSSelectorFromString(@"fontWithDescriptor:size:");
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(meta, sel, ^UIFont *(id self_, UIFontDescriptor *d, CGFloat size) {
            UIFont *o = ((UIFont *(*)(id, SEL, id, CGFloat))orig)(self_, sel, d, size);
            if (!replaceable(o)) return o;
            CGFloat s = size > 0 ? size : o.pointSize;
            UIFont *f = [UIFont fontWithName:name size:s];
            return f ?: o;
        });
    }
    for (NSArray *pair in @[@[@"UILabel", @"setFont:"], @[@"UITextView", @"setFont:"], @[@"UITextField", @"setFont:"]]) {
        Class cls = NSClassFromString(pair[0]);
        SEL sel = NSSelectorFromString(pair[1]);
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(cls, sel, ^(id self_, UIFont *f) {
            UIFont *use = replaceable(f) ? ([UIFont fontWithName:name size:f.pointSize] ?: f) : f;
            ((void (*)(id, SEL, id))orig)(self_, sel, use);
        });
    }
    for (NSArray *pair in @[@[@"UILabel", @"setAttributedText:"], @[@"UITextView", @"setAttributedText:"]]) {
        Class cls = NSClassFromString(pair[0]);
        SEL sel = NSSelectorFromString(pair[1]);
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(cls, sel, ^(id self_, NSAttributedString *s) {
            NSAttributedString *use = s;
            if (s.length) {
                NSMutableAttributedString *m = [s mutableCopy];
                [m enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, m.length) options:0 usingBlock:^(id v, NSRange r, BOOL *stop) {
                    if ([v isKindOfClass:[UIFont class]] && replaceable(v)) {
                        UIFont *nf = [UIFont fontWithName:name size:[(UIFont *)v pointSize]];
                        if (nf) [m addAttribute:NSFontAttributeName value:nf range:r];
                    }
                }];
                use = m;
            }
            ((void (*)(id, SEL, id))orig)(self_, sel, use);
        });
    }
    ITLog("fonts", @"font swizzles installed for %@", name);
}
static void InfinitokRegisterSavedFont(void) {
    NSString *file = [[NSUserDefaults standardUserDefaults] stringForKey:@"custom_font_file"];
    if (!file.length) return;
    NSURL *url = [NSURL fileURLWithPath:[InfinitokFontDir() stringByAppendingPathComponent:file]];
    CFErrorRef err = NULL;
    if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &err)) {
        ITLog("fonts", @"register failed for %@ (maybe already registered)", file);
        if (err) CFRelease(err);
    }
    InfinitokInstallFontSwizzles();
}

@interface InfinitokFontPicker : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@end
@implementation InfinitokFontPicker
- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *src = urls.firstObject;
    if (!src) return;
    NSString *ext = src.pathExtension.lowercaseString;
    if (![@[@"ttf", @"otf", @"ttc"] containsObject:ext]) {
        InfinitokAlert(self.presenter, @"Infinitok", @"Only .ttf, .otf and .ttc fonts are supported.");
        return;
    }
    NSString *dest = [InfinitokFontDir() stringByAppendingPathComponent:[@"custom." stringByAppendingString:ext]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:dest error:nil];
    NSError *e = nil;
    BOOL scoped = [src startAccessingSecurityScopedResource];
    [fm copyItemAtURL:src toURL:[NSURL fileURLWithPath:dest] error:&e];
    if (scoped) [src stopAccessingSecurityScopedResource];
    if (e) { InfinitokAlert(self.presenter, @"Infinitok", e.localizedDescription); return; }
    NSArray *descs = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)[NSURL fileURLWithPath:dest]));
    if (!descs.count) { [fm removeItemAtPath:dest error:nil]; InfinitokAlert(self.presenter, @"Infinitok", @"That file is not a valid font."); return; }
    NSString *ps = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)descs.firstObject, kCTFontNameAttribute));
    [[NSUserDefaults standardUserDefaults] setObject:ps forKey:@"custom_font_name"];
    [[NSUserDefaults standardUserDefaults] setObject:dest.lastPathComponent forKey:@"custom_font_file"];
    ITLog("fonts", @"imported font %@ (%@)", ps, dest.lastPathComponent);
    InfinitokAlert(self.presenter, @"Infinitok", [NSString stringWithFormat:@"Font \"%@\" imported. Fully close and reopen TikTok to apply it.", ps]);
}
@end
static InfinitokFontPicker *sInfinitokFontPicker;

static NSInteger sRepostDeleted, sRepostPass;
static BOOL sRepostRunning;
static __weak UIViewController *sRepostPresenter;
static UIAlertController *sRepostProgress;

static void InfinitokRepostFinish(NSString *msg) {
    sRepostRunning = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^show)(void) = ^{ InfinitokAlert(sRepostPresenter, @"Infinitok", msg); };
        if (sRepostProgress) { [sRepostProgress dismissViewControllerAnimated:YES completion:show]; sRepostProgress = nil; } else show();
    });
    ITLog("repost-clean", @"finished: %@", msg);
}
static NSString *InfinitokItemID(id item) {
    for (NSString *k in @[@"itemID", @"awemeID", @"awemeId", @"itemId"]) {
        id v = InfinitokObj(item, k);
        if (v) return [v description];
    }
    for (NSString *k in @[@"aweme", @"awemeModel", @"model", @"item"]) {
        id inner = InfinitokObj(item, k);
        if (inner) { NSString *r = InfinitokItemID(inner); if (r.length) return r; }
    }
    return nil;
}
static void InfinitokRepostLoadPage(void);
static void InfinitokRepostDeleteNext(NSMutableArray *queue) {
    if (!sRepostRunning) return;
    if (!queue.count) { InfinitokRepostLoadPage(); return; }
    id item = queue.firstObject; [queue removeObjectAtIndex:0];
    NSString *aid = InfinitokItemID(item);
    id svc = InfinitokObj(NSClassFromString(@"TTKUpvoteService"), @"sharedService");
    id ctrl = nil;
    if (aid && [svc respondsToSelector:NSSelectorFromString(@"getUpvoteDataControllerWithAwemeId:")])
        ctrl = ((id (*)(id, SEL, id))objc_msgSend)(svc, NSSelectorFromString(@"getUpvoteDataControllerWithAwemeId:"), aid);
    id upvote = InfinitokObj(ctrl, @"myUpvote");
    Class DM = NSClassFromString(@"TTKUpvoteDataControllerDeleteModel");
    id deleter = InfinitokObj(NSClassFromString(@"TTKRepostDeleter"), @"shared");
    if (!upvote || !DM || !deleter) {
        ITLog("repost-clean", @"skip item %@ (upvote=%d DM=%d deleter=%d)", aid, upvote != nil, DM != nil, deleter != nil);
        dispatch_async(dispatch_get_main_queue(), ^{ InfinitokRepostDeleteNext(queue); });
        return;
    }
    id model = [DM new];
    InfinitokSetObj(model, @"upvote", upvote);
    id aweme = InfinitokObj(item, @"aweme") ?: InfinitokObj(item, @"awemeModel") ?: item;
    InfinitokSetObj(model, @"awemeModel", aweme);
    Class TC = NSClassFromString(@"TTKUpvoteTrackContext");
    if (TC) InfinitokSetObj(model, @"trackerContext", [TC new]);
    InfinitokSetObj(model, @"completion", ^(id a, id b) {
        sRepostDeleted++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            sRepostProgress.message = [NSString stringWithFormat:@"Removed %ld reposts…", (long)sRepostDeleted];
            InfinitokRepostDeleteNext(queue);
        });
    });
    ((void (*)(id, SEL, id))objc_msgSend)(deleter, NSSelectorFromString(@"deleteWithModel:"), model);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (sRepostRunning && queue.firstObject == nil && sRepostDeleted == 0) {   }
    });
}
static void InfinitokRepostLoadPage(void) {
    if (!sRepostRunning) return;
    if (++sRepostPass > 60) { InfinitokRepostFinish([NSString stringWithFormat:@"Stopped after %ld reposts.", (long)sRepostDeleted]); return; }
    id mgrUser = InfinitokObj(InfinitokObj(NSClassFromString(@"NHAccountUserManager"), @"sharedInstance"), @"user");
    id uid = InfinitokObj(mgrUser, @"userID");
    Class MC = NSClassFromString(@"TTKUserProfileUpvoteItemListDataManager");
    if (!uid || !MC) { InfinitokRepostFinish(@"Couldn't find your account or the reposts list in this TikTok version."); return; }
    id mgr = ((id (*)(id, SEL, id))objc_msgSend)([MC alloc], NSSelectorFromString(@"initWithUserID:"), uid);
    SEL refresh = NSSelectorFromString(@"refreshWithCompletion:");
    if (![mgr respondsToSelector:refresh]) { InfinitokRepostFinish(@"Reposts list API not available."); return; }
    ((void (*)(id, SEL, id))objc_msgSend)(mgr, refresh, ^(id a, id b) {
        dispatch_async(dispatch_get_main_queue(), ^{
            id ds = InfinitokObj(mgr, @"dataSource") ?: mgr;
            NSArray *items = nil;
            for (NSString *k in @[@"dataArray", @"items", @"models", @"allItems", @"array"]) {
                id v = InfinitokObj(ds, k);
                if ([v isKindOfClass:[NSArray class]]) { items = v; break; }
            }
            if (!items && [ds isKindOfClass:[NSArray class]]) items = ds;
            ITLog("repost-clean", @"page %ld: %lu items", (long)sRepostPass, (unsigned long)items.count);
            if (!items.count) { InfinitokRepostFinish([NSString stringWithFormat:@"Done. Removed %ld reposts.", (long)sRepostDeleted]); return; }
            InfinitokRepostDeleteNext([items mutableCopy]);
        });
    });
}
static void InfinitokStartDeleteAllReposts(UIViewController *presenter) {
    UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Delete all your reposts?" message:@"This removes every video you have reposted. It cannot be undone." preferredStyle:UIAlertControllerStyleAlert];
    [c addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [c addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        if (sRepostRunning) return;
        sRepostRunning = YES; sRepostDeleted = 0; sRepostPass = 0; sRepostPresenter = presenter;
        sRepostProgress = [UIAlertController alertControllerWithTitle:@"Deleting reposts" message:@"Loading…" preferredStyle:UIAlertControllerStyleAlert];
        [sRepostProgress addAction:[UIAlertAction actionWithTitle:@"Stop" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) { sRepostRunning = NO; sRepostProgress = nil; }]];
        [InfinitokTopVC(presenter) presentViewController:sRepostProgress animated:YES completion:^{ InfinitokRepostLoadPage(); }];
    }]];
    [InfinitokTopVC(presenter) presentViewController:c animated:YES completion:nil];
}

void InfinitokPerformSettingsAction(NSString *action, UIViewController *presenter) {
    if ([action isEqualToString:@"font_import"]) {
        sInfinitokFontPicker = [InfinitokFontPicker new];
        sInfinitokFontPicker.presenter = presenter;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.truetype-ttf-font", @"public.opentype-font", @"public.truetype-collection-font", @"public.font", @"public.data"] inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
        p.delegate = sInfinitokFontPicker;
        [presenter presentViewController:p animated:YES completion:nil];
    } else if ([action isEqualToString:@"font_reset"]) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSString *file = [d stringForKey:@"custom_font_file"];
        if (file) [[NSFileManager defaultManager] removeItemAtPath:[InfinitokFontDir() stringByAppendingPathComponent:file] error:nil];
        [d removeObjectForKey:@"custom_font_name"]; [d removeObjectForKey:@"custom_font_file"];
        InfinitokAlert(presenter, @"Infinitok", @"Font reset. Fully close and reopen TikTok to apply.");
    } else if ([action isEqualToString:@"delete_all_reposts"]) {
        InfinitokStartDeleteAllReposts(presenter);
    }
}

static NSMutableDictionary<NSString *, NSString *> *sDeletedTextCache;
static NSString *InfinitokDMText(id o, int depth) {
    if (!o || depth > 3) return nil;
    for (NSString *k in @[@"displayText", @"displayTextContent", @"previewText", @"text", @"content"]) {
        id v = InfinitokObj(o, k);
        if ([v isKindOfClass:[NSString class]] && [v length]) return v;
    }
    for (NSString *k in @[@"getUnderlyingMessage", @"originMessage", @"originalMessage", @"recalledMessage", @"messageModel", @"cellViewModel", @"viewModel", @"model", @"data"]) {
        NSString *r = InfinitokDMText(InfinitokObj(o, k), depth + 1);
        if (r) return r;
    }
    return nil;
}
static NSMutableSet *sInfinitokRecalledIDs;

static void InfinitokDMLoad(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSArray *ids = [d arrayForKey:@"infinitok_recalled_ids"];
        if (!sInfinitokRecalledIDs) sInfinitokRecalledIDs = [NSMutableSet set];
        for (id i in ids) if ([i isKindOfClass:[NSString class]]) [sInfinitokRecalledIDs addObject:i];
        NSDictionary *t = [d dictionaryForKey:@"infinitok_deleted_text"];
        if (!sDeletedTextCache) sDeletedTextCache = [NSMutableDictionary dictionary];
        if (t) [sDeletedTextCache addEntriesFromDictionary:t];
    });
}
static void InfinitokDMSave(void) {
    static BOOL pending = NO;
    if (pending) return;
    pending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        pending = NO;
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSArray *ids = sInfinitokRecalledIDs.allObjects;
        if (ids.count > 1500) ids = [ids subarrayWithRange:NSMakeRange(ids.count - 1500, 1500)];
        [d setObject:ids forKey:@"infinitok_recalled_ids"];
        [d setObject:sDeletedTextCache ?: @{} forKey:@"infinitok_deleted_text"];
    });
}
static NSString *InfinitokDMKey(id vm) {
    NSMutableArray *objs = [NSMutableArray arrayWithObject:vm];
    for (NSString *k in @[@"getUnderlyingMessage", @"originMessage", @"messageModel", @"model", @"message"]) { id v = InfinitokObj(vm, k); if (v) [objs addObject:v]; }
    for (id o in objs) for (NSString *k in @[@"messageID", @"serverMessageID", @"serverMessageId", @"msgID", @"clientMessageID", @"uuid", @"localID"]) {
        NSString *v = InfinitokSafeDesc(o, k);
        if (v.length && ![v isEqualToString:@"0"]) return v;
    }
    return nil;
}
static BOOL InfinitokDMIsRecalled(id vm) {
    NSString *cn = NSStringFromClass([vm class]);
    if ([cn containsString:@"Recall"] || [cn containsString:@"Unavailable"]) return YES;
    for (NSString *k in @[@"getUnderlyingMessage", @"originMessage", @"messageModel"]) {
        id m = InfinitokObj(vm, k);
        if (m && [m respondsToSelector:@selector(isRecalled)] && ((BOOL (*)(id, SEL))objc_msgSend)(m, @selector(isRecalled))) return YES;
    }
    return NO;
}
static void InfinitokDMProcess(UIView *cell, id vm) {
    static const NSInteger kTag = 0x1DE1;
    [[cell viewWithTag:kTag] removeFromSuperview];
    if (!vm || ![BHIManager antiDeleteMessages]) return;
    InfinitokDMLoad();
    NSString *key = InfinitokDMKey(vm);
    BOOL hit = NO;
    if (sInfinitokRecalledIDs.count) {
        NSMutableArray *objs = [NSMutableArray arrayWithObject:vm];
        for (NSString *k in @[@"getUnderlyingMessage", @"originMessage", @"messageModel", @"model", @"message"]) { id v = InfinitokObj(vm, k); if (v) [objs addObject:v]; }
        { id cm = InfinitokObj(cell, @"message"); if (cm) [objs addObject:cm]; }
        for (id o in objs) for (NSString *k in @[@"serverMessageID", @"serverMessageId", @"messageID", @"msgID", @"localID", @"clientMessageID", @"messageId", @"uuid"]) {
            NSString *v = InfinitokSafeDesc(o, k);
            if (v && [sInfinitokRecalledIDs containsObject:v]) hit = YES;
        }
    }
    if (!hit && sInfinitokRecalledIDs.count) ITDebug("anti-delete", @"cell %@ vm %@ key=%@ no id match", NSStringFromClass([cell class]), NSStringFromClass([vm class]), key);
    if (hit) {
        cell.alpha = 0.5;
        UILabel *l = [[UILabel alloc] init];
        l.tag = kTag; l.text = @"🗑"; l.font = [UIFont systemFontOfSize:14]; [l sizeToFit];

        __weak UIView *wcell = cell; __weak UILabel *wl = l;
        void (^place)(void) = ^{
            UIView *c = wcell; UILabel *lab = wl; if (!c || !lab) return;
            UIView *bub = InfinitokObj(c, @"gestureBubbleView");
            if (![bub isKindOfClass:[UIView class]] || bub.bounds.size.width <= 1) bub = InfinitokObj(c, @"mainContentView");
            CGRect br = CGRectZero; BOOL haveBub = NO;
            if ([bub isKindOfClass:[UIView class]] && bub.superview && bub.bounds.size.width > 1) { br = [bub convertRect:bub.bounds toView:c]; haveBub = !CGRectIsEmpty(br); }
            BOOL mine = haveBub ? (CGRectGetMidX(br) > c.bounds.size.width / 2.0) : NO;
            CGFloat lw = lab.bounds.size.width, lh = lab.bounds.size.height;
            CGFloat x = haveBub ? (mine ? CGRectGetMinX(br) - lw / 2.0 : CGRectGetMaxX(br) - lw / 2.0) : 6;
            CGFloat y = haveBub ? CGRectGetMinY(br) - lh / 2.0 : 2;
            lab.frame = CGRectMake(MAX(0, MIN(x, c.bounds.size.width - lw)), MAX(0, y), lw, lh);
            ITDebug("anti-delete", @"icon %@ bubble=%@ mine=%d", haveBub ? @"on bubble corner" : @"fallback", NSStringFromCGRect(br), mine);
        };
        l.userInteractionEnabled = NO;
        [cell addSubview:l];
        place();
        dispatch_async(dispatch_get_main_queue(), place);
        return;
    }
    cell.alpha = 1;
    if (!InfinitokDMIsRecalled(vm)) {
        NSString *t = InfinitokDMText(vm, 0);
        if (key && t && ![sDeletedTextCache[key] isEqualToString:t]) { sDeletedTextCache[key] = t; if (sDeletedTextCache.count > 800) [sDeletedTextCache removeAllObjects]; InfinitokDMSave(); }
        return;
    }
    NSString *cached = key ? sDeletedTextCache[key] : nil;
    ITDebug("anti-delete", @"recalled cell key=%@ cached=%d class=%@", key, cached != nil, NSStringFromClass([vm class]));
    if (!cached) return;
    UILabel *l = [[UILabel alloc] initWithFrame:cell.bounds];
    l.tag = kTag; l.numberOfLines = 0; l.font = [UIFont systemFontOfSize:14];
    l.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    l.text = [@"🗑 " stringByAppendingString:cached];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cell addSubview:l];
}
static void InfinitokDMCollect(UIView *v, Class base, NSMutableArray *out, int depth) {
    if (depth > 12) return;
    if ([v isKindOfClass:base]) { [out addObject:v]; return; }
    for (UIView *sv in v.subviews) InfinitokDMCollect(sv, base, out, depth + 1);
}

static void InfinitokDMRefreshVisible(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class base = NSClassFromString(@"AWEIMMessageBaseCellView");
        if (!base) return;
        NSMutableArray *cells = [NSMutableArray array];
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) InfinitokDMCollect(w, base, cells, 0);
        }
        for (UIView *c in cells) {
            id vm = nil;
            for (NSString *k in @[@"cellViewModel", @"viewModel", @"vm", @"model"]) { vm = InfinitokObj(c, k); if (vm) break; }
            if (vm) InfinitokDMProcess(c, vm);
        }
        ITDebug("anti-delete", @"refreshed %lu visible message cells", (unsigned long)cells.count);
    });
}
static void InfinitokInstallDeletedOverlay(void) {
    Class base = NSClassFromString(@"AWEIMMessageBaseCellView");
    SEL sel = NSSelectorFromString(@"p_configWithCellViewModel:oldCellViewModel:");
    if (!base) { ITLog("anti-delete", @"AWEIMMessageBaseCellView missing"); return; }
    int n = 0;
    unsigned cnt = 0; Class *all = objc_copyClassList(&cnt);
    for (unsigned i = 0; i < cnt; i++) {
        Class c = all[i];
        BOOL sub = NO; for (Class s = c; s; s = class_getSuperclass(s)) if (s == base) { sub = YES; break; }
        if (!sub) continue;
        unsigned mc = 0; Method *ms = class_copyMethodList(c, &mc); BOOL own = NO;
        for (unsigned j = 0; j < mc; j++) if (method_getName(ms[j]) == sel) { own = YES; break; }
        free(ms);
        if (!own) continue;
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(c, sel, ^(UIView *cell, id vm, id old) {
            ((void (*)(id, SEL, id, id))orig)(cell, sel, vm, old);
            InfinitokDMProcess(cell, vm);
        });
        n++;
    }
    free(all);
    ITLog("anti-delete", @"deleted-message overlay hooked %d cell classes", n);
}

static BOOL InfinitokGhostBlocksURL(NSString *u) {
    if (![u isKindOfClass:[NSString class]] || !u.length) return NO;
    static NSArray *paths;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        paths = @[@"/tiktok/story/view/report/v1", @"/tiktok/v1/story/highlight/collection/view/report",
                  @"/tiktok/v1/activity_status/report", @"/aweme/v2/follow/feed/visit_report",
                  @"/tiktok/user/profile/view_record/add/v1"];
    });
    for (NSString *p in paths) if ([u containsString:p]) return YES;
    return NO;
}

static void InfinitokGhostNoop(NSString *clsName, NSString *selName, BOOL meta) {
    Class cls = NSClassFromString(clsName);
    if (!cls) { ITDebug("ghost", @"missing class %@", clsName); return; }
    SEL sel = NSSelectorFromString(selName);
    Class target = meta ? object_getClass(cls) : cls;
    if (!class_getInstanceMethod(target, sel)) { ITDebug("ghost", @"missing %@%@ %@", meta ? @"+" : @"-", clsName, selName); return; }
    __block IMP orig = NULL;

    orig = InfinitokReplaceInstance(target, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6) {
        if ([BHIManager ghostMode]) return 0;
        return orig ? ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, a1, a2, a3, a4, a5, a6) : 0;
    });
    ITDebug("ghost", @"hooked %@%@ %@", meta ? @"+" : @"-", clsName, selName);
}

static void InfinitokInstallGhostMode(void) {
    static const char *list[][3] = {
        {"TTKRichContentMarkReadService", "markAsRead:", "-"},
        {"TTKStoryManager", "_reportStoryRead:authorID:unlocked:retryCnt:", "-"},
        {"TTKStoryManager", "reportMarkRead:", "-"},
        {"TTKStoryManager", "retryReportMarkReadIfNeeded:", "-"},
        {"TTKStoryManager", "markStoryReaded:", "-"},
        {"TTKStoryNetworkService", "reportViewHighlightCollectionWithCollectionID:completion:", "+"},
        {"TTKGetUserStoryRequestModel", "setAllReadGids:", "-"},
        {"TTKStoryDetailEntranceRequestModel", "setAllReadGids:", "-"},
        {"TTKFriendsPlayedVideosRecorder", "recordForAwemeId:", "-"},
        {"TTKFriendsPlayedVideosRecorder", "insertOrReplaceRecordToDatabase:", "-"},
        {"TTKNoticeRepostItemListDataController", "postViewedAwemeIDsBeforeFeedContainerDisappear", "-"},
        {"TIMMessageMarkAsReadOperator", "clientMarkConversationAsRead:sendToServer:", "-"},
        {"TIMMessageMarkAsReadOperator", "clientMarkAllConversationsAsReadWithSendToServer:", "-"},
        {"TIMMessageMarkAsReadOperator", "clientBatchMarkConversationsAsRead:sendToServer:", "-"},
        {"TIMMessageMarkAsReadOperator", "clientMarkConversationAsRead:tillMessagePullIndex:serverMessageID:sendToServer:", "-"},
        {"TIMMessageMarkAsReadOperator", "serverMarkConversationAsRead:tillPullIndex:readBadgeCount:trackerReason:", "-"},
        {"TIMMessageMarkAsReadOperator", "p_sendBatchMarkReadRequestWithUpdate:context:cidToOldFakeUnreadCountMap:", "-"},
        {"TIMMessageMarkAsReadOperator", "p_clientUpdateReadIndexWithEntry:context:currentReadIndex:currentContentReadIndex:oldFakeUnreadCount:sendToServer:", "-"},
        {"TIMMessageMarkAsReadOperator", "p_clientBatchUpdateReadIndexWithUpdate:context:cidToOldFakeUnreadCountMap:sendToServer:", "-"},
        {"AWEIMActivityStatusReportManager", "p_reportActivityStatusIfNeededWithParams:", "-"},
        {"AWEIMActivityStatusReportManager", "p_reportActivityStatusWithParams:", "-"},
        {"AWEIMActivityStatusReportManager", "p_enableReportOnlineStatus", "-"},
        {"AWEIMActivityStatusReportManager", "reportActivityStatusForRegularIfNeeded", "-"},
        {"AWEIMActivityStatusReportManager", "reportActivityStatusForColdLaunchIfNeeded", "-"},
        {"AWEIMActivityStatusReportManager", "reportActivityStatusForSwitchAccountIfNeeded", "-"},
        {"AWEIMActivityStatusReportManager", "reportActivityStatusForEnableActivityStatusSwitchIfNeeded", "-"},
        {"AWEIMActivityStatusReportManager", "reportActivityStatusForEnableActivityStatusPushSwitchIfNeeded", "-"},
        {"AWEIMActivityStatusReportManager", "p_reportOnlineIfNeededWithScene:", "-"},
        {"AWEIMActivityStatusReportNetworkService", "requestReportCurrentUserActivityStatusWithType:sceneType:onCompletion:", "+"},
        {"TIMOInputStatusManager", "sendInputStatusWithConversationID:inputStatus:", "-"},
        {"TTKTypingFeatureTracker", "reportInputEventsWithContextParams:", "-"},
    };
    for (size_t i = 0; i < sizeof(list) / sizeof(list[0]); i++)
        InfinitokGhostNoop(@(list[i][0]), @(list[i][1]), list[i][2][0] == '+');

    Class req = NSClassFromString(@"AWENetworkRequest");
    SEL us = NSSelectorFromString(@"urlString");
    if (req && class_getInstanceMethod(req, us)) {
        __block IMP origURL = NULL;
        origURL = InfinitokReplaceInstance(req, us, ^id(id self_) {
            id u = ((id (*)(id, SEL))origURL)(self_, us);
            if ([BHIManager ghostMode] && InfinitokGhostBlocksURL(u)) {
                ITDebug("ghost", @"blocked request %@", u);
                return @"infinitok-privacy-blocked://local";
            }
            return u;
        });
        SEL rs = NSSelectorFromString(@"shouldRetryWithError:");
        if (class_getInstanceMethod(req, rs)) {
            __block IMP origRetry = NULL;
            origRetry = InfinitokReplaceInstance(req, rs, ^BOOL(id self_, id err) {
                if ([BHIManager ghostMode]) {
                    id u = ((id (*)(id, SEL))origURL)(self_, us);
                    if (InfinitokGhostBlocksURL(u)) return NO;
                }
                return ((BOOL (*)(id, SEL, id))origRetry)(self_, rs, err);
            });
        }
        ITLog("ghost", @"AWENetworkRequest URL blocking installed");
    } else {
        ITLog("ghost", @"AWENetworkRequest urlString missing");
    }
}

static void InfinitokNoopWhen(NSString *clsName, NSString *selName, BOOL meta, BOOL (^gate)(void)) {
    Class cls = NSClassFromString(clsName);
    if (!cls) { ITLog("anti-delete", @"class %@ missing", clsName); return; }
    SEL sel = NSSelectorFromString(selName);
    Class target = meta ? object_getClass(cls) : cls;
    if (!class_getInstanceMethod(target, sel)) { ITLog("anti-delete", @"%@ %@ missing", clsName, selName); return; }
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(target, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6) {
        if (gate()) {
            ITDebug("anti-delete", @"blocked -[%@ %@] a1=%lu", clsName, selName, (unsigned long)a1);
            if ([selName hasPrefix:@"performRecall"] && a1) {
                if (!sInfinitokRecalledIDs) sInfinitokRecalledIDs = [NSMutableSet set];
                [sInfinitokRecalledIDs addObject:[NSString stringWithFormat:@"%lu", (unsigned long)a1]]; InfinitokDMSave();
            }
            return 0;
        }
        return orig ? ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, a1, a2, a3, a4, a5, a6) : 0;
    });
    ITLog("anti-delete", @"hooked -[%@ %@]", clsName, selName);
}

static void InfinitokGuardPublish(NSString *cn, NSString *sn, BOOL unused) {
    Class c = NSClassFromString(cn);
    SEL sel = NSSelectorFromString(sn);
    Method m = c ? class_getInstanceMethod(c, sel) : NULL;
    if (!m) { ITLog("repost", @"%@ %@ missing", cn, sn); return; }
    __block IMP orig = NULL;
    orig = InfinitokReplaceInstance(c, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6) {
        if (![BHIManager confirmRepost] || CFAbsoluteTimeGetCurrent() < sInfinitokRepostBypassUntil || ![NSThread isMainThread] || !self_)
            return orig ? ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, a1, a2, a3, a4, a5, a6) : 0;
        uintptr_t args[6] = {a1, a2, a3, a4, a5, a6};
        NSMutableArray *keep = [NSMutableArray array];
        id completion = nil;
        unsigned n = method_getNumberOfArguments(m);
        for (unsigned i = 2; i < n && i < 8; i++) {
            char *t = method_copyArgumentType(m, i);
            BOOL isBlock = t && t[0] == '@' && t[1] == '?';
            BOOL isObj = t && t[0] == '@' && !isBlock;
            if (t) free(t);
            if (isBlock && args[i - 2]) {
                id copy = [(__bridge id)(void *)args[i - 2] copy];
                [keep addObject:copy];
                args[i - 2] = (uintptr_t)(__bridge void *)copy;
                completion = copy;
            } else if (isObj && args[i - 2]) {
                [keep addObject:(__bridge id)(void *)args[i - 2]];
            }
        }
        id selfKeep = self_;
        uintptr_t p0 = args[0], p1 = args[1], p2 = args[2], p3 = args[3], p4 = args[4], p5 = args[5];
        ITDebug("repost", @"publish intercepted (%@ %@) — asking", cn, sn);
        showConfirmationWithCancel(^{
            ITDebug("repost", @"publish confirmed — replaying");
            sInfinitokRepostBypassUntil = CFAbsoluteTimeGetCurrent() + 8.0;
            if (orig) ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))orig)(selfKeep, sel, p0, p1, p2, p3, p4, p5);
            (void)keep;
        }, ^{
            ITDebug("repost", @"publish cancelled by user");
            if (completion) { @try { ((void (^)(uintptr_t, uintptr_t))completion)(0, 0); } @catch (__unused id e) {} }
            (void)keep;
        });
        return 0;
    });
    ITLog("repost", @"guarding -[%@ %@]", cn, sn);
}

static NSString *InfinitokStripLeadingMention(NSString *t) {
    if (![t isKindOfClass:[NSString class]] || ![t hasPrefix:@"@"]) return t;
    NSRange r = [t rangeOfString:@"^@\\S+\\s+" options:NSRegularExpressionSearch];
    if (r.location == 0 && r.length < t.length) return [t substringFromIndex:r.length];
    return t;
}
static void InfinitokInstallCopyNoUsername(void) {
    Class c = NSClassFromString(@"TTKCommentCopyOperation");
    if (!c) { ITLog("copy", @"TTKCommentCopyOperation missing"); return; }
    Class meta = object_getClass(c);

    SEL s2 = NSSelectorFromString(@"copyContent:identifier:");
    SEL s3 = NSSelectorFromString(@"copyContent:tokenText:identifier:");
    for (NSValue *sv in @[[NSValue valueWithPointer:s2], [NSValue valueWithPointer:s3]]) {
        SEL sel = (SEL)[sv pointerValue];
        Method m = class_getInstanceMethod(meta, sel);
        if (!m) { ITLog("copy", @"+%s missing", sel_getName(sel)); continue; }
        unsigned n = method_getNumberOfArguments(m);
        char *t2 = method_copyArgumentType(m, 2); BOOL firstObj = t2 && t2[0] == '@'; if (t2) free(t2);
        if (!firstObj) { ITLog("copy", @"+%s first arg not an object — skipped", sel_getName(sel)); continue; }
        __block IMP orig = NULL;
        if (n == 4) {
            orig = InfinitokReplaceInstance(meta, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2) {
                uintptr_t x1 = a1; CFTypeRef held = NULL;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"copy_comment_no_username"] && a1 > 0x1000) {
                    id o = (__bridge id)(void *)a1;
                    if ([o isKindOfClass:[NSString class]]) { NSString *ns = InfinitokStripLeadingMention(o); if (ns != o) { held = CFBridgingRetain(ns); x1 = (uintptr_t)held; } }
                }
                uintptr_t rr = ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t))orig)(self_, sel, x1, a2); if (held) CFRelease(held); return rr;
            });
        } else if (n == 5) {
            orig = InfinitokReplaceInstance(meta, sel, ^uintptr_t(id self_, uintptr_t a1, uintptr_t a2, uintptr_t a3) {
                uintptr_t x1 = a1; CFTypeRef held = NULL;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"copy_comment_no_username"] && a1 > 0x1000) {
                    id o = (__bridge id)(void *)a1;
                    if ([o isKindOfClass:[NSString class]]) { NSString *ns = InfinitokStripLeadingMention(o); if (ns != o) { held = CFBridgingRetain(ns); x1 = (uintptr_t)held; } }
                }
                uintptr_t rr = ((uintptr_t (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t))orig)(self_, sel, x1, a2, a3); if (held) CFRelease(held); return rr;
            });
        } else continue;
        ITLog("copy", @"hooked +[TTKCommentCopyOperation %s]", sel_getName(sel));
    }
}
static void InfinitokInstallRepostGuard(void) {

    InfinitokGuardPublish(@"TTKUpvoteShareChannel", @"publishUpvoteClicked:withCompletion:", YES);
    InfinitokGuardPublish(@"TTKPlayInteractionUpvoteManager", @"publishWithAction:", YES);
}
static void InfinitokInstallAntiDelete(void) {
    InfinitokInstallRepostGuard();
    InfinitokInstallCopyNoUsername();
    BOOL (^on)(void) = ^BOOL{ return [BHIManager antiDeleteMessages]; };
    InfinitokNoopWhen(@"TIMCommandActorRecallMessage", @"performRecallMessageWithServerMessageID:recallUID:context:", NO, on);
    InfinitokNoopWhen(@"TIMStatusMessageHandlerRecallMessage", @"handleStatusMessage:entity:value:context:", NO, on);
    InfinitokNoopWhen(@"TIMMessageUpdater", @"scanAndCleanupRecalledMessages", NO, on);

    InfinitokNoopWhen(@"TIMMessageUpdater", @"startUndoRecallCleanup", NO, on);
    InfinitokNoopWhen(@"TIMStatusMessageHandlerDeleteMessage", @"handleStatusMessage:entity:value:context:", NO, on);
    InfinitokNoopWhen(@"TIMStatusMessageHandlerHideViolativeMessage", @"handleStatusMessage:entity:value:context:", NO, on);
    for (NSString *cn in @[@"_TtC17TikTokIMImplSwift22AWEIMMessageChangeInfo", @"_TtC17TikTokIMFlowModel26TTKIMFlowMessageChangeInfo"]) {
        Class c = NSClassFromString(cn); SEL sel = NSSelectorFromString(@"hasUpdatedToRecalled");
        if (!c || !class_getInstanceMethod(c, sel)) { ITLog("anti-delete", @"%@ hasUpdatedToRecalled missing", cn); continue; }
        __block IMP o2 = NULL;
        o2 = InfinitokReplaceInstance(c, sel, ^BOOL(id self_) {
            BOOL was = o2 ? ((BOOL (*)(id, SEL))o2)(self_, sel) : NO;
            if (was && [BHIManager antiDeleteMessages]) { ITDebug("anti-delete", @"%@ hasUpdatedToRecalled cleared", cn); return NO; }
            return was;
        });
        ITLog("anti-delete", @"hooked -[%@ hasUpdatedToRecalled]", cn);
    }
    for (NSString *c in @[@"TIMOMessage", @"AWEIMMessage", @"TIMMessageORM"]) {
        Class cls = NSClassFromString(c);
        SEL sel = NSSelectorFromString(@"recalled");
        Method m = cls ? class_getInstanceMethod(cls, sel) : NULL;
        char *rt = m ? method_copyReturnType(m) : NULL;
        BOOL ok = rt && (rt[0] == 'B' || rt[0] == 'c');
        if (rt) free(rt);
        if (!ok) { ITLog("anti-delete", @"%@ recalled getter unavailable", c); continue; }
        __block IMP orig = NULL;
        orig = InfinitokReplaceInstance(cls, sel, ^BOOL(id self_) {
            if ([BHIManager antiDeleteMessages]) return NO;
            return orig ? ((BOOL (*)(id, SEL))orig)(self_, sel) : NO;
        });
        ITLog("anti-delete", @"hooked -[%@ recalled]", c);

        SEL ssel = NSSelectorFromString(@"setRecalled:");
        if (class_getInstanceMethod(cls, ssel)) {
            __block IMP sorig = NULL;
            sorig = InfinitokReplaceInstance(cls, ssel, ^(id self_, uintptr_t a1) {
                BOOL yes = (a1 & 0xff) != 0;
                if (yes && [BHIManager antiDeleteMessages]) {
                    if (!sInfinitokRecalledIDs) sInfinitokRecalledIDs = [NSMutableSet set];
                    for (NSString *k in @[@"serverMessageID", @"messageID", @"localID", @"identifier", @"uuid", @"clientMessageID"]) {
                        NSString *v = InfinitokSafeDesc(self_, k);
                        if (v.length && ![v isEqualToString:@"0"]) { [sInfinitokRecalledIDs addObject:v]; InfinitokDMSave(); }
                    }
                    ITDebug("anti-delete", @"setRecalled:YES suppressed on %@ ids=%@", NSStringFromClass([self_ class]), sInfinitokRecalledIDs);
                    InfinitokDMRefreshVisible();
                    a1 = 0;
                }
                if (sorig) ((void (*)(id, SEL, uintptr_t))sorig)(self_, ssel, a1);
            });
            ITLog("anti-delete", @"hooked -[%@ setRecalled:]", c);
        }
    }
    {
        Class mc = NSClassFromString(@"TTKFeedPausePanelManager");
        SEL fs = NSSelectorFromString(@"p_canShowConfigArray");
        Method fm = mc ? class_getInstanceMethod(mc, fs) : NULL;
        char *frt = fm ? method_copyReturnType(fm) : NULL; BOOL isObj = frt && frt[0] == '@'; if (frt) free(frt);
        if (isObj && method_getNumberOfArguments(fm) == 2) {
            __block IMP forig = NULL;
            forig = InfinitokReplaceInstance(mc, fs, ^id(id self_) {
                id r = forig ? ((id (*)(id, SEL))forig)(self_, fs) : nil;
                if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_find_similar"] || ![r isKindOfClass:[NSArray class]]) return r;
                NSMutableArray *out = [NSMutableArray array];
                for (id cfg in (NSArray *)r) {
                    NSString *cn = NSStringFromClass([cfg class]);
                    if ([cn containsString:@"SimilarVideos"] || [cn containsString:@"VisualSearch"]) {
                        if (InfinitokFirstTime([@"pp|" stringByAppendingString:cn])) ITDebug("pausepanel", @"removed %@ from pause panel", cn);
                        continue;
                    }
                    [out addObject:cfg];
                }
                return out;
            });
            ITLog("pausepanel", @"hooked TTKFeedPausePanelManager p_canShowConfigArray");
        } else ITLog("pausepanel", @"p_canShowConfigArray unavailable");
    }
    InfinitokNoopWhen(@"TTKFeedVisualSearchManager", @"showVisualPaneIfNeedWithAweme:inputValue:", NO, ^BOOL{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_find_similar"]; });
    BOOL (^noSimilar)(void) = ^BOOL{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_find_similar"]; };
    InfinitokNoopWhen(@"TTKFeedPausePanelSimilarVideosConfig", @"canShowActionWithModel:interactionContext:", NO, noSimilar);
    InfinitokNoopWhen(@"TTKFeedPausePanelVisualSearchConfig", @"canShowActionWithModel:interactionContext:", NO, noSimilar);
}

static void InfinitokInstallPortFeatures(void) {
    InfinitokInstallAntiDelete();
    InfinitokInstallGhostMode();
    InfinitokInstallFullComments();
    InfinitokInstallNavHiding();
    InfinitokRegisterSavedFont();
    InfinitokInstallDeletedOverlay();
}

%ctor {
    jailbreakPaths = @[
        @"/Applications/Cydia.app", @"/Applications/blackra1n.app",
        @"/Applications/FakeCarrier.app", @"/Applications/Icy.app",
        @"/Applications/IntelliScreen.app", @"/Applications/MxTube.app",
        @"/Applications/RockApp.app", @"/Applications/SBSettings.app", @"/Applications/WinterBoard.app",
        @"/.cydia_no_stash", @"/.installed_unc0ver", @"/.bootstrapped_electra",
        @"/usr/libexec/cydia/firmware.sh", @"/usr/libexec/ssh-keysign",
        @"/usr/sbin/sshd", @"/usr/bin/sshd", @"/usr/libexec/sftp-server",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/Library/MobileSubstrate/DynamicLibraries",
        @"/Library/LaunchDaemons/com.ikey.bbot.plist",
        @"/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        @"/Library/PreferenceBundles/LibertyPref.bundle",
        @"/etc/apt", @"/etc/ssh/sshd_config",
        @"/bin/bash", @"/bin/sh", @"/bin/sftp",
        @"/private/var/lib/apt", @"/private/var/lib/cydia",
        @"/private/var/mobile/Library/SBSettings/Themes",
        @"/private/var/stash", @"/private/var/tmp/cydia.log",
        @"/var/cache/apt", @"/var/lib/apt", @"/var/lib/cydia", @"/var/log/syslog",
        @"/var/tmp/cydia.log"
    ];
    ITLog("boot", @"Infinitok loaded into %@ (debug logging %@)", [[NSBundle mainBundle] bundleIdentifier],
          InfinitokDebugLoggingEnabled() ? @"on" : @"off");

    InfinitokLogClassExists("repost", @[@"TTKRepostButtonView", @"TTKPlayInteractionUpvoteManager", @"TTKLiveRepostButtonView",
                                        @"TTKPlayInteractionUpvoteElement", @"TTKUpvoteShareChannel"]);
    InfinitokLogClassExists("tako", @[@"TikTokTakoService", @"TTKFeedRightTakoElement", @"TTKFeedFYPBottomRightTakoEntranceComponent",
                                      @"TTKFeedDetailTakoButton", @"FeedTabCornerTakoItem"]);
    InfinitokLogClassExists("hide", @[@"AWETabBarPlusButton", @"AWEPlayInteractionDummyDownloadBarElement",
                                      @"AWEPlayInteractionAIGCLabelElement", @"AWELiveFeedEntranceView"]);

    InfinitokInstallProfileBackgroundHooks();
    InfinitokInstallPortFeatures();
    InfinitokInstallABExperiments();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InfinitokForceRemoveAccountLimit();
        InfinitokForceBioLinkSafariRedirect();
    });
}
