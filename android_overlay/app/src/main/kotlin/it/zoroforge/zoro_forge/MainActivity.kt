package it.zoroforge.zoro_forge
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
    private var pendingNotification: MethodChannel.Result? = null
    private val notificationRequest = 9201
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoro_forge/platform").setMethodCallHandler { call, result ->
            if (call.method != "requestNotifications") result.notImplemented()
            else if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) result.success(true)
            else if (pendingNotification != null) result.error("BUSY", "Permission request already active", null)
            else { pendingNotification = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest) }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequest) { pendingNotification?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED); pendingNotification = null }
    }
    override fun onDestroy() {
        pendingNotification?.error("CANCELLED", "Activity closed during permission request", null)
        pendingNotification = null
        super.onDestroy()
    }
}
