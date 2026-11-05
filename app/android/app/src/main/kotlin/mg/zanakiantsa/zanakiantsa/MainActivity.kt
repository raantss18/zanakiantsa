package mg.zanakiantsa.zanakiantsa

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Canal « zanakiantsa/system » : numéro de version installé, lancement de l'installateur (ADR 0011), dossiers du moteur
/// d'échecs (ADR 0051).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zanakiantsa/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "build" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toInt() else @Suppress("DEPRECATION") info.versionCode)
                }
                // Dossiers où lancer et nourrir le moteur lc0 (ADR 0051) : ses bibliothèques natives, et les fichiers de l'appli.
                "engineDirs" -> result.success(mapOf("lib" to applicationInfo.nativeLibraryDir, "files" to filesDir.absolutePath))
                "install" -> {
                    // Sans l'autorisation « installer des applis inconnues », on ouvre le réglage : le parent l'accorde
                    // puis relance la mise à jour.
                    if (!packageManager.canRequestPackageInstalls()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                    // ACTION_INSTALL_PACKAGE n'est traité que par l'installateur du système ; ACTION_VIEW proposait aussi
                    // d'autres applis (PictoBlox…) dans une fenêtre « Ouvrir avec » (vu sur la SM-X135G, 2026-11-02).
                    @Suppress("DEPRECATION")
                    startActivity(Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
