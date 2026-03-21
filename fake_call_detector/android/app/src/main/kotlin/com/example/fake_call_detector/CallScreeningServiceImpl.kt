package com.example.fake_call_detector

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class CallScreeningServiceImpl : CallScreeningService() {
    companion object {
        const val TAG = "CallScreeningService"
        var incomingCallPhoneNumber: String? = null
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart
        if (BuildConfig.DEBUG) {
            val maskedNumber = if (phoneNumber.isNullOrBlank()) {
                "Unknown"
            } else {
                phoneNumber.takeLast(2).padStart(phoneNumber.length, '*')
            }
            Log.d(TAG, "Incoming call from: $maskedNumber")
        }
        incomingCallPhoneNumber = phoneNumber

        // Pass this event to Flutter or Native Audio service to kick off
        // the speakerphone + MIC workaround.
        MainActivity.triggerCallEvent(phoneNumber ?: "Unknown")

        // Respond to the telecom framework: allow the call to ring normally.
        // We will do passive analysis.
        val response = CallResponse.Builder()
            .setDisallowCall(false)      
            .setRejectCall(false)        
            .setSkipCallLog(false)       
            .setSkipNotification(false)  
            .build()
        
        respondToCall(callDetails, response)
    }
}
