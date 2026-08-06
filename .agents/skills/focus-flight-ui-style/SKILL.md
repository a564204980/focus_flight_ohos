---
name: focus-flight-ui-style
description: >
  Focus Flight UI Design System & HUD Glassmorphism Style Guide for HarmonyOS (ArkTS).
  Use when designing, building, or modifying UI components, floating bars, header bars,
  or focus session cards for Focus Flight.
---

# Focus Flight UI Design System & Glassmorphism Guidelines

## 核心产品定位与理念 (Core App Essence & Metaphor)
- **软件本质**: Focus Flight 本质是一款**个人专注与番茄钟高效生产力应用 (Focus & Pomodoro Productivity Application)**。
- **飞行包装**: “飞行”是该专注软件外层具象化的沉浸式体验包装与意象隐喻：
  - **航线规划 (Route)** = 制定专注目标与计划
  - **起飞 (Takeoff)** = 启动专注计时
  - **平稳巡航 (Cruising)** = 维持沉浸专注状态
  - **安全降落 (Landing)** = 成功完成专注任务并结算积分/打卡
  - **机舱选座与机体 (Cabin Seat & Aircraft Overlay)** = 提高专注仪式感与战术沉浸感的交互载体
- **最高准则**: 所有的 UI 设计、组件交互、文字话术与视觉特效，均必须紧密围绕“助推用户提升专注效率”展开，切勿偏离专注本质。

---

## 视觉基因与 Design Tokens (Design DNA)

1. **色彩系统 (Color System - 航空高奢战术 Token)**:
   - **深虚空夜色底板 (Midnight Void)**: `#050914` / `#0A0F1D` (飞行员舱位夜色)
   - **玻璃拟态容器 (Glass Panel)**: `#0D1322` / `rgba(13, 19, 34, 0.88)`
   - **发丝发光线框 (Hairline Border)**: `1px solid rgba(255, 255, 255, 0.15)` 或 `1px solid #1E293B`
   - **高奢仪表金 (Cockpit Amber Gold)**: `#F59E0B` (仪表盘主高亮 / 核心战术色)
   - **翡翠仪表绿 (Emerald Flight Green)**: `#10B981` (跑道状态绿 / 准点完成)
   - **钛银冰白 (Titanium Frost White)**: `#F8FAFC` (主文字与高奢图标) / `#94A3B8` (板岩灰)

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



### 3. 矢量图标绘制规范
- 使用原生 ArkTS `Path()` 组合，统一宽度高度为 `18` ~ `22` vp。
- 描边线条风格优先使用 `.stroke(color).strokeWidth(1.8).fill('none')` 或 `.fill(color)`。

### 4. 禁用与避坑指南
- 严禁加入与专注体验无关的商业资金（如 `$83,049K`）、机票销售等商业游戏化杂质。
- 严禁在全屏暗黑 3D 地球背景上使用纯白实色塑料块 (`#FFFFFF`)。
- 确保所有 `animateTo` 均使用 `this.getUIContext()?.animateTo(...)` 避免 API 告警。
- **严格遵循最小改动原则 (Minimal Modification & Code Protection)**: 修改代码时仅更改与当前需求直接相关的最小必要行，**绝不重置或覆盖用户手动微调过的代码/坐标**（如 `translate` 偏移、自定义控件尺寸与阴影位置），只做局部增量替换。

---

### 5. 公共组件与原生组件使用规范 (Common & Native Components First)
- **多用公共组件 (Reusable Components)**:
  - 遇到通用 UI 元素（如 HUD 返回按钮 `BackButton.ets`、顶栏 `TopHeaderBar.ets`、战术浮卡等），必须优先提炼并在 `components/` 目录下封装公共组件，严禁在各 Page / Overlay 中粗暴硬编码重复内联 UI 逻辑。
- **多用原生组件与原生弹窗 (ArkUI Native Components & CustomDialog)**:
  - 遇到底部抽屉/面板弹窗需求（如机场选择、机舱选座登机牌等），**必须优先使用 HarmonyOS ArkUI 原生 `@CustomDialog` + `CustomDialogController({ alignment: DialogAlignment.Bottom, customStyle: true })` 机制**（参考 `AirportSelectDialog.ets` 与 `SeatSelectBoardingDialog.ets`）。
  - 利用 HarmonyOS 系统底层的深色半透明蒙层、吸附动画与防错位抖动，严禁自行使用绝对定位手写伪弹窗。

---

### 6. 资源规划与代码拆分规范 (Resource Architecture & Code Modularization)
- **静态资源子目录分类 (rawfile Subdirectory Standard)**:
  - 严禁将静态文件（JS、CSS、图片、模型、JSON 配置等）粗暴散落平铺在 `rawfile` 根目录下。
  - 必须按文件类型建立结构清晰的子目录进行归类存放：
    - `rawfile/css/` ：CSS 样式库
    - `rawfile/js/` ：框架解析库与数据脚本
    - `rawfile/models/` ：3D 资产模型 (`.glb` / `.gltf`)
    - `rawfile/textures/` ：高清贴图与背景图片 (`.jpg` / `.png`)
    - `rawfile/data/` ：JSON 配置文件与数据文件
    - `rawfile/` 根目录仅允许保留 HTML 视图入口文件。
- **代码拆分防臃肿 (Modularization & Anti-Bloat)**:
  - 保持代码干净精简，单个组件/脚本文件切勿过于臃肿。当 UI 或业务逻辑复杂时，必须按功能模块拆分为独立的子组件与 Service 函数。
  - 严禁随意乱发/乱建临时重名文件，保持项目文件结构高度严谨。

---

### 7. 地图战术航线大圆弧生成规范 (Tactical Route Smooth Arc Generation & Bezier Fillet Specification)
- **避免尖锐折角与三段硬折线根因**:
  - 严禁对跨度数十/上百公里的航线直接使用 Chaikin 算法，也严禁将倒角切点 $P_2$ 设在远达数十公里的位置（会导致 60 个采样点平均间距高达 900m/点，在机场局部 Zoom 17 放大视角下产生硬折弯）。
- **高密度二次贝塞尔切线倒角算法 (Quadratic Bézier Fillet Arc Standard)**:
  - **跑道直飞切出点 $P_0$**: 取跑道 65%~80% 处（如 `interpolateLatLng(start, end, 0.65)`），保证跑道直飞段中线干练完整。
  - **空中延伸控制点 $V$**: 沿跑道方向延伸至末端外侧 125%~170% 处（如 `interpolateLatLng(start, end, 1.70)`），控制转弯弧线向空中伸展冲出更远。
  - **局部切入终点 $P_2$**: 设在巡航航线方向约 0.008~0.02 范围（控制在 10~30 公里局部范围内）。
  - **高密度插值**: 采用 `generateQuadraticBezierPoints(P0, V, P2, 80~100)` 生成 80~100 点高密度二次贝塞尔曲线，保证采样点间距控制在 40~100 米/点的微观极小范围内。
  - **视觉保障**: 确保航线在跑道视口、地区视口及全国视口（Zoom 8~17）下均呈现 100% 绝对圆润、流畅舒展的超大弧度真圆弧。

