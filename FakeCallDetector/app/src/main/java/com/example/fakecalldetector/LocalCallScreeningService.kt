package com.example.fakecalldetector

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@RequiresApi(Build.VERSION_CODES.N)
class LocalCallScreeningService : CallScreeningService() {

    private val TAG = "LocalCallScreener"
    private val voiceAnalyzer = LocalTFLiteVoiceAnalyzer()
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: ""
        Log.d(TAG, "Incoming call detected from: \$phoneNumber")

        // 1. Check if the number exists in local contacts
        val isKnownContact = isNumberInContacts(applicationContext, phoneNumber)

        // 2. Perform Heuristic Analysis (Spoofing checks)
        val isMetadataSpoofed = verifyMetadataLocally(phoneNumber, isKnownContact)

        // 3. Perform Mock On-Device ML Audio Liveness Detection
        // Because grabbing audio takes time, we run this asynchronously and then respond
        scope.launch {
            val isDeepfake = withContext(Dispatchers.IO) {
                // In reality, this would hook into AudioRecord. We mock it for the presentation.
                voiceAnalyzer.analyzeAudioLiveness()
            }

            val response = CallResponse.Builder()
        
            if (isMetadataSpoofed || isDeepfake) {
                Log.e(TAG, "FLAGGED: Call from \$phoneNumber blocked! Metadata Spoofed = \$isMetadataSpoofed, Deepfake = \$isDeepfake")
                
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
    }

    private fun isNumberInContacts(context: Context, number: String): Boolean {
        // In a real app, this queries the ContactsProvider securely.
        // For the hackathon, we simulate a local trusted contact list.
        val trustedContacts = listOf("+1234567890", "+919876543210", "+447700900000")
        
        // Normalize the incoming number for comparison
        val normalizedIncoming = number.replace(Regex("[^+\\d]"), "")
        
        return trustedContacts.any { trusted -> 
            normalizedIncoming.endsWith(trusted.takeLast(10)) 
        }
    }

    private fun verifyMetadataLocally(number: String, isKnown: Boolean): Boolean {
        if (!isKnown) {
            // We only care about detecting FAKE calls from "Well-Known Contacts" according to the prompt
            return false 
        }

        // Heuristic 1: International Number Masking (Spoofing local numbers with international codes)
        // e.g., A contact is local to India (+91), but the call comes from a +44 or +1 with the same 10 digits
        if (number.startsWith("+") && !number.startsWith("+91") && number.length > 11) {
             Log.w(TAG, "Spoof Warning: Known contact format but unexpected international prefix.")
             return true 
        }

        // Heuristic 2: Hidden/Restricted Caller ID masking as a known contact
        // Some spoofers hide their origin entirely. 
        if (number.isEmpty() || number.equals("Restricted", ignoreCase = true) || number.equals("Unknown", ignoreCase = true)) {
            Log.w(TAG, "Spoof Warning: Caller ID restricted or blocked.")
            return true
        }

        // Heuristic 3: Excessive Call Frequency (Simulated)
        // Scammers often use auto-dialers. If we see 5 calls in 1 minute, flag it.
        // TODO: Tie this into a local Room DB keeping track of connection timestamps.

        return false
    }
}
