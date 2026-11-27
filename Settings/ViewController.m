
#import "ViewController.h"
#import "CountryTable.h"
#import "LiveActions.h"
#import "PlaybackSpeed.h"
#import "Localization.h"
#import "InfinitokLog.h"
#import "ContributorsViewController.h"
#import "AppIconViewController.h"
#import <QuartzCore/QuartzCore.h>

typedef NS_ENUM(NSInteger, InfinitokSettingsRowType) {
    InfinitokSettingsRowTypeSwitch,
    InfinitokSettingsRowTypeText,
    InfinitokSettingsRowTypeRegionNav,
    InfinitokSettingsRowTypeResetRegion,
    InfinitokSettingsRowTypeLiveActionNav,
    InfinitokSettingsRowTypePlaybackSpeedNav,
    InfinitokSettingsRowTypeMediaVaultNav,
    InfinitokSettingsRowTypeAccentColorNav,
    InfinitokSettingsRowTypeDeveloperLink,
    InfinitokSettingsRowTypeExportDebugLog,
    InfinitokSettingsRowTypeClearDebugLog,
    InfinitokSettingsRowTypeContributorsNav,
    InfinitokSettingsRowTypeAppIconNav,
    InfinitokSettingsRowTypeHideUIButtonMode,
    InfinitokSettingsRowTypeAction,
};

extern void InfinitokPerformSettingsAction(NSString *action, UIViewController *presenter);

@interface InfinitokSettingsRow : NSObject
@property (nonatomic, assign) InfinitokSettingsRowType type;
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *detailKey;

@property (nonatomic, copy) NSString *staticTitle;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, assign) NSInteger textFieldTag;
@end

@implementation InfinitokSettingsRow
@end

@interface InfinitokSettingsSection : NSObject
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSArray<InfinitokSettingsRow *> *rows;
@end

@implementation InfinitokSettingsSection
@end

