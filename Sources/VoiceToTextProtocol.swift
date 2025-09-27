import Foundation

/// Protocol defining the interface for audio transcription
protocol VoiceToTextProtocol {
    /// Transcribe an audio file to text
    /// - Parameter filepath: The path to the audio file (m4a format)
    /// - Returns: The transcribed text
    /// - Throws: TranscriptionError if the transcription fails
    func process(filepath: String) async throws -> String
}
