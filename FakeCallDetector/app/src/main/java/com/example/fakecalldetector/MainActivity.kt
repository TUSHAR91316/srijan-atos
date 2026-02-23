package com.example.fakecalldetector

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var statusTextView: TextView
    private lateinit var enableServiceButton: Button

    private val roleRequestLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            statusTextView.text = "Status: ACTIVE. Listening locally..."
            Toast.makeText(this, "Call Screening Enabled", Toast.LENGTH_SHORT).show()
        } else {
            statusTextView.text = "Status: PERMISSION DENIED"
            Toast.makeText(this, "Must be default app to screen calls", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusTextView = findViewById(R.id.statusTextView)
        enableServiceButton = findViewById(R.id.enableServiceButton)

        enableServiceButton.setOnClickListener {
            requestCallScreeningRole()
        }
    }

    private fun requestCallScreeningRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                    Toast.makeText(this, "Already Enabled!", Toast.LENGTH_SHORT).show()
                    statusTextView.text = "Status: ACTIVE. Listening locally..."
                } else {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                    roleRequestLauncher.launch(intent)
                }
            }
        } else {
            Toast.makeText(this, "Requires Android 10+", Toast.LENGTH_LONG).show()
            statusTextView.text = "Status: UNSUPPORTED OS VERSION"
        }
    }
}
