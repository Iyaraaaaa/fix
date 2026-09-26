package com.example.health_project

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URLEncoder

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.veriframe_app/share_pdf"
    private val WHATSAPP_PACKAGE = "com.whatsapp"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sharePdfToApp" -> handleSharePdf(call, result)
                    "openWhatsAppChat" -> handleOpenWhatsAppChat(call, result)
                    "isAppInstalled" ->
                        result.success(isPackageInstalled(call.argument<String>("appPackage")))
                    else -> result.notImplemented()
                }
            }
    }

    private fun isPackageInstalled(appPackage: String?): Boolean {
        if (appPackage.isNullOrEmpty()) return false
        return try {
            packageManager.getPackageInfo(appPackage, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * ACTION_SEND the generated forensic PDF to a specific installed app.
     * Errors are propagated back to Dart so the UI can show a real failure
     * instead of silently doing nothing.
     */
    private fun handleSharePdf(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val appPackage = call.argument<String>("appPackage")
        val recipient = call.argument<String>("recipient")
        val subject = call.argument<String>("subject")
        val body = call.argument<String>("body")

        if (filePath.isNullOrEmpty() || appPackage.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "filePath and appPackage are required", null)
            return
        }
        if (!isPackageInstalled(appPackage)) {
            result.error("APP_NOT_INSTALLED", "$appPackage is not installed", null)
            return
        }
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "Report file not found: $filePath", null)
            return
        }

        try {
            val contentUri: Uri = FileProvider.getUriForFile(
                applicationContext,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, contentUri)
                if (!body.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, body)
                if (!subject.isNullOrEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
                if (!recipient.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                }
                setPackage(appPackage)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_ACTIVITY", "No activity in $appPackage can accept the report", e.message)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", e.message ?: "Share failed", null)
        }
    }

    /**
     * Opens a WhatsApp chat with a *specific* phone number and a pre-filled
     * message. ACTION_SEND cannot address a recipient, so the official
     * wa.me deep link is used — this is the only reliable way to guarantee the
     * report reaches the intended authority contact.
     */
    private fun handleOpenWhatsAppChat(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")
        val message = call.argument<String>("message") ?: ""

        if (phone.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "phone is required", null)
            return
        }
        val digits = phone.filter { it.isDigit() }
        if (digits.length < 8) {
            result.error("INVALID_PHONE", "Invalid phone number: $phone", null)
            return
        }
        if (!isPackageInstalled(WHATSAPP_PACKAGE)) {
            result.error("APP_NOT_INSTALLED", "WhatsApp is not installed", null)
            return
        }

        try {
            val encoded = URLEncoder.encode(message, "UTF-8")
            val intent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://wa.me/$digits?text=$encoded")
            ).apply {
                setPackage(WHATSAPP_PACKAGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_ACTIVITY", "WhatsApp cannot open the wa.me link", e.message)
        } catch (e: Exception) {
            result.error("WHATSAPP_FAILED", e.message ?: "Could not open WhatsApp", null)
        }
    }
}
