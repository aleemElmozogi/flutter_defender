package aleem.flutter.defender

import android.os.Build
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window

internal class OverlayAwareWindowCallback(
    val delegateCallback: Window.Callback,
    private val onObscuredTouch: () -> Unit,
    private val isActive: () -> Boolean
) : Window.Callback by delegateCallback {
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (isActive() && event.isObscuredTouch()) {
            onObscuredTouch()
            return true
        }
        return delegateCallback.dispatchTouchEvent(event)
    }
}

internal fun MotionEvent.isObscuredTouch(): Boolean {
    val obscured = flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
    val partiallyObscured =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
    return obscured || partiallyObscured
}

internal fun View.setFilterTouchesRecursively(enabled: Boolean) {
    filterTouchesWhenObscured = enabled
    if (this is ViewGroup) {
        for (index in 0 until childCount) {
            getChildAt(index).setFilterTouchesRecursively(enabled)
        }
    }
}
