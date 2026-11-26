#import "Localization.h"
#import "InfinitokLog.h"
#import <dlfcn.h>

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *InfinitokEmbeddedStrings(void) {
    static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = @{
            @"ar": @{
                @"section.clean_identity": @"إخفاء الهوية والموسيقى",
                @"clean_identity.video_usernames.title": @"إخفاء أسماء مستخدمي الفيديو",
                @"clean_identity.video_usernames.detail": @"إخفاء اسم صاحب الفيديو في الخلاصة.",
                @"clean_identity.video_avatars.title": @"إخفاء صور حسابات الفيديو",
                @"clean_identity.video_avatars.detail": @"إخفاء صور الحسابات في الخلاصة.",
                @"clean_identity.music_disc.title": @"إخفاء قرص الموسيقى",
                @"clean_identity.music_disc.detail": @"إخفاء قرص الموسيقى وواجهة الموسيقى.",
                @"clean_identity.comment_usernames.title": @"إخفاء أسماء المعلقين",
                @"clean_identity.comment_usernames.detail": @"إخفاء أسماء المعلقين والمنشئين والإشارات.",
                @"clean_identity.comment_avatars.title": @"إخفاء صور المعلقين",
                @"clean_identity.comment_avatars.detail": @"إخفاء صور المعلقين وشارات إعجاب المنشئ.",
                @"settings.title": @"إعدادات Infinitok",
                @"section.feed": @"الخلاصة",
                @"section.profile": @"الملف الشخصي",
                @"section.confirm": @"التأكيد",
                @"section.other": @"أخرى",
                @"section.region": @"المنطقة",
                @"section.live_button": @"وظيفة زر البث المباشر",
                @"section.playback_speed": @"سرعة التشغيل",
                @"section.developer": @"المطوّر",
                @"section.extra": @"ميزات إضافية",
                @"extra.save_comment_media.title": @"حفظ الصور من التعليقات",
                @"extra.save_comment_media.detail": @"اضغط مطولاً على صورة أو ملصق في التعليقات لحفظه",
                @"extra.exact_follower_count.title": @"عدد المتابعين الدقيق",
                @"extra.exact_follower_count.detail": @"إظهار العدد الدقيق للمتابعين بدلاً من المختصر",
                @"extra.copy_comment_no_username.title": @"نسخ التعليق بدون اسم المستخدم",
                @"extra.copy_comment_no_username.detail": @"اضغط مطولاً على تعليق لنسخ نصه مع حذف الإشارة @ في البداية إن وجدت",
                @"extra.post_stats.title": @"إحصائيات المنشور",
                @"extra.post_stats.detail": @"يضيف خيار إحصائيات إلى قائمة تنزيل الفيديو يعرض الإعجابات والتعليقات والمشاركات والمشاهدات والحفظ",
                @"extra.hide_tako_button.title": @"إخفاء زر Tako",
                @"extra.hide_tako_button.detail": @"يخفي مدخل مساعد الذكاء الاصطناعي Tako في الخلاصة",
                @"extra.translate_comments.title": @"ترجمة التعليقات",
                @"extra.translate_comments.detail": @"يفرض إظهار زر الترجمة الخاص بتيك توك على كل تعليق",
                @"extra.hide_ai_videos.title": @"إخفاء فيديوهات الذكاء الاصطناعي",
                @"extra.hide_ai_videos.detail": @"يتخطى فيديوهات الخلاصة التي يضع عليها تيك توك علامة المحتوى المُنشأ بالذكاء الاصطناعي",
                @"extra.watch_stories_anonymously.title": @"مشاهدة القصص بشكل مجهول",
                @"extra.watch_stories_anonymously.detail": @"يتخطى التقرير الذي يرسله تيك توك عند مشاهدة قصة شخص ما",
                @"extra.visit_profiles_privately.title": @"زيارة الملفات الشخصية بخصوصية",
                @"extra.visit_profiles_privately.detail": @"يتخطى التقرير الذي يرسله تيك توك عند زيارة ملف شخصي",
                @"extra.read_chats_anonymously.title": @"قراءة المحادثات بشكل مجهول",
                @"extra.read_chats_anonymously.detail": @"يتخطى إرسال إشعار القراءة عند فتح محادثة",
                @"extra.story_download.title": @"تنزيل القصص",
                @"extra.story_download.detail": @"إضافة زر تنزيل إلى قصص تيك توك",
                @"extra.story_view_count.title": @"عدد مشاهدات القصة",
                @"extra.story_view_count.detail": @"إظهار عدد الأشخاص الذين شاهدوا القصة",
                @"extra.hide_typing_indicator.title": @"إخفاء مؤشر الكتابة",
                @"extra.hide_typing_indicator.detail": @"لا يرى الشخص الآخر أنك تكتب",
                @"extra.anti_delete_messages.title": @"منع حذف الرسائل",
                @"extra.anti_delete_messages.detail": @"استمر برؤية محتوى الرسالة بعد حذفها من المرسل",
                @"extra.dm_delete_confirmation.title": @"تأكيد حذف الرسائل",
                @"extra.dm_delete_confirmation.detail": @"السؤال قبل حذف رسالة",
                @"extra.disable_phone_binding_popup.title": @"إيقاف نافذة ربط الهاتف",
                @"extra.disable_phone_binding_popup.detail": @"منع تيك توك من مطالبتك بربط رقم هاتف",
                @"extra.save_to_vault.title": @"حفظ التنزيلات في الخزنة",
                @"extra.save_to_vault.detail": @"نسخ كل ما تقوم بتنزيله أيضًا إلى خزنة الوسائط داخل التطبيق",
                @"extra.media_vault.title": @"خزنة الوسائط",
                @"extra.media_vault.detail": @"تصفح أو شارك أو احذف كل ما تم حفظه في الخزنة",
                @"extra.save_dm_media.title": @"حفظ الصور من الرسائل",
                @"extra.save_dm_media.detail": @"اضغط مطولاً على صورة أُرسلت في محادثة لحفظها",
                @"extra.lock_chats.title": @"قفل المحادثات",
                @"extra.lock_chats.detail": @"يتطلب Face ID أو رمز المرور لفتح صندوق رسائلك",
                @"extra.lock_favorites.title": @"قفل المفضلة",
                @"extra.lock_favorites.detail": @"يتطلب Face ID أو رمز المرور لفتح المفضلة",
                @"extra.disable_feed_refresh.title": @"إيقاف تحديث الخلاصة",
                @"extra.disable_feed_refresh.detail": @"منع تحديث الخلاصة عند الضغط على تبويب الرئيسية مرة أخرى",
                @"extra.exact_view_count.title": @"عدد المشاهدات الدقيق",
                @"extra.exact_view_count.detail": @"إظهار العدد الدقيق للمشاهدات والإعجابات في شبكة ملفك الشخصي بدلاً من الاختصار",
                @"extra.confirm_repost.title": @"تأكيد إعادة النشر",
                @"extra.confirm_repost.detail": @"السؤال قبل إعادة نشر فيديو",
                @"extra.confirm_favorite.title": @"تأكيد الإضافة إلى المفضلة",
                @"extra.confirm_favorite.detail": @"السؤال قبل حفظ فيديو في المفضلة",
                @"extra.confirm_send_comment.title": @"تأكيد إرسال التعليق",
                @"extra.confirm_send_comment.detail": @"السؤال قبل نشر تعليق",
                @"extra.hide_caption.title": @"إخفاء الوصف/الهاشتاغ",
                @"extra.hide_caption.detail": @"إخفاء نص وصف الفيديو في الخلاصة",
                @"extra.hide_comments_button.title": @"إخفاء زر التعليقات",
                @"extra.hide_comments_button.detail": @"إخفاء زر/عداد التعليقات في الخلاصة",
                @"extra.hide_likes_button.title": @"إخفاء زر الإعجاب",
                @"extra.hide_likes_button.detail": @"إخفاء زر/عداد الإعجاب في الخلاصة",
                @"extra.hide_music.title": @"إخفاء عنوان الصوت",
                @"extra.hide_music.detail": @"إخفاء عنوان الصوت/الموسيقى في الخلاصة",
                @"extra.hide_share_button.title": @"إخفاء زر المشاركة",
                @"extra.hide_share_button.detail": @"إخفاء زر المشاركة في الخلاصة",
                @"extra.hide_search_button.title": @"إخفاء زر البحث",
                @"extra.hide_search_button.detail": @"إخفاء أيقونة البحث",
                @"extra.hide_account_suggestions.title": @"إخفاء الحسابات المقترحة",
                @"extra.hide_account_suggestions.detail": @"يخفي الخلايا التي يشير اسم صنفها إلى بطاقة حساب موصى به — أسلوب تخميني وليس صنفًا مؤكدًا",
                @"extra.hide_live_button.title": @"إخفاء زر البث المباشر",
                @"extra.hide_live_button.detail": @"إخفاء زر الدخول إلى البث المباشر الذي يأخذك إلى بث مباشر بدلاً من مقاطع الفيديو",
                @"extra.hide_download_button_native.title": @"إخفاء زر التنزيل",
                @"extra.hide_download_button_native.detail": @"إخفاء زر/شريط التنزيل الأصلي من تيك توك",
                @"extra.hide_video_button.title": @"إخفاء زر الفيديو",
                @"extra.hide_video_button.detail": @"إخفاء زر \"+\" في شريط التبويب المستخدم لتسجيل/نشر فيديو جديد",
                @"extra.fast_logout.title": @"تسجيل خروج سريع",
                @"extra.fast_logout.detail": @"تخطي التأكيد عند تسجيل الخروج — يحاول استخدام طريقة تسجيل خروج مباشرة مخمّنة، ويعود للسلوك الطبيعي إن لم يجدها",
                @"extra.auto_clear_history.title": @"مسح السجل تلقائيًا",
                @"extra.auto_clear_history.detail": @"يمسح سجل البحث بعد فترة قصيرة من فتح التطبيق — يبحث عن طريقة مخمّنة لمسح السجل ويستدعيها، ولا يفعل شيئًا إن لم يجدها",
                @"extra.persistent_progress_slider.title": @"شريط تقدم دائم",
                @"extra.persistent_progress_slider.detail": @"إبقاء شريط تقدم قابل للسحب ظاهرًا دائمًا على الفيديوهات",
                @"extra.exact_timestamp.title": @"إظهار وقت النشر الدقيق",
                @"extra.exact_timestamp.detail": @"إظهار الوقت الدقيق لنشر الفيديو بدلاً من تاريخ نسبي فقط",
                @"extra.oled_mode.title": @"وضع OLED",
                @"extra.oled_mode.detail": @"خلفيات سوداء بالكامل ولوحة مفاتيح داكنة في جميع أنحاء التطبيق",
                @"extra.faster_feed_scrolling.title": @"تمرير أسرع للخلاصة",
                @"extra.faster_feed_scrolling.detail": @"تقليل تباطؤ التمرير ليصبح الانتقال في الخلاصة أكثر سلاسة",
                @"extra.show_only_favorites.title": @"إظهار الفيديوهات فقط في المفضلة",
                @"extra.show_only_favorites.detail": @"إخفاء تبويبات الأصوات/الهاشتاغ/المستخدمين في المفضلة، مع إبقاء الفيديوهات فقط — أسلوب تخميني بحسب اسم الصنف، وليس واجهة مؤكدة",
                @"extra.show_region_badge.title": @"إظهار شارة منطقة المحتوى",
                @"extra.show_region_badge.detail": @"إظهار علم صغير على فيديوهات الخلاصة يشير إلى منطقة الناشر",
                @"extra.custom_accent_color.title": @"لون تمييز مخصص",
                @"extra.custom_accent_color.detail": @"استخدام اللون المختار أدناه كلون تمييز للتطبيق بدلاً من لون تيك توك الافتراضي",
                @"extra.pick_accent_color.title": @"اختيار لون التمييز",
                @"extra.pick_accent_color.detail": @"يفتح منتقي الألوان الخاص بالنظام",
                @"settings.hide_ads.title": @"إخفاء الإعلانات",
                @"settings.hide_ads.detail": @"إخفاء جميع الإعلانات من التطبيق",
                @"settings.download_button.title": @"زر التنزيل",
                @"settings.download_button.detail": @"تفعيل زر تنزيل الفيديوهات",
                @"settings.share_sheet.title": @"قائمة المشاركة",
                @"settings.share_sheet.detail": @"تفعيل خيارات المشاركة في قائمة المشاركة",
                @"settings.remove_watermark.title": @"إزالة العلامة المائية",
                @"settings.remove_watermark.detail": @"إزالة العلامة المائية لتيك توك من الفيديوهات",
                @"settings.remove_elements_button.title": @"زر إظهار/إخفاء الواجهة",
                @"settings.remove_elements_button.detail": @"إظهار أو إخفاء زر واجهة المستخدم",
                @"settings.stop_play.title": @"إيقاف التشغيل",
                @"settings.stop_play.detail": @"إيقاف تشغيل الفيديو تلقائيًا",
                @"settings.auto_play.title": @"تشغيل الفيديو التالي تلقائيًا",
                @"settings.auto_play.detail": @"تشغيل الفيديو التالي تلقائيًا",
                @"settings.show_porgress_bar.title": @"إظهار شريط التقدم",
                @"settings.show_porgress_bar.detail": @"إظهار شريط تقدم أثناء تشغيل الفيديو",
                @"settings.buttons_on_right.title": @"الأزرار على اليمين",
                @"settings.buttons_on_right.detail": @"نقل زري التنزيل وإخفاء الواجهة إلى الجانب الأيمن",
                @"settings.show_username.title": @"إظهار أسماء المستخدمين",
                @"settings.show_username.detail": @"إظهار أسماء المستخدمين على الفيديوهات",
                @"settings.disable_unsensitive.title": @"تعطيل تصفية المحتوى الحساس",
                @"settings.disable_unsensitive.detail": @"تعطيل مرشح المحتوى الحساس",
                @"settings.disable_warnings.title": @"تعطيل التحذيرات",
                @"settings.disable_warnings.detail": @"تعطيل تحذيرات تيك توك",
                @"settings.disable_live.title": @"تعطيل البث المباشر",
                @"settings.disable_live.detail": @"تعطيل البث المباشر للفيديو",
                @"settings.skip_recommnedations.title": @"تخطي التوصيات",
                @"settings.skip_recommnedations.detail": @"تخطي الفيديوهات الموصى بها",
                @"settings.save_profile.title": @"حفظ الملف الشخصي",
                @"settings.save_profile.detail": @"حفظ تفاصيل الملف الشخصي في الحافظة",
                @"settings.copy_profile_information.title": @"نسخ الملف الشخصي",
                @"settings.copy_profile_information.detail": @"نسخ معلومات الملف الشخصي",
                @"settings.video_like_count.title": @"عدد إعجابات الفيديو",
                @"settings.video_like_count.detail": @"إظهار عدد الإعجابات على الفيديوهات",
                @"settings.video_upload_date.title": @"تاريخ رفع الفيديو",
                @"settings.video_upload_date.detail": @"إظهار تاريخ رفع الفيديوهات",
                @"settings.like_confirm.title": @"تأكيد الإعجاب",
                @"settings.like_confirm.detail": @"التأكيد قبل الإعجاب بفيديو",
                @"settings.like_comment_confirm.title": @"تأكيد إعجاب التعليق",
                @"settings.like_comment_confirm.detail": @"التأكيد قبل الإعجاب بتعليق",
                @"settings.dislike_comment_confirm.title": @"تأكيد عدم إعجاب التعليق",
                @"settings.dislike_comment_confirm.detail": @"التأكيد قبل عدم الإعجاب بتعليق",
                @"settings.follow_confirm.title": @"تأكيد المتابعة",
                @"settings.follow_confirm.detail": @"التأكيد قبل متابعة مستخدم",
                @"settings.en_region.title": @"تفعيل تغيير المنطقة",
                @"settings.en_region.detail": @"تفعيل وظيفة تغيير المنطقة",
                @"settings.en_livefunc.title": @"إجراء زر البث المباشر",
                @"settings.en_livefunc.detail": @"تغيير الإجراء الافتراضي لزر البث المباشر",
                @"settings.playback_en.title": @"سرعة التشغيل",
                @"settings.playback_en.detail": @"تفعيل سرعة تشغيل دائمة.",
                @"section.privacy": @"الخصوصية وإخفاء الهوية",
                @"section.messages": @"الرسائل",
                @"section.media": @"الوسائط والخزنة",
                @"section.appearance": @"المظهر",
                @"section.feed_content": @"محتوى الخلاصة",
                @"section.fake_profile": @"الملف الشخصي المزيف",
                @"settings.en_fake.title": @"تفعيل التعديلات المزيفة",
                @"settings.en_fake.detail": @"تفعيل تعديلات الملف الشخصي المزيفة",
                @"settings.fake_verify.title": @"توثيق مزيف",
                @"settings.fake_verify.detail": @"جعل حسابك يبدو موثقًا",
                @"settings.extended_bio.title": @"سيرة ذاتية موسّعة",
                @"settings.extended_bio.detail": @"توسيع قسم السيرة الذاتية في ملفك الشخصي",
                @"settings.extended_comment.title": @"تعليقات موسّعة",
                @"settings.extended_comment.detail": @"توسيع طول تعليقاتك",
                @"settings.upload_hd.title": @"رفع بجودة عالية",
                @"settings.upload_hd.detail": @"رفع الفيديوهات بجودة عالية الدقة",
                @"section.security": @"الأمان",
                @"settings.padlock.title": @"قفل التطبيق",
                @"settings.padlock.detail": @"قفل التطبيق برمز مرور",
                @"settings.open_in_browser.title": @"فتح الروابط في سفاري دائمًا",
                @"settings.open_in_browser.detail": @"فتح الروابط دائمًا في متصفح سفاري",
                @"settings.debug_logging.title": @"سجلات التصحيح",
                @"settings.debug_logging.detail": @"يكتب تشخيصات Infinitok إلى سجل الجهاز. معطّل افتراضيًا.",
                @"settings.export_debug_log.title": @"تصدير سجل التصحيح",
                @"settings.export_debug_log.detail": @"مشاركة ملف سجل التصحيح",
                @"settings.export_debug_log.empty_title": @"لا يوجد سجل بعد",
                @"settings.export_debug_log.empty_message": @"لم يتم تسجيل أي شيء بعد. حاول إعادة إنتاج المشكلة، ثم صدّر مرة أخرى.",
                @"settings.clear_debug_log.title": @"مسح سجل التصحيح",
                @"settings.clear_debug_log.confirm_title": @"مسح سجل التصحيح؟",
                @"settings.clear_debug_log.confirm_message": @"سيؤدي هذا إلى حذف ملف السجل من هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.",
                @"common.cancel": @"إلغاء",
                @"common.delete": @"حذف",
                @"settings.version_footer": @"Infinitok الإصدار %@",
                @"settings.app_icon.title": @"أيقونة التطبيق",
                @"settings.app_icon.detail": @"تغيير أيقونة Infinitok",
                @"settings.app_icon.default_name": @"الافتراضية",
                @"settings.app_icon.selected": @"محددة",
                @"settings.app_icon.tap_to_apply": @"اضغط للتطبيق",
                @"settings.app_icon.footer": @"قد يستغرق تغيير الأيقونة على الشاشة الرئيسية بعض الوقت.",
                @"settings.app_icon.unsupported": @"هذا الجهاز أو التثبيت لا يدعم الأيقونات البديلة.",
                @"settings.app_icon.signing_error": @"رفض iOS تغيير الأيقونة. عادةً ما يعني هذا أن SpringBoard إمّا خزّن معلومات أيقونة التطبيق مؤقتًا قبل وجود الأيقونات البديلة، أو لا يتعرّف على ملفات الأيقونة كجزء من محتوى التطبيق الموقّع — جرّب إعادة تشغيل جهازك بالكامل ثم أعد المحاولة. إذا استمر الفشل بعد ذلك، فمن المحتمل أن يكون قيدًا صارمًا في طريقة التثبيت هذه لا يمكن التغلب عليه من داخل التعديل.",
                @"settings.hide_ui_button_mode.title": @"سلوك زر إخفاء الواجهة",
                @"settings.hide_ui_button_mode.menu": @"السؤال في كل مرة",
                @"settings.hide_ui_button_mode.this_video": @"هذا الفيديو فقط",
                @"settings.hide_ui_button_mode.all": @"جميع الفيديوهات",
                @"common.ok": @"حسنًا",
                @"common.retry": @"إعادة المحاولة",
                @"settings.contributors.title": @"المساهمون",
                @"settings.contributors.parse_error": @"تعذّرت قراءة قائمة المساهمين. حاول مرة أخرى بعد قليل.",
                @"settings.contributors.empty": @"لا يوجد مساهمون.",
            },
            @"en": @{
                @"section.clean_identity": @"Identity & Music",
                @"clean_identity.video_usernames.title": @"Hide video usernames",
                @"clean_identity.video_usernames.detail": @"Hide the author name on feed videos.",
                @"clean_identity.video_avatars.title": @"Hide video avatars",
                @"clean_identity.video_avatars.detail": @"Hide profile avatars on feed videos.",
                @"clean_identity.music_disc.title": @"Hide music disc",
                @"clean_identity.music_disc.detail": @"Hide the spinning music disc and music view.",
                @"clean_identity.comment_usernames.title": @"Hide comment usernames",
                @"clean_identity.comment_usernames.detail": @"Hide comment names, creator names and @mentions.",
                @"clean_identity.comment_avatars.title": @"Hide comment avatars",
                @"clean_identity.comment_avatars.detail": @"Hide comment avatars and creator-liked avatar badges.",
                @"settings.title": @"Infinitok Settings",
                @"section.feed": @"Feed",
                @"section.profile": @"Profile",
                @"section.confirm": @"Confirm",
                @"section.other": @"Other",
                @"section.region": @"Region",
                @"section.live_button": @"Live Button Function",
                @"section.playback_speed": @"Playback Speed",
                @"section.developer": @"Developer",
                @"section.extra": @"Extra Features",
                @"extra.save_comment_media.title": @"Save Images From Comments",
                @"extra.save_comment_media.detail": @"Long-press images and stickers in comments to save them",
                @"extra.exact_follower_count.title": @"Exact Follower Count",
                @"extra.exact_follower_count.detail": @"Show the exact digit follower count instead of the abbreviated one",
                @"extra.copy_comment_no_username.title": @"Copy Comment Without Username",
                @"extra.copy_comment_no_username.detail": @"Long-press a comment to copy its text, stripping a leading @mention if present",
                @"extra.post_stats.title": @"Post Stats",
                @"extra.post_stats.detail": @"Adds a Post Stats option to the video download menu showing likes, comments, shares, plays and saves",
                @"extra.hide_tako_button.title": @"Hide Tako Button",
                @"extra.hide_tako_button.detail": @"Hides TikTok's AI assistant entry point on the feed",
                @"extra.translate_comments.title": @"Translate Comments",
                @"extra.translate_comments.detail": @"Forces TikTok's own translate button to show on every comment",
                @"extra.hide_ai_videos.title": @"Hide AI Videos",
                @"extra.hide_ai_videos.detail": @"Skips feed videos TikTok has labeled as AI-generated content",
                @"extra.watch_stories_anonymously.title": @"Watch Stories Anonymously",
                @"extra.watch_stories_anonymously.detail": @"Skips the network report TikTok sends when you view someone's story",
                @"extra.visit_profiles_privately.title": @"Visit Profiles Privately",
                @"extra.visit_profiles_privately.detail": @"Skips the network report TikTok sends when you visit someone's profile",
                @"extra.read_chats_anonymously.title": @"Read Chats Anonymously",
                @"extra.read_chats_anonymously.detail": @"Skips sending the read receipt when you open a chat",
                @"extra.story_download.title": @"Story Download",
                @"extra.story_download.detail": @"Add a download button to TikTok Stories",
                @"extra.story_view_count.title": @"Story View Count",
                @"extra.story_view_count.detail": @"Show how many people viewed the story",
                @"extra.hide_typing_indicator.title": @"Hide Typing Indicator",
                @"extra.hide_typing_indicator.detail": @"The other person doesn't see that you're typing",
                @"extra.anti_delete_messages.title": @"Anti Delete Messages",
                @"extra.anti_delete_messages.detail": @"Still see a DM's content after the sender deletes/recalls it",
                @"extra.dm_delete_confirmation.title": @"DM Delete Confirmation",
                @"extra.dm_delete_confirmation.detail": @"Ask before deleting a message",
                @"extra.disable_phone_binding_popup.title": @"Disable Phone Binding Popup",
                @"extra.disable_phone_binding_popup.detail": @"Stop TikTok from nagging you to link a phone number",
                @"extra.save_to_vault.title": @"Save Downloads To Vault",
                @"extra.save_to_vault.detail": @"Also copy anything you download into the in-app Media Vault",
                @"extra.media_vault.title": @"Media Vault",
                @"extra.media_vault.detail": @"Browse, share, or delete everything saved to the vault",
                @"extra.save_dm_media.title": @"Save Media From DMs",
                @"extra.save_dm_media.detail": @"Long-press an image sent in a chat to save it",
                @"extra.lock_chats.title": @"Lock Chats",
                @"extra.lock_chats.detail": @"Require Face ID/passcode to open your DM inbox",
                @"extra.lock_favorites.title": @"Lock Favorites",
                @"extra.lock_favorites.detail": @"Require Face ID/passcode to open your Favorites",
                @"extra.disable_feed_refresh.title": @"Disable Feed Refresh",
                @"extra.disable_feed_refresh.detail": @"Stop tapping the Home tab again from refreshing the feed",
                @"extra.exact_view_count.title": @"Exact View Count",
                @"extra.exact_view_count.detail": @"Show the exact number of views/likes on your profile grid instead of an abbreviation",
                @"extra.confirm_repost.title": @"Confirm Repost",
                @"extra.confirm_repost.detail": @"Ask before reposting a video",
                @"extra.confirm_favorite.title": @"Confirm Add To Favorites",
                @"extra.confirm_favorite.detail": @"Ask before saving a video to favorites",
                @"extra.confirm_send_comment.title": @"Confirm Sending Comment",
                @"extra.confirm_send_comment.detail": @"Ask before posting a comment",
                @"extra.hide_caption.title": @"Hide Caption/Hashtags",
                @"extra.hide_caption.detail": @"Hide the video description text on the feed",
                @"extra.hide_comments_button.title": @"Hide Comments Button",
                @"extra.hide_comments_button.detail": @"Hide the comment button/count on the feed",
                @"extra.hide_likes_button.title": @"Hide Likes Button",
                @"extra.hide_likes_button.detail": @"Hide the like button/count on the feed",
                @"extra.hide_music.title": @"Hide Audio Title",
                @"extra.hide_music.detail": @"Hide the sound/music title on the feed",
                @"extra.hide_share_button.title": @"Hide Share Button",
                @"extra.hide_share_button.detail": @"Hide the share button on the feed",
                @"extra.hide_search_button.title": @"Hide Search Button",
                @"extra.hide_search_button.detail": @"Hide the search icon",
                @"extra.hide_account_suggestions.title": @"Hide Account Suggestions",
                @"extra.hide_account_suggestions.detail": @"Hides cells whose class name suggests a recommended-account card — heuristic, not a confirmed class",
                @"extra.hide_live_button.title": @"Hide Live Button",
                @"extra.hide_live_button.detail": @"Hides the in-feed LIVE entrance button that jumps into a live stream instead of the video feed",
                @"extra.hide_download_button_native.title": @"Hide Download Button",
                @"extra.hide_download_button_native.detail": @"Hides TikTok's own native download bar/button on videos",
                @"extra.hide_video_button.title": @"Hide Video Button",
                @"extra.hide_video_button.detail": @"Hides the tab bar's \"+\" button used to record/post a new video",
                @"extra.fast_logout.title": @"Fast Logout",
                @"extra.fast_logout.detail": @"Skip the confirmation when logging out — tries a guessed direct-logout method, falls back to normal behavior if not found",
                @"extra.auto_clear_history.title": @"Auto Clear History",
                @"extra.auto_clear_history.detail": @"Clears search history shortly after launch — scans for and calls a guessed clear-history method, does nothing if none is found",
                @"extra.persistent_progress_slider.title": @"Persistent Progress Slider",
                @"extra.persistent_progress_slider.detail": @"Keep a draggable progress bar always visible on videos",
                @"extra.exact_timestamp.title": @"Show Exact Post Timestamp",
                @"extra.exact_timestamp.detail": @"Show the exact time a video was posted, not just a relative date",
                @"extra.oled_mode.title": @"OLED Mode",
                @"extra.oled_mode.detail": @"True black backgrounds and a dark keyboard throughout the app",
                @"extra.faster_feed_scrolling.title": @"Faster Feed Scrolling",
                @"extra.faster_feed_scrolling.detail": @"Reduce scroll deceleration so swiping through the feed feels snappier",
                @"extra.show_only_favorites.title": @"Show Only Favorites",
                @"extra.show_only_favorites.detail": @"Hide sounds/hashtags/users tabs on the Favorites screen, leaving just videos — heuristic by cell class name, not a confirmed API",
                @"extra.show_region_badge.title": @"Show Content Region Badge",
                @"extra.show_region_badge.detail": @"Show a small flag on feed videos indicating the uploader's region",
                @"extra.custom_accent_color.title": @"Custom Accent Color",
                @"extra.custom_accent_color.detail": @"Use the color picked below as the app's tint color instead of TikTok's default",
                @"extra.pick_accent_color.title": @"Pick Accent Color",
                @"extra.pick_accent_color.detail": @"Opens the system color picker",
                @"settings.hide_ads.title": @"Hide Ads",
                @"settings.hide_ads.detail": @"Hide all ads from the app",
                @"settings.download_button.title": @"Download Button",
                @"settings.download_button.detail": @"Enable download button for videos",
                @"settings.share_sheet.title": @"Share Sheet",
                @"settings.share_sheet.detail": @"Enable sharing options in share sheet",
                @"settings.remove_watermark.title": @"Remove Watermark",
                @"settings.remove_watermark.detail": @"Remove the TikTok watermark from videos",
                @"settings.remove_elements_button.title": @"Show/Hide UI Button",
                @"settings.remove_elements_button.detail": @"Show or hide the UI button",
                @"settings.stop_play.title": @"Stop Playback",
                @"settings.stop_play.detail": @"Stop video playback automatically",
                @"settings.auto_play.title": @"Auto Play Next Video",
                @"settings.auto_play.detail": @"Automatically play the next video",
                @"settings.show_porgress_bar.title": @"Show Progress Bar",
                @"settings.show_porgress_bar.detail": @"Display progress bar on video playback",
                @"settings.buttons_on_right.title": @"Buttons on Right Side",
                @"settings.buttons_on_right.detail": @"Move the download and hide-UI buttons to the right side",
                @"settings.show_username.title": @"Show Usernames",
                @"settings.show_username.detail": @"Display usernames on videos",
                @"settings.disable_unsensitive.title": @"Disable Sensitive Content",
                @"settings.disable_unsensitive.detail": @"Disable sensitive content filter",
                @"settings.disable_warnings.title": @"Disable Warnings",
                @"settings.disable_warnings.detail": @"Disable TikTok warnings",
                @"settings.disable_live.title": @"Disable Live Streaming",
                @"settings.disable_live.detail": @"Disable live video streaming",
                @"settings.skip_recommnedations.title": @"Skip Recommendations",
                @"settings.skip_recommnedations.detail": @"Skip recommended videos",
                @"settings.save_profile.title": @"Profile Save",
                @"settings.save_profile.detail": @"Save profile details to clipboard",
                @"settings.copy_profile_information.title": @"Profile Copy",
                @"settings.copy_profile_information.detail": @"Copy profile information",
                @"settings.video_like_count.title": @"Video Like Count",
                @"settings.video_like_count.detail": @"Show the number of likes on videos",
                @"settings.video_upload_date.title": @"Video Upload Date",
                @"settings.video_upload_date.detail": @"Show the date videos were uploaded",
                @"settings.like_confirm.title": @"Like Confirmation",
                @"settings.like_confirm.detail": @"Confirm before liking a video",
                @"settings.like_comment_confirm.title": @"Like Comment Confirmation",
                @"settings.like_comment_confirm.detail": @"Confirm before liking a comment",
                @"settings.dislike_comment_confirm.title": @"Dislike Comment Confirmation",
                @"settings.dislike_comment_confirm.detail": @"Confirm before disliking a comment",
                @"settings.follow_confirm.title": @"Follow Confirmation",
                @"settings.follow_confirm.detail": @"Confirm before following a user",
                @"settings.en_region.title": @"Enable Region Changing",
                @"settings.en_region.detail": @"Enable region changing functionality",
                @"settings.en_livefunc.title": @"Live Button Action",
                @"settings.en_livefunc.detail": @"Change The Default Live Button Action",
                @"settings.playback_en.title": @"Playback Speed",
                @"settings.playback_en.detail": @"Enable Persistent Playback Speed.",
                @"section.privacy": @"Privacy & Anonymity",
                @"section.messages": @"Messages",
                @"section.media": @"Media & Vault",
                @"section.appearance": @"Appearance",
                @"section.feed_content": @"Feed Content",
                @"section.fake_profile": @"Fake Profile",
                @"settings.en_fake.title": @"Enable Fake Changes",
                @"settings.en_fake.detail": @"Enable fake profile changes",
                @"settings.fake_verify.title": @"Fake Verified",
                @"settings.fake_verify.detail": @"Make your account appear verified",
                @"settings.extended_bio.title": @"Extended Bio",
                @"settings.extended_bio.detail": @"Extend bio section of your profile",
                @"settings.extended_comment.title": @"Extended Comments",
                @"settings.extended_comment.detail": @"Extend the length of your comments",
                @"settings.upload_hd.title": @"Upload HD",
                @"settings.upload_hd.detail": @"Upload videos in HD quality",
                @"section.security": @"Security",
                @"settings.padlock.title": @"App Lock",
                @"settings.padlock.detail": @"Lock the app with a passcode",
                @"settings.open_in_browser.title": @"Always Open Safari",
                @"settings.open_in_browser.detail": @"Always open links in Safari",
                @"settings.debug_logging.title": @"Debug logging",
                @"settings.debug_logging.detail": @"Writes Infinitok diagnostics to the device console. Off by default.",
                @"settings.export_debug_log.title": @"Export Debug Log",
                @"settings.export_debug_log.detail": @"Share the debug log file",
                @"settings.export_debug_log.empty_title": @"No Log Yet",
                @"settings.export_debug_log.empty_message": @"Nothing has been logged yet. Try reproducing the issue, then export again.",
                @"settings.clear_debug_log.title": @"Clear Debug Log",
                @"settings.clear_debug_log.confirm_title": @"Clear Debug Log?",
                @"settings.clear_debug_log.confirm_message": @"This deletes the log file on this device. This can't be undone.",
                @"common.cancel": @"Cancel",
                @"common.delete": @"Delete",
                @"settings.version_footer": @"Infinitok v%@",
                @"settings.app_icon.title": @"App Icon",
                @"settings.app_icon.detail": @"Change Infinitok's icon",
                @"settings.app_icon.default_name": @"Default",
                @"settings.app_icon.selected": @"Selected",
                @"settings.app_icon.tap_to_apply": @"Tap to apply",
                @"settings.app_icon.footer": @"Icons may take a moment to change on the Home Screen.",
                @"settings.app_icon.unsupported": @"This device or install doesn't support alternate icons.",
                @"settings.app_icon.signing_error": @"iOS refused the icon change. This usually means SpringBoard either cached this app's icon info before the alternate icons existed, or doesn't recognize the icon files as part of the app's signed contents — try fully restarting your device and try again. If it still fails after that, it's likely a hard restriction on this install method that can't be worked around from inside the tweak.",
                @"settings.hide_ui_button_mode.title": @"Hide UI Button Behavior",
                @"settings.hide_ui_button_mode.menu": @"Ask Each Time",
                @"settings.hide_ui_button_mode.this_video": @"This Video Only",
                @"settings.hide_ui_button_mode.all": @"All Videos",
                @"common.ok": @"OK",
                @"common.retry": @"Retry",
                @"settings.contributors.title": @"Contributors",
                @"settings.contributors.parse_error": @"Couldn't read the contributors list. Try again in a moment.",
                @"settings.contributors.empty": @"No contributors found.",
            },
        };
    });
    return table;
}

