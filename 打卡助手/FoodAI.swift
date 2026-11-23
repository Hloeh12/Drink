import Foundation
import UIKit

// MARK: - GitHub 设备登录 + Copilot AI 识别
// 流程：Device Flow 拿 OAuth token（自动含 copilot 权限）→ copilot_internal/v2/token
//       换短期 token → api.githubcopilot.com/chat/completions (vision)

enum FoodAI {

    // Device Flow 持久化的 OAuth token
    static var token: String {
        get { KeychainHelper.get("gh_oauth_token") ?? "" }
        set { KeychainHelper.set("gh_oauth_token", newValue) }
    }
    static var isConfigured: Bool { token.count > 20 }

    private static var cachedCopilotToken: (value: String, expires: Date)?

    // MARK: - Keychain 轻量封装
    enum KeychainHelper {
        static func set(_ key: String, _ value: String) {
            let data = Data(value.utf8)
            SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key
            ] as CFDictionary)
            SecItemAdd([
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecValueData: data
            ] as CFDictionary, nil)
        }
        static func get(_ key: String) -> String? {
            var query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ] as CFDictionary
            var out: AnyObject?
            guard SecItemCopyMatching(query, &out) == errSecSuccess,
                  let d = out as? Data else { return nil }
            return String(data: d, encoding: .utf8)
        }
        static func remove(_ key: String) {
            SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key
            ] as CFDictionary)
        }
    }

    // MARK: - Device Flow

    struct DeviceFlowStart {
        let deviceCode: String
        let userCode: String
        let verifyURI: String
        let interval: Double
    }

    /// 第一步：请求设备码
    static func startDeviceFlow() async throws -> DeviceFlowStart {
        var req = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // Copilot 官方客户端 ID
        req.httpBody = "client_id=Iv1.b507a08c87ecfe98&scope=copilot".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dc = obj["device_code"] as? String,
              let uc = obj["user_code"] as? String else {
            throw AIError.deviceFlowFailed("无法获取设备码，请检查网络")
        }
        let uri = (obj["verification_uri"] as? String) ?? "https://github.com/login/device"
        let interval = (obj["interval"] as? Int).map { Double($0) } ?? 5.0
        return DeviceFlowStart(deviceCode: dc, userCode: uc, verifyURI: uri, interval: interval)
    }

    /// 第二步：轮询等待用户授权
    static func pollDeviceFlow(_ start: DeviceFlowStart) async throws {
        let deadline = Date().addingTimeInterval(600) // 最多等 10 分钟
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(start.interval * 1_000_000_000))
            var req = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = """
            client_id=Iv1.b507a08c87ecfe98&device_code=\(start.deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code
            """.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let at = obj["access_token"] as? String {
                token = at
                cachedCopilotToken = nil
                return
            }
            if let err = obj["error"] as? String {
                if err == "authorization_pending" || err == "slow_down" { continue }
                throw AIError.deviceFlowFailed("授权失败：\(err)")
            }
        }
        throw AIError.deviceFlowFailed("授权超时，请重试")
    }

    /// 第三步：用 OAuth token 换 Copilot 短期 token
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
        req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Plugin-Version")
        req.setValue("copilot-chat/0.20.0", forHTTPHeaderField: "Copilot-Integration-Id")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = obj["token"] as? String else {
            token = ""
            throw AIError.authFailed
        }
        let exp = (obj["expires_at"] as? Int).map { Date(timeIntervalSince1970: TimeInterval($0)) }
            ?? Date().addingTimeInterval(1500)
        cachedCopilotToken = (t, exp)
        return t
    }

    /// 识别食物照片，返回 (食物描述, 总热量)
    static func recognizeFood(image: UIImage) async throws -> (items: String, calories: Int) {
        guard isConfigured else { throw AIError.notConfigured }
        let ct = try await copilotToken()

        guard let jpeg = image.jpegData(compressionQuality: 0.55) else { throw AIError.imageError }
        // 缩到最大 512px 减小流量
        if let resized = resize(image, maxSide: 512), let small = resized.jpegData(compressionQuality: 0.5) {
            return try await callVision(jpegData: small, copilotToken: ct)
        }
        return try await callVision(jpegData: jpeg, copilotToken: ct)
    }

    private static func callVision(jpegData: Data, copilotToken ct: String) async throws -> (items: String, calories: Int) {
        let b64 = jpegData.base64EncodedString()

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "你是营养师。识别图片中的食物和饮品，只输出 JSON：{\"items\":\"食物名列表，顿号分隔\",\"calories\":总千卡数字}。不要输出其他任何文字。"
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "识别这餐的食物和总热量"],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
                    ]
                ]
            ],
            "max_tokens": 300
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AIError.requestError
        }

        // 免费版账号走 individual 域名，通用域名做备选
        let endpoints = [
            "https://api.individual.githubcopilot.com/chat/completions",
            "https://api.githubcopilot.com/chat/completions"
        ]

        var lastStatus = 0
        for ep in endpoints {
            guard let url = URL(string: ep) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("Bearer \(ct)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Visual Studio Code", forHTTPHeaderField: "Editor-Version")
            req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Plugin-Version")
            req.setValue("copilot-chat/0.20.0", forHTTPHeaderField: "Copilot-Integration-Id")
            req.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw AIError.requestError }
            lastStatus = http.statusCode
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 { cachedCopilotToken = nil }
                continue // 换下一个端点
            }
            return try parseVisionResponse(data)
        }
        throw AIError.requestFailed("服务返回 \(lastStatus)，请稍后重试")
    }

    private static func parseVisionResponse(_ data: Data) throws -> (items: String, calories: Int) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw AIError.parseFailed
        }

        // 从回复中提取 JSON
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let items = result["items"] as? String else {
            // 兜底：把整段文字当描述
            return (String(content.prefix(80)), 0)
        }
        let cal = (result["calories"] as? Int)
            ?? (result["calories"] as? Double).map { Int($0) }
            ?? 0
        return (items, cal)
    }

    private static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage? {
        let size = image.size
        let longest = Swift.max(size.width, size.height)
        guard longest > maxSide else { return nil }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out
    }

    /// 退出登录
    static func logout() {
        KeychainHelper.remove("gh_oauth_token")
        cachedCopilotToken = nil
    }

    /// 供设置页测试连通性
    static func copilotTokenForTest() async throws -> String {
        try await copilotToken()
    }

    enum AIError: LocalizedError {
        case notConfigured, badURL, imageError, authFailed, parseFailed, requestError
        case deviceFlowFailed(String)
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "尚未登录 GitHub，请先在我的页面完成设备授权"
            case .badURL: return "网络地址错误"
            case .imageError: return "图片处理失败"
            case .authFailed: return "授权已过期，请重新登录"
            case .parseFailed: return "AI 返回格式异常，请重试"
            case .requestError: return "请求构建失败"
            case .deviceFlowFailed(let m): return m
            case .requestFailed(let m): return m
            }
        }
    }
}
