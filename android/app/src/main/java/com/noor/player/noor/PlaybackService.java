package com.noor.player.noor;

import android.app.*;
import android.content.*;
import android.media.AudioManager;
import android.media.AudioFocusRequest;
import android.media.AudioAttributes;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.*;
import io.flutter.plugin.common.MethodChannel;

/** Keeps the existing mpv player alive while its Flutter activity is backgrounded. */
public final class PlaybackService extends Service {
    static MethodChannel channel;
    private MediaSession session;
    private AudioManager audio;
    private AudioFocusRequest focus;
    private boolean playing;
    private boolean focused;
    private PowerManager.WakeLock wake;
    private String title = "Noor";
    private final AudioManager.OnAudioFocusChangeListener focusListener = change -> {
        if (change < 0) command("pause");
    };
    static void command(String action) {
        if (channel != null) channel.invokeMethod(action, null);
    }
    @Override public void onCreate() {
        super.onCreate();
        getSystemService(NotificationManager.class).createNotificationChannel(
            new NotificationChannel("noor-playback", "NOOR playback", NotificationManager.IMPORTANCE_LOW));
        audio = (AudioManager)getSystemService(AUDIO_SERVICE);
        focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
            .setOnAudioFocusChangeListener(focusListener).build();
        wake = ((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "noor:playback");
        session = new MediaSession(this, "Noor");
        session.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { command("play"); }
            @Override public void onPause() { command("pause"); }
            @Override public void onStop() { command("stop"); stopSelf(); }
            @Override public void onSeekTo(long position) {
                if (channel != null) channel.invokeMethod("seek", position);
            }
        });
        session.setActive(true);
        registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    }
    private final BroadcastReceiver noisy = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) { command("pause"); }
    };
    private PendingIntent action(String name, int id) {
        return PendingIntent.getService(this, id, new Intent(this, PlaybackService.class).setAction(name),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
    @Override public int onStartCommand(Intent intent, int flags, int id) {
        if (intent == null || channel == null) { stopSelf(); return START_NOT_STICKY; }
        String action = intent.getAction();
        if ("play".equals(action) || "pause".equals(action)) { command(action); return START_NOT_STICKY; }
        if ("stop".equals(action)) { command("stop"); stopSelf(); return START_NOT_STICKY; }
        playing = intent.getBooleanExtra("playing", false);
        title = intent.getStringExtra("title");
        long position = intent.getLongExtra("position", 0);
        session.setMetadata(new MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, intent.getLongExtra("duration", 0)).build());
        session.setPlaybackState(new PlaybackState.Builder()
            .setActions(PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE | PlaybackState.ACTION_STOP | PlaybackState.ACTION_SEEK_TO)
            .setState(playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED, position, playing ? 1 : 0).build());
        PendingIntent open = PendingIntent.getActivity(this, 0, getPackageManager().getLaunchIntentForPackage(getPackageName()),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(this, "noor-playback")
            .setSmallIcon(R.drawable.ic_noor_notification).setContentTitle(title).setContentText("Noor")
            .setContentIntent(open).setOnlyAlertOnce(true).setOngoing(playing)
            .addAction(new Notification.Action.Builder(null, playing ? "إيقاف مؤقت" : "تشغيل", action(playing ? "pause" : "play", 10)).build())
            .addAction(new Notification.Action.Builder(null, "إغلاق", action("stop", 11)).build())
            .setStyle(new Notification.MediaStyle().setMediaSession(session.getSessionToken()).setShowActionsInCompactView(0, 1)).build();
        startForeground(4102, notification);
        if (playing) {
            if (!wake.isHeld()) wake.acquire();
            if (!focused) {
                focused = audio.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
                if (!focused) command("pause");
            }
        } else {
            if (wake.isHeld()) wake.release();
            if (focused) { audio.abandonAudioFocusRequest(focus); focused = false; }
        }
        return START_NOT_STICKY;
    }
    @Override public void onTaskRemoved(Intent intent) { command("pause"); stopSelf(); }
    @Override public void onDestroy() {
        unregisterReceiver(noisy);
        if (wake.isHeld()) wake.release();
        audio.abandonAudioFocusRequest(focus);
        session.release();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent) { return null; }
}
