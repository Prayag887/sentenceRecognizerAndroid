package com.prayag.sentence_recognizer_android

import android.util.Log
import java.util.Locale

class MapperSentence {
    val speakLoud: String = "Please speak clearly and loudly in a silent environment."

    fun mapNumbersIncludingSpellings(text: String, mapping: Map<String, List<String>>): String {
        if (text.isBlank()) return text

        val normalizedInput = text.trim().lowercase(Locale.ROOT)

        // Invert the mapping to pronunciation -> keys
        val reversedMapping = mutableMapOf<String, MutableList<String>>()
        mapping.forEach { (key, spellings) ->
            for (spelling in spellings) {
                val normalizedSpelling = spelling.lowercase(Locale.ROOT).trim()
                reversedMapping.getOrPut(normalizedSpelling) { mutableListOf() }.add(key)
            }
        }

        // Find all keys that match the full normalized input
        val matchedKeys = reversedMapping[normalizedInput]
            ?.distinct()
            ?: listOf(text.uppercase(Locale.ROOT))

        return matchedKeys.joinToString(", ")
    }


    fun mapNumber(text: String, mapping: Map<String, List<String>>): String {
        if (text.isBlank()) {
            return speakLoud
        }
        Log.d("TAG", "numbers: ------------- $text")
        val normalizedText = text.lowercase(Locale.ROOT)
        val reversedMapping = mutableMapOf<String, MutableList<String>>()
        mapping.forEach { (key, values) ->
            values.forEach { pronunciation ->
                val normalizedPronunciation = pronunciation.lowercase(Locale.ROOT)
                reversedMapping.getOrPut(normalizedPronunciation) { mutableListOf() }.add(key)
            }
        }
        val matchedKeys = reversedMapping[normalizedText]?.distinct() ?: listOf(text.uppercase(Locale.ROOT))
        return matchedKeys.joinToString(", ")
    }

    fun mapText(text: String, mapping: Map<String, List<String>>): String {
        Log.d("TAG", "texts: ------------- $text")
        val normalizedText = text.lowercase(Locale.ROOT)
        val matchedKeys = mapping.entries
            .filter { (_, pronunciations) ->
                pronunciations.any { it.lowercase(Locale.ROOT) == normalizedText }
            }
            .map { it.key }
            .distinct()

        return if (matchedKeys.isNotEmpty()) {
            matchedKeys.joinToString(", ")
        } else {
            speakLoud // if null
        }
    }
}