import Foundation

/// Every user-visible string. Add a case here and a row in `L10n.table`; the tests fail if a
/// language is missing or the format arguments differ between languages.
public enum L: String, CaseIterable, Sendable {
    // Popover state
    case titleHolding, titleWaiting, titleOff, titlePaused
    case reasonAgents, reasonGrace, reasonAlways, reasonTimer, reasonNoAgents, reasonOff
    case reasonTimerDone, reasonBattery, reasonOnBattery, reasonThermal, reasonIdle
    case lidCanClose, lidClosedNow, lidWillSleep, lidNoPermission, allowLidMode, allowLidModeHint
    case sleepDisabledOutside
    case modeAuto, modeAlways, modeTimer
    case modeAutoHint, modeAlwaysHint, modeTimerHint
    case agents, noAgents, noAgentsHint, working, idle, sessionsCount
    case statsToday, settingsButton, quit, toggleHint
    // Settings
    case tabGeneral, tabAgents, tabSafety, tabAbout
    case language, languageSystem, launchAtLogin, globalShortcut, globalShortcutHint
    case keepDisplayOn, displayOffOnLidClose, displayOffOnLidCloseHint
    case notifications, notifyFinished, notifyReleased, notifyLidSummary, playSound
    case watchedAgents, watchedAgentsHint, customCommands, customCommandsHint, customPlaceholder, add, remove
    case autoMode, graceAfterLast, idleRelease, idleReleaseAfter, idleReleaseHint, minutesShort
    case batteryFloor, batteryFloorHint, requireCharger, requireChargerHint, thermalGuard, thermalGuardHint
    case helperRule, helperInstalled, helperMissing, helperInstall, helperRemove, helperHint
    case emergency, restoreSleepNow, restoreSleepHint, currentSetting, settingOn, settingOff
    case aboutTagline, aboutVersion, aboutSource, aboutLidTotal, clearHistory
    case adminPrompt, adminRemovePrompt
    // Onboarding
    case onboardingTitle, onboardingPoint1, onboardingPoint2, onboardingPoint3, notNow
    // Notifications
    case notifFinishedTitle, notifFinishedBody, notifReleasedTitle, notifLidTitle, notifLidBody, notifLidBodyNone
    // Units
    case unitHour, unitMinute, unitSecond
}

public enum L10n {
    /// Forces a language, for screenshots.
    nonisolated(unsafe) public static var override: AppLanguage?
    public static var language: AppLanguage { override ?? AppSettings.shared.language.resolved }

    public static func t(_ key: L, _ args: CVarArg...) -> String {
        format(key, language: language, args)
    }

    public static func format(_ key: L, language: AppLanguage, _ args: [CVarArg]) -> String {
        let template = string(key, language: language)
        return args.isEmpty ? template : String(format: template, locale: locale(for: language), arguments: args)
    }

    public static func string(_ key: L, language: AppLanguage) -> String {
        guard let row = table[key] else { return key.rawValue }
        switch language.resolved {
        case .ru: return row.ru
        case .uk: return row.uk
        default: return row.en
        }
    }

