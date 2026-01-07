# CLAUDE.md - Jessep Project

## Project Overview

Jessep is a native macOS menu bar application that displays Claude Max Plan usage limits. It monitors the user's Claude subscription usage and provides alerts when approaching limits.

**Repository**: Jessep  
**Language**: Swift 5.9+  
**Platform**: macOS 13.0+ (Ventura)  
**UI Framework**: SwiftUI + AppKit (for menu bar integration)

## Quick Reference

```bash
# Build
xcodebuild -scheme Jessep -configuration Debug build

# Run tests
xcodebuild test -scheme Jessep -destination 'platform=macOS'

# Clean
xcodebuild clean -scheme Jessep

# Archive for release
xcodebuild archive -scheme Jessep -archivePath build/Jessep.xcarchive -configuration Release
```

## Project Structure

```
Jessep/
├── App/
│   ├── JessepApp.swift              # @main entry point
│   └── AppDelegate.swift            # NSStatusBar, popover management
├── Views/
│   ├── UsagePopoverView.swift       # Main popover content
│   ├── UsageProgressBar.swift       # Reusable progress bar component
│   ├── SettingsView.swift           # Preferences window
│   ├── TokenEntryView.swift         # Manual token entry UI
│   └── ErrorView.swift              # Error state display
├── Models/
│   ├── UsageData.swift              # API response models
│   ├── UsageHistory.swift           # Historical data for predictions
│   └── AppSettings.swift            # @AppStorage preferences
├── Services/
│   ├── ClaudeAPIService.swift       # API client (actor)
│   ├── KeychainService.swift        # Token retrieval
│   ├── NotificationService.swift    # macOS notifications
│   ├── UsageViewModel.swift         # Main state management
│   ├── UsageCache.swift             # Offline data persistence
│   ├── UsagePredictionService.swift # Rate calculation & prediction
│   ├── LaunchAtLoginManager.swift   # SMAppService wrapper
│   └── RetryHandler.swift           # Exponential backoff
├── Utilities/
│   ├── DateFormatters.swift         # Time formatting helpers
│   └── Constants.swift              # API endpoints, colours
├── Resources/
│   └── Assets.xcassets              # Icons, colours
└── JessepTests/
    └── ...                          # Unit tests
```

## Key Technical Decisions

### Menu Bar App Pattern
- Uses `NSStatusBar` + `NSPopover` for menu bar presence
- `@NSApplicationDelegateAdaptor` bridges AppKit and SwiftUI
- `LSUIElement = true` in Info.plist (no dock icon)
- Popover behaviour is `.transient` (closes on outside click)

### Authentication
The app reads OAuth tokens from Claude Code's keychain entry:
- **Service name**: `Claude Code-credentials`
- **JSON path**: `claudeAiOauth.accessToken`
- Fallback: Manual token entry stored in app's own keychain

### API Integration
- **Endpoint**: `https://api.anthropic.com/api/oauth/usage`
- **Required header**: `anthropic-beta: oauth-2025-04-20`
- This is an undocumented API - handle schema changes gracefully
- All fields in response models should be optional

### Concurrency
- `ClaudeAPIService` is an `actor` for thread safety
- `UsageViewModel` uses `@MainActor` for UI updates
- Background polling via `Task` with cancellation support

## Coding Conventions

### Swift Style
- Use Swift's modern concurrency (`async/await`, `Task`, `actor`)
- Prefer `@Published` properties in ObservableObject for SwiftUI binding
- Use `@AppStorage` for UserDefaults-backed preferences
- Avoid force unwrapping - use `guard let` or optional chaining

### Naming
- Files named after primary type: `UsageViewModel.swift`
- SwiftUI views suffixed with `View`: `UsagePopoverView`
- Services suffixed with `Service` or `Manager`
- Use British English in user-facing strings ("colour" not "color")

### Error Handling
- Define domain-specific error enums with `LocalizedError` conformance
- Always provide user-friendly `errorDescription`
- Log errors for debugging but show friendly messages in UI

