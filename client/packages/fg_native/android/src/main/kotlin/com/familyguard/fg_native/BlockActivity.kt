package com.familyguard.fg_native

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen "paused" screen shown over an app that a rule doesn't allow
 * right now. Explains why, and offers the home screen or FamilyGuard (where
 * the child can ask for more time). Plain views — opens instantly without
 * starting Flutter.
 */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showing = true
        render(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        render(intent)
    }

    override fun onDestroy() {
        showing = false
        super.onDestroy()
    }

    @Deprecated("Back goes to the home screen, not back into the paused app.")
    override fun onBackPressed() {
        goHome()
    }

    private fun render(intent: Intent) {
        val reason = intent.getStringExtra(EXTRA_REASON) ?: REASON_APP
        val app = intent.getStringExtra(EXTRA_APP)
        val label = app?.let {
            try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(it, 0)).toString()
            } catch (_: Exception) {
                it
            }
        } ?: "This app"

        val (title, body) = when (reason) {
            REASON_BEDTIME -> "It's bedtime" to
                "Apps are paused until morning. Calls still work."
            REASON_LIMIT -> "Screen time is up for today" to
                "You've used today's screen time. You can ask your parent for more in FamilyGuard."
            else -> "$label is paused" to
                "Your parent has turned this app off. You can ask them about it in FamilyGuard."
        }

        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(px(32), px(32), px(32), px(32))
            setBackgroundColor(Color.parseColor("#080C12"))
        }
        val icon = TextView(this).apply {
            text = when (reason) {
                REASON_BEDTIME -> "🌙"
                REASON_LIMIT -> "⏳"
                else -> "⏸"
            }
            textSize = 56f
            gravity = Gravity.CENTER
        }
        val titleView = TextView(this).apply {
            text = title
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor("#E8EEF7"))
            gravity = Gravity.CENTER
            setPadding(0, px(24), 0, px(12))
        }
        val bodyView = TextView(this).apply {
            text = body
            textSize = 16f
            setTextColor(Color.parseColor("#8A99AE"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, px(32))
        }
        fun button(textValue: String, filled: Boolean, onClick: () -> Unit) = Button(this).apply {
            text = textValue
            setAllCaps(false) // (isAllCaps getter needs API 28; minSdk is 24)
            textSize = 16f
            setTextColor(if (filled) Color.WHITE else Color.parseColor("#4C8DFF"))
            background = GradientDrawable().apply {
                cornerRadius = px(12).toFloat()
                if (filled) setColor(Color.parseColor("#4C8DFF"))
                else setStroke(px(1), Color.parseColor("#223042"))
            }
            setOnClickListener { onClick() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, px(52)
            ).apply { topMargin = px(12) }
        }

        root.addView(icon)
        root.addView(titleView)
        root.addView(bodyView)
        root.addView(button("Open FamilyGuard", true) { openFamilyGuard() })
        root.addView(button("Go to home screen", false) { goHome() })
        setContentView(root)
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }

    private fun openFamilyGuard() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        finish()
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val EXTRA_APP = "app"
        const val REASON_APP = "app"
        const val REASON_BEDTIME = "bedtime"
        const val REASON_LIMIT = "limit"

        @Volatile
        var showing = false
    }
}