    static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language.resolved == .system ? "en" : language.resolved.rawValue)
    }

    /// "1 h 12 min", "42 min", "30 s" in the current language.
    public static func duration(_ seconds: TimeInterval, language: AppLanguage? = nil) -> String {
        let lang = language ?? self.language
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        let H = string(.unitHour, language: lang), M = string(.unitMinute, language: lang), S = string(.unitSecond, language: lang)
        if h > 0 { return m > 0 ? "\(h) \(H) \(m) \(M)" : "\(h) \(H)" }
        if m > 0 { return "\(m) \(M)" }
        return "\(s) \(S)"
    }

    /// "1:24:05" or "24:05" for a countdown.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    typealias Row = (en: String, ru: String, uk: String)

    static let table: [L: Row] = [
        .titleHolding: ("Staying awake", "Не засыпает", "Не засинає"),
        .titleWaiting: ("Waiting for agents", "Ждёт агентов", "Чекає на агентів"),
        .titleOff: ("Sleeps as usual", "Спит как обычно", "Спить як зазвичай"),
        .titlePaused: ("Paused", "На паузе", "На паузі"),

        .reasonAgents: ("Running: %@", "Работает: %@", "Працює: %@"),
        .reasonGrace: ("Agents are done. Sleep in %@", "Агенты закончили. Сон через %@", "Агенти завершили. Сон через %@"),
        .reasonAlways: ("Until you turn it off", "Пока не выключите", "Доки не вимкнете"),
        .reasonTimer: ("%@ left", "Осталось %@", "Лишилося %@"),
        .reasonNoAgents: ("Turns on when an agent starts", "Включится, когда запустится агент", "Увімкнеться, коли запуститься агент"),
        .reasonOff: ("Turn on before you close the lid", "Включите, прежде чем закрыть крышку", "Увімкніть, перш ніж закрити кришку"),
        .reasonTimerDone: ("Timer finished", "Таймер закончился", "Таймер скінчився"),
        .reasonBattery: ("Battery at %d%%, below your limit", "Батарея %d%%, ниже порога", "Батарея %d%%, нижче порогу"),
        .reasonOnBattery: ("On battery. Plug in to continue", "Работает от батареи. Подключите зарядку", "Працює від батареї. Під’єднайте зарядку"),
        .reasonThermal: ("The Mac is too hot. Sleep allowed", "Mac перегрелся. Сон разрешён", "Mac перегрівся. Сон дозволено"),
        .reasonIdle: ("Agents idle for %@. Sleep allowed", "Агенты простаивают %@. Сон разрешён", "Агенти простоюють %@. Сон дозволено"),

        .lidCanClose: ("You can close the lid", "Крышку можно закрыть", "Кришку можна закрити"),
        .lidClosedNow: ("Lid closed, still running", "Крышка закрыта, всё работает", "Кришка закрита, усе працює"),
        .lidWillSleep: ("Closing the lid puts the Mac to sleep", "Если закрыть крышку, Mac уснёт", "Якщо закрити кришку, Mac засне"),
        .lidNoPermission: ("Closing the lid will still put the Mac to sleep", "С закрытой крышкой Mac всё равно уснёт", "Із закритою кришкою Mac однаково засне"),
        .allowLidMode: ("Allow lid-closed mode", "Разрешить работу с закрытой крышкой", "Дозволити роботу із закритою кришкою"),
        .allowLidModeHint: ("One administrator prompt. It allows only pmset disablesleep on and off.",
                            "Один запрос пароля администратора. Разрешается только pmset disablesleep: вкл. и выкл.",
                            "Один запит пароля адміністратора. Дозволяється лише pmset disablesleep: увімк. і вимк."),
        .sleepDisabledOutside: ("Sleep is turned off outside Vibecode24. The app leaves it as is.",
                                "Сон выключен не через Vibecode24. Приложение его не трогает.",
                                "Сон вимкнено не через Vibecode24. Застосунок його не чіпає."),

        .modeAuto: ("Auto", "Авто", "Авто"),
        .modeAlways: ("Always", "Всегда", "Завжди"),
        .modeTimer: ("Timer", "Таймер", "Таймер"),
        .modeAutoHint: ("Awake while agents run", "Не спит, пока работают агенты", "Не спить, доки працюють агенти"),
        .modeAlwaysHint: ("Awake until you turn it off", "Не спит, пока не выключите", "Не спить, доки не вимкнете"),
        .modeTimerHint: ("Awake for a set time", "Не спит заданное время", "Не спить заданий час"),

        .agents: ("Agents", "Агенты", "Агенти"),
        .noAgents: ("No agents running", "Агенты не запущены", "Агенти не запущені"),
        .noAgentsHint: ("Start claude, codex or another agent in a terminal.",
                        "Запустите claude, codex или другого агента в терминале.",
                        "Запустіть claude, codex або іншого агента в терміналі."),
        .working: ("working", "работает", "працює"),
        .idle: ("idle", "ждёт", "чекає"),
        .sessionsCount: ("%d sessions", "сессий: %d", "сесій: %d"),
        .statsToday: ("Today %@ awake, %@ with the lid closed", "Сегодня %@ без сна, %@ с закрытой крышкой", "Сьогодні %@ без сну, %@ із закритою кришкою"),
        .settingsButton: ("Settings…", "Настройки…", "Налаштування…"),
        .quit: ("Quit", "Выйти", "Вийти"),
        .toggleHint: ("Keep the Mac awake", "Не давать Mac уснуть", "Не давати Mac заснути"),

        .tabGeneral: ("General", "Основные", "Загальні"),
        .tabAgents: ("Agents", "Агенты", "Агенти"),
        .tabSafety: ("Safety", "Защита", "Захист"),
        .tabAbout: ("About", "О программе", "Про застосунок"),

        .language: ("Language", "Язык", "Мова"),
        .languageSystem: ("System", "Как в системе", "Як у системі"),
        .launchAtLogin: ("Open at login", "Открывать при входе", "Відкривати під час входу"),
        .globalShortcut: ("Toggle with ⌃⌥⌘A", "Переключать по ⌃⌥⌘A", "Перемикати через ⌃⌥⌘A"),
        .globalShortcutHint: ("Works from any app.", "Работает из любого приложения.", "Працює з будь-якого застосунку."),
        .keepDisplayOn: ("Keep the display on while awake", "Не гасить экран, пока Mac не спит", "Не вимикати екран, доки Mac не спить"),
        .displayOffOnLidClose: ("Turn the display off when the lid closes", "Гасить экран, когда закрывается крышка", "Вимикати екран, коли закривається кришка"),
        .displayOffOnLidCloseHint: ("Also locks the Mac if your password is required right away.",
                                    "Заодно блокирует Mac, если пароль требуется сразу.",
                                    "Заразом блокує Mac, якщо пароль потрібен одразу."),
        .notifications: ("Notifications", "Уведомления", "Сповіщення"),
        .notifyFinished: ("When an agent finishes", "Когда агент закончил", "Коли агент завершив"),
        .notifyReleased: ("When sleep comes back", "Когда сон снова включён", "Коли сон знову ввімкнено"),
        .notifyLidSummary: ("Summary when you open the lid", "Сводка, когда открываете крышку", "Підсумок, коли відкриваєте кришку"),
        .playSound: ("Play a sound", "Со звуком", "Зі звуком"),

        .watchedAgents: ("Watched agents", "Отслеживаемые агенты", "Агенти, за якими стежить"),
        .watchedAgentsHint: ("Auto mode keeps the Mac awake while any of these run.",
                             "В режиме «Авто» Mac не спит, пока работает любой из них.",
                             "У режимі «Авто» Mac не спить, доки працює будь-який із них."),
        .customCommands: ("Your commands", "Свои команды", "Власні команди"),
        .customCommandsHint: ("The process name as ps shows it, e.g. my-agent.",
                              "Имя процесса, как его показывает ps, например my-agent.",
                              "Ім’я процесу, як його показує ps, наприклад my-agent."),
        .customPlaceholder: ("process name", "имя процесса", "ім’я процесу"),
        .add: ("Add", "Добавить", "Додати"),
        .remove: ("Remove", "Удалить", "Видалити"),
        .autoMode: ("Auto mode", "Режим «Авто»", "Режим «Авто»"),
        .graceAfterLast: ("Wait after the last agent stops", "Ждать после последнего агента", "Чекати після останнього агента"),
        .idleRelease: ("Allow sleep when agents are idle", "Разрешать сон, если агенты простаивают", "Дозволяти сон, якщо агенти простоюють"),
        .idleReleaseAfter: ("Idle for", "Простой дольше", "Простій довше"),
        .idleReleaseHint: ("Idle means under 3% CPU for the agent and everything it started. An agent waiting on a slow model can look idle.",
                           "Простой: меньше 3% CPU у агента и всего, что он запустил. Агент, который ждёт медленную модель, тоже может выглядеть простаивающим.",
                           "Простій: менше 3% CPU в агента й усього, що він запустив. Агент, який чекає на повільну модель, теж може виглядати як простій."),
        .minutesShort: ("%d min", "%d мин", "%d хв"),

        .batteryFloor: ("Allow sleep below", "Разрешать сон ниже", "Дозволяти сон нижче"),
        .batteryFloorHint: ("On battery only. Plugging in lifts the limit.",
                            "Только от батареи. С зарядкой порог не действует.",
                            "Лише від батареї. Із зарядкою поріг не діє."),
        .requireCharger: ("Only when connected to power", "Только при подключённой зарядке", "Лише з під’єднаною зарядкою"),
        .requireChargerHint: ("Safest for a closed lid in a bag.", "Безопаснее всего, если Mac лежит в сумке.", "Найбезпечніше, якщо Mac лежить у сумці."),
        .thermalGuard: ("Allow sleep when the Mac overheats", "Разрешать сон при перегреве", "Дозволяти сон у разі перегріву"),
        .thermalGuardHint: ("Uses the macOS thermal state. With the lid closed there is less airflow.",
                            "По тепловому состоянию macOS. С закрытой крышкой охлаждение хуже.",
                            "За тепловим станом macOS. Із закритою кришкою охолодження гірше."),
        .helperRule: ("Lid-closed permission", "Разрешение для закрытой крышки", "Дозвіл для закритої кришки"),
        .helperInstalled: ("Installed", "Установлено", "Встановлено"),
        .helperMissing: ("Not installed", "Не установлено", "Не встановлено"),
        .helperInstall: ("Install…", "Установить…", "Встановити…"),
        .helperRemove: ("Remove…", "Удалить…", "Видалити…"),
        .helperHint: ("A sudoers rule that allows your user to run exactly these two commands without a password:",
                      "Правило sudoers, которое разрешает вашему пользователю запускать без пароля ровно эти две команды:",
                      "Правило sudoers, яке дозволяє вашому користувачу запускати без пароля рівно ці дві команди:"),
        .emergency: ("Emergency", "Если что-то пошло не так", "Якщо щось пішло не так"),
        .restoreSleepNow: ("Restore sleep now", "Вернуть сон сейчас", "Повернути сон зараз"),
        .restoreSleepHint: ("Runs pmset -a disablesleep 0. Same as the Terminal command:",
                            "Выполняет pmset -a disablesleep 0. То же, что команда в Терминале:",
                            "Виконує pmset -a disablesleep 0. Те саме, що команда в Терміналі:"),
        .currentSetting: ("SleepDisabled right now", "SleepDisabled сейчас", "SleepDisabled зараз"),
        .settingOn: ("on", "включён", "увімкнено"),
        .settingOff: ("off", "выключен", "вимкнено"),

        .aboutTagline: ("Close the lid. Your agents keep working.", "Закройте крышку. Агенты продолжат работу.", "Закрийте кришку. Агенти працюватимуть далі."),
        .aboutVersion: ("Version %@", "Версия %@", "Версія %@"),
        .aboutSource: ("Source code on GitHub", "Исходный код на GitHub", "Вихідний код на GitHub"),
        .aboutLidTotal: ("Lid closed with agents running, all time: %@", "С закрытой крышкой за всё время: %@", "Із закритою кришкою за весь час: %@"),
        .clearHistory: ("Clear history", "Очистить историю", "Очистити історію"),
        .adminPrompt: ("Vibecode24 wants to install a rule that lets it turn sleep off and back on.",
                       "Vibecode24 хочет установить правило, чтобы выключать и включать сон.",
                       "Vibecode24 хоче встановити правило, щоб вимикати й вмикати сон."),
        .adminRemovePrompt: ("Vibecode24 wants to remove its sleep rule.",
                             "Vibecode24 хочет удалить своё правило сна.",
                             "Vibecode24 хоче видалити своє правило сну."),

        .onboardingTitle: ("Close the lid. Agents keep going.", "Закройте крышку. Агенты продолжат работу.", "Закрийте кришку. Агенти працюватимуть далі."),
        .onboardingPoint1: ("Vibecode24 sits in the menu bar and notices Claude Code, Codex and other agents.",
                            "Vibecode24 живёт в строке меню и замечает Claude Code, Codex и других агентов.",
                            "Vibecode24 живе в рядку меню й помічає Claude Code, Codex та інших агентів."),
        .onboardingPoint2: ("To keep working with the lid closed, macOS asks for your password once. The rule allows only pmset disablesleep.",
                            "Чтобы работать с закрытой крышкой, macOS один раз спросит пароль. Правило разрешает только pmset disablesleep.",
                            "Щоб працювати із закритою кришкою, macOS один раз спитає пароль. Правило дозволяє лише pmset disablesleep."),
        .onboardingPoint3: ("Sleep comes back when the agents finish, the battery runs low or the Mac gets hot.",
                            "Сон вернётся, когда агенты закончат, батарея сядет или Mac перегреется.",
                            "Сон повернеться, коли агенти завершать, батарея сяде або Mac перегріється."),
        .notNow: ("Not now", "Не сейчас", "Не зараз"),

        .notifFinishedTitle: ("%@ is done", "%@: готово", "%@: готово"),
        .notifFinishedBody: ("Ran for %@.", "Время работы: %@.", "Час роботи: %@."),
        .notifReleasedTitle: ("Sleep is back on", "Сон снова включён", "Сон знову ввімкнено"),
        .notifLidTitle: ("Welcome back", "С возвращением", "З поверненням"),
        .notifLidBody: ("The lid was closed for %@. Finished: %@.", "Крышка была закрыта %@. Закончили: %@.", "Кришка була закрита %@. Завершили: %@."),
        .notifLidBodyNone: ("The lid was closed for %@. Agents are still running.", "Крышка была закрыта %@. Агенты ещё работают.", "Кришка була закрита %@. Агенти ще працюють."),

        .unitHour: ("h", "ч", "год"),
        .unitMinute: ("min", "мин", "хв"),
        .unitSecond: ("s", "с", "с"),
    ]

    /// "Claude Code, Codex і Gemini CLI" in the app's language, not the system's.
    public static func list(_ items: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale(for: language)
        return formatter.string(from: items) ?? items.joined(separator: ", ")
    }

    /// Text for the reason under the title.
    public static func reason(_ decision: AwakeDecision, now: Date = Date()) -> String {
        switch decision {
        case .hold(.agents(let names)): return t(.reasonAgents, list(names))
        case .hold(.grace(let until)): return t(.reasonGrace, clock(until.timeIntervalSince(now)))
        case .hold(.always): return t(.reasonAlways)
        case .hold(.timer(let until)): return t(.reasonTimer, clock(until.timeIntervalSince(now)))
        case .release(.off): return t(.reasonOff)
        case .release(.noAgents): return t(.reasonNoAgents)
        case .release(.timerDone): return t(.reasonTimerDone)
        case .release(.battery(let percent)): return t(.reasonBattery, percent)
        case .release(.onBattery): return t(.reasonOnBattery)
        case .release(.thermal): return t(.reasonThermal)
        case .release(.agentsIdle): return t(.reasonIdle, duration(Double(AppSettings.shared.idleMinutes * 60)))
        }
    }
}
