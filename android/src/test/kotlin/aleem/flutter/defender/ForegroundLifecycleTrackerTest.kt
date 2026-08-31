package aleem.flutter.defender

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ForegroundLifecycleTrackerTest {
    @Test
    fun `tracks resume and pause only for the protected activity`() {
        val protectedActivity = Any()
        val otherActivity = Any()
        val states = mutableListOf<Boolean>()
        val tracker = ForegroundStateTracker(
            targetOwner = { protectedActivity },
            onForegroundChanged = states::add
        )

        tracker.update(otherActivity, true)
        assertNull(tracker.isForeground)
        assertEquals(emptyList(), states)

        tracker.update(protectedActivity, true)
        tracker.update(protectedActivity, true)
        tracker.update(protectedActivity, false)
        tracker.update(protectedActivity, false)

        assertEquals(false, tracker.isForeground)
        assertEquals(listOf(true, false), states)
    }
}
