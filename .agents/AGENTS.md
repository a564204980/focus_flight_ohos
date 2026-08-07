# Focus Flight Project Rules

## UI & Design System Guidelines
- **UI Style Standard**: All UI components in this workspace MUST follow the `focus-flight-ui-style` Dark Glassmorphism Cyber HUD design system.
- **Color Tokens**:
  - Panel Background: `rgba(10, 15, 26, 0.82-0.88)`
  - Border: `1px solid rgba(255, 255, 255, 0.12-0.15)`
  - Accent Color: `#38BDF8` (Cyber Cyan)
  - Success Color: `#4ADE80`
  - Text: Primary `#F8FAFC`, Secondary `#94A3B8`
- **Domain Purpose & Metaphor**: Focus Flight fundamentally is a gamified focus/pomodoro productivity application. The "flight" element is an immersive experiential packaging (Route = Focus Goal, Takeoff/Cruising = Focus Session, Landing = Completion, Cabin/Seats = Immersion Ritual). Do NOT insert unrelated commercial airline elements (such as ticket sales or money `$83,049K`). Keep the interface pure, immersive, and focus-centered.

## File Architecture & Minimal Edit Guidelines
- **Minimal Modification & User Code Protection (最小改动与保护用户微调代码)**: Strictly follow the minimal modification principle. NEVER overwrite files containing user fine-tuned parameters (such as `translate` offsets, custom layout positions, shadow coordinates, etc.). Only modify the minimal necessary lines relevant to the current user request, preserving all user-customized variables and layout coordinates.
- **Rawfile Resource Structure**: Never dump JS, CSS, models, images, or JSON files directly into the root of `rawfile/`. Group them into subfolders: `css/`, `js/`, `models/`, `textures/`, `data/`. Keep only HTML entry files in `rawfile/` root.
- **Clean Modular Code**: Keep code clean and modular. Never create bloated monolithic files. Split complex UI or logic into focused components and helper modules. Never create redundant or temporary scratch files.

## HDC Real-Time Screen Capture & Self-Verification Rule (自动化截图对比自我校验法则)
- **Auto-Verification Requirement**: After deploying any UI or Map Marker visual updates, the agent MUST run HDC `uitest screenCap` to capture the real-time screen (`screen.png`), inspect the captured image via `view_file`, and perform self-comparison to verify heading alignment, red dot indicator position, and UI placement BEFORE reporting back to the user.
