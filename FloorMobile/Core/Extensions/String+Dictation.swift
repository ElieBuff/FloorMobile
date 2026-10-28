//
//  String+Dictation.swift
//  FloorMobile
//

import Foundation

nonisolated extension String {
    /// Adds what was dictated after the text already there, with a space
    /// between them unless the text is empty or already ends with a space or
    /// a line break: a keyboard suggestion leaves a trailing space, and
    /// dictation hands its text back trimmed (`SpeechTranscription.Transcript.text`).
    mutating func append(dictation: String) {
        if let last, !last.isWhitespace {
            append(" ")
        }
        append(dictation)
    }
}
