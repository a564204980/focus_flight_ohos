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

## File Architecture & Modularization Guidelines
- **Rawfile Resource Structure**: Never dump JS, CSS, models, images, or JSON files directly into the root of `rawfile/`. Group them into subfolders: `css/`, `js/`, `models/`, `textures/`, `data/`. Keep only HTML entry files in `rawfile/` root.
- **Clean Modular Code**: Keep code clean and modular. Never create bloated monolithic files. Split complex UI or logic into focused components and helper modules. Never create redundant or temporary scratch files.
