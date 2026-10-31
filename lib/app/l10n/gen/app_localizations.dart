import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'نور'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get navLibrary;

  /// No description provided for @navDownloads.
  ///
  /// In ar, this message translates to:
  /// **'التحميلات'**
  String get navDownloads;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @welcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في نور'**
  String get welcome;

  /// No description provided for @openVideo.
  ///
  /// In ar, this message translates to:
  /// **'فتح فيديو أو أكثر'**
  String get openVideo;

  /// No description provided for @onlineVideo.
  ///
  /// In ar, this message translates to:
  /// **'تحميل أو Streaming من رابط'**
  String get onlineVideo;

  /// No description provided for @onlineHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط فيديو ثم اختر التنزيل أو المشاهدة المباشرة. دعم يوتيوب وفيسبوك وتيك توك وإكس تجريبي، وكذلك روابط الفيديو المباشرة.'**
  String get onlineHint;

  /// No description provided for @videoLink.
  ///
  /// In ar, this message translates to:
  /// **'رابط الفيديو'**
  String get videoLink;

  /// No description provided for @pasteLink.
  ///
  /// In ar, this message translates to:
  /// **'لصق الرابط'**
  String get pasteLink;

  /// No description provided for @invalidLink.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رابط HTTP أو HTTPS صالحًا.'**
  String get invalidLink;

  /// No description provided for @downloadVideo.
  ///
  /// In ar, this message translates to:
  /// **'تحميل الفيديو'**
  String get downloadVideo;

  /// No description provided for @streaming.
  ///
  /// In ar, this message translates to:
  /// **'Streaming — مشاهدة مباشرة'**
  String get streaming;

  /// No description provided for @cancelAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancelAction;

  /// No description provided for @onlineLimit.
  ///
  /// In ar, this message translates to:
  /// **'حمّل المحتوى المسموح لك فقط. قد يمنع المصدر التنزيل أو Streaming. يمكن استكمال التنزيل المتوقف إذا كان المصدر يدعم ذلك.'**
  String get onlineLimit;

  /// No description provided for @downloadingVideo.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الفيديو…'**
  String get downloadingVideo;

  /// No description provided for @preparingLink.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز الرابط… قد يستغرق الاستخدام الأول وقتًا أطول.'**
  String get preparingLink;

  /// No description provided for @operationCancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت العملية.'**
  String get operationCancelled;

  /// No description provided for @onlineUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تنفيذ الطلب لهذا الرابط.'**
  String get onlineUnavailable;

  /// No description provided for @tryStreaming.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تجربة Streaming للمشاهدة المباشرة، أو إعادة المحاولة. بعض المصادر لا تتيح أيًا منهما.'**
  String get tryStreaming;

  /// No description provided for @errorDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل السبب'**
  String get errorDetails;

  /// No description provided for @completedDownloads.
  ///
  /// In ar, this message translates to:
  /// **'التحميلات المكتملة'**
  String get completedDownloads;

  /// No description provided for @importingVideo.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ استيراد الفيديو…'**
  String get importingVideo;

  /// No description provided for @importFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر استيراد الفيديو. تأكد من توفر الملف ومساحة التخزين وحاول مجددًا.'**
  String get importFailed;

  /// No description provided for @libraryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة فارغة حالياً'**
  String get libraryEmpty;

  /// No description provided for @downloadsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ملفاتك المحمّلة ستظهر هنا.'**
  String get downloadsEmpty;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'النظام'**
  String get themeSystem;

  /// No description provided for @playerError.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة أثناء التشغيل: {message}'**
  String playerError(String message);

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get pause;

  /// No description provided for @seekBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع 10 ثوانٍ'**
  String get seekBack;

  /// No description provided for @seekForward.
  ///
  /// In ar, this message translates to:
  /// **'تقدّم 10 ثوانٍ'**
  String get seekForward;

  /// No description provided for @continueWatching.
  ///
  /// In ar, this message translates to:
  /// **'تابع المشاهدة'**
  String get continueWatching;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @filterFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get filterFavorites;

  /// No description provided for @filterRecent.
  ///
  /// In ar, this message translates to:
  /// **'شُغّل مؤخراً'**
  String get filterRecent;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المكتبة'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResults;

  /// No description provided for @fileMissing.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير موجود'**
  String get fileMissing;

  /// No description provided for @removeFromLibrary.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المكتبة'**
  String get removeFromLibrary;

  /// No description provided for @addFavorite.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى المفضلة'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المفضلة'**
  String get removeFavorite;

  /// No description provided for @resumedAt.
  ///
  /// In ar, this message translates to:
  /// **'تم الاستئناف من {time}'**
  String resumedAt(String time);

  /// No description provided for @speed.
  ///
  /// In ar, this message translates to:
  /// **'سرعة التشغيل'**
  String get speed;

  /// No description provided for @audioTrack.
  ///
  /// In ar, this message translates to:
  /// **'المسار الصوتي'**
  String get audioTrack;

  /// No description provided for @subtitles.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة'**
  String get subtitles;

  /// No description provided for @subtitlesOff.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get subtitlesOff;

  /// No description provided for @trackN.
  ///
  /// In ar, this message translates to:
  /// **'مسار {n}'**
  String trackN(int n);

  /// No description provided for @fullscreen.
  ///
  /// In ar, this message translates to:
  /// **'ملء الشاشة'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء ملء الشاشة'**
  String get exitFullscreen;

  /// No description provided for @mute.
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get unmute;

  /// No description provided for @volume.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الصوت'**
  String get volume;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @nextVideo.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو التالي'**
  String get nextVideo;

  /// No description provided for @fileNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير موجود أو لم يعد متاحاً'**
  String get fileNotFound;

  /// No description provided for @downloadKind.
  ///
  /// In ar, this message translates to:
  /// **'نوع التحميل'**
  String get downloadKind;

  /// No description provided for @videoWithAudio.
  ///
  /// In ar, this message translates to:
  /// **'فيديو مع الصوت'**
  String get videoWithAudio;

  /// No description provided for @audioOnlyMp3.
  ///
  /// In ar, this message translates to:
  /// **'صوت فقط (MP3)'**
  String get audioOnlyMp3;

  /// No description provided for @audioQuality.
  ///
  /// In ar, this message translates to:
  /// **'معدل الصوت'**
  String get audioQuality;

  /// No description provided for @videoQuality.
  ///
  /// In ar, this message translates to:
  /// **'أقصى دقة للفيديو'**
  String get videoQuality;

  /// No description provided for @highestQuality.
  ///
  /// In ar, this message translates to:
  /// **'أعلى جودة متاحة'**
  String get highestQuality;

  /// No description provided for @audioFormatHint.
  ///
  /// In ar, this message translates to:
  /// **'استخراج الصوت وحفظه كملف MP3.'**
  String get audioFormatHint;

  /// No description provided for @videoQualityHint.
  ///
  /// In ar, this message translates to:
  /// **'ينزّل أعلى دقة متاحة حتى اختيارك، بدون تكبير دقة المصدر.'**
  String get videoQualityHint;

  /// No description provided for @downloadAudio.
  ///
  /// In ar, this message translates to:
  /// **'تحميل الصوت'**
  String get downloadAudio;

  /// No description provided for @publicDownloadHint.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ في مجلد التنزيلات / NOOR على جهازك.'**
  String get publicDownloadHint;

  /// No description provided for @saveToPhoneDownloads.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في تنزيلات الهاتف'**
  String get saveToPhoneDownloads;

  /// No description provided for @openDownloadsFolder.
  ///
  /// In ar, this message translates to:
  /// **'فتح التنزيلات'**
  String get openDownloadsFolder;

  /// No description provided for @folderOpenHint.
  ///
  /// In ar, this message translates to:
  /// **'افتح مجلد Download/NOOR من مدير الملفات.'**
  String get folderOpenHint;

  /// No description provided for @downloadSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ في مجلد التنزيلات / NOOR'**
  String get downloadSaved;

  /// No description provided for @resumeDownload.
  ///
  /// In ar, this message translates to:
  /// **'استكمال التحميل'**
  String get resumeDownload;

  /// No description provided for @downloadPaused.
  ///
  /// In ar, this message translates to:
  /// **'التحميل متوقف مؤقتًا'**
  String get downloadPaused;

  /// No description provided for @downloadWaiting.
  ///
  /// In ar, this message translates to:
  /// **'انتظار الاتصال - ستتم إعادة المحاولة'**
  String get downloadWaiting;

  /// No description provided for @openAudio.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل صوت'**
  String get openAudio;

  /// No description provided for @openFolder.
  ///
  /// In ar, this message translates to:
  /// **'فتح مجلد'**
  String get openFolder;

  /// No description provided for @dropMediaHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ملفات الصوت والفيديو أو المجلد إلى نور'**
  String get dropMediaHint;

  /// No description provided for @autoplayNext.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الفيديو التالي تلقائيًا'**
  String get autoplayNext;

  /// No description provided for @autoplayNextHint.
  ///
  /// In ar, this message translates to:
  /// **'عند انتهاء الفيديو يبدأ التالي من نفس المجلد أو الاختيار بعد 5 ثوانٍ.'**
  String get autoplayNextHint;

  /// No description provided for @upNextIn.
  ///
  /// In ar, this message translates to:
  /// **'التالي خلال {seconds} ث: {title}'**
  String upNextIn(int seconds, String title);

  /// No description provided for @playNow.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الآن'**
  String get playNow;

  /// No description provided for @removedFromLibrary.
  ///
  /// In ar, this message translates to:
  /// **'حُذف «{title}» من المكتبة'**
  String removedFromLibrary(String title);

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالموقع. تأكد من الإنترنت ثم أعد المحاولة.'**
  String get errorNetwork;

  /// No description provided for @errorUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الفيديو غير متاح أو حُذف من الموقع.'**
  String get errorUnavailable;

  /// No description provided for @errorPrivate.
  ///
  /// In ar, this message translates to:
  /// **'هذا الفيديو خاص ولا يمكن الوصول إليه.'**
  String get errorPrivate;

  /// No description provided for @errorLoginRequired.
  ///
  /// In ar, this message translates to:
  /// **'الموقع يطلب تسجيل الدخول أو التحقق لهذا الفيديو.'**
  String get errorLoginRequired;

  /// No description provided for @errorUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط غير مدعوم. جرّب رابط الفيديو نفسه.'**
  String get errorUnsupported;

  /// No description provided for @errorQuality.
  ///
  /// In ar, this message translates to:
  /// **'الجودة المطلوبة غير متاحة. اختر جودة أعلى أو «أعلى جودة متاحة».'**
  String get errorQuality;

  /// No description provided for @errorTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من الحد المسموح (2 جيجابايت).'**
  String get errorTooLarge;

  /// No description provided for @errorStorage.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مساحة كافية لحفظ الملف.'**
  String get errorStorage;

  /// No description provided for @errorEngine.
  ///
  /// In ar, this message translates to:
  /// **'ملفات محرك التحميل ناقصة. استخدم مجلد نور الكامل.'**
  String get errorEngine;

  /// No description provided for @engineTitle.
  ///
  /// In ar, this message translates to:
  /// **'محرك التحميل'**
  String get engineTitle;

  /// No description provided for @engineVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار الحالي: {version}'**
  String engineVersion(String version);

  /// No description provided for @engineVersionUnknown.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار غير معروف بعد'**
  String get engineVersionUnknown;

  /// No description provided for @engineHint.
  ///
  /// In ar, this message translates to:
  /// **'المواقع تغيّر طريقتها باستمرار. إذا فشلت روابط كانت تعمل، حدّث المحرك.'**
  String get engineHint;

  /// No description provided for @engineUpdate.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من التحديث'**
  String get engineUpdate;

  /// No description provided for @engineUpdating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحديث…'**
  String get engineUpdating;

  /// No description provided for @engineUpToDate.
  ///
  /// In ar, this message translates to:
  /// **'المحرك محدّث بالفعل ({version})'**
  String engineUpToDate(String version);

  /// No description provided for @engineUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم التحديث إلى {version}'**
  String engineUpdated(String version);

  /// No description provided for @engineUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحديث. تأكد من الإنترنت ثم أعد المحاولة.'**
  String get engineUpdateFailed;

  /// No description provided for @engineBusy.
  ///
  /// In ar, this message translates to:
  /// **'انتظر حتى ينتهي التحميل الحالي أو ألغِه أولًا.'**
  String get engineBusy;

  /// No description provided for @checkQualities.
  ///
  /// In ar, this message translates to:
  /// **'عرض الجودات المتاحة'**
  String get checkQualities;

  /// No description provided for @qualitiesListed.
  ///
  /// In ar, this message translates to:
  /// **'القائمة تعرض الآن جودات هذا الرابط فقط مع الحجم التقريبي.'**
  String get qualitiesListed;

  /// No description provided for @noQualityList.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط لا يعرض قائمة جودات، وسيُحمَّل كما هو.'**
  String get noQualityList;

  /// No description provided for @addToQueue.
  ///
  /// In ar, this message translates to:
  /// **'إضافة لقائمة الانتظار'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى قائمة الانتظار، وسيبدأ بعد التحميل الحالي.'**
  String get addedToQueue;

  /// No description provided for @queueTitle.
  ///
  /// In ar, this message translates to:
  /// **'في قائمة الانتظار ({count})'**
  String queueTitle(int count);

  /// No description provided for @queueWaitingPaused.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ التحميلات المنتظرة بعد استكمال التحميل المتوقف أو إلغائه.'**
  String get queueWaitingPaused;

  /// No description provided for @removeFromQueue.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من قائمة الانتظار'**
  String get removeFromQueue;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
