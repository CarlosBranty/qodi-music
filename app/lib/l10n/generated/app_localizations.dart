// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Qodi Music'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @connectToServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server'**
  String get connectToServer;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Song} other{{count} Songs}}'**
  String songCount(int count);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @usingDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Using music on this device only'**
  String get usingDeviceOnly;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @equalizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Presets and custom sound'**
  String get equalizerSubtitle;

  /// No description provided for @streamingQuality.
  ///
  /// In en, this message translates to:
  /// **'Streaming quality'**
  String get streamingQuality;

  /// No description provided for @streamQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get streamQualityOriginal;

  /// No description provided for @streamQualityOriginalHint.
  ///
  /// In en, this message translates to:
  /// **'Lossless / source file'**
  String get streamQualityOriginalHint;

  /// No description provided for @streamQualityOpus.
  ///
  /// In en, this message translates to:
  /// **'Opus 128 kbps'**
  String get streamQualityOpus;

  /// No description provided for @streamQualityOpusHint.
  ///
  /// In en, this message translates to:
  /// **'Saves data, transcoded on the server'**
  String get streamQualityOpusHint;

  /// No description provided for @musicOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Music on this device'**
  String get musicOnThisDevice;

  /// No description provided for @serverLibrary.
  ///
  /// In en, this message translates to:
  /// **'Server library'**
  String get serverLibrary;

  /// No description provided for @syncOfflineLibrary.
  ///
  /// In en, this message translates to:
  /// **'Sync offline library'**
  String get syncOfflineLibrary;

  /// No description provided for @syncOfflineLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Download the latest library changes'**
  String get syncOfflineLibraryHint;

  /// No description provided for @librarySynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Library synced (1 change)} other{Library synced ({count} changes)}}'**
  String librarySynced(int count);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @rescanMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Rescan music folder'**
  String get rescanMusicFolder;

  /// No description provided for @rescanMusicFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the server to look for new songs'**
  String get rescanMusicFolderHint;

  /// No description provided for @scanStarted.
  ///
  /// In en, this message translates to:
  /// **'Scan started'**
  String get scanStarted;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the scan'**
  String get scanFailed;

  /// No description provided for @downloadedMusic.
  ///
  /// In en, this message translates to:
  /// **'Downloaded music'**
  String get downloadedMusic;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your music server'**
  String get signInSubtitle;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @enterServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the server URL'**
  String get enterServerUrl;

  /// No description provided for @serverUrlRule.
  ///
  /// In en, this message translates to:
  /// **'Use a full URL like http://192.168.1.10:4040'**
  String get serverUrlRule;

  /// No description provided for @enterYourUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enterYourUsername;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @wrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password'**
  String get wrongCredentials;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @useWithoutServer.
  ///
  /// In en, this message translates to:
  /// **'Use without server'**
  String get useWithoutServer;

  /// No description provided for @useWithoutServerHint.
  ///
  /// In en, this message translates to:
  /// **'Play the music stored on this device. You can connect a server later in Settings.'**
  String get useWithoutServerHint;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errorForbidden;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check the URL.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get enterUsername;

  /// No description provided for @usernameRule.
  ///
  /// In en, this message translates to:
  /// **'Use 3–32 characters: letters, numbers, _ . -'**
  String get usernameRule;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get enterPassword;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'Use 8–128 characters'**
  String get passwordRule;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get passwordsDiffer;

  /// No description provided for @enterInvite.
  ///
  /// In en, this message translates to:
  /// **'Enter your invite code'**
  String get enterInvite;

  /// No description provided for @invalidInvite.
  ///
  /// In en, this message translates to:
  /// **'This invite code is not valid, expired or already used.'**
  String get invalidInvite;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get usernameTaken;

  /// No description provided for @badRequest.
  ///
  /// In en, this message translates to:
  /// **'Check the username and password rules.'**
  String get badRequest;

  /// No description provided for @wrongCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'The current password is wrong.'**
  String get wrongCurrentPassword;

  /// No description provided for @haveInvite.
  ///
  /// In en, this message translates to:
  /// **'Have an invite? Create account'**
  String get haveInvite;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Qodi Music server with an invite'**
  String get createAccountSubtitle;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @usersAndInvites.
  ///
  /// In en, this message translates to:
  /// **'Users & invites'**
  String get usersAndInvites;

  /// No description provided for @usersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage who can listen'**
  String get usersSubtitle;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @invites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invites;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get deleteUser;

  /// No description provided for @cannotDeleteSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t delete yourself'**
  String get cannotDeleteSelf;

  /// No description provided for @deleteUserQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? Their playlists, favorites and plays are removed and they are signed out.'**
  String deleteUserQuestion(String name);

  /// No description provided for @userDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String userDeleted(String name);

  /// No description provided for @createInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite'**
  String get createInvite;

  /// No description provided for @expiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in (hours)'**
  String get expiresInHours;

  /// No description provided for @maxUses.
  ///
  /// In en, this message translates to:
  /// **'Max uses'**
  String get maxUses;

  /// No description provided for @expiryRule.
  ///
  /// In en, this message translates to:
  /// **'Between 1 and 720 hours'**
  String get expiryRule;

  /// No description provided for @usesRule.
  ///
  /// In en, this message translates to:
  /// **'Between 1 and 50'**
  String get usesRule;

  /// No description provided for @inviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Invite created'**
  String get inviteCreated;

  /// No description provided for @shareInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Send the join link. Android users can install the app from the APK link.'**
  String get shareInviteHint;

  /// No description provided for @joinLink.
  ///
  /// In en, this message translates to:
  /// **'Join link'**
  String get joinLink;

  /// No description provided for @apkLink.
  ///
  /// In en, this message translates to:
  /// **'Android app (APK)'**
  String get apkLink;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard'**
  String get copied;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeInvite.
  ///
  /// In en, this message translates to:
  /// **'Revoke invite'**
  String get revokeInvite;

  /// No description provided for @revokeInviteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revoke invite {code}? It can no longer be used.'**
  String revokeInviteQuestion(String code);

  /// No description provided for @inviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get inviteRevoked;

  /// No description provided for @noInvites.
  ///
  /// In en, this message translates to:
  /// **'No invites yet'**
  String get noInvites;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusUsedUp.
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get statusUsedUp;

  /// No description provided for @inviteUses.
  ///
  /// In en, this message translates to:
  /// **'Uses {used}/{max}'**
  String inviteUses(int used, int max);

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn(String date);

  /// No description provided for @expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String expiredOn(String date);

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Pull to retry.'**
  String get loadFailed;

  /// No description provided for @appUpdates.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get appUpdates;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String currentVersion(String version);

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @neverChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get neverChecked;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version'**
  String get upToDate;

  /// No description provided for @noPublishedUpdate.
  ///
  /// In en, this message translates to:
  /// **'No update published on the server'**
  String get noPublishedUpdate;

  /// No description provided for @checkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get checkFailed;

  /// No description provided for @updateNoServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server to get updates'**
  String get updateNoServer;

  /// No description provided for @versionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String versionAvailable(String version);

  /// No description provided for @lastChecked.
  ///
  /// In en, this message translates to:
  /// **'{result} · checked {when}'**
  String lastChecked(String result, String when);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @updateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Update available (v{from} → v{to})'**
  String updateQuestion(String from, String to);

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get downloadingUpdate;

  /// No description provided for @checksumMismatch.
  ///
  /// In en, this message translates to:
  /// **'The download is corrupted (checksum mismatch). Please try again.'**
  String get checksumMismatch;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed. Check your connection and try again.'**
  String get updateDownloadFailed;

  /// No description provided for @installPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Qodi Music to install apps to update it.'**
  String get installPermission;

  /// No description provided for @installFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the installer.'**
  String get installFailed;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @equalizerHint.
  ///
  /// In en, this message translates to:
  /// **'Shape the sound with presets or your own curve'**
  String get equalizerHint;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @bands.
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get bands;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get presetCustom;

  /// No description provided for @equalizerUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get equalizerUnavailableTitle;

  /// No description provided for @equalizerUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The equalizer works on Android. On this device the audio engine has no equalizer.'**
  String get equalizerUnavailableBody;

  /// No description provided for @equalizerWaitingBands.
  ///
  /// In en, this message translates to:
  /// **'Play a song to load the equalizer bands of this device.'**
  String get equalizerWaitingBands;

  /// No description provided for @presetFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get presetFlat;

  /// No description provided for @presetBassBoost.
  ///
  /// In en, this message translates to:
  /// **'Bass boost'**
  String get presetBassBoost;

  /// No description provided for @presetTrebleBoost.
  ///
  /// In en, this message translates to:
  /// **'Treble boost'**
  String get presetTrebleBoost;

  /// No description provided for @presetVocal.
  ///
  /// In en, this message translates to:
  /// **'Vocal'**
  String get presetVocal;

  /// No description provided for @presetRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get presetRock;

  /// No description provided for @presetPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get presetPop;

  /// No description provided for @presetElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get presetElectronic;

  /// No description provided for @presetAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Acoustic'**
  String get presetAcoustic;

  /// No description provided for @availableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get availableOffline;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @someDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} downloaded'**
  String someDownloaded(int done, int total);

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get downloadAll;

  /// No description provided for @qualityHiRes.
  ///
  /// In en, this message translates to:
  /// **'Hi-Res'**
  String get qualityHiRes;

  /// No description provided for @qualityLossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless'**
  String get qualityLossless;

  /// No description provided for @trackInfo.
  ///
  /// In en, this message translates to:
  /// **'Track info'**
  String get trackInfo;

  /// No description provided for @infoFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get infoFormat;

  /// No description provided for @infoBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get infoBitrate;

  /// No description provided for @infoSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get infoSampleRate;

  /// No description provided for @infoBitDepth.
  ///
  /// In en, this message translates to:
  /// **'Bit depth'**
  String get infoBitDepth;

  /// No description provided for @infoChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get infoChannels;

  /// No description provided for @infoSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get infoSize;

  /// No description provided for @channelsMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get channelsMono;

  /// No description provided for @channelsStereo.
  ///
  /// In en, this message translates to:
  /// **'Stereo'**
  String get channelsStereo;

  /// No description provided for @channelCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel} other{{count} channels}}'**
  String channelCount(int count);

  /// No description provided for @kbpsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kbps'**
  String kbpsValue(int value);

  /// No description provided for @kHzValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kHz'**
  String kHzValue(String value);

  /// No description provided for @bitsValue.
  ///
  /// In en, this message translates to:
  /// **'{value}-bit'**
  String bitsValue(int value);

  /// No description provided for @transcodedFrom.
  ///
  /// In en, this message translates to:
  /// **'{streamed} · from {source}'**
  String transcodedFrom(String streamed, String source);

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @playingNext.
  ///
  /// In en, this message translates to:
  /// **'Playing next: {title}'**
  String playingNext(String title);

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get addedToQueue;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @removeDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get removeDownload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @goToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to album · {album}'**
  String goToAlbum(String album);

  /// No description provided for @goToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to artist · {artist}'**
  String goToArtist(String artist);

  /// No description provided for @favoritesUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorites'**
  String get favoritesUpdateFailed;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @albumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String albumCount(int count);

  /// No description provided for @songCountLower.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String songCountLower(int count);

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @deviceUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Device music is up to date'**
  String get deviceUpToDate;

  /// No description provided for @deviceRescanResult.
  ///
  /// In en, this message translates to:
  /// **'Found {added} new, {removed} removed'**
  String deviceRescanResult(int added, int removed);

  /// No description provided for @deviceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load device music\n{error}'**
  String deviceLoadFailed(String error);

  /// No description provided for @searchDeviceMusic.
  ///
  /// In en, this message translates to:
  /// **'Search device music'**
  String get searchDeviceMusic;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @songsOnDevice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Song on this device} other{{count} Songs on this device}}'**
  String songsOnDevice(int count);

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @deviceFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a device song to keep it here.'**
  String get deviceFavoritesEmpty;

  /// No description provided for @noSongsFound.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get noSongsFound;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbumsFound;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No artists found'**
  String get noArtistsFound;

  /// No description provided for @newDevicePlaylist.
  ///
  /// In en, this message translates to:
  /// **'New device playlist'**
  String get newDevicePlaylist;

  /// No description provided for @importSongsHint.
  ///
  /// In en, this message translates to:
  /// **'Import songs into the app to play them here.'**
  String get importSongsHint;

  /// No description provided for @noMusicInFolders.
  ///
  /// In en, this message translates to:
  /// **'No music found in {folders}.\nAdd a folder in Settings.'**
  String noMusicInFolders(String folders);

  /// No description provided for @theScannedFolders.
  ///
  /// In en, this message translates to:
  /// **'the scanned folders'**
  String get theScannedFolders;

  /// No description provided for @importSongs.
  ///
  /// In en, this message translates to:
  /// **'Import songs'**
  String get importSongs;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// No description provided for @permissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Qodi Music needs access to your music files.\nAllow it in the app settings.'**
  String get permissionPermanentlyDenied;

  /// No description provided for @permissionRationale.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your music files to play the songs stored on this device.'**
  String get permissionRationale;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowAccess;

  /// No description provided for @folderPickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the folder picker'**
  String get folderPickerFailed;

  /// No description provided for @importedSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 song} other{Imported {count} songs}}'**
  String importedSongs(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @albumGone.
  ///
  /// In en, this message translates to:
  /// **'This album is no longer on this device'**
  String get albumGone;

  /// No description provided for @artistGone.
  ///
  /// In en, this message translates to:
  /// **'This artist is no longer on this device'**
  String get artistGone;

  /// No description provided for @playlistGone.
  ///
  /// In en, this message translates to:
  /// **'This playlist is no longer on this device'**
  String get playlistGone;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get renamePlaylist;

  /// No description provided for @deletePlaylistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get deletePlaylistQuestion;

  /// No description provided for @deleteDevicePlaylistBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted. Songs stay on your device.'**
  String deleteDevicePlaylistBody(String name);

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @folderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get folderDefault;

  /// No description provided for @folderAddedByYou.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get folderAddedByYou;

  /// No description provided for @folderNotFound.
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get folderNotFound;

  /// No description provided for @removeFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get removeFolder;

  /// No description provided for @importSongsHintSettings.
  ///
  /// In en, this message translates to:
  /// **'Copies audio files into the app'**
  String get importSongsHintSettings;

  /// No description provided for @rescanDeviceMusic.
  ///
  /// In en, this message translates to:
  /// **'Rescan device music'**
  String get rescanDeviceMusic;

  /// No description provided for @songsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song found} other{{count} songs found}}'**
  String songsFound(int count);

  /// No description provided for @scanDone.
  ///
  /// In en, this message translates to:
  /// **'Scan done: {added} new, {removed} removed'**
  String scanDone(int added, int removed);

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to playlist'**
  String get addedToPlaylist;

  /// No description provided for @addedSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 song} other{Added {count} songs}}'**
  String addedSongs(int count);

  /// No description provided for @addToPlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add to playlist'**
  String get addToPlaylistFailed;

  /// No description provided for @listener.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get listener;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @offlineModeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Offline mode,'**
  String get offlineModeGreeting;

  /// No description provided for @listenPrompt.
  ///
  /// In en, this message translates to:
  /// **'What do you want\nto listen today?'**
  String get listenPrompt;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @homePlaylistsHeader.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get homePlaylistsHeader;

  /// No description provided for @noPlaylistsYetHome.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Create one in Library.'**
  String get noPlaylistsYetHome;

  /// No description provided for @noDevicePlaylistsYetHome.
  ///
  /// In en, this message translates to:
  /// **'No device playlists yet. Create one in Library.'**
  String get noDevicePlaylistsYetHome;

  /// No description provided for @playlistsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load playlists'**
  String get playlistsLoadFailed;

  /// No description provided for @favoritesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any song to keep it here.'**
  String get favoritesEmptyHint;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites'**
  String get favoritesLoadFailed;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @scanningYourMusic.
  ///
  /// In en, this message translates to:
  /// **'Scanning your music…'**
  String get scanningYourMusic;

  /// No description provided for @allowAccessShort.
  ///
  /// In en, this message translates to:
  /// **'Allow access to play your music files'**
  String get allowAccessShort;

  /// No description provided for @onThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onThisDevice;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @libraryNeedsServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server in Settings to see your library.'**
  String get libraryNeedsServer;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get yourLibrary;

  /// No description provided for @createPlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create playlist'**
  String get createPlaylistFailed;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistsLoadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load playlists\n{error}'**
  String playlistsLoadFailedDetail(String error);

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @favoritesLoadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites\n{error}'**
  String favoritesLoadFailedDetail(String error);

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @downloadingSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Downloading 1 song} other{Downloading {count} songs}}'**
  String downloadingSongs(int count);

  /// No description provided for @albumLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load album\n{error}'**
  String albumLoadFailed(String error);

  /// No description provided for @artistLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load artist\n{error}'**
  String artistLoadFailed(String error);

  /// No description provided for @exploreServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore your server'**
  String get exploreServerTitle;

  /// No description provided for @exploreServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Browsing albums and artists of your music server needs a connection. Your device music is in Library.'**
  String get exploreServerMessage;

  /// No description provided for @browseMusic.
  ///
  /// In en, this message translates to:
  /// **'Browse Music'**
  String get browseMusic;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums'**
  String get searchHint;

  /// No description provided for @somethingWentWrongDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.\n{error}'**
  String somethingWentWrongDetail(String error);

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmpty;

  /// No description provided for @playlistSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the playlist'**
  String get playlistSaveFailed;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename'**
  String get renameFailed;

  /// No description provided for @deletePlaylistBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted. Songs stay in your library.'**
  String deletePlaylistBody(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete'**
  String get deleteFailed;

  /// No description provided for @playlistOptions.
  ///
  /// In en, this message translates to:
  /// **'Playlist options'**
  String get playlistOptions;

  /// No description provided for @emptyPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Empty playlist. Long-press any song and choose \"Add to playlist\".'**
  String get emptyPlaylistHint;

  /// No description provided for @playlistLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load playlist\n{error}'**
  String playlistLoadFailed(String error);

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @downloadingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Downloading 1 song…} other{Downloading {count} songs…}}'**
  String downloadingCount(int count);

  /// No description provided for @noDownloadsYet.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet. Use \"Download\" on a song, album or playlist to listen offline.'**
  String get noDownloadsYet;

  /// No description provided for @downloadsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read downloads\n{error}'**
  String downloadsLoadFailed(String error);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @nothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get nothingPlaying;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat: off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat: all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat: one'**
  String get repeatOne;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics for this song'**
  String get noLyrics;

  /// No description provided for @lyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics · {title}'**
  String lyricsTitle(String title);

  /// No description provided for @lyricsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load lyrics'**
  String get lyricsLoadFailed;

  /// No description provided for @seek.
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get seek;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @browseDeviceMusic.
  ///
  /// In en, this message translates to:
  /// **'Browse music on this device'**
  String get browseDeviceMusic;

  /// No description provided for @statsServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats live on your server'**
  String get statsServerTitle;

  /// No description provided for @statsServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Listening stats are computed by your music server. Connect one to see them.'**
  String get statsServerMessage;

  /// No description provided for @yourStats.
  ///
  /// In en, this message translates to:
  /// **'Your Stats'**
  String get yourStats;

  /// No description provided for @statsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load stats\n{error}'**
  String statsLoadFailed(String error);

  /// No description provided for @listeningTime.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get listeningTime;

  /// No description provided for @totalPlays.
  ///
  /// In en, this message translates to:
  /// **'Total plays'**
  String get totalPlays;

  /// No description provided for @uniqueTracks.
  ///
  /// In en, this message translates to:
  /// **'Unique tracks'**
  String get uniqueTracks;

  /// No description provided for @ofPlays.
  ///
  /// In en, this message translates to:
  /// **'of plays'**
  String get ofPlays;

  /// No description provided for @noPlaysYet.
  ///
  /// In en, this message translates to:
  /// **'No plays yet'**
  String get noPlaysYet;

  /// No description provided for @topArtist.
  ///
  /// In en, this message translates to:
  /// **'Top artist'**
  String get topArtist;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @minutesListened.
  ///
  /// In en, this message translates to:
  /// **'minutes listened'**
  String get minutesListened;

  /// No description provided for @topTracks.
  ///
  /// In en, this message translates to:
  /// **'Top tracks'**
  String get topTracks;

  /// No description provided for @topTracksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play some music to see your top tracks.'**
  String get topTracksEmpty;

  /// No description provided for @range7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get range7Days;

  /// No description provided for @range30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get range30Days;

  /// No description provided for @rangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rangeAllTime;

  /// No description provided for @chooseMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a music folder'**
  String get chooseMusicFolder;

  /// No description provided for @importMusic.
  ///
  /// In en, this message translates to:
  /// **'Import music'**
  String get importMusic;

  /// No description provided for @playbackChannelName.
  ///
  /// In en, this message translates to:
  /// **'Qodi Music playback'**
  String get playbackChannelName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
