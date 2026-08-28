package com.looped.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val CHANNEL = "com.looped.app/story"
private const val INSTAGRAM = "com.instagram.android"

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstagramInstalled" -> result.success(isInstagramInstalled())
                    "shareToInstagramStory" -> result.success(shareToInstagramStory(call))
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInstagramInstalled(): Boolean {
        // Requiere el <package android:name="com.instagram.android"/> del
        // bloque <queries> del manifest; sin eso Android 11+ miente y dice que
        // no esta instalado.
        return try {
            packageManager.getPackageInfo(INSTAGRAM, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Abre el editor de stories de Instagram con el PNG de stats ya puesto como
     * sticker, para que el usuario elija la foto de fondo ahi adentro.
     *
     * Devuelve false si no se pudo (Instagram ausente, version vieja, archivo
     * que no existe): el lado Dart cae al share sheet del sistema.
     */
    private fun shareToInstagramStory(call: MethodCall): Boolean {
        val path = call.argument<String>("path") ?: return false
        val file = File(path)
        if (!file.exists()) return false

        val uri: Uri = try {
            FileProvider.getUriForFile(this, "$packageName.storyprovider", file)
        } catch (e: IllegalArgumentException) {
            return false
        }

        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setPackage(INSTAGRAM)
            type = "image/*"
            // Sin imagen de fondo: mandamos solo el sticker y el degrade que
            // Instagram pinta atras hasta que el usuario pone su foto.
            putExtra("interactive_asset_uri", uri)
            putExtra(
                "top_background_color",
                call.argument<String>("topColor") ?: "#000000",
            )
            putExtra(
                "bottom_background_color",
                call.argument<String>("bottomColor") ?: "#00D9A5",
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // El extra no viaja con el permiso del setData, hay que darselo a mano.
        grantUriPermission(INSTAGRAM, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
