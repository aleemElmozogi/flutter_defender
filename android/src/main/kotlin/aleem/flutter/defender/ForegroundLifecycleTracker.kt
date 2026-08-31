package aleem.flutter.defender

import android.app.Activity
import android.app.Application
import android.os.Bundle

internal class ForegroundLifecycleTracker(
    targetActivity: () -> Activity?,
    private val onForegroundChanged: (Boolean) -> Unit
) : Application.ActivityLifecycleCallbacks {
    private val stateTracker = ForegroundStateTracker(
        targetOwner = targetActivity,
        onForegroundChanged = onForegroundChanged
    )

    val isForeground: Boolean?
        get() = stateTracker.isForeground

    override fun onActivityResumed(activity: Activity) {
        stateTracker.update(activity, true)
    }

    override fun onActivityPaused(activity: Activity) {
        stateTracker.update(activity, false)
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    override fun onActivityDestroyed(activity: Activity) = Unit
}

internal class ForegroundStateTracker<T : Any>(
    private val targetOwner: () -> T?,
    private val onForegroundChanged: (Boolean) -> Unit
) {
    var isForeground: Boolean? = null
        private set

    fun update(owner: T, active: Boolean) {
        if (owner !== targetOwner() || isForeground == active) {
            return
        }
        isForeground = active
        onForegroundChanged(active)
    }
}
