package aleem.flutter.defender

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class PlayIntegrityProviderTest {
    @Test
    fun `request fails until provider is prepared`() {
        val provider = PlayIntegrityProvider(
            PlayIntegrityClient { _, _ -> error("prepare should not be called") }
        )

        val failure = captureResult<String> { callback ->
            provider.requestToken("request-hash", callback)
        }

        assertFailsWith<IllegalStateException> { failure.getOrThrow() }
    }

    @Test
    fun `prepared provider forwards request hash and token`() {
        var preparedProject = 0L
        var receivedHash = ""
        val provider = PlayIntegrityProvider(
            PlayIntegrityClient { project, callback ->
                preparedProject = project
                callback(
                    Result.success(
                        PlayIntegrityTokenRequester { requestHash, tokenCallback ->
                            receivedHash = requestHash
                            tokenCallback(Result.success("encrypted-token"))
                        }
                    )
                )
            }
        )

        val preparation = captureResult<Unit> { callback ->
            provider.prepare(123456789L, callback)
        }
        val token = captureResult<String> { callback ->
            provider.requestToken("canonical-request-hash", callback)
        }

        preparation.getOrThrow()
        assertEquals(123456789L, preparedProject)
        assertEquals("canonical-request-hash", receivedHash)
        assertEquals("encrypted-token", token.getOrThrow())
    }

    @Test
    fun `failed reprepare clears an older provider`() {
        var prepareCount = 0
        val provider = PlayIntegrityProvider(
            PlayIntegrityClient { _, callback ->
                prepareCount += 1
                if (prepareCount == 1) {
                    callback(
                        Result.success(
                            PlayIntegrityTokenRequester { _, tokenCallback ->
                                tokenCallback(Result.success("old-token"))
                            }
                        )
                    )
                } else {
                    callback(Result.failure(IllegalStateException("prepare failed")))
                }
            }
        )

        captureResult<Unit> { callback -> provider.prepare(1L, callback) }.getOrThrow()
        val failedPreparation = captureResult<Unit> { callback ->
            provider.prepare(2L, callback)
        }
        assertFailsWith<IllegalStateException> { failedPreparation.getOrThrow() }

        val token = captureResult<String> { callback ->
            provider.requestToken("request-hash", callback)
        }
        assertFailsWith<IllegalStateException> { token.getOrThrow() }
    }

    @Test
    fun `latest concurrent preparation owns the token provider`() {
        val preparationCallbacks = mutableListOf<(Result<PlayIntegrityTokenRequester>) -> Unit>()
        val provider = PlayIntegrityProvider(
            PlayIntegrityClient { _, callback -> preparationCallbacks += callback }
        )
        var firstResult: Result<Unit>? = null
        var secondResult: Result<Unit>? = null

        provider.prepare(1L) { firstResult = it }
        provider.prepare(2L) { secondResult = it }

        val latestRequester = PlayIntegrityTokenRequester { _, callback ->
            callback(Result.success("latest-token"))
        }
        preparationCallbacks[1](Result.success(latestRequester))
        preparationCallbacks[0](
            Result.success(
                PlayIntegrityTokenRequester { _, callback ->
                    callback(Result.success("stale-token"))
                }
            )
        )

        secondResult?.getOrThrow()
        assertFailsWith<IllegalStateException> { requireNotNull(firstResult).getOrThrow() }
        val token = captureResult<String> { callback ->
            provider.requestToken("request-hash", callback)
        }
        assertEquals("latest-token", token.getOrThrow())
    }

    @Test
    fun `invalid token provider is cleared after a failed request`() {
        class InvalidProviderException : IllegalStateException()

        val provider = PlayIntegrityProvider(
            client = PlayIntegrityClient { _, callback ->
                callback(
                    Result.success(
                        PlayIntegrityTokenRequester { _, tokenCallback ->
                            tokenCallback(Result.failure(InvalidProviderException()))
                        }
                    )
                )
            },
            isInvalidProviderError = { it is InvalidProviderException }
        )

        captureResult<Unit> { callback -> provider.prepare(1L, callback) }.getOrThrow()
        val invalidRequest = captureResult<String> { callback ->
            provider.requestToken("request-hash", callback)
        }
        assertFailsWith<InvalidProviderException> { invalidRequest.getOrThrow() }

        val requestAfterInvalidation = captureResult<String> { callback ->
            provider.requestToken("request-hash", callback)
        }
        assertFailsWith<IllegalStateException> { requestAfterInvalidation.getOrThrow() }
    }

    @Test
    fun `invalid request inputs are rejected before calling the client`() {
        var prepareCalled = false
        val provider = PlayIntegrityProvider(
            PlayIntegrityClient { _, _ -> prepareCalled = true }
        )

        val invalidPreparation = captureResult<Unit> { callback ->
            provider.prepare(0L, callback)
        }
        assertFailsWith<IllegalArgumentException> { invalidPreparation.getOrThrow() }
        assertTrue(!prepareCalled)
        val blankHash = captureResult<String> { callback ->
            provider.requestToken(" ", callback)
        }
        assertFailsWith<IllegalArgumentException> { blankHash.getOrThrow() }
        val longHash = captureResult<String> { callback ->
            provider.requestToken("a".repeat(501), callback)
        }
        assertFailsWith<IllegalArgumentException> { longHash.getOrThrow() }
    }

    private fun <T> captureResult(
        operation: (((Result<T>) -> Unit) -> Unit)
    ): Result<T> {
        var captured: Result<T>? = null
        operation { captured = it }
        return requireNotNull(captured) { "Expected a synchronous test callback." }
    }
}
