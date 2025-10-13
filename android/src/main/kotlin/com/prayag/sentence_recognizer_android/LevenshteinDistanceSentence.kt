package com.prayag.sentence_recognizer_android

class LevenshteinDistanceSentence {
    fun calculate(s1: String, s2: String): Int {
        val len1 = s1.length
        val len2 = s2.length

        // Create a matrix to store distances
        val matrix = Array(len1 + 1) { IntArray(len2 + 1) }

        // Initialize first row and column
        for (i in 0..len1) matrix[i][0] = i
        for (j in 0..len2) matrix[0][j] = j

        // Fill the matrix
        for (i in 1..len1) {
            for (j in 1..len2) {
                val cost = if (s1[i - 1] == s2[j - 1]) 0 else 1

                matrix[i][j] = minOf(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[len1][len2]
    }
}