/// What went wrong with an online link, so the UI can say it plainly.
/// The raw engine message stays available under "Reason details".
enum OnlineErrorKind {
  network,
  private,
  loginRequired,
  unavailable,
  unsupported,
  quality,
  tooLarge,
  storage,
  engine,
  other,
}

// Order matters: a private video also says "Sign in", and a removed page
// fails with "Unable to download webpage: HTTP Error 404".
const _patterns = <OnlineErrorKind, List<String>>{
  OnlineErrorKind.engine: ['engine files are missing'],
  OnlineErrorKind.storage: ['No space left', 'ENOSPC', 'not enough space'],
  OnlineErrorKind.tooLarge: ['larger than max-filesize', 'File is larger than'],
  OnlineErrorKind.quality: [
    'No video at or below',
    'Requested resolution unavailable',
    'requested format is not available',
  ],
  OnlineErrorKind.private: ['Private video', 'video is private'],
  OnlineErrorKind.loginRequired: [
    'Sign in to confirm',
    'login required',
    'requires authentication',
    'use --cookies',
  ],
  OnlineErrorKind.unavailable: [
    'Video unavailable',
    'video is unavailable',
    'no longer available',
    'has been removed',
    'HTTP Error 404',
    'HTTP Error 410',
  ],
  OnlineErrorKind.unsupported: [
    'Unsupported URL',
    'is not a valid URL',
    'valid public web link',
    'valid HTTP or HTTPS link',
  ],
  OnlineErrorKind.network: [
    'No address associated',
    'Name or service not known',
    'Temporary failure in name resolution',
    'getaddrinfo failed',
    'Network is unreachable',
    'Connection refused',
    'Connection reset',
    'timed out',
    'Unable to download webpage',
    'Remote end closed',
  ],
};

OnlineErrorKind classifyOnlineError(String? message) {
  if (message == null || message.isEmpty) return OnlineErrorKind.other;
  final text = message.toLowerCase();
  for (final entry in _patterns.entries) {
    if (entry.value.any((p) => text.contains(p.toLowerCase()))) {
      return entry.key;
    }
  }
  return OnlineErrorKind.other;
}
