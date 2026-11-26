#import "CleanIdentityPrefs.h"

@implementation CleanIdentityPrefs

+ (void)load {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"cleanidentity_hide_comment_usernames": @YES,
        @"cleanidentity_hide_comment_avatars": @YES,
        @"cleanidentity_hide_video_usernames": @YES,
        @"cleanidentity_hide_video_avatars": @YES,
        @"cleanidentity_hide_music_disc": @YES
    }];
}
+ (BOOL)hideCommentUsernames {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_comment_usernames"];
}
+ (BOOL)hideCommentAvatars {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_comment_avatars"];
}
+ (BOOL)hideVideoUsernames {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_video_usernames"];
}
+ (BOOL)hideVideoAvatars {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_video_avatars"];
}
+ (BOOL)hideMusicDisc {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanidentity_hide_music_disc"];
}
@end
