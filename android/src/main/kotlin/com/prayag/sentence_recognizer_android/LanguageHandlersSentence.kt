package com.prayag.alpha_num_recognizer_android

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
//import android.widget.Toast
import org.apache.commons.lang3.StringUtils
import java.io.BufferedReader
import java.io.InputStreamReader

class LanguageHandlersSentence(private val context: Context) {
    private var pluginInstance: SentenceRecognizerAndroidPlugin? = null

    /**
     * Sets the plugin instance that will receive the recognition results.
     *
     * @param plugin the plugin instance to receive the recognition results
     */
    fun setPluginInstance(plugin: SentenceRecognizerAndroidPlugin) {
        pluginInstance = plugin
    }

    /**
     * Handles alphabet recognition, first gets nepali language and maps it back to english..
     * Its done because english cant detect alphabets.
     * @param timeoutMillis the timeout in milliseconds for the recognition
     */
    fun handleAlphabetRecognition(timeoutMillis: Int) {

        val lang = "ne-NP"
        pluginInstance?.startRecognition(
            paragraph = "",
            lang = lang,
            MapperSentence = { text -> MapperSentence().mapText(text.keys.first(), PhoneticMappingSentence.phoneticNepaliToEnglishMapping) },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles recognition for all languages.
     *
     * @param timeoutMillis the timeout in milliseconds for the recognition
     * @param languageCode the language code for the recognition
     */
    fun handleAllLanguages(timeoutMillis: Int, languageCode: String) {

        pluginInstance?.startRecognition(
            paragraph = "",
            lang = languageCode,
            MapperSentence = { text -> MapperSentence().mapNumber(text.keys.first(), PhoneticMappingSentence.phoneticNepaliToEnglishMapping) },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles Korean alphabet recognition, works similar to english alohabets.
     *
     * @param timeoutMillis the timeout in milliseconds for the recognition
     */
    fun handleKoreanAlphabetRecognition(timeoutMillis: Int) {

        pluginInstance?.startRecognition(
            paragraph = "",
            lang = "ne-NP",
            MapperSentence = { text -> MapperSentence().mapText(text.keys.first(), PhoneticMappingSentence.phoneticKoreanMapping) },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles number recognition based on hindi, similar to english alphabet detection.
     *
     * @param timeoutMillis the timeout in milliseconds for the recognition
     */
    fun handleNumberRecognition(timeoutMillis: Int, sentence: String) {
        val lang = if (listOf("0","1", "2", "3", "4", "5", "6", "7", "8", "9", "10").any { sentence.contains(it) }) {
            "ne-NP"
        } else {
            "hi-IN"
        }

        pluginInstance?.startRecognition(
            paragraph = "",
            lang = lang,
            MapperSentence = { text -> MapperSentence().mapNumbersIncludingSpellings(text.keys.first(), PhoneticMappingSentence.phoneticNumbersMapping) },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles word recognition like objects.
     *
     * @param languageCode the language code for the recognition
     * @param timeoutMillis the timeout in milliseconds for the recognition
     * @param sentence the sentence to recognize
     */
    fun handleWordsRecognition(languageCode: String?, timeoutMillis: Int, sentence: String) {
        Log.d("SpeechRecognition", "SENTENCE FROM FLUTTER SIDE: \"$sentence\"")
        if (languageCode == null) {
            pluginInstance?.activeResult?.error("INVALID_LANG", "Language code required", null)
            pluginInstance?.activeResult = null
            return
        }

        pluginInstance?.startRecognition(
            paragraph = "", // Keep empty for word recognition
            lang = languageCode,
            MapperSentence = { text ->
                if (languageCode == "en-US") {
                    val context = ContextBasedDetectionSentence().detectContext(sentence)
                    Log.d("SpeechRecognition", "Original recognition: ${text.keys.first()}")

                    try {
                        // Get detailed analysis and return it directly
                        val detailedAnalysis = getDetailedPhraseAnalysis(
                            listOf(text.keys.first()),
                            sentence,
                            context
                        )

                        Log.d("SpeechRecognition", "Returning detailed analysis directly: $detailedAnalysis")

                        // Return the detailed analysis directly instead of storing it
                        detailedAnalysis

                    } catch (e: Exception) {
                        Log.e("SpeechRecognition", "Error getting detailed analysis", e)
                        // Fallback to simple correction
                        val simpleResult = correctRecognizedPhrase(listOf(text.keys.first()), sentence, context)
                        mapOf(
                            "correctedPhrase" to simpleResult.keys.first(),
                            "confidence" to simpleResult.values.first(),
                            "detailedAnalysis" to false
                        )
                    }
                } else {
                    // For non-English, wrap in expected format
                    mapOf(
                        "correctedPhrase" to text.keys.first(),
                        "confidence" to text.values.first(),
                        "detailedAnalysis" to false
                    )
                }
            },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles paragraph mapping or partial texts.
     *
     * @param languageCode the language code for the recognition
     * @param timeoutMillis the timeout in milliseconds for the recognition
     * @param paragraph the paragraph to recognize
     */
    fun handleParagraphMapping(languageCode: String?, timeoutMillis: Int, paragraph: String) {
        Log.d("SpeechRecognition", "PARAGRAPH FROM FLUTTER SIDE: \"$paragraph\"")
        if (languageCode == null) {
            pluginInstance?.activeResult?.error("INVALID_LANG", "Language code required", null)
            pluginInstance?.activeResult = null
            return
        }

        val words = paragraph.split(" ").map { it.trim() }.filter { it.isNotEmpty() }

        pluginInstance?.startRecognition(
            paragraph = paragraph,
            lang = languageCode,
            MapperSentence = { text ->
                if (languageCode == "en-US") {
                    pluginInstance?.updateHighlightedText(text.keys.first(), words, paragraph)
                }
                text
            },
            timeoutMillis = timeoutMillis,
            keepListening = true
        )
    }

    /**
     * Handles Japanese recognition based on nepali language.
     *
     * @param timeoutMillis the timeout in milliseconds for the recognition
     * @param type the type of recognition
     */
    fun handleJapaneseRecognition(timeoutMillis: Int, type: String) {

        val lang = "ne-NP"
        pluginInstance?.startRecognition(
            paragraph = "",
            lang = lang,
            MapperSentence = { text ->
                MapperSentence().mapNumber(
                    text.keys.first(),
                    PhoneticMappingSentence.phoneticJapaneseAlphabetMapping
                )
            },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    /**
     * Handles Korean number recognition based on nepali language.
     *
     * @param timeoutMillis the timeout in milliseconds for the recognition
     * @param type the type of recognition
     */
    fun handleKoreanNumberRecognition(timeoutMillis: Int, type: String) {

        val lang = "ne-NP"
        pluginInstance?.startRecognition(
            paragraph = "",
            lang = lang,
            MapperSentence = { text ->
                MapperSentence().mapNumber(
                    text.keys.first(),
                    PhoneticMappingSentence.phoneticKoreanNumberMapping
                )
            },
            timeoutMillis = timeoutMillis,
            keepListening = false
        )
    }

    // Helper method for correcting recognized phrases based on phonetic similarity
    data class PhraseAnalysisResultSentence(
        val overallSimilarity: Double,
        val correctedPhrase: String,
        val originalPhrase: String,
        val wordAnalysis: List<WordAnalysisResultSentence>,
        val accepted: Boolean,
        val reason: String
    )

    fun correctRecognizedPhraseWithAnalysis(
        recognizedPhrases: List<String>,
        expectedPhrase: String,
        context: String = ""
    ): PhraseAnalysisResultSentence {
        if (recognizedPhrases.isEmpty()) {
            return PhraseAnalysisResultSentence(
                overallSimilarity = 0.0,
                correctedPhrase = "",
                originalPhrase = "",
                wordAnalysis = emptyList(),
                accepted = false,
                reason = "No recognized phrases provided"
            )
        }

        val enhancedSimilarity = PhoneticSimilaritySentence()
        var bestMatch = ""
        var bestSimilarity = 0.0
        var bestWordAnalysis = emptyList<WordAnalysisResultSentence>()
        var bestAccepted = false
        var bestReason = ""

        val auxiliaryVerbs = setOf("am", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "shall", "should", "can", "could", "may", "might", "must")

        val expectedWords = expectedPhrase
            .lowercase()
            .replace(Regex("[^a-zA-Z\\s]"), "")
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() && it !in auxiliaryVerbs }

        for ((index, recognizedPhrase) in recognizedPhrases.withIndex()) {
            val preprocessedPhrase = ContextBasedDetectionSentence().preprocessWithContext(recognizedPhrase, context)

            val recognizedWords = preprocessedPhrase
                .lowercase()
                .replace(Regex("[^a-zA-Z\\s]"), "")
                .split(Regex("\\s+"))
                .filter { it.isNotBlank() }

            // Check for exact word matches first
            val containsAllExpected = expectedWords.all { expectedWord ->
                recognizedWords.any { recognizedWord ->
                    recognizedWord == expectedWord
                }
            }

            if (containsAllExpected) {
                val perfectWordAnalysis = recognizedWords.map { word ->
                    WordAnalysisResultSentence(
                        recognizedWord = word,
                        confidence = 1.0,
                        phoneticContentSimilarity = 1.0
                    )
                }
                return PhraseAnalysisResultSentence(
                    overallSimilarity = 1.0,
                    correctedPhrase = expectedPhrase,
                    originalPhrase = expectedPhrase,
                    wordAnalysis = perfectWordAnalysis,
                    accepted = true,
                    reason = "Perfect word match - all content words found"
                )
            }

            // Get detailed analysis with word-level results
            val (similarity, wordAnalysis) = enhancedSimilarity.calculatePhoneticSimilaritySentenceWithWordAnalysis(
                expectedPhrase,
                preprocessedPhrase
            )

            // Show ONLY word-level analysis
            showWordLevelAnalysis(wordAnalysis, expectedPhrase, preprocessedPhrase)

            // Determine acceptance and reason
            val accepted = similarity >= 0.90
            val reason = when {
                similarity >= 0.95 -> "Excellent phonetic match (≥95%)"
                similarity >= 0.90 -> "Good phonetic match (≥90%)"
                similarity >= 0.70 -> "Moderate phonetic match but below threshold"
                similarity >= 0.50 -> "Weak phonetic match"
                else -> "Poor phonetic match"
            }

            if (similarity > bestSimilarity) {
                bestSimilarity = similarity
                bestMatch = preprocessedPhrase
                bestWordAnalysis = wordAnalysis
                bestAccepted = accepted
                bestReason = reason
            }
        }

        val finalPhrase = if (bestSimilarity >= 0.93) expectedPhrase else bestMatch

        return PhraseAnalysisResultSentence(
            overallSimilarity = bestSimilarity,
            correctedPhrase = finalPhrase,
            originalPhrase = expectedPhrase,
            wordAnalysis = bestWordAnalysis,
            accepted = bestAccepted,
            reason = bestReason
        )
    }

    // Legacy function for backward compatibility
    fun correctRecognizedPhrase(
        recognizedPhrases: List<String>,
        expectedPhrase: String,
        context: String = ""
    ): Map<String, Double> {
        val result = correctRecognizedPhraseWithAnalysis(recognizedPhrases, expectedPhrase, context)
        return mapOf(result.correctedPhrase to result.overallSimilarity)
    }

    // Helper function to show ONLY detailed word-level analysis
    private fun showWordLevelAnalysis(
        wordAnalysis: List<WordAnalysisResultSentence>,
        expectedPhrase: String,
        recognizedPhrase: String
    ) {
        println("\n📊 WORD-LEVEL ANALYSIS:")
        println("Expected: '$expectedPhrase' | Recognized: '$recognizedPhrase'")

        if (wordAnalysis.isEmpty()) {
            println("No word analysis available")
            return
        }

        wordAnalysis.forEachIndexed { index, result ->
            val confidenceBar = createProgressBar(result.confidence, 20)
            val phoneticBar = createProgressBar(result.phoneticContentSimilarity, 20)

            println("${index + 1}. '${result.recognizedWord}'")
            println("   Confidence:    ${String.format("%.2f", result.confidence)} $confidenceBar")
            println("   Phonetic Sim:  ${String.format("%.2f", result.phoneticContentSimilarity)} $phoneticBar")

            // Add interpretation
            val confidenceLevel = when {
                result.confidence >= 0.9 -> "Excellent"
                result.confidence >= 0.7 -> "Good"
                result.confidence >= 0.5 -> "Fair"
                else -> "Poor"
            }

            val phoneticLevel = when {
                result.phoneticContentSimilarity >= 0.9 -> "Excellent"
                result.phoneticContentSimilarity >= 0.7 -> "Good"
                result.phoneticContentSimilarity >= 0.5 -> "Fair"
                else -> "Poor"
            }

            println("   Quality: $confidenceLevel confidence, $phoneticLevel phonetic match\n")
        }

        // Summary statistics
        val avgConfidence = wordAnalysis.map { it.confidence }.average()
        val avgPhonetic = wordAnalysis.map { it.phoneticContentSimilarity }.average()
        val weakWords = wordAnalysis.count { it.confidence < 0.6 }
        val strongWords = wordAnalysis.count { it.confidence >= 0.8 }

        println("SUMMARY:")
        println("Average Confidence: ${String.format("%.2f", avgConfidence)}")
        println("Average Phonetic Similarity: ${String.format("%.2f", avgPhonetic)}")
        println("Strong Words (≥80%): $strongWords/${wordAnalysis.size}")
        println("Weak Words (<60%): $weakWords/${wordAnalysis.size}")
        println()
    }

    // Helper function to create progress bars for visualization
    private fun createProgressBar(value: Double, width: Int): String {
        val filled = (value * width).toInt()
        val empty = width - filled
        return "[${"█".repeat(filled)}${" ".repeat(empty)}]"
    }

    // Enhanced function to get word analysis as map (for API responses)
    fun getDetailedPhraseAnalysis(
        recognizedPhrases: List<String>,
        expectedPhrase: String,
        context: String = ""
    ): Map<String, Any> {
        val result = correctRecognizedPhraseWithAnalysis(recognizedPhrases, expectedPhrase, context)

        return mapOf(
            "overallSimilarity" to result.overallSimilarity,
            "correctedPhrase" to result.correctedPhrase,
            "originalPhrase" to result.originalPhrase,
            "accepted" to result.accepted,
            "reason" to result.reason,
            "wordAnalysis" to result.wordAnalysis.map { word ->
                mapOf(
                    "recognizedWord" to word.recognizedWord,
                    "confidence" to word.confidence,
                    "phoneticContentSimilarity" to word.phoneticContentSimilarity
                )
            },
            "summary" to mapOf(
                "totalWords" to result.wordAnalysis.size,
                "averageConfidence" to if (result.wordAnalysis.isNotEmpty()) {
                    result.wordAnalysis.map { it.confidence }.average()
                } else 0.0,
                "averagePhoneticSimilaritySentence" to if (result.wordAnalysis.isNotEmpty()) {
                    result.wordAnalysis.map { it.phoneticContentSimilarity }.average()
                } else 0.0,
                "strongWords" to result.wordAnalysis.count { it.confidence >= 0.8 },
                "weakWords" to result.wordAnalysis.count { it.confidence < 0.6 }
            )
        )
    }

    // Helper extension for string repetition
    private operator fun String.times(n: Int): String = this.repeat(n)
}