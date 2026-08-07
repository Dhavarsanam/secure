package com.example.secure_ride

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile ("pull down the shade" toggle, next to Wi-Fi /
 * Airplane mode) that gives the user one-tap access to SecureRide's SOS
 * flow — even from the lock screen, without unlocking or opening the app
 * from the launcher.
 *
 * We deliberately do NOT fire the SOS alert directly from here: sending
 * emails / writing to Firestore needs a running Flutter/Dart engine, and
 * a silent trigger from a pocket-tap would be dangerous for a safety app.
 * Instead the tile opens the app straight to the SOS confirmation screen
 * (see MainActivity + main.dart), matching the existing "Send SOS Now?"
 * confirmation dialog already used inside the app.
 */
class SosTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.label = "SOS Alert"
            tile.subtitle = "SecureRide"
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_SOS
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_SOS, true)
        }

        if (Build.VERSION.SDK_INT >= 34) {
            // Android 14+ requires the PendingIntent overload.
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    companion object {
        const val ACTION_OPEN_SOS = "com.example.secure_ride.ACTION_OPEN_SOS"
        const val EXTRA_OPEN_SOS = "open_sos"
    }
}