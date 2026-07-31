---
name: focus-flight-ui-style
description: >
  Focus Flight UI Design System & HUD Glassmorphism Style Guide for HarmonyOS (ArkTS).
  Use when designing, building, or modifying UI components, floating bars, header bars,
  or focus session cards for Focus Flight.
---

# Focus Flight UI Design System & Glassmorphism Guidelines

## Overview
Focus Flight 是一款基于 3D 地球视界的高端「专注/番茄钟」应用。UI 设计风格统一采用 **深空暗黑玻璃拟态 (Dark Glassmorphic Cyber HUD Style)**，在保持极简沉浸专注体验的同时，兼具现代航空与科幻 UI 的重研质感。

---

## 视觉基因与 Design Tokens (Design DNA)

1. **色彩系统 (Color System)**:
   - **深空背景 (Base Background)**: `#020617` / `#030712` (夜空极暗蓝)
   - **玻璃拟态容器 (Glass Panel)**: `rgba(10, 15, 26, 0.82–0.88)`
   - **微光边框 (Hairline Border)**: `1px solid rgba(255, 255, 255, 0.12–0.15)`
   - **高亮/主色调 (Accent Cyan)**: `#38BDF8` (电光蓝 / 品牌色)
   - **成功/积极状态 (Success Green)**: `#4ADE80` (绿色)
   - **警告/进度 (Warning Amber)**: `#F59E0B` (暖黄)
   - **文本颜色**: 标题与主字 `#F8FAFC` (纯白/柔白)，次要字与图标 `#94A3B8` / `#64748B` (板岩灰)

2. **圆角与阴影 (Radius & Elevation)**:
   - 悬浮外壳胶囊: `borderRadius(20)` ~ `borderRadius(28)`
   - 卡片微光阴影: `shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.55)', offsetY: 6 })`

3. **布局与结构层级 (Layout Stack)**:
   - **底层 (Level 0)**: 3D 地球背景视界 (`Web` 加载 `earth.html` 全屏展开)
   - **顶层 (Level 1 - Top Header)**: `TopHeaderBar.ets` (品牌 Logo + 今日专注时长 + 完成航次 + 白噪音开关)
   - **左侧 (Level 1 - Left Floating Card)**: `FlightDetailCard.ets` (专注倒计时 + 巡航进度 + 专注Telemetry + 暂停/降落控制)
   - **右下 (Level 1 - Bottom Dock)**: `BottomNavBar.ets` (3大核心胶囊 Tab：专注 Focus, 日志 Log, 机库 Hangar)

---

## 核心 ArkTS 组件开发规范

### 1. 悬浮胶囊外壳标准写法
```ets
Row() { ... }
.height(52)
.padding({ left: 6, right: 8, top: 4, bottom: 4 })
.backgroundColor('rgba(10, 15, 26, 0.88)')
.border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 20 })
.borderRadius(20)
.shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
```

### 2. 选中态与未选中态 Tab 样式
- **选中态**: `.backgroundColor('rgba(56, 189, 248, 0.14)')` + `.border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 14 })` + `#38BDF8` 电光蓝矢量图标与加粗文本。
- **未选中态**: 透明背景，`#F8FAFC` 或 `#94A3B8` 板岩灰图标。

### 3. 矢量图标绘制规范
- 使用原生 ArkTS `Path()` 组合，统一宽度高度为 `18` ~ `22` vp。
- 描边线条风格优先使用 `.stroke(color).strokeWidth(1.8).fill('none')` 或 `.fill(color)`。

### 4. 禁用与避坑指南
- 严禁加入与专注体验无关的商业资金（如 `$83,049K`）、机票销售等商业游戏化杂质。
- 严禁在全屏暗黑 3D 地球背景上使用纯白实色塑料块 (`#FFFFFF`)。
- 确保所有 `animateTo` 均使用 `this.getUIContext()?.animateTo(...)` 避免 API 告警。