static NSString * _Nullable InfinitokDylibDirectory(void) {
    Dl_info info;
    if (dladdr((const void *)&InfinitokDylibDirectory, &info) && info.dli_fname) {
        NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
        return [dylibPath stringByDeletingLastPathComponent];
    }
    return nil;
}

NSBundle * _Nullable InfinitokBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSString *> *candidatePaths = [NSMutableArray array];

        NSString *dylibDir = InfinitokDylibDirectory();
        if (dylibDir) {
            NSString *dir = dylibDir;
            for (int depth = 0; depth < 6 && dir.length > 1; depth++) {
                [candidatePaths addObject:[dir stringByAppendingPathComponent:@"Infinitok.bundle"]];
                [candidatePaths addObject:[dir stringByAppendingPathComponent:@"Library/Application Support/Infinitok.bundle"]];
                dir = [dir stringByDeletingLastPathComponent];
            }
        }

        NSString *appBundlePath = [[NSBundle mainBundle] bundlePath];
        if (appBundlePath) {
            [candidatePaths addObject:[appBundlePath stringByAppendingPathComponent:@"Library/Application Support/Infinitok.bundle"]];
        }

        [candidatePaths addObject:@"/var/jb/Library/Application Support/Infinitok.bundle"];

        [candidatePaths addObject:@"/Library/Application Support/Infinitok.bundle"];

        for (NSString *path in candidatePaths) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                bundle = [NSBundle bundleWithPath:path];
                if (bundle) {
                    ITLog("localization", @"Found Infinitok.bundle at %@", path);
                    break;
                }
            }
        }

        if (!bundle) {
            ITError("localization", @"Could not locate Infinitok.bundle in any of %lu candidate paths — falling back to the embedded strings table", (unsigned long)candidatePaths.count);
        }
    });
    return bundle;
}

