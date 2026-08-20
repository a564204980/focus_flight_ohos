---
name: dribbble-design-patterns
description: >
  Dribbble (https://dribbble.com/) 顶级移动端 UI/UX 设计语言、视觉美学与 ArkTS 落地设计模式指南。
  当设计、重构或优化任何 UI 界面、卡片、抽屉弹窗、按钮动效、渐变光晕及视觉层级时触发并参考此规范。
---

# Dribbble 顶级移动端设计模式与美学落地指南 (Dribbble UI/UX Design System)

> 本规范提炼自 [Dribbble](https://dribbble.com/) 顶级产品设计、移动端概念作品与高赞 UI/UX 设计语言，结合 HarmonyOS (ArkTS) 特性沉淀为可直接落地的组件模式与代码范式。

---

## 一、Dribbble 视觉设计核心哲学 (Core Visual Aesthetics)

### 1. 通透感与环境微光 (Ambient Light & Mesh Gradients)
- **拒绝平淡死板的纯色**：重要卡片、视窗和背景应使用细腻的多色网格渐变（Mesh Gradient）或柔和的光晕衬底。
- **高质感毛玻璃 (Frosted Glassmorphism)**：使用深色/浅色半透明背景搭配 `backdropBlur(20~30)`，边缘叠加 `1vp` 半透明内发光描边（如 `rgba(255, 255, 255, 0.6)`）。

### 2. 极致亲和力的柔和几何 (Fluid Rounded Geometry)
- **大圆角体系**：
  - 底部抽屉 / 大容器：`32vp`
  - 主功能 / 主题卡片：`20vp ~ 24vp`
  - 微型预览台 / 徽标：`16vp ~ 22vp`
  - 主操作按钮：全胶囊型（`Capsule`，高度一半圆角）

### 3. 多层弥散柔和阴影 (Soft Diffused Elevation)
- **严禁使用生硬的纯黑重阴影**（如 `rgba(0,0,0,0.5)`）。
- **Dribbble 级阴影公式**：
  - **默认卡片**：大模糊半径、极低透明度、带轻微环境色偏移：
    ```typescript
    .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.04)', offsetY: 4 })
    ```
  - **高亮 / 选中状态卡片**：带有主题色光晕的弥散投影：
    ```typescript
    .shadow({ radius: 16, color: 'rgba(240, 101, 83, 0.22)', offsetY: 4 })
    ```

### 4. 风格化微排版 (Micro Typography & Tags)
- **英文风格化小 Tag**：
  - 字号 8.5vp ~ 9.5vp，字重 Bold，全大写。
  - 增加字间距：letterSpacing(0.8 ~ 1.2)。
  - 赋予主题强调色或浅灰，放置在中文标题上方，瞬间提升现代质感。
- **视觉预览视窗 (Hero Visual Orb / Badge)**：
  - 每张卡片上方需有专属的拟物/渐变光晕预览球（Orb）、立体图形或微动视窗，避免纯文本卡片的单调。

---

## 二、ArkTS 组件落地设计模式 (ArkTS Implementation Patterns)

### 1. Dribbble 级艺术卡片模式 (Art Card Pattern)

```typescript
@Builder
buildArtCard(item: CardItemConfig, isSelected: boolean) {
  Stack({ alignContent: Alignment.TopEnd }) {
    Column() {
      // 1. 专属艺术微光视窗
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 44, height: 44 })
          .linearGradient({
            angle: 135,
            colors: [['#FF7B6B', 0.0], ['#F06553', 1.0]]
          })
          .shadow({ radius: 8, color: 'rgba(240, 101, 83, 0.30)', offsetY: 2 })
        Text(item.icon).fontSize(22)
      }
      .width(68).height(68)
      .borderRadius(22)
      .backgroundColor(isSelected ? 'rgba(255,255,255,0.95)' : 'rgba(248,250,252,0.90)')
      .margin({ top: 14 })

      // 2. 风格化英文 Tag
      Text(item.enTag)
        .fontSize(8.5)
        .fontWeight(FontWeight.Bold)
        .fontColor(isSelected ? '#F06553' : '#94A3B8')
        .letterSpacing(0.8)
        .margin({ top: 10 })

      // 3. 中文标题
      Text(item.title)
        .fontSize(13.5)
        .fontWeight(FontWeight.Bold)
        .fontColor(isSelected ? '#0F172A' : '#334155')
        .margin({ top: 3 })

      // 4. 场景副标胶囊
      Text(item.badge)
        .fontSize(10.5)
        .fontColor(isSelected ? '#F06553' : '#94A3B8')
        .backgroundColor(isSelected ? 'rgba(240, 101, 83, 0.08)' : 'rgba(148, 163, 184, 0.10)')
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
        .margin({ top: 6, bottom: 10 })
    }
    .width(136).height(178)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({
      width: isSelected ? 2 : 1,
      color: isSelected ? '#F06553' : 'rgba(0, 0, 0, 0.06)'
    })
    .shadow({
      radius: isSelected ? 14 : 4,
      color: isSelected ? 'rgba(240, 101, 83, 0.22)' : 'rgba(15, 23, 42, 0.03)',
      offsetY: isSelected ? 4 : 2
    })
    .scale(isSelected ? { x: 1.02, y: 1.02 } : { x: 1.0, y: 1.0 })
    .animation({ duration: 220, curve: Curve.EaseOut })

    // 选中浮雕徽标
    if (isSelected) {
      Stack({ alignContent: Alignment.Center }) {
        Text('✓').fontSize(12).fontWeight(FontWeight.Bolder).fontColor('#FFFFFF')
      }
      .width(22).height(22).borderRadius(11)
      .backgroundColor('#F06553')
      .shadow({ radius: 6, color: 'rgba(240, 101, 83, 0.40)', offsetY: 2 })
      .margin({ top: 8, right: 8 })
    }
  }
}
```

### 2. Dribbble 级底部抽屉规范 (Bottom Sheet Pattern)
- **遮罩层**：`backgroundColor('rgba(15, 23, 42, 0.40)')` + `backdropBlur(25)`。
- **抽屉主体**：
  - 顶部 `42*4vp` 药丸拖拽指示条。
  - 标题栏带灵动 Tag（如 `LIVE`、`PRO`）与圆润圆形关闭按钮（`32*32vp`，`#F1F5F9`）。
  - 滑轨采用 `List` + `listDirection(Axis.Horizontal)` + `edgeEffect(EdgeEffect.Spring)`。
  - 底部操作按钮采用高度 `48vp` 胶囊按钮（`ButtonType.Capsule`），搭配柔和主色投影与触觉震动反馈。

---

## 三、微交互与触感反馈 (Micro-Interactions & Haptics)

1. **触感反馈**：每个重要卡片点击与底部按钮均需调用 `@ohos.vibrator` 轻快微震动（`duration: 15ms`），赋予界面真实的机械物理按压质感。
2. **弹性与缩放**：
   - 选中元素伴随轻微微缩放（`scale: 1.02 ~ 1.03`）。
   - 浮雕打勾标记采用缩放淡入动效：`.transition(TransitionEffect.scale({ x: 0.2, y: 0.2 }))`。