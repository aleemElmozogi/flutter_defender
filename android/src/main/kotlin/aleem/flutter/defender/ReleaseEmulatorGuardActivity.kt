package aleem.flutter.defender

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class ReleaseEmulatorGuardActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (shouldBlockReleaseEmulator()) {
            Log.w(TAG, "Blocking non-debuggable emulator launch.")
            showReleaseEmulatorBlocker()
            return
        }
        forwardToTargetActivity()
    }

    private fun shouldBlockReleaseEmulator(): Boolean {
        return isReleaseLikeBuild() && EmulatorDetector.isEmulator()
    }

    private fun isReleaseLikeBuild(): Boolean {
        return (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0
    }

    private fun targetActivityName(): String {
        val configured = activityMetadata().getString(META_TARGET_ACTIVITY)
        if (!configured.isNullOrBlank()) {
            return if (configured.startsWith(".")) {
                "$packageName$configured"
            } else {
                configured
            }
        }
        return "$packageName.MainActivity"
    }

    private fun forwardToTargetActivity() {
        val targetActivity = targetActivityName()
        try {
            Log.d(TAG, "Forwarding launcher to $targetActivity.")
            startActivity(Intent().setClassName(packageName, targetActivity))
            finish()
            overridePendingTransition(0, 0)
        } catch (error: ActivityNotFoundException) {
            Log.e(TAG, "Configured target activity was not found: $targetActivity", error)
            showConfigurationError(targetActivity)
        }
    }

    @Suppress("DEPRECATION")
    private fun activityMetadata(): Bundle {
        return try {
            val activityInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getActivityInfo(
                    componentName,
                    PackageManager.ComponentInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                packageManager.getActivityInfo(componentName, PackageManager.GET_META_DATA)
            }
            activityInfo.metaData ?: Bundle.EMPTY
        } catch (error: PackageManager.NameNotFoundException) {
            Log.w(TAG, "Release emulator guard metadata was not found.", error)
            Bundle.EMPTY
        }
    }

    private fun showReleaseEmulatorBlocker() {
        val metadata = activityMetadata()
        val titleText = metadataText(metadata, META_BLOCK_TITLE, DEFAULT_BLOCK_TITLE)
        val subtitleText = metadataText(metadata, META_BLOCK_SUBTITLE, DEFAULT_BLOCK_SUBTITLE)
        val messageText = metadataText(metadata, META_BLOCK_MESSAGE, DEFAULT_BLOCK_MESSAGE)
        val buttonText = metadataText(metadata, META_BLOCK_BUTTON, DEFAULT_BLOCK_BUTTON)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F4F7FB"))
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28), dp(32), dp(28), dp(28))
            elevation = dp(8).toFloat()

            background = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(Color.WHITE)
            }
        }

        val icon = TextView(this).apply {
            text = "!"
            textSize = 54f
            setTextColor(Color.parseColor("#DC2626"))
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(14))
        }

        val title = TextView(this).apply {
            text = titleText
            setTextColor(Color.parseColor("#0F172A"))
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            textSize = 24f
        }

        val subtitle = TextView(this).apply {
            text = subtitleText
            setTextColor(Color.parseColor("#64748B"))
            gravity = Gravity.CENTER
            textSize = 15f
            setPadding(0, dp(8), 0, dp(22))
        }

        val message = TextView(this).apply {
            text = messageText

            setTextColor(Color.parseColor("#334155"))
            gravity = Gravity.CENTER
            textSize = 17f
            setLineSpacing(0f, 1.3f)
            setPadding(0, 0, 0, dp(28))
        }

        val closeButton = Button(this).apply {
            text = buttonText
            isAllCaps = false
            textSize = 16f
            setTextColor(Color.WHITE)

            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(Color.parseColor("#2563EB"))
            }

            setPadding(dp(20), dp(14), dp(20), dp(14))

            setOnClickListener {
                finishAndRemoveTask()
            }
        }

        card.addView(icon)

        card.addView(
            title,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        card.addView(
            subtitle,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        card.addView(
            message,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        card.addView(
            closeButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        root.addView(
            card,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        setContentView(root)
    }

    private fun showConfigurationError(targetActivity: String) {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.WHITE)
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }
        val title = TextView(this).apply {
            text = "Launch configuration error"
            setTextColor(Color.parseColor("#991B1B"))
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            textSize = 22f
        }
        val message = TextView(this).apply {
            text = "flutter_defender could not open $targetActivity.\nCheck aleem.flutter.defender.TARGET_ACTIVITY in AndroidManifest.xml."
            setTextColor(Color.parseColor("#334155"))
            gravity = Gravity.CENTER
            textSize = 16f
            setLineSpacing(0f, 1.25f)
            setPadding(0, dp(18), 0, dp(26))
        }
        val closeButton = Button(this).apply {
            text = "Close App"
            isAllCaps = false
            setOnClickListener { finishAndRemoveTask() }
        }
        root.addView(
            title,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        root.addView(
            message,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        root.addView(
            closeButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        setContentView(root)
    }

    private fun metadataText(metadata: Bundle, key: String, fallback: String): String {
        return metadata.getString(key)?.takeIf { it.isNotBlank() } ?: fallback
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private companion object {
        const val TAG = "FlutterDefenderGuard"
        const val META_TARGET_ACTIVITY = "aleem.flutter.defender.TARGET_ACTIVITY"
        const val META_BLOCK_TITLE = "aleem.flutter.defender.BLOCK_TITLE"
        const val META_BLOCK_SUBTITLE = "aleem.flutter.defender.BLOCK_SUBTITLE"
        const val META_BLOCK_MESSAGE = "aleem.flutter.defender.BLOCK_MESSAGE"
        const val META_BLOCK_BUTTON = "aleem.flutter.defender.BLOCK_BUTTON"
        const val DEFAULT_BLOCK_TITLE = "Unsupported Device"
        const val DEFAULT_BLOCK_SUBTITLE = "Security protection is enabled"
        const val DEFAULT_BLOCK_BUTTON = "Close App"
        val DEFAULT_BLOCK_MESSAGE = """
            This release build cannot run on emulators.
            Please use a physical Android device.
            
            لا يمكن تشغيل هذا الإصدار على المحاكي.
            يرجى استخدام جهاز حقيقي.
        """.trimIndent()
    }
}
