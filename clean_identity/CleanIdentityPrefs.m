#import "CleanIdentityPrefs.h"

@implementation CleanIdentityPrefs
+ (void)load {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // Preserve a user's old choice if both switches were disabled.
    if (![defaults objectForKey:@"cleanidentity_hide_all_avatars"]) {
        id video = [defaults objectForKey:@"cleanidentity_hide_video_avatars"];
        id comment = [defaults objectForKey:@"cleanidentity_hide_comment_avatars"];
        if (video || comment)
            [defaults setBool:(!video || [video boolValue] || !comment || [comment boolValue])
                       forKey:@"cleanidentity_hide_all_avatars"];
    }
    [defaults registerDefaults:@{
        @"cleanidentity_hide_comment_usernames": @YES,
        @"cleanidentity_hide_all_avatars": @YES,
        @"cleanidentity_hide_video_usernames": @YES,
        @"cleanidentity_hide_music_disc": @YES
    }];
}
+ (BOOL)hideAllAvatars {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_all_avatars"];
}
+ (BOOL)hideCommentAvatars { return [self hideAllAvatars]; }
+ (BOOL)hideVideoAvatars { return [self hideAllAvatars]; }
+ (BOOL)hideCommentUsernames {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_comment_usernames"];
}
+ (BOOL)hideVideoUsernames {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_video_usernames"];
}
+ (BOOL)hideMusicDisc {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_music_disc"];
}
@end
