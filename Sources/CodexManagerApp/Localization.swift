import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case chinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        }
    }
}

struct Strings {
    var language: AppLanguage

    func text(_ key: Key) -> String {
        switch language {
        case .english:
            return key.english
        case .chinese:
            return key.chinese
        }
    }

    enum Key {
        case appTitle
        case noActiveAccount
        case noActiveSubtitle
        case accounts
        case noManagedAccounts
        case noManagedSubtitle
        case addAccount
        case importCurrent
        case officialUsage
        case browserUsage
        case browserUsageExplanation
        case settings
        case quit
        case refreshUsage
        case switchAccount
        case notVerified
        case noEmail
        case usageNotRefreshed
        case credits
        case unlimited
        case primary
        case secondary
        case remainingQuota
        case localEstimate
        case tokens
        case threads
        case language
        case preferences
        case appearance
        case accountManagement
        case displayName
        case saveName
        case refresh
        case switchTitle
        case email
        case plan
        case profileID
        case codexHome
        case lastRefresh
        case deleteLocalProfile
        case dataLocation
        case usageExplanationTitle
        case creditsExplanation
        case primaryExplanation
        case secondaryExplanation
        case localEstimateExplanation
        case addAccountTitle
        case addAccountDescription
        case signInWithChatGPT
        case switchAfterAdding
        case accountAlreadyManaged
        case addedAccountMessage
        case startingLogin
        case code
        case copyCode
        case copiedCode
        case finishSignInTitle
        case finishSignInDescription
        case openVerificationPage
        case waitingForLogin
        case savingAccount
        case tryAgain
        case cancel
        case done
        case deleteConfirmTitle
        case deleteConfirmBody
        case deleteButton
        case switchConfirmTitle
        case switchConfirmBodyDesktop
        case switchConfirmBodyTerminal
        case restartAndSwitch

        var english: String {
            switch self {
            case .appTitle: "Codex Manager"
            case .noActiveAccount: "No active account"
            case .noActiveSubtitle: "Import your current Codex login or add a new ChatGPT account."
            case .accounts: "Accounts"
            case .noManagedAccounts: "No managed accounts"
            case .noManagedSubtitle: "Use the plus button to add an isolated Codex profile."
            case .addAccount: "Add account"
            case .importCurrent: "Import Current"
            case .officialUsage: "Usage"
            case .browserUsage: "Browser"
            case .browserUsageExplanation: "Browser usage depends on whichever ChatGPT account is currently signed in on chatgpt.com. It may not match this Codex profile."
            case .settings: "Settings"
            case .quit: "Quit"
            case .refreshUsage: "Refresh usage"
            case .switchAccount: "Switch account"
            case .notVerified: "Not verified"
            case .noEmail: "No email"
            case .usageNotRefreshed: "Usage not refreshed"
            case .credits: "Credits"
            case .unlimited: "Unlimited"
            case .primary: "Primary"
            case .secondary: "Secondary"
            case .remainingQuota: "Remaining quota"
            case .localEstimate: "Local estimate"
            case .tokens: "tokens"
            case .threads: "threads"
            case .language: "Language"
            case .preferences: "Preferences"
            case .appearance: "Appearance"
            case .accountManagement: "Account Management"
            case .displayName: "Display name"
            case .saveName: "Save Name"
            case .refresh: "Refresh Usage"
            case .switchTitle: "Switch"
            case .email: "Email"
            case .plan: "Plan"
            case .profileID: "Profile ID"
            case .codexHome: "Codex Home"
            case .lastRefresh: "Last Refresh"
            case .deleteLocalProfile: "Delete Local Profile"
            case .dataLocation: "Data Location"
            case .usageExplanationTitle: "What These Numbers Mean"
            case .creditsExplanation: "Credits are extra Codex credits reported by Codex. A balance of 0 means no extra credits are available."
            case .primaryExplanation: "Primary is the short remaining-quota window from Codex, usually the near-term limit window."
            case .secondaryExplanation: "Secondary is the longer remaining-quota window from Codex, usually the weekly or multi-day window."
            case .localEstimateExplanation: "Local estimate reads tokens from this Mac's Codex SQLite database. It is not the official remaining quota."
            case .addAccountTitle: "Add Account"
            case .addAccountDescription: "You need to use a ChatGPT account to sign in."
            case .signInWithChatGPT: "Sign In"
            case .switchAfterAdding: "Switch after adding"
            case .accountAlreadyManaged: "This account already exists. The existing account was updated."
            case .addedAccountMessage: "Account added successfully."
            case .startingLogin: "Starting Codex login..."
            case .code: "Code"
            case .copyCode: "Copy code"
            case .copiedCode: "Copied"
            case .finishSignInTitle: "Finish sign in"
            case .finishSignInDescription: "Use this code on the verification page, then return here. This window will stay open while Codex completes login."
            case .openVerificationPage: "Open verification page"
            case .waitingForLogin: "Waiting for login..."
            case .savingAccount: "Saving account..."
            case .tryAgain: "Try Again"
            case .cancel: "Cancel"
            case .done: "Done"
            case .deleteConfirmTitle: "Delete local profile?"
            case .deleteConfirmBody: "This removes the local managed profile. It does not delete the ChatGPT account."
            case .deleteButton: "Delete"
            case .switchConfirmTitle: "Switch Codex account?"
            case .switchConfirmBodyDesktop: "Codex is running and will be restarted after switching."
            case .switchConfirmBodyTerminal: "Codex is running. Desktop Codex can be restarted automatically; terminal sessions should be restarted after switching."
            case .restartAndSwitch: "Restart Codex and Switch"
            }
        }