static NSArray<NSString *> *InfinitokRawPreferredLanguages(void) {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    if ([raw isKindOfClass:[NSArray class]] && raw.count > 0) {
        return raw;
    }

    return [NSLocale preferredLanguages];
}

static NSDictionary<NSString *, NSString *> *InfinitokStringsDictionaryAtPath(NSString *lprojPath) {
    static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    @synchronized (cache) {
        NSDictionary *cached = cache[lprojPath];
        if (cached) {
            return cached;
        }
        NSString *stringsPath = [lprojPath stringByAppendingPathComponent:@"Localizable.strings"];
        NSDictionary *parsed = [NSDictionary dictionaryWithContentsOfFile:stringsPath];
        if (![parsed isKindOfClass:[NSDictionary class]]) {
            parsed = @{};
            ITError("localization", @"Could not parse %@ as a strings dictionary", stringsPath);
        }
        cache[lprojPath] = parsed;
        return parsed;
    }
}

static NSString *InfinitokPreferredLanguageCode(void) {
    for (NSString *language in InfinitokRawPreferredLanguages()) {
        NSString *base = [language componentsSeparatedByString:@"-"].firstObject;
        if ([InfinitokEmbeddedStrings() objectForKey:base]) {
            return base;
        }
    }
    return @"en";
}

