package com.meowclash.app.plugins

import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Native crypto plugin used to offload AES-256-CBC subscription decryption
 * from Dart (PointyCastle) to platform-native primitives backed by
 * Conscrypt/BoringSSL. PBKDF2 in particular is 10–100x faster here than in
 * pure Dart on Android, which is what makes encrypted-subscription refresh
 * feel near-instant instead of multi-second.
 */
class CryptoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var scope: CoroutineScope

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(Dispatchers.Default)
        channel = MethodChannel(binding.binaryMessenger, "crypto")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "decryptAesCbc" -> {
                val password = call.argument<String>("password")
                val salt = call.argument<ByteArray>("salt")
                val iv = call.argument<ByteArray>("iv")
                val ciphertext = call.argument<ByteArray>("ciphertext")
                val iterations = call.argument<Int>("iterations") ?: 480_000
                val keyBits = call.argument<Int>("keyBits") ?: 256
                if (password == null || salt == null || iv == null || ciphertext == null) {
                    result.error(
                        "INVALID_ARGUMENTS",
                        "password, salt, iv and ciphertext are required",
                        null,
                    )
                    return
                }
                scope.launch {
                    val plaintext = runCatching {
                        withContext(Dispatchers.Default) {
                            decryptAesCbc(password, salt, iv, ciphertext, iterations, keyBits)
                        }
                    }
                    plaintext.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.error("DECRYPT_FAILED", it.message, null) },
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun decryptAesCbc(
        password: String,
        salt: ByteArray,
        iv: ByteArray,
        ciphertext: ByteArray,
        iterations: Int,
        keyBits: Int,
    ): ByteArray {
        // PBKDF2WithHmacSHA256 is available since API 26. The fork's minSdk is
        // well above that, so we can rely on the native implementation
        // directly without a PointyCastle fallback on Android.
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val passwordChars = password.toCharArray()
        val keySpec = PBEKeySpec(passwordChars, salt, iterations, keyBits)
        try {
            val derived = factory.generateSecret(keySpec).encoded
            val secretKey = SecretKeySpec(derived, "AES")
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey, IvParameterSpec(iv))
            val plaintext = cipher.doFinal(ciphertext)
            // Best-effort wipe of derived key bytes from memory.
            derived.fill(0)
            return plaintext
        } finally {
            keySpec.clearPassword()
            passwordChars.fill('\u0000')
            // Build version check avoids a useless warning on older devices.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                // no-op
            }
        }
    }
}
