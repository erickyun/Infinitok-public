# Infinitok
A TikTok tweak (Theos, iOS)

## Features

### Feed
No Ads, Auto Play Next Video, Show Progress Bar, Persistent Progress Slider, Faster Feed Scrolling, Show/Hide UI Button, Skip Recommendations, Disable Live Broadcast, Disable Pull-to-refresh, Disable Feed Refresh, Hide Tako Button, Hide AI Videos, Hide Caption/Hashtags, Hide Comments Button, Hide Likes Button, Hide Audio Title, Hide Share Button, Hide Search Button, Hide Account Suggestions, Show Exact Post Timestamp, Show Content Region Badge, Extended Comment Limit, Stop Playback, Buttons on Right Side, Show Usernames, Video Like Count, Video Upload Date, Hide Live Button, Hide Download Button (TikTok's native one), Hide Video Button (the tab bar "+"), Hide Find Similar, Hide Feed Tabs (Following/Friends/For You strip), Hide Friends Tab, Hide Profile Tab, Hide Tab Bar Text, Hide UI Button Behavior (ask each time / this video only / all videos)

### Video & Photos
Download Videos, Download HD Video, Download Photos (all or a specific one, no watermark), Download Music, Remove Watermark, Download Button / Share Sheet toggles, Persistent Playback Speed, Copy Description, Copy Video Link, Copy Music Link, Post Stats

### Comments
Save Images From Comments, Copy Comment Without Username, Translate Comments, Full-Length Comments, Enable Comment Reposts, Like/Dislike Comment Confirmation

### Stories
Story Download, Story View Count, Watch Stories Anonymously

### Favorites
Show Only Favorites

### Profile
Show Username Instead Of Name, Save Avatars With Long Press, Copy Profile Info, Exact Follower Count, Exact View Count, Fake Follower/Following Count, Fake Profile Likes, Fake Verified Badge, Visit Profiles Privately, Extended Bio, Lock Favorites, Profile Save, Force New Profile UI, Profile Background (Change Background), Delete All Reposts, Show/Hide UI Button

### Messages
Hide Typing Indicator, Read Chats Anonymously, Anti Delete Messages, DM Delete Confirmation, Save Media From DMs, Streak Keeper, Enable Voice Messages

### Media Vault
Save Downloads To Vault, Media Vault (browse/share/delete everything saved)

### Privacy & Anonymity
Ghost Mode (anonymous story views, private profile visits, hidden read receipts and typing indicator in one toggle)

### Other
Like Confirmation, Follow Confirmation, Confirm Repost, Confirm Add To Favorites, Confirm Sending Comment, Always Open Safari, Always Upload HD, Region Changing, Disable Sensitive Content, Disable Warnings, Share Sheet For Custom Save Location, App Lock, Lock Chats, Fast Logout, Auto Clear History, OLED Mode, Custom Accent Color, Enable Liquid Glass UI (with separate toggles for buttons/menus, toasts/notices, and modals/sheets), Enable Flex, Remove Logged-In Account Limit, Disable Phone Binding Popup, Live Button Action (default / Infinitok settings / playback speed), Custom Font (import/reset a .ttf/.otf/.ttc), Alternate App Icons, Settings Search, Debug Logging & Export/Clear Debug Log, Contributors screen

## Settings
Full-screen with a back button and animated open/close. The "Infinitok settings" row inserted into TikTok's own Settings list uses a grey icon.

## Credits
- [Mod4](https://github.com/M0d-4)
- [faroukbmiled](https://github.com/faroukbmiled)
- [jaydenjcpy](https://github.com/jaydenjcpy)
- [raulsaeed](https://github.com/raulsaeed)
- [BandarHL](https://github.com/BandarHL)

## Localization
English and Arabic.

## CI: Build & Inject
`.github/workflows/build-and-inject.yml`, manually triggered. Inputs:
- `ipa_url` — a decrypted TikTok `.ipa` you own. Leave empty to just build the `.deb`.
- `upload_to_filebin` — uploads the built `.ipa` to filebin.net.
- `create_release` — publishes a GitHub Release with the download link.
- `patch_sideload` — patches the `.ipa` with [ipapatch](https://github.com/asdfzxcvbn/ipapatch) (zxPluginsInject) for sideloading.

## Identity & Music (CleanIdentity)
Five independent switches under Infinitok Settings → Identity & Music (enabled by default): video usernames, video avatars, music disc, comment usernames (including @mentions and creator names), and comment avatars (including creator-liked badges). The port uses UI-only hooks from the standalone CleanIdentity branch; it does not import DouX login or network hooks. Recycled comment rows and view visibility are guarded by the existing CleanIdentity implementation. Restart TikTok after changing switches if an existing view does not refresh. Tested on-device compatibility is not implied.
