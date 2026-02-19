package io.agewallet.sdk.demo.flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.linusu.flutter_web_auth_2.FlutterWebAuth2Plugin

/**
 * Custom callback activity that handles the OIDC redirect URL and brings
 * the Flutter task back to the foreground after processing the callback.
 *
 * Replicates the logic of flutter_web_auth_2's CallbackActivity, then
 * relaunches MainActivity so the app surface is visible to the user.
 */
class AgeWalletCallbackActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = intent?.data
        val scheme = url?.scheme

        if (scheme != null) {
            FlutterWebAuth2Plugin.callbacks.remove(scheme)?.success(url.toString())
        }

        // Bring the Flutter task to the foreground.
        // FLAG_ACTIVITY_NEW_TASK + FLAG_ACTIVITY_CLEAR_TOP finds the existing
        // Flutter task (regardless of task affinity) and brings it to front.
        // FLAG_ACTIVITY_REORDER_TO_FRONT only works within the same task and
        // cannot cross task boundaries, so it was silently a no-op here.
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
        )

        finishAndRemoveTask()
    }
}
