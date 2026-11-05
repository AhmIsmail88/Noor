# youtubedl-android ships no consumer rules; its README asks apps to keep
# these. Without them R8 strips the constructors commons-compress creates by
# reflection while unpacking Python and yt-dlp on first use, and every link
# that needs the engine (YouTube, TikTok, Facebook, X) fails in release
# builds, while direct media links keep working.
-keep class com.yausername.** { *; }
-keep class org.apache.commons.compress.archivers.zip.** { *; }
