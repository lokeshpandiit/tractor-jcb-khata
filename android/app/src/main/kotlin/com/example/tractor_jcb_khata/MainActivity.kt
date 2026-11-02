package com.example.tractor_jcb_khata

import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CONTACT_PICK_REQUEST = 4711
        private const val CONTACT_CHANNEL = "lxh_one/contact_picker"
        private const val PICKER_PREFS = "lxh_one_contact_picker"
        private const val KEY_PENDING_ROLE = "pending_role"
        private const val KEY_PENDING_NAME = "pending_name"
        private const val KEY_PENDING_PHONE = "pending_phone"
    }

    private var pendingContactResult: MethodChannel.Result? = null
    private val pickerPrefs by lazy {
        getSharedPreferences(PICKER_PREFS, MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPhoneContact" -> {
                        if (pendingContactResult != null) {
                            result.error("PICKER_BUSY", "Contact picker is already open.", null)
                            return@setMethodCallHandler
                        }

                        val role = call.argument<String>("role")
                        if (role != "Worker" && role != "Client") {
                            result.error("INVALID_ROLE", "Choose Worker or Client before opening contacts.", null)
                            return@setMethodCallHandler
                        }

                        // Save the intended list before leaving the app. If Android
                        // recreates the Activity while the system picker is open,
                        // onActivityResult can still recover where this contact belongs.
                        pickerPrefs.edit()
                            .putString(KEY_PENDING_ROLE, role)
                            .remove(KEY_PENDING_NAME)
                            .remove(KEY_PENDING_PHONE)
                            .apply()

                        pendingContactResult = result
                        try {
                            val intent = Intent(
                                Intent.ACTION_PICK,
                                ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                            )
                            startActivityForResult(intent, CONTACT_PICK_REQUEST)
                        } catch (error: Exception) {
                            pendingContactResult = null
                            pickerPrefs.edit().remove(KEY_PENDING_ROLE).apply()
                            result.error("PICKER_OPEN_FAILED", error.message, null)
                        }
                    }

                    "consumePendingContact" -> {
                        val name = pickerPrefs.getString(KEY_PENDING_NAME, null)
                        val phone = pickerPrefs.getString(KEY_PENDING_PHONE, null)
                        val role = pickerPrefs.getString(KEY_PENDING_ROLE, null)
                        if (name.isNullOrBlank() || phone.isNullOrBlank() ||
                            (role != "Worker" && role != "Client")) {
                            result.success(null)
                        } else {
                            // Consume exactly once so lifecycle resume + app startup
                            // cannot add the same contact twice.
                            pickerPrefs.edit()
                                .remove(KEY_PENDING_NAME)
                                .remove(KEY_PENDING_PHONE)
                                .remove(KEY_PENDING_ROLE)
                                .apply()
                            result.success(mapOf("name" to name, "phone" to phone, "role" to role))
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated Android callback retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CONTACT_PICK_REQUEST) return

        val callback = pendingContactResult
        pendingContactResult = null

        if (resultCode != RESULT_OK || data?.data == null) {
            pickerPrefs.edit()
                .remove(KEY_PENDING_ROLE)
                .remove(KEY_PENDING_NAME)
                .remove(KEY_PENDING_PHONE)
                .apply()
            callback?.success(null)
            return
        }

        try {
            val selectedUri = data.data!!
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            val contact = contentResolver.query(selectedUri, projection, null, null, null).use { cursor ->
                if (cursor == null || !cursor.moveToFirst()) {
                    null
                } else {
                    val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val phoneIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val name = if (nameIndex >= 0) cursor.getString(nameIndex).orEmpty() else ""
                    val phone = if (phoneIndex >= 0) cursor.getString(phoneIndex).orEmpty() else ""
                    mapOf("name" to name, "phone" to phone)
                }
            }

            if (contact == null || contact["name"].isNullOrBlank() || contact["phone"].isNullOrBlank()) {
                pickerPrefs.edit().remove(KEY_PENDING_ROLE).apply()
                callback?.success(null)
                return
            }

            val role = pickerPrefs.getString(KEY_PENDING_ROLE, null)
            if (role != "Worker" && role != "Client") {
                callback?.error("MISSING_ROLE", "Could not recover whether this contact was a Worker or Client.", null)
                return
            }

            if (callback != null) {
                // Normal path: complete the original Flutter method call.
                pickerPrefs.edit().remove(KEY_PENDING_ROLE).apply()
                callback.success(
                    mapOf("name" to contact["name"], "phone" to contact["phone"], "role" to role)
                )
            } else {
                // Recovery path: Flutter/Activity was recreated while Contacts was
                // open. Persist the result for Dart to consume on app resume/startup.
                pickerPrefs.edit()
                    .putString(KEY_PENDING_NAME, contact["name"])
                    .putString(KEY_PENDING_PHONE, contact["phone"])
                    .putString(KEY_PENDING_ROLE, role)
                    .apply()
            }
        } catch (error: Exception) {
            pickerPrefs.edit()
                .remove(KEY_PENDING_ROLE)
                .remove(KEY_PENDING_NAME)
                .remove(KEY_PENDING_PHONE)
                .apply()
            callback?.error("CONTACT_READ_FAILED", error.message, null)
        }
    }
}
