# Menubar RunCat Changelog


## v2.1.0 (2026-06-16) — Square Card Grid & Diagnostic Insights

### Design
- Replaced vertical full-width card rows with 2-column `LazyVGrid` of square cards
- Removed runner picker widget from dashboard (runner type managed internally)

### New Features
- **Top CPU Processes**: Shows top 5 processes by CPU% via `proc_pidinfo(PROC_PIDTASKINFO)` delta sampling every 5s
- **Top Memory Processes**: Shows top 5 processes by resident memory
- Helps identify what's causing high CPU/memory usage directly from the dashboard

### Performance
- Process sampling runs every 5th tick (every 5 seconds) to stay lightweight
- Full binary: 852 KB executable, 976 KB app bundle — lighter than Lume (1.3 MB)
- No external dependencies; pure Darwin/libproc APIs

### Fixes
- Fixed CPU spike bug: `currentUsage()` was called twice per sample, causing division-by-zero in second call
- Fixed `totalTicks` denominator: now computed in a separate pass after collecting all PIDs
- Added `guard totalTicks > 0` safety check in CPU.swift
## v2.0.0 (2026-06-16) — Apple-Native Redesign & Lume Features

### Design
- Replaced custom cyberpunk theme with native `NSVisualEffectView` popover using `.popover` material
- Card-based widget layout inspired by Lume: rounded cards with quaternary fills
- System SF Pro typography throughout; hierarchical SF Symbols for all icons
- Respects light/dark mode with semantic system colors

### New Features
- **Battery widget**: percentage, charging state, time remaining (IOKit power sources)
- **Uptime widget**: formatted uptime display via `sysctl(KERN_BOOTTIME)`
- **Thermal state widget**: color-coded nominal/fair/serious/critical indicator
- **Memory breakdown**: wired, compressed, and free subtotals in memory card
- Scrollable dashboard with all widgets in a single popover

### Dashboard Widgets
- CPU gauge with Swift Charts area/line graph
- Memory card with bar + wired/compressed/free breakdown
- Storage card with usage bar + free/total text
- Network card with download/upload speeds
- Battery card with percentage + charging badge + time remaining
- System card with uptime + thermal state
- Runner picker + speed slider
- CPU menu bar toggle + Quit button

### Architecture
- SystemMonitor now publishes BatteryData, UptimeData, and thermalPressure
- Deployed via XcodeGen (`project.yml`) with generated Info.plist (LSUIElement=true)
- macOS 13.0+ deployment target with unit test bundle (xctest, test host)

## v1.0.0 (2026-06-16) — Initial Fork & Modernization

- Forked from Kyome22/menubar_runcat
- Upgraded deployment target to macOS 13.0
- Added XcodeGen project configuration
- Implemented SystemMonitor (CPU, Memory, Disk, Network) via IOKit/Darwin
- Added RunnerEngine with 7 runner types (Cat, Neon Cat, Dog, Rabbit, Bird, Runner, Glitch)
- Replaced NSMenu with NSPopover + SwiftUI dashboard
- Added unit test bundle (4 tests, all passing)