        var chinese: String {
            switch self {
            case .appTitle: "Codex 管理器"
            case .noActiveAccount: "没有当前账号"
            case .noActiveSubtitle: "导入当前 Codex 登录，或添加一个新的 ChatGPT 账号。"
            case .accounts: "账号"
            case .noManagedAccounts: "还没有托管账号"
            case .noManagedSubtitle: "点击加号添加一个隔离的 Codex 账号档案。"
            case .addAccount: "添加账号"
            case .importCurrent: "导入当前"
            case .officialUsage: "用量"
            case .browserUsage: "浏览器"
            case .browserUsageExplanation: "浏览器里的用量取决于 chatgpt.com 当前登录的是哪个账号，可能和这个 Codex 档案不一致。"
            case .settings: "设置"
            case .quit: "退出"
            case .refreshUsage: "刷新用量"
            case .switchAccount: "切换账号"
            case .notVerified: "未验证"
            case .noEmail: "没有邮箱"
            case .usageNotRefreshed: "尚未刷新用量"
            case .credits: "额度"
            case .unlimited: "不限量"
            case .primary: "短周期"
            case .secondary: "长周期"
            case .remainingQuota: "剩余额度"
            case .localEstimate: "本机估算"
            case .tokens: "tokens"
            case .threads: "会话"
            case .language: "语言"
            case .preferences: "偏好设置"
            case .appearance: "外观"
            case .accountManagement: "账号管理"
            case .displayName: "显示名称"
            case .saveName: "保存名称"
            case .refresh: "刷新用量"
            case .switchTitle: "切换"
            case .email: "邮箱"
            case .plan: "套餐"
            case .profileID: "档案 ID"
            case .codexHome: "Codex 目录"
            case .lastRefresh: "上次刷新"
            case .deleteLocalProfile: "删除本地档案"
            case .dataLocation: "数据位置"
            case .usageExplanationTitle: "这些数字是什么意思"
            case .creditsExplanation: "额度是 Codex 返回的额外 credits。显示 0 代表当前没有额外 credits。"
            case .primaryExplanation: "短周期是 Codex 返回的近期限额窗口，这里显示的是该窗口的剩余额度。"
            case .secondaryExplanation: "长周期是 Codex 返回的更长限额窗口，这里显示的是该窗口的剩余额度。"
            case .localEstimateExplanation: "本机估算来自这台 Mac 的 Codex SQLite 数据库，不等于官方剩余额度。"
            case .addAccountTitle: "添加账号"
            case .addAccountDescription: "你需要使用 ChatGPT 账号来进行登录。"
            case .signInWithChatGPT: "登录"
            case .switchAfterAdding: "添加后立即切换"
            case .accountAlreadyManaged: "该账号已存在，已更新现有账号。"
            case .addedAccountMessage: "账号添加成功。"
            case .startingLogin: "正在启动 Codex 登录..."
            case .code: "验证码"
            case .copyCode: "复制验证码"
            case .copiedCode: "已复制"
            case .finishSignInTitle: "完成登录"
            case .finishSignInDescription: "在验证页面输入这个验证码，然后回到这里。这个窗口会保持打开，直到 Codex 完成登录。"
            case .openVerificationPage: "打开验证页面"
            case .waitingForLogin: "等待登录完成..."
            case .savingAccount: "正在保存账号..."
            case .tryAgain: "重试"
            case .cancel: "取消"
            case .done: "完成"
            case .deleteConfirmTitle: "删除本地档案？"
            case .deleteConfirmBody: "这只会删除本机托管档案，不会删除 ChatGPT 账号。"
            case .deleteButton: "删除"
            case .switchConfirmTitle: "切换 Codex 账号？"
            case .switchConfirmBodyDesktop: "Codex 正在运行，切换后会自动重启桌面端。"
            case .switchConfirmBodyTerminal: "Codex 正在运行。桌面端可以自动重启，终端会话需要你切换后手动重开。"
            case .restartAndSwitch: "重启 Codex 并切换"
            }
        }
    }
}
