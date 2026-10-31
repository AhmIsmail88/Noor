// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'نور';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navDownloads => 'التحميلات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get welcome => 'أهلاً بك في نور';

  @override
  String get openVideo => 'فتح فيديو أو أكثر';

  @override
  String get onlineVideo => 'تحميل أو Streaming من رابط';

  @override
  String get onlineHint =>
      'الصق رابط فيديو ثم اختر التنزيل أو المشاهدة المباشرة. دعم يوتيوب وفيسبوك وتيك توك وإكس تجريبي، وكذلك روابط الفيديو المباشرة.';

  @override
  String get videoLink => 'رابط الفيديو';

  @override
  String get pasteLink => 'لصق الرابط';

  @override
  String get invalidLink => 'أدخل رابط HTTP أو HTTPS صالحًا.';

  @override
  String get downloadVideo => 'تحميل الفيديو';

  @override
  String get streaming => 'Streaming — مشاهدة مباشرة';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get onlineLimit =>
      'حمّل المحتوى المسموح لك فقط. قد يمنع المصدر التنزيل أو Streaming. يمكن استكمال التنزيل المتوقف إذا كان المصدر يدعم ذلك.';

  @override
  String get downloadingVideo => 'جارٍ تحميل الفيديو…';

  @override
  String get preparingLink =>
      'جارٍ تجهيز الرابط… قد يستغرق الاستخدام الأول وقتًا أطول.';

  @override
  String get operationCancelled => 'أُلغيت العملية.';

  @override
  String get onlineUnavailable => 'تعذّر تنفيذ الطلب لهذا الرابط.';

  @override
  String get tryStreaming =>
      'يمكنك تجربة Streaming للمشاهدة المباشرة، أو إعادة المحاولة. بعض المصادر لا تتيح أيًا منهما.';

  @override
  String get errorDetails => 'تفاصيل السبب';

  @override
  String get completedDownloads => 'التحميلات المكتملة';

  @override
  String get importingVideo => 'جارٍ استيراد الفيديو…';

  @override
  String get importFailed =>
      'تعذّر استيراد الفيديو. تأكد من توفر الملف ومساحة التخزين وحاول مجددًا.';

  @override
  String get libraryEmpty => 'المكتبة فارغة حالياً';

  @override
  String get downloadsEmpty => 'ملفاتك المحمّلة ستظهر هنا.';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get theme => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'النظام';

  @override
  String playerError(String message) {
    return 'مشكلة أثناء التشغيل: $message';
  }

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get seekBack => 'رجوع 10 ثوانٍ';

  @override
  String get seekForward => 'تقدّم 10 ثوانٍ';

  @override
  String get continueWatching => 'تابع المشاهدة';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterFavorites => 'المفضلة';

  @override
  String get filterRecent => 'شُغّل مؤخراً';

  @override
  String get searchHint => 'ابحث في المكتبة';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get fileMissing => 'الملف غير موجود';

  @override
  String get removeFromLibrary => 'إزالة من المكتبة';

  @override
  String get addFavorite => 'إضافة إلى المفضلة';

  @override
  String get removeFavorite => 'إزالة من المفضلة';

  @override
  String resumedAt(String time) {
    return 'تم الاستئناف من $time';
  }

  @override
  String get speed => 'سرعة التشغيل';

  @override
  String get audioTrack => 'المسار الصوتي';

  @override
  String get subtitles => 'الترجمة';

  @override
  String get subtitlesOff => 'إيقاف';

  @override
  String trackN(int n) {
    return 'مسار $n';
  }

  @override
  String get fullscreen => 'ملء الشاشة';

  @override
  String get exitFullscreen => 'إنهاء ملء الشاشة';

  @override
  String get mute => 'كتم الصوت';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get volume => 'مستوى الصوت';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get back => 'رجوع';

  @override
  String get nextVideo => 'الفيديو التالي';

  @override
  String get fileNotFound => 'الملف غير موجود أو لم يعد متاحاً';

  @override
  String get downloadKind => 'نوع التحميل';

  @override
  String get videoWithAudio => 'فيديو مع الصوت';

  @override
  String get audioOnlyMp3 => 'صوت فقط (MP3)';

  @override
  String get audioQuality => 'معدل الصوت';

  @override
  String get videoQuality => 'أقصى دقة للفيديو';

  @override
  String get highestQuality => 'أعلى جودة متاحة';

  @override
  String get audioFormatHint => 'استخراج الصوت وحفظه كملف MP3.';

  @override
  String get videoQualityHint =>
      'ينزّل أعلى دقة متاحة حتى اختيارك، بدون تكبير دقة المصدر.';

  @override
  String get downloadAudio => 'تحميل الصوت';

  @override
  String get publicDownloadHint => 'الحفظ في مجلد التنزيلات / NOOR على جهازك.';

  @override
  String get saveToPhoneDownloads => 'حفظ في تنزيلات الهاتف';

  @override
  String get openDownloadsFolder => 'فتح التنزيلات';

  @override
  String get folderOpenHint => 'افتح مجلد Download/NOOR من مدير الملفات.';

  @override
  String get downloadSaved => 'تم الحفظ في مجلد التنزيلات / NOOR';

  @override
  String get resumeDownload => 'استكمال التحميل';

  @override
  String get downloadPaused => 'التحميل متوقف مؤقتًا';

  @override
  String get downloadWaiting => 'انتظار الاتصال - ستتم إعادة المحاولة';

  @override
  String get openAudio => 'تشغيل صوت';

  @override
  String get openFolder => 'فتح مجلد';

  @override
  String get dropMediaHint => 'اسحب ملفات الصوت والفيديو أو المجلد إلى نور';
}
