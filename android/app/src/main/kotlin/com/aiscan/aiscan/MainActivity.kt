package com.aiscan.aiscan

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

/**
 * Main activity for the Scanaï application.
 *
 * Overrides onActivityResult to handle the case where Android kills the app
 * while the ML Kit document scanner is running. This prevents crashes when
 * the scanner result is delivered to a recreated activity with null MethodChannel.Result.
 */
class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "AIScanMainActivity"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        try {
            super.onActivityResult(requestCode, resultCode, data)
        } catch (e: NullPointerException) {
            // This can happen when the app was killed while the scanner was running.
            // The Flutter engine gets recreated but the pending Result callback is null.
            // We catch this to prevent a crash and log it for debugging.
            Log.w(TAG, "Caught NullPointerException in onActivityResult - app may have been recreated", e)

            // The user will need to re-scan as the result is lost
            // The UI will show the scanner screen again, allowing them to retry
        } catch (e: RuntimeException) {
            // Catch broader RuntimeException to handle "Failure delivering result" errors
            if (e.message?.contains("Failure delivering result") == true &&
                e.cause is NullPointerException) {
                Log.w(TAG, "Caught RuntimeException with NullPointerException cause in onActivityResult", e)
            } else {
                // Re-throw other RuntimeExceptions
                throw e
            }
        }
    }
}