static void InfinitokLogLocalizationDiagnosticsOnce(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *rawDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
        ITDebug("localization-diag", @"AppleLanguages (raw defaults) = %@", rawDefaults);
        ITDebug("localization-diag", @"NSLocale.preferredLanguages = %@", [NSLocale preferredLanguages]);
        ITDebug("localization-diag", @"resolved InfinitokRawPreferredLanguages() = %@", InfinitokRawPreferredLanguages());
        ITDebug("localization-diag", @"InfinitokPreferredLanguageCode() = %@", InfinitokPreferredLanguageCode());
        NSBundle *bundle = InfinitokBundle();
        ITDebug("localization-diag", @"InfinitokBundle() path = %@", bundle.bundlePath ?: @"(nil — bundle not found)");
        if (bundle) {
            NSString *testKey = @"settings.title";
            for (NSString *language in InfinitokRawPreferredLanguages()) {
                NSString *base = [language componentsSeparatedByString:@"-"].firstObject;
                NSString *exact = [bundle pathForResource:language ofType:@"lproj"];
                NSString *baseMatch = [bundle pathForResource:base ofType:@"lproj"];
                NSString *lprojPath = exact ?: baseMatch;
                ITDebug("localization-diag", @"  candidate '%@' -> exact lproj: %@ | base '%@' lproj: %@", language, exact ?: @"nil", base, baseMatch ?: @"nil");
                if (lprojPath) {
                    NSString *value = InfinitokStringsDictionaryAtPath(lprojPath)[testKey];
                    ITDebug("localization-diag", @"    direct-dictionary '%@' lookup -> %@", testKey, value ?: @"MISSING");
                }
            }
        }
    });
}