static NSArray<InfinitokSettingsSection *> *InfinitokBuildSettingsSections(void) {
    NSMutableArray<InfinitokSettingsSection *> *sections = [NSMutableArray array];

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.feed";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_ads";
            row.titleKey = @"settings.hide_ads.title";
            row.detailKey = @"settings.hide_ads.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"download_button";
            row.titleKey = @"settings.download_button.title";
            row.detailKey = @"settings.download_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"share_sheet";
            row.titleKey = @"settings.share_sheet.title";
            row.detailKey = @"settings.share_sheet.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"remove_watermark";
            row.titleKey = @"settings.remove_watermark.title";
            row.detailKey = @"settings.remove_watermark.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"remove_elements_button";
            row.titleKey = @"settings.remove_elements_button.title";
            row.detailKey = @"settings.remove_elements_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"stop_play";
            row.titleKey = @"settings.stop_play.title";
            row.detailKey = @"settings.stop_play.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"auto_play";
            row.titleKey = @"settings.auto_play.title";
            row.detailKey = @"settings.auto_play.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"show_porgress_bar";
            row.titleKey = @"settings.show_porgress_bar.title";
            row.detailKey = @"settings.show_porgress_bar.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"buttons_on_right";
            row.titleKey = @"settings.buttons_on_right.title";
            row.detailKey = @"settings.buttons_on_right.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeHideUIButtonMode;
            row.titleKey = @"settings.hide_ui_button_mode.title";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"show_username";
            row.titleKey = @"settings.show_username.title";
            row.detailKey = @"settings.show_username.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"disable_unsensitive";
            row.titleKey = @"settings.disable_unsensitive.title";
            row.detailKey = @"settings.disable_unsensitive.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"disable_warnings";
            row.titleKey = @"settings.disable_warnings.title";
            row.detailKey = @"settings.disable_warnings.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"disable_live";
            row.titleKey = @"settings.disable_live.title";
            row.detailKey = @"settings.disable_live.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"skip_recommnedations";
            row.titleKey = @"settings.skip_recommnedations.title";
            row.detailKey = @"settings.skip_recommnedations.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.profile";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"save_profile";
            row.titleKey = @"settings.save_profile.title";
            row.detailKey = @"settings.save_profile.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"copy_profile_information";
            row.titleKey = @"settings.copy_profile_information.title";
            row.detailKey = @"settings.copy_profile_information.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"video_like_count";
            row.titleKey = @"settings.video_like_count.title";
            row.detailKey = @"settings.video_like_count.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"video_upload_date";
            row.titleKey = @"settings.video_upload_date.title";
            row.detailKey = @"settings.video_upload_date.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.confirm";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"like_confirm";
            row.titleKey = @"settings.like_confirm.title";
            row.detailKey = @"settings.like_confirm.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"like_comment_confirm";
            row.titleKey = @"settings.like_comment_confirm.title";
            row.detailKey = @"settings.like_comment_confirm.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"dislike_comment_confirm";
            row.titleKey = @"settings.dislike_comment_confirm.title";
            row.detailKey = @"settings.dislike_comment_confirm.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"follow_confirm";
            row.titleKey = @"settings.follow_confirm.title";
            row.detailKey = @"settings.follow_confirm.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"confirm_repost";
            row.titleKey = @"extra.confirm_repost.title";
            row.detailKey = @"extra.confirm_repost.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"confirm_favorite";
            row.titleKey = @"extra.confirm_favorite.title";
            row.detailKey = @"extra.confirm_favorite.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"confirm_send_comment";
            row.titleKey = @"extra.confirm_send_comment.title";
            row.detailKey = @"extra.confirm_send_comment.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"dm_delete_confirmation";
            row.titleKey = @"extra.dm_delete_confirmation.title";
            row.detailKey = @"extra.dm_delete_confirmation.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.region";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"en_region";
            row.titleKey = @"settings.en_region.title";
            row.detailKey = @"settings.en_region.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeRegionNav;
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeResetRegion;
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.live_button";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"en_livefunc";
            row.titleKey = @"settings.en_livefunc.title";
            row.detailKey = @"settings.en_livefunc.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeLiveActionNav;
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.playback_speed";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"playback_en";
            row.titleKey = @"settings.playback_en.title";
            row.detailKey = @"settings.playback_en.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypePlaybackSpeedNav;
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"persistent_progress_slider";
            row.titleKey = @"extra.persistent_progress_slider.title";
            row.detailKey = @"extra.persistent_progress_slider.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"faster_feed_scrolling";
            row.titleKey = @"extra.faster_feed_scrolling.title";
            row.detailKey = @"extra.faster_feed_scrolling.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.privacy";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"ghost_mode";
            row.titleKey = @"extra.ghost_mode.title";
            row.detailKey = @"extra.ghost_mode.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_feed_tabs";
            row.titleKey = @"extra.hide_feed_tabs.title";
            row.detailKey = @"extra.hide_feed_tabs.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_tab_slot_second";
            row.titleKey = @"extra.hide_tab_slot_second.title";
            row.detailKey = @"extra.hide_tab_slot_second.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_tab_slot_last";
            row.titleKey = @"extra.hide_tab_slot_last.title";
            row.detailKey = @"extra.hide_tab_slot_last.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"full_length_comments";
            row.titleKey = @"extra.full_length_comments.title";
            row.detailKey = @"extra.full_length_comments.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeAction;
            row.defaultsKey = @"font_import";
            row.titleKey = @"extra.font_import.title";
            row.detailKey = @"extra.font_import.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeAction;
            row.defaultsKey = @"font_reset";
            row.titleKey = @"extra.font_reset.title";
            row.detailKey = @"extra.font_reset.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeAction;
            row.defaultsKey = @"delete_all_reposts";
            row.titleKey = @"extra.delete_all_reposts.title";
            row.detailKey = @"extra.delete_all_reposts.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.messages";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"anti_delete_messages";
            row.titleKey = @"extra.anti_delete_messages.title";
            row.detailKey = @"extra.anti_delete_messages.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"disable_phone_binding_popup";
            row.titleKey = @"extra.disable_phone_binding_popup.title";
            row.detailKey = @"extra.disable_phone_binding_popup.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"save_dm_media";
            row.titleKey = @"extra.save_dm_media.title";
            row.detailKey = @"extra.save_dm_media.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"lock_chats";
            row.titleKey = @"extra.lock_chats.title";
            row.detailKey = @"extra.lock_chats.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.media";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"save_comment_media";
            row.titleKey = @"extra.save_comment_media.title";
            row.detailKey = @"extra.save_comment_media.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"story_download";
            row.titleKey = @"extra.story_download.title";
            row.detailKey = @"extra.story_download.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"story_view_count";
            row.titleKey = @"extra.story_view_count.title";
            row.detailKey = @"extra.story_view_count.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"post_stats";
            row.titleKey = @"extra.post_stats.title";
            row.detailKey = @"extra.post_stats.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"save_to_vault";
            row.titleKey = @"extra.save_to_vault.title";
            row.detailKey = @"extra.save_to_vault.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeMediaVaultNav;
            row.titleKey = @"extra.media_vault.title";
            row.detailKey = @"extra.media_vault.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.appearance";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"oled_mode";
            row.titleKey = @"extra.oled_mode.title";
            row.detailKey = @"extra.oled_mode.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"custom_accent_color";
            row.titleKey = @"extra.custom_accent_color.title";
            row.detailKey = @"extra.custom_accent_color.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeAccentColorNav;
            row.titleKey = @"extra.pick_accent_color.title";
            row.detailKey = @"extra.pick_accent_color.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeAppIconNav;
            row.titleKey = @"settings.app_icon.title";
            row.detailKey = @"settings.app_icon.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"force_new_profile_ui";
            row.titleKey = @"extra.force_new_profile_ui.title";
            row.detailKey = @"extra.force_new_profile_ui.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"profile_background_enabled";
            row.titleKey = @"extra.profile_background_enabled.title";
            row.detailKey = @"extra.profile_background_enabled.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"enable_voice_messages";
            row.titleKey = @"extra.enable_voice_messages.title";
            row.detailKey = @"extra.enable_voice_messages.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"remove_account_limit";
            row.titleKey = @"extra.remove_account_limit.title";
            row.detailKey = @"extra.remove_account_limit.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"show_region_badge";
            row.titleKey = @"extra.show_region_badge.title";
            row.detailKey = @"extra.show_region_badge.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.feed_content";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_ai_videos";
            row.titleKey = @"extra.hide_ai_videos.title";
            row.detailKey = @"extra.hide_ai_videos.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_caption";
            row.titleKey = @"extra.hide_caption.title";
            row.detailKey = @"extra.hide_caption.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_comments_button";
            row.titleKey = @"extra.hide_comments_button.title";
            row.detailKey = @"extra.hide_comments_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_likes_button";
            row.titleKey = @"extra.hide_likes_button.title";
            row.detailKey = @"extra.hide_likes_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_music";
            row.titleKey = @"extra.hide_music.title";
            row.detailKey = @"extra.hide_music.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_share_button";
            row.titleKey = @"extra.hide_share_button.title";
            row.detailKey = @"extra.hide_share_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_search_button";
            row.titleKey = @"extra.hide_search_button.title";
            row.detailKey = @"extra.hide_search_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_account_suggestions";
            row.titleKey = @"extra.hide_account_suggestions.title";
            row.detailKey = @"extra.hide_account_suggestions.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_live_button";
            row.titleKey = @"extra.hide_live_button.title";
            row.detailKey = @"extra.hide_live_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_download_button_native";
            row.titleKey = @"extra.hide_download_button_native.title";
            row.detailKey = @"extra.hide_download_button_native.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"enable_comment_repost";
            row.titleKey = @"extra.enable_comment_repost.title";
            row.detailKey = @"extra.enable_comment_repost.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_find_similar";
            row.titleKey = @"extra.hide_find_similar.title";
            row.detailKey = @"extra.hide_find_similar.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_tab_bar_text";
            row.titleKey = @"extra.hide_tab_bar_text.title";
            row.detailKey = @"extra.hide_tab_bar_text.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_video_button";
            row.titleKey = @"extra.hide_video_button.title";
            row.detailKey = @"extra.hide_video_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"hide_tako_button";
            row.titleKey = @"extra.hide_tako_button.title";
            row.detailKey = @"extra.hide_tako_button.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"show_only_favorites";
            row.titleKey = @"extra.show_only_favorites.title";
            row.detailKey = @"extra.show_only_favorites.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"exact_follower_count";
            row.titleKey = @"extra.exact_follower_count.title";
            row.detailKey = @"extra.exact_follower_count.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"exact_view_count";
            row.titleKey = @"extra.exact_view_count.title";
            row.detailKey = @"extra.exact_view_count.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"exact_timestamp";
            row.titleKey = @"extra.exact_timestamp.title";
            row.detailKey = @"extra.exact_timestamp.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"translate_comments";
            row.titleKey = @"extra.translate_comments.title";
            row.detailKey = @"extra.translate_comments.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"copy_comment_no_username";
            row.titleKey = @"extra.copy_comment_no_username.title";
            row.detailKey = @"extra.copy_comment_no_username.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.fake_profile";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"en_fake";
            row.titleKey = @"settings.en_fake.title";
            row.detailKey = @"settings.en_fake.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeText;
            row.defaultsKey = @"follower_count";
            row.textFieldTag = 2;
            row.staticTitle = @"Follower:";
            row.placeholder = @"Enter follower count";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeText;
            row.defaultsKey = @"following_count";
            row.textFieldTag = 1;
            row.staticTitle = @"Following:";
            row.placeholder = @"Enter following count";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeText;
            row.defaultsKey = @"like_count";
            row.textFieldTag = 3;
            row.staticTitle = @"Likes:";
            row.placeholder = @"Enter like count";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"fake_verify";
            row.titleKey = @"settings.fake_verify.title";
            row.detailKey = @"settings.fake_verify.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"extended_bio";
            row.titleKey = @"settings.extended_bio.title";
            row.detailKey = @"settings.extended_bio.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"extendedComment";
            row.titleKey = @"settings.extended_comment.title";
            row.detailKey = @"settings.extended_comment.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"upload_hd";
            row.titleKey = @"settings.upload_hd.title";
            row.detailKey = @"settings.upload_hd.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.security";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"lock_favorites";
            row.titleKey = @"extra.lock_favorites.title";
            row.detailKey = @"extra.lock_favorites.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"padlock";
            row.titleKey = @"settings.padlock.title";
            row.detailKey = @"settings.padlock.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.other";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"openInBrowser";
            row.titleKey = @"settings.open_in_browser.title";
            row.detailKey = @"settings.open_in_browser.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"fast_logout";
            row.titleKey = @"extra.fast_logout.title";
            row.detailKey = @"extra.fast_logout.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"auto_clear_history";
            row.titleKey = @"extra.auto_clear_history.title";
            row.detailKey = @"extra.auto_clear_history.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"disable_feed_refresh";
            row.titleKey = @"extra.disable_feed_refresh.title";
            row.detailKey = @"extra.disable_feed_refresh.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"debug_logging";
            row.titleKey = @"settings.debug_logging.title";
            row.detailKey = @"settings.debug_logging.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeExportDebugLog;
            row.titleKey = @"settings.export_debug_log.title";
            row.detailKey = @"settings.export_debug_log.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeClearDebugLog;
            row.titleKey = @"settings.clear_debug_log.title";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.developer";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeDeveloperLink;
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeContributorsNav;
            row.titleKey = @"settings.contributors.title";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    {
        InfinitokSettingsSection *section = [InfinitokSettingsSection new];
        section.titleKey = @"section.clean_identity";
        NSMutableArray<InfinitokSettingsRow *> *rows = [NSMutableArray array];
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"cleanidentity_hide_video_usernames";
            row.titleKey = @"clean_identity.video_usernames.title";
            row.detailKey = @"clean_identity.video_usernames.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"cleanidentity_hide_all_avatars";
            row.titleKey = @"clean_identity.all_avatars.title";
            row.detailKey = @"clean_identity.all_avatars.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"cleanidentity_hide_music_disc";
            row.titleKey = @"clean_identity.music_disc.title";
            row.detailKey = @"clean_identity.music_disc.detail";
            [rows addObject:row];
        }
        {
            InfinitokSettingsRow *row = [InfinitokSettingsRow new];
            row.type = InfinitokSettingsRowTypeSwitch;
            row.defaultsKey = @"cleanidentity_hide_comment_usernames";
            row.titleKey = @"clean_identity.comment_usernames.title";
            row.detailKey = @"clean_identity.comment_usernames.detail";
            [rows addObject:row];
        }
        section.rows = rows;
        [sections addObject:section];
    }

    return sections;
}
@interface ViewController () <UISearchResultsUpdating, UISearchControllerDelegate>
@property (nonatomic, strong) UITableView *staticTable;
@property (nonatomic, copy) NSArray<InfinitokSettingsSection *> *sections;
@property (nonatomic, copy) NSArray<InfinitokSettingsSection *> *filteredSections;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL infinitokIsDismissing;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.sections = InfinitokBuildSettingsSections();

    self.title = IKLocalize(@"settings.title");

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};

        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(infinitokDismissSettings)];
    self.navigationItem.leftBarButtonItem = backButton;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.delegate = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;

    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.searchBar.placeholder = IKLocalize(@"settings.search.placeholder");
    self.definesPresentationContext = YES;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    self.staticTable = [[UITableView alloc] initWithFrame:CGRectZero];
    self.staticTable.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.staticTable];
    [NSLayoutConstraint activateConstraints:@[
        [self.staticTable.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.staticTable.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.staticTable.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.staticTable.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.staticTable.dataSource = self;
    self.staticTable.delegate = self;
    self.staticTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(regionSelected:)
                                                 name:@"RegionSelectedNotification"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.staticTable reloadData];
}

- (void)regionSelected:(NSNotification *)notification {
    [self.staticTable reloadData];
}

#pragma mark - Search

- (void)didDismissSearchController:(UISearchController *)searchController {
    self.filteredSections = nil;
    if (self.infinitokIsDismissing) {

        return;
    }
    [self.staticTable reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text;
    if (query.length == 0) {
        self.filteredSections = nil;
        [self.staticTable reloadData];
        return;
    }
    NSMutableArray<InfinitokSettingsSection *> *filtered = [NSMutableArray array];
    for (InfinitokSettingsSection *section in self.sections) {
        NSMutableArray<InfinitokSettingsRow *> *matchingRows = [NSMutableArray array];
        for (InfinitokSettingsRow *row in section.rows) {
            NSString *title = row.titleKey ? IKLocalize(row.titleKey) : row.staticTitle;
            NSString *detail = row.detailKey ? IKLocalize(row.detailKey) : nil;
            if ([title localizedCaseInsensitiveContainsString:query] || [detail localizedCaseInsensitiveContainsString:query]) {
                [matchingRows addObject:row];
            }
        }
        if (matchingRows.count > 0) {
            InfinitokSettingsSection *filteredSection = [InfinitokSettingsSection new];
            filteredSection.titleKey = section.titleKey;
            filteredSection.rows = matchingRows;
            [filtered addObject:filteredSection];
        }
    }
    self.filteredSections = filtered;
    [self.staticTable reloadData];
}

#pragma mark - Row lookup

- (NSArray<InfinitokSettingsSection *> *)currentSections {
    return self.filteredSections ?: self.sections;
}

- (InfinitokSettingsRow *)rowAtIndexPath:(NSIndexPath *)indexPath {
    InfinitokSettingsSection *section = [self currentSections][indexPath.section];
    return section.rows[indexPath.row];
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self currentSections].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return IKLocalize([self currentSections][section].titleKey);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != [self currentSections].count - 1) {
        return nil;
    }
#ifdef INFINITOK_VERSION_STRING
    NSString *version = @INFINITOK_VERSION_STRING;
#else
    NSString *version = @"?";
#endif
    return [NSString stringWithFormat:IKLocalize(@"settings.version_footer"), version];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self currentSections][section].rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    InfinitokSettingsRow *row = [self rowAtIndexPath:indexPath];

    switch (row.type) {
        case InfinitokSettingsRowTypeSwitch:
            return [self createSwitchCellWithTitle:IKLocalize(row.titleKey)
                                            Detail:IKLocalize(row.detailKey)
                                               Key:row.defaultsKey];

        case InfinitokSettingsRowTypeText:
            return [self createTextCellWithTitle:row.staticTitle
                                      placeholder:row.placeholder
                                              tag:row.textFieldTag
                                      defaultsKey:row.defaultsKey];

        case InfinitokSettingsRowTypeRegionNav: {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = @"Regions";
            NSDictionary *selectedRegion = [defaults dictionaryForKey:@"region"];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", selectedRegion[@"area"]];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeResetRegion: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"Reset Region";
            cell.textLabel.textColor = [UIColor systemRedColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            return cell;
        }

        case InfinitokSettingsRowTypeLiveActionNav: {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = @"Actions";
            NSString *selectedLiveAction = [defaults valueForKey:@"live_action"];
            NSArray *liveFuncTitles = @[@"Default", @"Infinitok Settings", @"Playback Speed"];
            if (selectedLiveAction != nil) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [liveFuncTitles objectAtIndex:[selectedLiveAction integerValue]]];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypePlaybackSpeedNav: {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = @"Speeds";
            NSString *selectedSpeed = [defaults valueForKey:@"playback_speed"];
            if (selectedSpeed != nil) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ x", selectedSpeed];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeMediaVaultNav: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.detailTextLabel.text = IKLocalize(row.detailKey);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeAccentColorNav: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.detailTextLabel.text = IKLocalize(row.detailKey);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeAppIconNav: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.detailTextLabel.text = IKLocalize(row.detailKey);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeHideUIButtonMode: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.detailTextLabel.text = [self hideUIButtonModeDisplayName];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        case InfinitokSettingsRowTypeDeveloperLink: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = @"Mod4";
            cell.textLabel.textColor = [UIColor systemBlueColor];
            cell.detailTextLabel.text = @"Github Page";
            cell.imageView.image = [UIImage systemImageNamed:@"link"];
            cell.detailTextLabel.textColor = [UIColor systemGrayColor];
            return cell;
        }

        case InfinitokSettingsRowTypeExportDebugLog: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.textLabel.textColor = [UIColor systemBlueColor];
            cell.detailTextLabel.text = IKLocalize(row.detailKey);
            cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
            return cell;
        }

        case InfinitokSettingsRowTypeAction: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.textLabel.textColor = [row.defaultsKey isEqualToString:@"delete_all_reposts"] ? [UIColor systemRedColor] : [UIColor systemBlueColor];
            cell.detailTextLabel.text = IKLocalize(row.detailKey);
            cell.detailTextLabel.numberOfLines = 0;
            return cell;
        }

        case InfinitokSettingsRowTypeClearDebugLog: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.textLabel.textColor = [UIColor systemRedColor];
            cell.imageView.image = [UIImage systemImageNamed:@"trash"];
            return cell;
        }

        case InfinitokSettingsRowTypeContributorsNav: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = IKLocalize(row.titleKey);
            cell.imageView.image = [UIImage systemImageNamed:@"person.2"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
    }
    return [UITableViewCell new];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    InfinitokSettingsRow *row = [self rowAtIndexPath:indexPath];

    switch (row.type) {
        case InfinitokSettingsRowTypeRegionNav: {
            CountryTable *countryTable = [[CountryTable alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:countryTable];
            [self presentViewController:navController animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeResetRegion: {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"region"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RegionSelectedNotification" object:nil userInfo:nil];
            break;
        }
        case InfinitokSettingsRowTypeLiveActionNav: {
            LiveActions *liveActions = [[LiveActions alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:liveActions];
            [self presentViewController:navController animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypePlaybackSpeedNav: {
            PlaybackSpeed *playbackSpeed = [[PlaybackSpeed alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:playbackSpeed];
            [self presentViewController:navController animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeMediaVaultNav: {
            UIViewController *vaultVC = [[NSClassFromString(@"InfinitokVaultViewController") alloc] init];
            [self.navigationController pushViewController:vaultVC animated:true];
            break;
        }
        case InfinitokSettingsRowTypeAccentColorNav: {
            UIColorPickerViewController *picker = [UIColorPickerViewController new];
            picker.delegate = self;
            NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"custom_accent_color_value"];
            UIColor *storedColor = colorData ? [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:colorData error:nil] : nil;
            picker.selectedColor = storedColor ?: [UIColor systemPinkColor];
            [self presentViewController:picker animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeAppIconNav: {
            AppIconViewController *appIconVC = [[AppIconViewController alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appIconVC];
            [self presentViewController:navController animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeHideUIButtonMode: {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            UIAlertController *sheet = [UIAlertController alertControllerWithTitle:IKLocalize(@"settings.hide_ui_button_mode.title")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

            NSArray<NSArray<NSString *> *> *options = @[
                @[@"menu", @"settings.hide_ui_button_mode.menu"],
                @[@"this_video", @"settings.hide_ui_button_mode.this_video"],
                @[@"all", @"settings.hide_ui_button_mode.all"],
            ];
            for (NSArray<NSString *> *option in options) {
                NSString *value = option[0];
                NSString *titleKey = option[1];
                [sheet addAction:[UIAlertAction actionWithTitle:IKLocalize(titleKey) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [defaults setObject:value forKey:@"hide_ui_button_mode"];
                    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                }]];
            }
            [sheet addAction:[UIAlertAction actionWithTitle:IKLocalize(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];

            if (is_iPad()) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                sheet.popoverPresentationController.sourceView = cell ?: self.view;
                sheet.popoverPresentationController.sourceRect = cell ? cell.bounds : self.view.bounds;
            }
            [self presentViewController:sheet animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeDeveloperLink: {
            NSURL *url = [NSURL URLWithString:@"https://github.com/M0d-4"];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
            break;
        }
        case InfinitokSettingsRowTypeExportDebugLog: {
            NSString *logPath = InfinitokDebugLogFilePath();
            if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:IKLocalize(@"settings.export_debug_log.empty_title")
                                                                                 message:IKLocalize(@"settings.export_debug_log.empty_message")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:IKLocalize(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                break;
            }

            NSURL *logURL = [NSURL fileURLWithPath:logPath];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[logURL] applicationActivities:nil];

            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            activityVC.popoverPresentationController.sourceView = cell ?: self.view;
            activityVC.popoverPresentationController.sourceRect = cell ? cell.bounds : self.view.bounds;

            [self presentViewController:activityVC animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeAction: {
            InfinitokPerformSettingsAction(row.defaultsKey, self);
            break;
        }
        case InfinitokSettingsRowTypeClearDebugLog: {
            NSString *logPath = InfinitokDebugLogFilePath();
            if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:IKLocalize(@"settings.export_debug_log.empty_title")
                                                                                 message:IKLocalize(@"settings.export_debug_log.empty_message")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:IKLocalize(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                break;
            }

            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:IKLocalize(@"settings.clear_debug_log.confirm_title")
                                                                               message:IKLocalize(@"settings.clear_debug_log.confirm_message")
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:IKLocalize(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:IKLocalize(@"common.delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                NSError *removeError = nil;
                BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:logPath error:&removeError];
                if (removed) {
                    ITLog("boot", @"debug log file cleared by user");
                } else {
                    ITError("boot", @"failed to clear debug log file: %@", removeError.localizedDescription);
                }
            }]];
            [self presentViewController:confirm animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeContributorsNav: {
            ContributorsViewController *contributorsVC = [[ContributorsViewController alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:contributorsVC];
            [self presentViewController:navController animated:YES completion:nil];
            break;
        }
        case InfinitokSettingsRowTypeSwitch:
        case InfinitokSettingsRowTypeText:
            break;
    }
}

- (NSString *)hideUIButtonModeDisplayName {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"hide_ui_button_mode"];
    if ([mode isEqualToString:@"all"]) {
        return IKLocalize(@"settings.hide_ui_button_mode.all");
    }
    if ([mode isEqualToString:@"this_video"]) {
        return IKLocalize(@"settings.hide_ui_button_mode.this_video");
    }
    return IKLocalize(@"settings.hide_ui_button_mode.menu");
}

#pragma mark - Cell builders

- (UITableViewCell *)createSwitchCellWithTitle:(NSString *)title Detail:(NSString *)detail Key:(NSString *)key {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    UISwitch *switchView = [[UISwitch alloc] init];
    [cell.contentView addSubview:switchView];
    cell.accessoryView = switchView;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    switchView.on = [defaults boolForKey:key];
    switchView.accessibilityLabel = key;
    [switchView addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];

    cell.textLabel.text = title;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (UITableViewCell *)createTextCellWithTitle:(NSString *)title placeholder:(NSString *)placeholder tag:(NSInteger)tag defaultsKey:(NSString *)defaultsKey {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];

    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:16];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:label];

    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = placeholder;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.delegate = self;
    textField.tag = tag;
    textField.returnKeyType = UIReturnKeyDone;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:textField];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:15],
        [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:100],

        [textField.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [textField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-15],
        [textField.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [textField.heightAnchor constraintEqualToConstant:30]
    ]];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedText = [defaults stringForKey:defaultsKey];
    if (savedText) {
        textField.text = savedText;
    }

    return cell;
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    NSString *key = sender.accessibilityLabel;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:key];
    [defaults synchronize];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSString *key = nil;
    switch (textField.tag) {
        case 1: key = @"following_count"; break;
        case 2: key = @"follower_count"; break;
        case 3: key = @"like_count"; break;
        default: return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:textField.text forKey:key];
    [defaults synchronize];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)infinitokDismissSettings {

    self.infinitokIsDismissing = YES;
    if (self.searchController.isActive) {
        self.searchController.active = NO;
    }
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.type = kCATransitionPush;
    transition.subtype = kCATransitionFromLeft;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.view.window.layer addAnimation:transition forKey:kCATransition];
    [self dismissViewControllerAnimated:false completion:nil];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:viewController.selectedColor requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"custom_accent_color_value"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"custom_accent_color"];
}

@end
