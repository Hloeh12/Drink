import Foundation
import UIKit

// MARK: - Copilot AI 识别服务
// 使用 GitHub Copilot 的 OpenAI 兼容接口做食物图像识别
// 流程：GitHub token -> copilot_internal/v2/token 换短期 token -> chat/completions (vision)

enum FoodAI {

    static var token: String {
        get { UserDefaults.standard.string(forKey: "gh_pat_for_ai") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "gh_pat_for_ai") }
    }
    static var isConfigured: Bool { token.contains("ghp_") || token.contains("github_pat_") || token.count > 20 }

    private static var cachedCopilotToken: (value: String, expires: Date)?

    /// 用 GitHub token 换取 Copilot API 短期 token
    private static func copilotToken() async throws -> String {
        if let c = cachedCopilotToken, c.expires > Date().addingTimeInterval(120) {
            return c.value
        }
        guard let url = URL(string: "https://api.github.com/copilot_internal/v2/token") else {
            throw AIError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("Visual Studio Code", forHTTPHeaderField: "Editor-Version")
        req.setValue(" vscode/1.95.0", forHTTPHeaderField: "Editor-Plugin-Version".trimmingCharacters(in: .whitespaces))
        req.setValue("copilot-chat/0.20.0", forHTTPHeaderField: "Copilot-Integration-Id")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = obj["token"] as? String else {
            throw AIError.authFailed
        }
        let exp = (obj["expires_at"] as? Int).map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date().addingTimeInterval(1500)
        cachedCopilotToken = (t, exp)
        return t
    }

    /// 识别食物照片，返回 (食物描述, 总热量)
    static func recognizeFood(image: UIImage) async throws -> (items: String, calories: Int) {
        let ct = try await copilotToken()

        guard let jpeg = image.jpegData(compressionQuality: 0.55) else { throw AIError.imageError }
        // 压到合理大小
        var data = jpeg
        var quality = 0.55
        while data.count > 900_000 && quality > 0.15 {
            quality -= 0.15
            data = image.jpegData(compressionQuality: quality) ?? data
        }
        let b64 = data.base64EncodedString()

        let prompt = """
        你是营养估算助手。识别照片中的食物和饮品，估算总热量。
        只返回 JSON，格式：{"items":"食物描述，用顿号分隔","calories":整数千卡}
        估算原则：按照片中可见份量估计；饮料也估算。不要输出其他内容。
        """

        let body: [String: Any] = [
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
                    ]
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.2
        ]

        guard let url = URL(string: "https://api.githubcopilot.com/chat/completions") else { throw AIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(ct)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Visual Studio Code", forHTTPHeaderField: "Editor-Version")
        req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Plugin-Version")
        req.setValue("copilot-chat/0.20.0", forHTTPHeaderField: "Copilot-Integration-Id")
        req.setValue("2024-10-01", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data2, response2) = try await URLSession.shared.data(for: req)
        guard let http = response2 as? HTTPURLResponse else { throw AIError.requestFailed }
        guard (200..<300).contains(http.statusCode) else { throw AIError.requestFailed }

        guard let obj = try? JSONSerialization.jsonObject(with: data2) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { throw AIError.parseError }

        // 解析 JSON（容错：截取第一个 { 到最后一个 }）
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"),
              let parsed = try? JSONSerialization.jsonObject(with: Data(content[start...end].utf8)) as? [String: Any],
              let items = parsed["items"] as? String,
              let cal = parsed["calories"] as? Int else { throw AIError.parseError }

        return (items, cal)
    }

    enum AIError: LocalizedError {
        case badURL, authFailed, imageError, requestFailed, parseError
        var errorDescription: String? {
            switch self {
            case .badURL: return "接口地址错误"
            case .authFailed: return "Token 无效或 Copilot 未开通，请在「我的」页检查"
            case .imageError: return "照片处理失败"
            case .requestFailed: return "网络请求失败，请重试"
            case .parseError: return "识别结果解析失败，请重试"
            }
        }
    }
}

// MARK: - 照片选择器（拍照 + 相册）

import PhotosUI
import SwiftUI

struct FoodPhotoPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            item.loadObject(ofClass: UIImage.self) { [onImage] obj, _ in
                if let img = obj as? UIImage {
                    DispatchQueue.main.async { onImage(img) }
                }
            }
        }
    }
}
