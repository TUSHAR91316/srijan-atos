package com.example.fakecalldetector

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class LocalCallScreeningService : CallScreeningService() {

    private val TAG = "LocalCallScreener"

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: ""
        Log.d(TAG, "Incoming call detected from: \$phoneNumber")

        // 1. Check if the number exists in local contacts
        val isKnownContact = isNumberInContacts(applicationContext, phoneNumber)

        // 2. Perform Heuristic Analysis (Spoofing checks)
        val isSpoofed = verifyMetadataLocally(phoneNumber, isKnownContact)

        val response = CallResponse.Builder()
        
        if (isSpoofed) {
            Log.e(TAG, "FLAGGED: Call from \$phoneNumber appears to be SPOOFED/FAKE.")
            
            // Block the call automatically OR silence it
            response.setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false) // Let the user know we blocked a fake call
        } else {
            Log.d(TAG, "Call allowed.")
        }

        // Must respond to the system
        respondToCall(callDetails, response.build())
    }

    private fun isNumberInContacts(context: Context, number: String): Boolean {
        // TODO: Implement local SQLite/Contacts Provider lookup
        // For hackathon prototype, assume true if it matches a hardcoded trusted pattern
        return true
    }

    private fun verifyMetadataLocally(number: String, isKnown: Boolean): Boolean {
        // TODO: Implement heuristics (Format anomalies, STIR/SHAKEN flags, Frequency)
        // For demonstration, let's flag specific test numbers as spoofed
        if (number.contains("+44") || number == "1234567890") {
            return true
        }
        return false
    }
}
