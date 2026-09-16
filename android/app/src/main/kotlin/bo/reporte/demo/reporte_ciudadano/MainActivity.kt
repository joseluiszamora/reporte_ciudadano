package bo.reporte.demo.reporte_ciudadano

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var storageChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        storageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bo.reporte.demo/draft_storage"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "read" && call.method != "write") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val value = call.arguments as? String
                if (call.method == "write" && value == null) {
                    result.error("invalid_value", "Se esperaba una instantánea de texto.", null)
                    return@setMethodCallHandler
                }
                // Las operaciones de disco no bloquean el hilo de interfaz.
                storageExecutor.execute {
                    try {
                        val preferences = applicationContext.getSharedPreferences(
                            "reporte_ciudadano_demo", MODE_PRIVATE
                        )
                        if (call.method == "read") {
                            val stored = preferences.getString("submissions_v1", null)
                            mainHandler.post { result.success(stored) }
                        } else {
                            // Confirmar la escritura antes de anunciar éxito a Flutter.
                            val saved = preferences.edit().putString("submissions_v1", value).commit()
                            mainHandler.post {
                                if (saved) result.success(null)
                                else result.error("storage_write", "No se pudo guardar el borrador.", null)
                            }
                        }
                    } catch (_: Exception) {
                        mainHandler.post {
                            result.error("storage_unavailable", "Almacenamiento local no disponible.", null)
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        storageChannel?.setMethodCallHandler(null)
        storageExecutor.shutdown()
        super.onDestroy()
    }
}
