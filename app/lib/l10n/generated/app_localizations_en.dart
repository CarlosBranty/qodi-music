// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Qodi Music';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get done => 'Done';

  @override
  String get copy => 'Copy';

  @override
  String get rename => 'Rename';

  @override
  String get retry => 'Retry';

  @override
  String get more => 'More';

  @override
  String get close => 'Close';

  @override
  String get search => 'Search';

  @override
  String get openSettings => 'Open settings';

  @override
  String get connectToServer => 'Connect to a server';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0';
  }

  @override
  String get settings => 'Settings';

  @override
  String get notConnected => 'Not connected';

  @override
  String get usingDeviceOnly => 'Using music on this device only';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get playback => 'Playback';

  @override
  String get equalizerSubtitle => 'Presets and custom sound';

  @override
  String get streamingQuality => 'Streaming quality';

  @override
  String get streamQualityOriginal => 'Original';

  @override
  String get streamQualityOriginalHint => 'Lossless / source file';

  @override
  String get streamQualityOpus => 'Opus 128 kbps';

  @override
  String get streamQualityOpusHint => 'Saves data, transcoded on the server';

  @override
  String get musicOnThisDevice => 'Music on this device';

  @override
  String get serverLibrary => 'Server library';

  @override
  String get syncOfflineLibrary => 'Sync offline library';

  @override
  String get syncOfflineLibraryHint => 'Download the latest library changes';

  @override
  String librarySynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Library synced ($count changes)',
      one: 'Library synced (1 change)',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get rescanMusicFolder => 'Rescan music folder';

  @override
  String get rescanMusicFolderHint => 'Ask the server to look for new songs';

  @override
  String get scanStarted => 'Scan started';

  @override
  String get scanFailed => 'Could not start the scan';

  @override
  String get downloadedMusic => 'Downloaded music';

  @override
  String get logOut => 'Log out';

  @override
  String get signInSubtitle => 'Sign in to your music server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get enterServerUrl => 'Enter the server URL';

  @override
  String get serverUrlRule => 'Use a full URL like http://192.168.1.10:4040';

  @override
  String get enterYourUsername => 'Enter your username';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get wrongCredentials => 'Wrong username or password';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get useWithoutServer => 'Use without server';

  @override
  String get useWithoutServerHint =>
      'Play the music stored on this device. You can connect a server later in Settings.';

  @override
  String get errorForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorNetwork => 'Cannot reach the server. Check the URL.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get enterUsername => 'Enter a username';

  @override
  String get usernameRule => 'Use 3–32 characters: letters, numbers, _ . -';

  @override
  String get enterPassword => 'Enter a password';

  @override
  String get passwordRule => 'Use 8–128 characters';

  @override
  String get passwordsDiffer => 'The passwords do not match';

  @override
  String get enterInvite => 'Enter your invite code';

  @override
  String get invalidInvite =>
      'This invite code is not valid, expired or already used.';

  @override
  String get usernameTaken => 'That username is already taken.';

  @override
  String get badRequest => 'Check the username and password rules.';

  @override
  String get wrongCurrentPassword => 'The current password is wrong.';

  @override
  String get haveInvite => 'Have an invite? Create account';

  @override
  String get createAccount => 'Create account';

  @override
  String get createAccountSubtitle => 'Join a Qodi Music server with an invite';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get account => 'Account';

  @override
  String get admin => 'Admin';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get usersAndInvites => 'Users & invites';

  @override
  String get usersSubtitle => 'Manage who can listen';

  @override
  String get users => 'Users';

  @override
  String get invites => 'Invites';

  @override
  String get you => 'You';

  @override
  String get deleteUser => 'Delete user';

  @override
  String get cannotDeleteSelf => 'You can\'t delete yourself';

  @override
  String deleteUserQuestion(String name) {
    return 'Delete $name? Their playlists, favorites and plays are removed and they are signed out.';
  }

  @override
  String userDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get createInvite => 'Create invite';

  @override
  String get expiresInHours => 'Expires in (hours)';

  @override
  String get maxUses => 'Max uses';

  @override
  String get expiryRule => 'Between 1 and 720 hours';

  @override
  String get usesRule => 'Between 1 and 50';

  @override
  String get inviteCreated => 'Invite created';

  @override
  String get shareInviteHint =>
      'Send the join link. Android users can install the app from the APK link.';

  @override
  String get joinLink => 'Join link';

  @override
  String get apkLink => 'Android app (APK)';

  @override
  String get copyCode => 'Copy code';

  @override
  String get copied => 'Copied to the clipboard';

  @override
  String get revoke => 'Revoke';

  @override
  String get revokeInvite => 'Revoke invite';

  @override
  String revokeInviteQuestion(String code) {
    return 'Revoke invite $code? It can no longer be used.';
  }

  @override
  String get inviteRevoked => 'Invite revoked';

  @override
  String get noInvites => 'No invites yet';

  @override
  String get statusActive => 'Active';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusUsedUp => 'Used up';

  @override
  String inviteUses(int used, int max) {
    return 'Uses $used/$max';
  }

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String expiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String get loadFailed => 'Could not load. Pull to retry.';

  @override
  String get appUpdates => 'App updates';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String currentVersion(String version) {
    return 'Current version $version';
  }

  @override
  String get checking => 'Checking…';

  @override
  String get neverChecked => 'Not checked yet';

  @override
  String get upToDate => 'You have the latest version';

  @override
  String get noPublishedUpdate => 'No update published on the server';

  @override
  String get checkFailed => 'Could not check for updates';

  @override
  String get updateNoServer => 'Connect to a server to get updates';

  @override
  String versionAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String lastChecked(String result, String when) {
    return '$result · checked $when';
  }

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateQuestion(String from, String to) {
    return 'Update available (v$from → v$to)';
  }

  @override
  String get update => 'Update';

  @override
  String get later => 'Later';

  @override
  String get downloadingUpdate => 'Downloading update…';

  @override
  String get checksumMismatch =>
      'The download is corrupted (checksum mismatch). Please try again.';

  @override
  String get updateDownloadFailed =>
      'The download failed. Check your connection and try again.';

  @override
  String get installPermission =>
      'Allow Qodi Music to install apps to update it.';

  @override
  String get installFailed => 'Could not open the installer.';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get reset => 'Reset';

  @override
  String get equalizerHint => 'Shape the sound with presets or your own curve';

  @override
  String get presets => 'Presets';

  @override
  String get bands => 'Bands';

  @override
  String get presetCustom => 'Custom';

  @override
  String get equalizerUnavailableTitle => 'Not available on this platform';

  @override
  String get equalizerUnavailableBody =>
      'The equalizer works on Android. On this device the audio engine has no equalizer.';

  @override
  String get equalizerWaitingBands =>
      'Play a song to load the equalizer bands of this device.';

  @override
  String get presetFlat => 'Flat';

  @override
  String get presetBassBoost => 'Bass boost';

  @override
  String get presetTrebleBoost => 'Treble boost';

  @override
  String get presetVocal => 'Vocal';

  @override
  String get presetRock => 'Rock';

  @override
  String get presetPop => 'Pop';

  @override
  String get presetElectronic => 'Electronic';

  @override
  String get presetAcoustic => 'Acoustic';

  @override
  String get availableOffline => 'Available offline';

  @override
  String get downloaded => 'Downloaded';

  @override
  String someDownloaded(int done, int total) {
    return '$done of $total downloaded';
  }

  @override
  String get downloadAll => 'Download all';

  @override
  String get qualityHiRes => 'Hi-Res';

  @override
  String get qualityLossless => 'Lossless';

  @override
  String get trackInfo => 'Track info';

  @override
  String get infoFormat => 'Format';

  @override
  String get infoBitrate => 'Bitrate';

  @override
  String get infoSampleRate => 'Sample rate';

  @override
  String get infoBitDepth => 'Bit depth';

  @override
  String get infoChannels => 'Channels';

  @override
  String get infoSize => 'Size';

  @override
  String get channelsMono => 'Mono';

  @override
  String get channelsStereo => 'Stereo';

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String kbpsValue(int value) {
    return '$value kbps';
  }

  @override
  String kHzValue(String value) {
    return '$value kHz';
  }

  @override
  String bitsValue(int value) {
    return '$value-bit';
  }

  @override
  String transcodedFrom(String streamed, String source) {
    return '$streamed · from $source';
  }

  @override
  String get playNext => 'Play next';

  @override
  String playingNext(String title) {
    return 'Playing next: $title';
  }

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get removeDownload => 'Remove download';

  @override
  String get download => 'Download';

  @override
  String goToAlbum(String album) {
    return 'Go to album · $album';
  }

  @override
  String goToArtist(String artist) {
    return 'Go to artist · $artist';
  }

  @override
  String get favoritesUpdateFailed => 'Could not update favorites';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get songs => 'Songs';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artists';

  @override
  String get favorites => 'Favorites';

  @override
  String get playlists => 'Playlists';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String songCountLower(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get clear => 'Clear';

  @override
  String get deviceUpToDate => 'Device music is up to date';

  @override
  String deviceRescanResult(int added, int removed) {
    return 'Found $added new, $removed removed';
  }

  @override
  String deviceLoadFailed(String error) {
    return 'Could not load device music\n$error';
  }

  @override
  String get searchDeviceMusic => 'Search device music';

  @override
  String get scanning => 'Scanning…';

  @override
  String songsOnDevice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs on this device',
      one: '1 Song on this device',
    );
    return '$_temp0';
  }

  @override
  String get rescan => 'Rescan';

  @override
  String get deviceFavoritesEmpty =>
      'Tap the heart on a device song to keep it here.';

  @override
  String get noSongsFound => 'No songs found';

  @override
  String get noAlbumsFound => 'No albums found';

  @override
  String get noArtistsFound => 'No artists found';

  @override
  String get newDevicePlaylist => 'New device playlist';

  @override
  String get importSongsHint => 'Import songs into the app to play them here.';

  @override
  String noMusicInFolders(String folders) {
    return 'No music found in $folders.\nAdd a folder in Settings.';
  }

  @override
  String get theScannedFolders => 'the scanned folders';

  @override
  String get importSongs => 'Import songs';

  @override
  String get addFolder => 'Add folder';

  @override
  String get permissionPermanentlyDenied =>
      'Qodi Music needs access to your music files.\nAllow it in the app settings.';

  @override
  String get permissionRationale =>
      'Allow access to your music files to play the songs stored on this device.';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get folderPickerFailed => 'Could not open the folder picker';

  @override
  String importedSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count songs',
      one: 'Imported 1 song',
    );
    return '$_temp0';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get album => 'Album';

  @override
  String get artist => 'Artist';

  @override
  String get playlist => 'Playlist';

  @override
  String get albumGone => 'This album is no longer on this device';

  @override
  String get artistGone => 'This artist is no longer on this device';

  @override
  String get playlistGone => 'This playlist is no longer on this device';

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get deletePlaylistQuestion => 'Delete playlist?';

  @override
  String deleteDevicePlaylistBody(String name) {
    return '\"$name\" will be deleted. Songs stay on your device.';
  }

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get folderDefault => 'Default';

  @override
  String get folderAddedByYou => 'Added by you';

  @override
  String get folderNotFound => 'not found';

  @override
  String get removeFolder => 'Remove folder';

  @override
  String get importSongsHintSettings => 'Copies audio files into the app';

  @override
  String get rescanDeviceMusic => 'Rescan device music';

  @override
  String songsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs found',
      one: '1 song found',
    );
    return '$_temp0';
  }

  @override
  String scanDone(int added, int removed) {
    return 'Scan done: $added new, $removed removed';
  }

  @override
  String get addedToPlaylist => 'Added to playlist';

  @override
  String addedSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count songs',
      one: 'Added 1 song',
    );
    return '$_temp0';
  }

  @override
  String get addToPlaylistFailed => 'Could not add to playlist';

  @override
  String get listener => 'Listener';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get offlineModeGreeting => 'Offline mode,';

  @override
  String get listenPrompt => 'What do you want\nto listen today?';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get viewAll => 'View all';

  @override
  String get homePlaylistsHeader => 'Playlist';

  @override
  String get noPlaylistsYetHome => 'No playlists yet. Create one in Library.';

  @override
  String get noDevicePlaylistsYetHome =>
      'No device playlists yet. Create one in Library.';

  @override
  String get playlistsLoadFailed => 'Could not load playlists';

  @override
  String get favoritesEmptyHint => 'Tap the heart on any song to keep it here.';

  @override
  String get favoritesLoadFailed => 'Could not load favorites';

  @override
  String get loading => 'Loading…';

  @override
  String get scanningYourMusic => 'Scanning your music…';

  @override
  String get allowAccessShort => 'Allow access to play your music files';

  @override
  String get onThisDevice => 'On this device';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get libraryNeedsServer =>
      'Connect to a server in Settings to see your library.';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get createPlaylistFailed => 'Could not create playlist';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String playlistsLoadFailedDetail(String error) {
    return 'Could not load playlists\n$error';
  }

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String favoritesLoadFailedDetail(String error) {
    return 'Could not load favorites\n$error';
  }

  @override
  String get play => 'Play';

  @override
  String downloadingSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count songs',
      one: 'Downloading 1 song',
    );
    return '$_temp0';
  }

  @override
  String albumLoadFailed(String error) {
    return 'Could not load album\n$error';
  }

  @override
  String artistLoadFailed(String error) {
    return 'Could not load artist\n$error';
  }

  @override
  String get exploreServerTitle => 'Explore your server';

  @override
  String get exploreServerMessage =>
      'Browsing albums and artists of your music server needs a connection. Your device music is in Library.';

  @override
  String get browseMusic => 'Browse Music';

  @override
  String get searchHint => 'Search songs, artists, albums';

  @override
  String somethingWentWrongDetail(String error) {
    return 'Something went wrong.\n$error';
  }

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get playlistSaveFailed => 'Could not save the playlist';

  @override
  String get renameFailed => 'Could not rename';

  @override
  String deletePlaylistBody(String name) {
    return '\"$name\" will be deleted. Songs stay in your library.';
  }

  @override
  String get deleteFailed => 'Could not delete';

  @override
  String get playlistOptions => 'Playlist options';

  @override
  String get emptyPlaylistHint =>
      'Empty playlist. Long-press any song and choose \"Add to playlist\".';

  @override
  String playlistLoadFailed(String error) {
    return 'Could not load playlist\n$error';
  }

  @override
  String get playlistName => 'Playlist name';

  @override
  String downloadingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count songs…',
      one: 'Downloading 1 song…',
    );
    return '$_temp0';
  }

  @override
  String get noDownloadsYet =>
      'No downloads yet. Use \"Download\" on a song, album or playlist to listen offline.';

  @override
  String downloadsLoadFailed(String error) {
    return 'Could not read downloads\n$error';
  }

  @override
  String get back => 'Back';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get queue => 'Queue';

  @override
  String get moreActions => 'More actions';

  @override
  String get nothingPlaying => 'Nothing is playing';

  @override
  String get repeatOff => 'Repeat: off';

  @override
  String get repeatAll => 'Repeat: all';

  @override
  String get repeatOne => 'Repeat: one';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get pause => 'Pause';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get noLyrics => 'No lyrics for this song';

  @override
  String lyricsTitle(String title) {
    return 'Lyrics · $title';
  }

  @override
  String get lyricsLoadFailed => 'Could not load lyrics';

  @override
  String get seek => 'Seek';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navLibrary => 'Library';

  @override
  String get navStats => 'Stats';

  @override
  String get browseDeviceMusic => 'Browse music on this device';

  @override
  String get statsServerTitle => 'Stats live on your server';

  @override
  String get statsServerMessage =>
      'Listening stats are computed by your music server. Connect one to see them.';

  @override
  String get yourStats => 'Your Stats';

  @override
  String statsLoadFailed(String error) {
    return 'Could not load stats\n$error';
  }

  @override
  String get listeningTime => 'Listening time';

  @override
  String get totalPlays => 'Total plays';

  @override
  String get uniqueTracks => 'Unique tracks';

  @override
  String get ofPlays => 'of plays';

  @override
  String get noPlaysYet => 'No plays yet';

  @override
  String get topArtist => 'Top artist';

  @override
  String get daily => 'Daily';

  @override
  String get minutesListened => 'minutes listened';

  @override
  String get topTracks => 'Top tracks';

  @override
  String get topTracksEmpty => 'Play some music to see your top tracks.';

  @override
  String get range7Days => '7 days';

  @override
  String get range30Days => '30 days';

  @override
  String get rangeAllTime => 'All time';

  @override
  String get chooseMusicFolder => 'Choose a music folder';

  @override
  String get importMusic => 'Import music';

  @override
  String get playbackChannelName => 'Qodi Music playback';
}
