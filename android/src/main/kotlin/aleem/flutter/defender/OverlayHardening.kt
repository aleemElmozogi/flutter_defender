package aleem.flutter.defender

import android.os.Build
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window

internal class OverlayAwareWindowCallback(
    val delegateCallback: Window.Callback,
    private val onObscuredTouch: () -> Unit,
    private val onUnobscuredTouch: () -> Unit,
    private val onWindowFocusChange: ((Boolean) -> Unit)? = null,
    private val isActive: () -> Boolean
) : Window.Callback by delegateCallback {
    private val touchStateTracker = OverlayTouchStateTracker()

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (!isActive()) {
            return delegateCallback.dispatchTouchEvent(event)
        }

        val touchKind = event.overlayTouchKind()
        when (
            touchStateTracker.update(
                kind = touchKind,
                gestureStart = event.actionMasked == MotionEvent.ACTION_DOWN,
                eventTimeMs = event.eventTime
            )
        ) {
            OverlayTouchStateChange.violation -> onObscuredTouch()
            OverlayTouchStateChange.cleared -> onUnobscuredTouch()
            null -> Unit
        }
        if (touchKind != OverlayTouchKind.clear) {
            return true
        }
        return delegateCallback.dispatchTouchEvent(event)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        if (isActive()) {
            onWindowFocusChange?.invoke(hasFocus)
        }
        delegateCallback.onWindowFocusChanged(hasFocus)
    }
}

private const val PARTIAL_OVERLAY_CONFIRMATION_MS = 2_000L

internal enum class OverlayTouchStateChange { violation, cleared }

internal enum class OverlayTouchKind { clear, partial, full }

internal class OverlayTouchStateTracker(
    private val partialConfirmationMs: Long = PARTIAL_OVERLAY_CONFIRMATION_MS
) {
    private var violationActive = false
    private var firstPartialGestureAtMs: Long? = null

    fun update(
        kind: OverlayTouchKind,
        gestureStart: Boolean,
        eventTimeMs: Long
    ): OverlayTouchStateChange? {
        if (kind == OverlayTouchKind.full) {
            firstPartialGestureAtMs = null
            if (violationActive) return null
            violationActive = true
            return OverlayTouchStateChange.violation
        }

        if (kind == OverlayTouchKind.partial) {
            if (violationActive || !gestureStart) return null
            val firstPartialAt = firstPartialGestureAtMs
            if (firstPartialAt == null) {
                firstPartialGestureAtMs = eventTimeMs
                return null
            }
            if (eventTimeMs - firstPartialAt < partialConfirmationMs) return null
            firstPartialGestureAtMs = null
            violationActive = true
            return OverlayTouchStateChange.violation
        }

        if (!gestureStart) return null
        firstPartialGestureAtMs = null
        if (!violationActive) return null
        violationActive = false
        return OverlayTouchStateChange.cleared
    }
}

internal fun MotionEvent.overlayTouchKind(): OverlayTouchKind {
    if (flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0) {
        return OverlayTouchKind.full
    }
    if (
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
    ) {
        return OverlayTouchKind.partial
    }
    return OverlayTouchKind.clear
}

internal fun View.setFilterTouchesRecursively(enabled: Boolean) {
    filterTouchesWhenObscured = enabled
    if (this is ViewGroup) {
        for (index in 0 until childCount) {
            getChildAt(index).setFilterTouchesRecursively(enabled)
        }
    }
}
