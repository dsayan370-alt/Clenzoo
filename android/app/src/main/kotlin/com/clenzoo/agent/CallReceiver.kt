package com.clenzoo.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.telephony.TelephonyManager
import android.util.Log
import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class CallReceiver : BroadcastReceiver() {

    companion object {
        private var callStartMs = 0L
        private var lastNumber  = ""
        private var isActive    = false
        private var callStartStr = ""
        private const val TAG = "CZCall"
        private const val API = "https://clenzoo.com/login/call_log_api.php"
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        val state  = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val number = try { intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: "" } catch (e: Exception) { "" }
        val sdf    = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())

        when (state) {
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                callStartMs  = System.currentTimeMillis()
                callStartStr = sdf.format(Date())
                isActive     = true
                if (number.isNotEmpty()) lastNumber = number
                Log.d(TAG, "Call connected: $lastNumber")
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                if (isActive && callStartMs > 0) {
                    val durSec   = ((System.currentTimeMillis() - callStartMs) / 1000).toInt()
                    val callEnd  = sdf.format(Date())
                    isActive     = false
                    val num      = lastNumber
                    val start    = callStartStr
                    Log.d(TAG, "Call ended: $num dur=${durSec}s")
                    Thread { send(ctx, num, durSec, "outgoing", start, callEnd) }.start()
                }
            }

            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (number.isNotEmpty()) lastNumber = number
            }
        }
    }

    private fun send(ctx: Context, contact: String, dur: Int, type: String, start: String, end: String) {
        val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.agent_token", "") ?: ""
        if (token.isEmpty()) { saveOffline(ctx, contact, dur, type, start, end); return }

        try {
            val body = JSONObject().apply {
                put("contact", contact)
                put("duration_seconds", dur)
                put("call_type", type)
                put("call_start", start)
                put("call_end", end)
            }.toString().toByteArray(Charsets.UTF_8)

            val conn = URL("$API?action=log_call").openConnection() as HttpURLConnection
            conn.requestMethod  = "POST"
            conn.connectTimeout = 12000
            conn.readTimeout    = 12000
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-Agent-Token", token)
            conn.doOutput = true
            conn.outputStream.use { it.write(body) }

            val resp = conn.inputStream.bufferedReader().readText()
            Log.d(TAG, "Server: $resp")

            val json   = JSONObject(resp)
            val msg    = json.optString("message", "Call logged")
            val valid  = json.optBoolean("is_valid", false)
            val comm   = json.optDouble("commission", 0.0)

            // Toast
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                android.widget.Toast.makeText(
                    ctx,
                    if (valid) "✅ ${dur}s | ₹${comm.toInt()} credited!" else "📞 ${dur}s | $msg",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Send failed: ${e.message}")
            saveOffline(ctx, contact, dur, type, start, end)
        }
    }

    private fun saveOffline(ctx: Context, contact: String, dur: Int, type: String, start: String, end: String) {
        try {
            val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val existing = prefs.getString("flutter.offline_q", "[]") ?: "[]"
            val arr = org.json.JSONArray(existing)
            arr.put(JSONObject().apply {
                put("contact", contact); put("duration_seconds", dur)
                put("call_type", type);  put("call_start", start); put("call_end", end)
            })
            prefs.edit().putString("flutter.offline_q", arr.toString()).apply()
        } catch (e: Exception) { Log.e(TAG, "Offline save: ${e.message}") }
    }
}
