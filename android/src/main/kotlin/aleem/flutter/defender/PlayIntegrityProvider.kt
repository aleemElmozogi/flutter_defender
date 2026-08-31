package aleem.flutter.defender

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode

internal fun interface PlayIntegrityTokenRequester {
    fun request(requestHash: String, callback: (Result<String>) -> Unit)
}

internal fun interface PlayIntegrityClient {
    fun prepare(
        cloudProjectNumber: Long,
        callback: (Result<PlayIntegrityTokenRequester>) -> Unit
    )
}

internal class PlayIntegrityProvider(
    private val client: PlayIntegrityClient,
    private val isInvalidProviderError: (Throwable) -> Boolean = { error ->
        error is StandardIntegrityException &&
            error.errorCode == StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID
    }
) {
    constructor(context: Context) : this(GooglePlayIntegrityClient(context))

    private val stateLock = Any()

    @Volatile
    private var tokenRequester: PlayIntegrityTokenRequester? = null

    private var preparationGeneration = 0L

    fun prepare(cloudProjectNumber: Long, callback: (Result<Unit>) -> Unit) {
        if (cloudProjectNumber <= 0) {
            callback(Result.failure(IllegalArgumentException("Cloud project number must be positive.")))
            return
        }
        val generation = synchronized(stateLock) {
            tokenRequester = null
            preparationGeneration += 1
            preparationGeneration
        }
        client.prepare(cloudProjectNumber) { result ->
            val isCurrent = synchronized(stateLock) {
                if (generation != preparationGeneration) {
                    false
                } else {
                    tokenRequester = result.getOrNull()
                    true
                }
            }
            if (!isCurrent) {
                callback(
                    Result.failure(
                        IllegalStateException(
                            "Play Integrity preparation was superseded by a newer request."
                        )
                    )
                )
            } else {
                callback(result.map { Unit })
            }
        }
    }

    fun requestToken(requestHash: String, callback: (Result<String>) -> Unit) {
        if (requestHash.isBlank()) {
            callback(Result.failure(IllegalArgumentException("Request hash must not be blank.")))
            return
        }
        if (requestHash.toByteArray(Charsets.UTF_8).size > MAX_REQUEST_HASH_BYTES) {
            callback(
                Result.failure(
                    IllegalArgumentException(
                        "Request hash must not exceed $MAX_REQUEST_HASH_BYTES UTF-8 bytes."
                    )
                )
            )
            return
        }
        val requester = tokenRequester
            ?: return callback(
                Result.failure(
                    IllegalStateException(
                        "Play Integrity is not prepared. Call preparePlayIntegrity first."
                    )
                )
            )
        requester.request(requestHash) { result ->
            val error = result.exceptionOrNull()
            if (error != null && isInvalidProviderError(error)) {
                synchronized(stateLock) {
                    if (tokenRequester === requester) {
                        tokenRequester = null
                    }
                }
            }
            callback(result)
        }
    }

    private companion object {
        const val MAX_REQUEST_HASH_BYTES = 500
    }
}

private class GooglePlayIntegrityClient(context: Context) : PlayIntegrityClient {
    private val manager = IntegrityManagerFactory.createStandard(context)

    override fun prepare(
        cloudProjectNumber: Long,
        callback: (Result<PlayIntegrityTokenRequester>) -> Unit
    ) {
        val request = StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
            .setCloudProjectNumber(cloudProjectNumber)
            .build()
        manager.prepareIntegrityToken(request)
            .addOnSuccessListener { provider ->
                callback(
                    Result.success(
                        PlayIntegrityTokenRequester { requestHash, tokenCallback ->
                            val tokenRequest =
                                StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
                                    .setRequestHash(requestHash)
                                    .build()
                            provider.request(tokenRequest)
                                .addOnSuccessListener { response ->
                                    tokenCallback(Result.success(response.token()))
                                }
                                .addOnFailureListener { error ->
                                    tokenCallback(Result.failure(error))
                                }
                        }
                    )
                )
            }
            .addOnFailureListener { error ->
                callback(Result.failure(error))
            }
    }
}
