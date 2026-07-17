package aleem.flutter.defender

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class OverlayTouchStateTrackerTest {
    @Test
    fun `full obscuration blocks immediately and clears on a clean gesture`() {
        val tracker = OverlayTouchStateTracker(partialConfirmationMs = 2_000)

        assertEquals(
            OverlayTouchStateChange.violation,
            tracker.update(
                kind = OverlayTouchKind.full,
                gestureStart = true,
                eventTimeMs = 1_000
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.full,
                gestureStart = false,
                eventTimeMs = 1_050
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.clear,
                gestureStart = false,
                eventTimeMs = 1_100
            )
        )
        assertEquals(
            OverlayTouchStateChange.cleared,
            tracker.update(
                kind = OverlayTouchKind.clear,
                gestureStart = true,
                eventTimeMs = 1_500
            )
        )
    }

    @Test
    fun `camera privacy dot sequence does not show a violation`() {
        val tracker = OverlayTouchStateTracker(partialConfirmationMs = 2_000)

        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 0
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 186
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 935
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.clear,
                gestureStart = true,
                eventTimeMs = 6_195
            )
        )
    }

    @Test
    fun `persistent partial obscuration escalates on a later gesture`() {
        val tracker = OverlayTouchStateTracker(partialConfirmationMs = 2_000)

        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 1_000
            )
        )
        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 2_999
            )
        )
        assertEquals(
            OverlayTouchStateChange.violation,
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 3_000
            )
        )
        assertEquals(
            OverlayTouchStateChange.cleared,
            tracker.update(
                kind = OverlayTouchKind.clear,
                gestureStart = true,
                eventTimeMs = 3_500
            )
        )
    }

    @Test
    fun `full obscuration overrides a pending partial gesture`() {
        val tracker = OverlayTouchStateTracker(partialConfirmationMs = 2_000)

        assertNull(
            tracker.update(
                kind = OverlayTouchKind.partial,
                gestureStart = true,
                eventTimeMs = 1_000
            )
        )
        assertEquals(
            OverlayTouchStateChange.violation,
            tracker.update(
                kind = OverlayTouchKind.full,
                gestureStart = false,
                eventTimeMs = 1_100
            )
        )
    }
}
