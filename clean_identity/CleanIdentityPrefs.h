#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Standalone, default-ON settings. This header does not import or link DouX.
@interface CleanIdentityPrefs : NSObject
+ (BOOL)hideCommentUsernames;
+ (BOOL)hideAllAvatars;
+ (BOOL)hideCommentAvatars;
+ (BOOL)hideVideoUsernames;
+ (BOOL)hideVideoAvatars;
+ (BOOL)hideMusicDisc;
@end

// Lightweight declarations only for classes we hook at runtime.
@interface AWECommentPanelCell : UITableView
@end

@interface AWEPlayInteractionAuthorUserNameButton : UIView
@end

@interface AWEBaseElementView : UIView
@end

@interface AWEAdAvatarView : UIView
@end

@interface AWEPlayInteractionUserAvatarView : UIView
@end

@interface AWEPlayInteractionAvatarView : UIView
@end

@interface AWEPlayInteractionUserProfileContainerView : UIView
@end

@interface AWEPlayInteractionUserAvatarOptElementElement : NSObject
@end

@interface AWEPlayInteractionMusicView : UIView
@end

@interface TTTAttributedLabel : UILabel
@end

@interface TUXLabel : UILabel
@end

@interface AWEIMMessageBaseCellView : UIView
@end
