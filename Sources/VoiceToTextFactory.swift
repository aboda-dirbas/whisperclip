import Foundation

@MainActor
class VoiceToTextFactory {
    static func createVoiceToText() -> VoiceToTextProtocol {
        return VoiceToTextModel.shared
    }
}
