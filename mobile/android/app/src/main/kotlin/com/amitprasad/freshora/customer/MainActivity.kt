package com.amitprasad.freshora.customer

import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val updateManager by lazy { AppUpdateManagerFactory.create(this) }
    private var updateRequestPending = false

    override fun onResume() {
        super.onResume()
        checkForPlayUpdate()
    }

    private fun checkForPlayUpdate() {
        if (updateRequestPending) return
        updateRequestPending = true
        updateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                updateRequestPending = false
                if (isFinishing || isDestroyed) return@addOnSuccessListener
                val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                val inProgress = info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                if ((available && info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) || inProgress) {
                    try {
                        updateManager.startUpdateFlowForResult(
                            info, this,
                            AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                            UPDATE_REQUEST_CODE
                        )
                    } catch (_: Exception) {
                        // Store or device may not support the update flow; app remains usable.
                    }
                }
            }
            .addOnFailureListener { updateRequestPending = false }
    }

    companion object {
        private const val UPDATE_REQUEST_CODE = 4101
    }
}
