package it.diegorusso.voce_linkedin

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private var pendingShare: String? = null
    private var channel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val alias = "voce.local.v1"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        receive(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
        channel?.invokeMethod("sharedAvailable", null)
    }
    private fun receive(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            pendingShare = intent.getStringExtra(Intent.EXTRA_TEXT)?.take(22000)
        } else if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
            pendingShare = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()?.take(22000)
        }
    }
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .build())
        return generator.generateKey()
    }
    private fun encrypt(name: String, value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
    }
    private fun decrypt(name: String, value: String): String {
        val bytes = Base64.decode(value, Base64.NO_WRAP)
        require(bytes.size >= 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "it.diegorusso.voce/device")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "read", "write" -> {
                    val name = call.argument<String>("key") ?: ""
                    if (name !in setOf("workspace", "server_token")) {
                        result.error("INVALID_KEY", "Chiave non valida", null)
                    } else {
                        executor.execute {
                            try {
                                val prefs = getSharedPreferences("voce_encrypted", MODE_PRIVATE)
                                if (call.method == "read") {
                                    val value = prefs.getString(name, null)?.let { decrypt(name, it) }
                                    runOnUiThread { result.success(value) }
                                } else {
                                    val value = call.argument<String>("value") ?: ""
                                    require(value.toByteArray().size <= 12 * 1024 * 1024)
                                    check(prefs.edit().putString(name, encrypt(name, value)).commit())
                                    runOnUiThread { result.success(null) }
                                }
                            } catch (_: Exception) {
                                runOnUiThread { result.error("STORAGE", "Archivio non leggibile o salvataggio non riuscito", null) }
                            }
                        }
                    }
                }
                "sharedText" -> {
                    val value = pendingShare
                    pendingShare = null
                    result.success(value)
                }
                "open" -> {
                    val uri = Uri.parse(call.argument<String>("url") ?: "")
                    val host = uri.host ?: ""
                    if (uri.scheme != "https" || !(host == "linkedin.com" || host.endsWith(".linkedin.com")) || uri.userInfo != null) {
                        result.error("URL", "Indirizzo LinkedIn non valido", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("OPEN", "Nessuna applicazione disponibile per aprire il link", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        executor.shutdown()
        super.onDestroy()
    }
}
