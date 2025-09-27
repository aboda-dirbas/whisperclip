import Foundation
import WhisperKit

class LocalWhisperKit {
    static func loadModel(modelRepo: String, modelName: String) async throws -> WhisperKit {
        Logger.log("Loading WhisperKit model", log: Logger.general)
        let modelPath = try await ModelStorage.shared.getModelPath(modelRepo: modelRepo, modelName: modelName)

        Logger.log("Loading WhisperKit model from \(modelPath.path)", log: Logger.general)
        let pipe = try await WhisperKit(WhisperKitConfig(
            model: modelName,
            modelFolder: modelPath.path,
            prewarm: true
        ))
        Logger.log("WhisperKit model loaded", log: Logger.general)
        return pipe
    }
}

