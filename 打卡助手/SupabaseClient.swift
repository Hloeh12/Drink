import Foundation

// MARK: - Supabase 配置
// 在 Supabase Dashboard → Settings → API 获取以下值
// 填入后即可启用云同步

enum SupabaseConfig {
    /// Supabase 项目 URL，例如 https://xxxxx.supabase.co
    static let url = "https://phzemsnrglyeyhcswuqz.supabase.co"
    /// Supabase anon public key（公开密钥，不是 service role key）
    static let anonKey = "YOUR_ANON_KEY"
    /// 是否启用云同步（填入正确的 key 后自动启用）
    static var enabled: Bool {
        !url.contains("YOUR_PROJECT") && !anonKey.contains("YOUR_ANON")
    }
}

// MARK: - Supabase REST 客户端
// 使用 Supabase PostgREST API + Auth API
// 纯 URLSession 实现，不依赖第三方库

@MainActor
final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userId: String?
    @Published private(set) var userEmail: String?
    @Published var syncState: SyncState = .idle

    enum SyncState: Equatable {
        case idle
        case syncing
        case success
        case error(String)
    }

    private let session = URLSession.shared
    private let baseURL: String
    private let apiKey: String
    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "supabase_access_token")
    }

    private init() {
        baseURL = SupabaseConfig.url
        apiKey = SupabaseConfig.anonKey
        restoreSession()
    }

    // MARK: - Session 恢复

    private func restoreSession() {
        guard let token = UserDefaults.standard.string(forKey: "supabase_access_token"),
              let expires = UserDefaults.standard.object(forKey: "supabase_token_expires") as? Date,
              expires > Date() else {
            return
        }
        isAuthenticated = true
        userId = UserDefaults.standard.string(forKey: "supabase_user_id")
        userEmail = UserDefaults.standard.string(forKey: "supabase_user_email")
        _ = token
    }

    // MARK: - 邮箱注册

    func signUp(email: String, password: String) async throws {
        guard SupabaseConfig.enabled else { throw SupabaseError.notConfigured }

        let body: [String: Any] = ["email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "注册失败"
            throw SupabaseError.authFailed(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let accessToken = json["access_token"] as? String,
              let user = json["user"] as? [String: Any],
              let uid = user["id"] as? String else {
            // 注册成功但需要邮箱确认
            if json["user"] != nil {
                throw SupabaseError.emailConfirmationRequired
            }
            throw SupabaseError.parseError
        }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        saveSession(token: accessToken, uid: uid, email: email, expiresIn: expiresIn)
    }

    // MARK: - 邮箱登录

    func signIn(email: String, password: String) async throws {
        guard SupabaseConfig.enabled else { throw SupabaseError.notConfigured }

        let body: [String: Any] = ["email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "登录失败"
            throw SupabaseError.authFailed(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let accessToken = json["access_token"] as? String,
              let user = json["user"] as? [String: Any],
              let uid = user["id"] as? String else {
            throw SupabaseError.parseError
        }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        saveSession(token: accessToken, uid: uid, email: email, expiresIn: expiresIn)
    }

    // MARK: - 保存会话

    private func saveSession(token: String, uid: String, email: String, expiresIn: Int) {
        let expires = Date().addingTimeInterval(TimeInterval(expiresIn))
        UserDefaults.standard.set(token, forKey: "supabase_access_token")
        UserDefaults.standard.set(expires, forKey: "supabase_token_expires")
        UserDefaults.standard.set(uid, forKey: "supabase_user_id")
        UserDefaults.standard.set(email, forKey: "supabase_user_email")

        isAuthenticated = true
        userId = uid
        userEmail = email
    }

    // MARK: - 登出

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_token_expires")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        isAuthenticated = false
        userId = nil
        userEmail = nil
    }

    // MARK: - 数据库 CRUD

    func upsert(table: String, record: [String: Any]) async throws {
        guard SupabaseConfig.enabled else { throw SupabaseError.notConfigured }
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }

        let bodyData = try JSONSerialization.data(withJSONObject: record)
        let url = URL(string: "\(baseURL)/rest/v1/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = bodyData

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }

    func select(table: String) async throws -> [[String: Any]] {
        guard SupabaseConfig.enabled else { throw SupabaseError.notConfigured }
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }

        let urlString = "\(baseURL)/rest/v1/\(table)?select=*&order=created_at.desc&limit=1000"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SupabaseError.requestFailed
        }

        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }

    // MARK: - 存储上传（餐食照片）

    func uploadPhoto(data: Data, fileName: String) async throws -> String {
        guard SupabaseConfig.enabled else { throw SupabaseError.notConfigured }
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }

        let bucket = "meals"
        let path = "photos/\(fileName)"
        let url = URL(string: "\(baseURL)/storage/v1/object/\(bucket)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.uploadFailed
        }
        return "\(baseURL)/storage/v1/object/public/\(bucket)/\(path)"
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case authFailed(String)
    case emailConfirmationRequired
    case parseError
    case requestFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未配置，请先填入密钥"
        case .notAuthenticated: return "请先登录"
        case .authFailed(let msg): return "登录失败：\(msg)"
        case .emailConfirmationRequired: return "注册成功！请去邮箱确认后登录"
        case .parseError: return "数据解析失败"
        case .requestFailed: return "网络请求失败"
        case .uploadFailed: return "照片上传失败"
        }
    }
}