### SwiftUI Patterns
```swift
// Preferred: Inject dependencies
struct UsagePopoverView: View {
    @StateObject private var viewModel: UsageViewModel
    
    init(viewModel: UsageViewModel = UsageViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

// Use environment for shared state
@EnvironmentObject var settings: AppSettings
```

## Colour Palette

Match Claude's dark theme:
```swift
extension Color {
    static let claudeBackground = Color(red: 0.13, green: 0.13, blue: 0.14)      // #212122
    static let claudeCardBackground = Color(red: 0.16, green: 0.16, blue: 0.17)  // #292929
    static let claudeProgressBar = Color(red: 0.33, green: 0.56, blue: 0.85)     // #548FD9
    static let claudeProgressTrack = Color(red: 0.25, green: 0.25, blue: 0.26)   // #404042
    static let claudeTextPrimary = Color.white
    static let claudeTextSecondary = Color(white: 0.6)
}
```

## API Response Schema

```json
{
  "five_hour": {
    "utilization": 22.0,
    "resets_at": "2026-01-07T12:59:59.570930+00:00"
  },
  "seven_day": {
    "utilization": 64.0,
    "resets_at": "2026-01-08T08:59:59.570948+00:00"
  },
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": {
    "utilization": 75.0,
    "resets_at": "2026-01-08T10:59:59.570955+00:00"
  },
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": null,
    "used_credits": null,
    "utilization": null
  }
}
```

**Important**: The API schema is undocumented and may change. Always use optional decoding.

## Key Features to Implement

### 1. Usage Display
- Current session (5-hour rolling)
- Weekly limits (all models)
- Sonnet-only limits
- Progress bars with percentage

### 2. Notifications
- Threshold alerts (configurable, default 65%)
- Limit reached (100%)
- Reset notifications
- Use `UNUserNotificationCenter`

### 3. Usage Prediction
- Track usage over time
- Calculate consumption rate
- Predict time to limit
- Display: "At current rate: limit in X hr Y min"

### 4. Settings
- Launch at login (`SMAppService`)
- Refresh interval
- Menu bar style (icon/percentage/dynamic)
- Notification preferences
- Warning threshold slider

## Testing Approach

### Unit Tests
- Mock `URLSession` using `URLProtocol` subclass
- Test model decoding with various JSON shapes
- Test date formatting edge cases
- Test prediction calculations

### Integration Tests
- Test keychain access (may need entitlements)
- Test notification scheduling

### Manual Testing
- Test on fresh macOS install
- Verify Gatekeeper doesn't block
- Test offline behaviour

## Common Pitfalls

1. **Keychain Access**: Requires app to run without sandbox, or use manual token entry
2. **Menu Bar Icon**: Must use template images for proper dark/light mode
3. **Notification Permissions**: Request on first launch, handle denial gracefully
4. **ISO8601 Parsing**: API returns fractional seconds - use `.withFractionalSeconds`
5. **Rate Limiting**: Don't poll more than once per minute

## Dependencies

None external - uses only Apple frameworks:
- SwiftUI
- AppKit (NSStatusBar, NSPopover)
- Security (Keychain)
- UserNotifications
- ServiceManagement (Launch at Login)

## Build Configuration

### Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.network.client</key>
<true/>
```

### Info.plist
```xml
<key>LSUIElement</key>
<true/>
<key>LSMinimumSystemVersion</key>
<string>13.0</string>
```

## Linear Project

Issues are tracked in Linear under the **Jessep** project. Reference issues using `STA-XXX` identifiers.

Key milestones:
1. Foundation (STA-222 to STA-226): Project setup, auth, API
2. Core UI (STA-227 to STA-231): Menu bar, popover, state
3. Features (STA-235 to STA-238): Notifications, predictions
4. Polish (STA-241 to STA-244): Icons, tests, release

## Useful Links

- [Claude Usage API Discovery](https://codelynx.dev/posts/claude-code-usage-limits-statusline)
- [NSStatusBar Documentation](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [SwiftUI App Lifecycle](https://developer.apple.com/documentation/swiftui/app)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [SMAppService (Launch at Login)](https://developer.apple.com/documentation/servicemanagement/smappservice)

## Other Guidelines

- Use macos-developer agent for all development
