// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get welcome => 'Welcome to NOOR';

  @override
  String get openVideo => 'Open one or more videos';

  @override
  String get onlineVideo => 'Download or stream a link';

  @override
  String get onlineHint =>
      'Paste a video link and choose Download or Streaming. YouTube, Facebook, TikTok and X support is experimental. Direct video links are supported too.';

  @override
  String get videoLink => 'Video link';

  @override
  String get pasteLink => 'Paste link';

  @override
  String get invalidLink => 'Enter a valid HTTP or HTTPS link.';

  @override
  String get downloadVideo => 'Download video';

  @override
  String get streaming => 'Streaming — watch online';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get onlineLimit =>
      'Download only permitted content. Sources may deny downloads or streaming. Interrupted downloads can resume when the source supports it.';

  @override
  String get downloadingVideo => 'Downloading video…';

  @override
  String get preparingLink => 'Preparing link… First use may take longer.';

  @override
  String get operationCancelled => 'Operation cancelled.';

  @override
  String get onlineUnavailable => 'This link could not be processed.';

  @override
  String get tryStreaming =>
      'Try Streaming to watch online, or retry. Some sources allow neither option.';

  @override
  String get errorDetails => 'Reason details';

  @override
  String get completedDownloads => 'Completed downloads';

  @override
  String get importingVideo => 'Importing video…';

  @override
  String get importFailed =>
      'Could not import the video. Check file access and available storage, then try again.';

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get downloadsEmpty => 'Your downloaded files will appear here.';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String playerError(String message) {
    return 'Playback issue: $message';
  }

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get seekBack => 'Back 10 seconds';

  @override
  String get seekForward => 'Forward 10 seconds';

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get filterAll => 'All';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String get filterRecent => 'Recently played';

  @override
  String get searchHint => 'Search library';

  @override
  String get noResults => 'No results';

  @override
  String get fileMissing => 'File not found';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String resumedAt(String time) {
    return 'Resumed from $time';
  }

  @override
  String get speed => 'Playback speed';

  @override
  String get audioTrack => 'Audio track';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesOff => 'Off';

  @override
  String trackN(int n) {
    return 'Track $n';
  }

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get volume => 'Volume';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get nextVideo => 'Next video';

  @override
  String get fileNotFound => 'The file is missing or no longer accessible';

  @override
  String get downloadKind => 'Download type';

  @override
  String get videoWithAudio => 'Video with audio';

  @override
  String get audioOnlyMp3 => 'Audio only (MP3)';

  @override
  String get audioQuality => 'Audio bitrate';

  @override
  String get videoQuality => 'Maximum video resolution';

  @override
  String get highestQuality => 'Highest available';

  @override
  String get audioFormatHint => 'Extract the audio as an MP3 file.';

  @override
  String get videoQualityHint =>
      'Downloads the best available resolution up to your choice; it does not upscale.';

  @override
  String get downloadAudio => 'Download audio';

  @override
  String get publicDownloadHint => 'Saved in Downloads/NOOR on your device.';

  @override
  String get saveToPhoneDownloads => 'Save to phone Downloads';

  @override
  String get openDownloadsFolder => 'Open Downloads';

  @override
  String get folderOpenHint => 'Open Download/NOOR in your file manager.';

  @override
  String get downloadSaved => 'Saved to Downloads/NOOR';

  @override
  String get resumeDownload => 'Resume download';

  @override
  String get downloadPaused => 'Download paused';

  @override
  String get downloadWaiting => 'Waiting to retry — check your connection';

  @override
  String get openAudio => 'Play audio';

  @override
  String get openFolder => 'Open folder';

  @override
  String get dropMediaHint => 'Drop audio, video files or a folder into NOOR';

  @override
  String get autoplayNext => 'Autoplay next video';

  @override
  String get autoplayNextHint =>
      'When a video ends, the next one from the same folder or selection starts after 5 seconds.';

  @override
  String upNextIn(int seconds, String title) {
    return 'Up next in ${seconds}s: $title';
  }

  @override
  String get playNow => 'Play now';

  @override
  String removedFromLibrary(String title) {
    return 'Removed “$title” from the library';
  }

  @override
  String get undo => 'Undo';

  @override
  String get errorNetwork =>
      'Could not reach the site. Check your internet connection and try again.';

  @override
  String get errorUnavailable =>
      'This video is unavailable or was removed from the site.';

  @override
  String get errorPrivate => 'This video is private and cannot be accessed.';

  @override
  String get errorLoginRequired =>
      'The site requires signing in or verification for this video.';

  @override
  String get errorUnsupported =>
      'This link is not supported. Try the link to the video itself.';

  @override
  String get errorQuality =>
      'The requested quality is unavailable. Choose a higher resolution or “Highest available”.';

  @override
  String get errorTooLarge => 'The file is larger than the 2 GB limit.';

  @override
  String get errorStorage =>
      'There is not enough storage space to save the file.';

  @override
  String get errorEngine =>
      'Download engine files are missing. Use the complete NOOR folder.';

  @override
  String get engineTitle => 'Download engine';

  @override
  String engineVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get engineVersionUnknown => 'Version not known yet';

  @override
  String get engineHint =>
      'Sites change often. If links that used to work start failing, update the engine.';

  @override
  String get engineUpdate => 'Check for update';

  @override
  String get engineUpdating => 'Updating…';

  @override
  String engineUpToDate(String version) {
    return 'The engine is already up to date ($version)';
  }

  @override
  String engineUpdated(String version) {
    return 'Updated to $version';
  }

  @override
  String get engineUpdateFailed =>
      'Update failed. Check your internet connection and try again.';

  @override
  String get engineBusy =>
      'Wait for the current download to finish, or cancel it first.';

  @override
  String get checkQualities => 'Show available qualities';

  @override
  String get qualitiesListed =>
      'The list now shows only this link\'s qualities, with approximate sizes.';

  @override
  String get noQualityList =>
      'This link has no quality list; it downloads as is.';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue =>
      'Added to the queue; it starts after the current download.';

  @override
  String queueTitle(int count) {
    return 'Waiting in queue ($count)';
  }

  @override
  String get queueWaitingPaused =>
      'Queued downloads start after the paused download is resumed or cancelled.';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String timeLeft(String time) {
    return '$time left';
  }

  @override
  String get includeSubtitles =>
      'Include subtitles (Arabic and English, when available)';

  @override
  String get loadSubtitleFile => 'Load subtitle file…';

  @override
  String get pickFromPlaylist => 'Choose from a playlist or channel';

  @override
  String get notAPlaylist => 'This link is a single video, not a list.';

  @override
  String get selectAll => 'Select all';

  @override
  String downloadSelected(int count) {
    return 'Download $count';
  }

  @override
  String playlistQueued(int count) {
    return 'Added $count to the queue.';
  }
}
