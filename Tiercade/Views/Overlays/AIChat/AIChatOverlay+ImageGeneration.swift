import SwiftUI

#if canImport(ImagePlayground)
import ImagePlayground
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

extension AIChatOverlay {
    @available(iOS 18.4, macOS 15.4, *)
    func performImageGeneration(prompt: String) async {
        #if canImport(ImagePlayground)
        do {
            logImageGenerationStart(prompt: prompt)
            let creator = try await ImageCreator()

            guard let style = creator.availableStyles.first else {
                app.showErrorToast("No Styles", message: "No image generation styles available")
                return
            }

            let imageGenerated = try await generateAndConvertImage(creator: creator, prompt: prompt, style: style)

            if imageGenerated {
                showImagePreview = true
            } else {
                app.showErrorToast("Generation Failed", message: "No image was generated")
            }
        } catch let error as ImageCreator.Error {
            handleImageCreationError(error)
        } catch {
            handleUnexpectedImageError(error)
        }
        #endif
    }
}

#if canImport(ImagePlayground)
extension AIChatOverlay {
    @available(iOS 18.4, macOS 15.4, *)
    func logImageGenerationStart(prompt: String) {
        let currentLocale = Locale.current
        print("🎨 [Image] Starting generation for: \(prompt)")
        print("🎨 [Image] Current locale: \(currentLocale.identifier)")
        print("🎨 [Image] Language: \(currentLocale.language.languageCode?.identifier ?? "unknown")")
        print("🎨 [Image] Region: \(currentLocale.region?.identifier ?? "unknown")")
    }

    @available(iOS 18.4, macOS 15.4, *)
    func generateAndConvertImage(
        creator: ImageCreator,
        prompt: String,
        style: ImagePlaygroundStyle
    ) async throws -> Bool {
        let concepts = [ImagePlaygroundConcept.text(prompt)]
        var imageGenerated = false

        for try await createdImage in creator.images(for: concepts, style: style, limit: 1) {
            print("🎨 [Image] Image generated successfully")
            let cgImage = createdImage.cgImage

            #if os(macOS) && !targetEnvironment(macCatalyst)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            generatedImage = Image(nsImage: nsImage)
            imageGenerated = true
            #elseif os(iOS) || targetEnvironment(macCatalyst)
            let uiImage = UIImage(cgImage: cgImage)
            generatedImage = Image(uiImage: uiImage)
            imageGenerated = true
            #endif
            break // Only take first image
        }

        return imageGenerated
    }

    @available(iOS 18.4, macOS 15.4, *)
    func handleImageCreationError(_ error: ImageCreator.Error) {
        print("🎨 [Image] Error: \(error)")
        let message = buildImageErrorMessage(error)
        app.showErrorToast("Generation Failed", message: message)
    }

    @available(iOS 18.4, macOS 15.4, *)
    func buildImageErrorMessage(_ error: ImageCreator.Error) -> String {
        switch error {
        case .notSupported:
            return "Image generation is not supported on this device"
        case .unavailable:
            return "Image generation is currently unavailable"
        case .unsupportedLanguage:
            let locale = Locale.current
            let languageCode = locale.language.languageCode?.identifier ?? "unknown"
            let regionCode = locale.region?.identifier ?? "unknown"
            let localeInfo = "\(languageCode)-\(regionCode)"
            return """
            Unsupported locale: \(localeInfo)

            ImagePlayground requires English (US, UK, CA, AU, NZ, IE, or ZA).
            Check System Settings > General > Language & Region.
            """
        case .creationFailed:
            return "Image generation failed. Try a different prompt."
        case .backgroundCreationForbidden:
            return "App must be in foreground to generate images"
        default:
            return "Image generation failed: \(error.localizedDescription)"
        }
    }

    @available(iOS 18.4, macOS 15.4, *)
    func handleUnexpectedImageError(_ error: Error) {
        print("🎨 [Image] Unexpected error: \(error)")
        app.showErrorToast("Error", message: "Unexpected error: \(error.localizedDescription)")
    }
}
#endif
