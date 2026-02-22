import Cocoa

// Initialize LanguageManager early so AppleLanguages is set before any UI loads
_ = LanguageManager.shared

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
