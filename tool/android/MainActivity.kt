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
    }

    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickPhoneContact") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                if (pendingContactResult != null) {
                    result.error("PICKER_BUSY", "Contact picker is already open.", null)
                    return@setMethodCallHandler
                }

                pendingContactResult = result
                try {
                    // ACTION_PICK grants temporary read access to only the selected
                    // phone-row URI. The app does not need broad READ_CONTACTS access.
                    val intent = Intent(
                        Intent.ACTION_PICK,
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                    )
                    startActivityForResult(intent, CONTACT_PICK_REQUEST)
                } catch (error: Exception) {
                    pendingContactResult = null
                    result.error("PICKER_OPEN_FAILED", error.message, null)
                }
            }
    }

    @Deprecated("Deprecated in Android API, retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CONTACT_PICK_REQUEST) return

        val callback = pendingContactResult
        pendingContactResult = null
        if (callback == null) return

        if (resultCode != RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }

        try {
            val selectedUri = data.data!!
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            contentResolver.query(selectedUri, projection, null, null, null).use { cursor ->
                if (cursor == null || !cursor.moveToFirst()) {
                    callback.success(null)
                    return
                }

                val nameIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                )
                val phoneIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                )
                val name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "" else ""
                val phone = if (phoneIndex >= 0) cursor.getString(phoneIndex) ?: "" else ""

                callback.success(mapOf("name" to name, "phone" to phone))
            }
        } catch (error: Exception) {
            callback.error("CONTACT_READ_FAILED", error.message, null)
        }
    }
}
