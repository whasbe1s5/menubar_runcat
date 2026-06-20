# Menubar RunCat

A macOS menubar application that shows an animated runner in the menu bar whose speed reflects CPU load, and provides a system-monitoring dashboard in a popover.

## Language

**Runner**:
The animated character or visual (Cat, Neon Cat, Dog, Rabbit, Bird, Runner, Glitch) displayed in the menu bar.
_Avoid_: Animation, sprite, icon

**RunnerEngine**:
Owns the runner's frame animation — loading images, driving the timer, rendering the current frame into the status item button. It accepts a speed value but knows nothing about where that speed comes from.
_Avoid_: AnimationEngine, Timer, Player

**SystemMonitor**:
The source of truth for system metrics: CPU, memory, disk, network, battery, uptime, and top processes. Publishes data via Combine publishers.

**SystemCleaner**:
A separate subsystem for scanning and cleaning system junk (trash, caches, logs). Owns the scan/clean lifecycle and publishes its own state. Not part of `SystemMonitor` — monitoring observes, cleaning mutates.
_Avoid_: Cleaner subsystem inside SystemMonitor

**SystemOrchestrator**:
The role (currently played by `AppDelegate`) that reads CPU from `SystemMonitor` and writes speed to `RunnerEngine`. Not a separate type — a naming for the responsibility boundary between the two subsystems.
_Avoid_: Controller, Coordinator

**Speed**:
A scalar (0.0–100.0+) representing CPU usage percentage that `RunnerEngine.updateSpeed(cpuUsage:)` converts into a frame-interval. The runner itself doesn't know the unit — it gets a `Double` and maps it to animation timing.

**Humanoid** (RunnerType):
One of the concrete runner visuals — a running person rendered as emoji. Named to avoid confusion between the type system (`RunnerType`) and the generic concept of a runner.
_Avoid_: Runner (as a visual type)

**Dashboard**:
A SwiftUI popover view that displays `SystemMonitor` data and `RunnerEngine` settings (runner type, speed multiplier, show-CPU-in-menu-bar toggle). Read-only except for settings and the cleaner action.