NSString *InfinitokLocalizedString(NSString *key) {
    InfinitokLogLocalizationDiagnosticsOnce();

    NSBundle *bundle = InfinitokBundle();
    if (bundle) {
        for (NSString *language in InfinitokRawPreferredLanguages()) {
            NSString *lprojPath = [bundle pathForResource:language ofType:@"lproj"];
            if (!lprojPath) {
                NSString *baseLanguage = [language componentsSeparatedByString:@"-"].firstObject;
                lprojPath = [bundle pathForResource:baseLanguage ofType:@"lproj"];
            }
            if (lprojPath) {
                NSString *value = InfinitokStringsDictionaryAtPath(lprojPath)[key];
                if (value) {
                    return value;
                }
            }
        }

        NSString *enPath = [bundle pathForResource:@"en" ofType:@"lproj"];
        if (enPath) {
            NSString *value = InfinitokStringsDictionaryAtPath(enPath)[key];
            if (value) {
                return value;
            }
        }
    }

    NSString *preferredLanguage = InfinitokPreferredLanguageCode();
    NSString *value = InfinitokEmbeddedStrings()[preferredLanguage][key];
    if (value) {
        return value;
    }
    value = InfinitokEmbeddedStrings()[@"en"][key];
    if (value) {
        return value;
    }

    return key;
}
