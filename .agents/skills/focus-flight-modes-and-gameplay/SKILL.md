---
name: focus-flight-modes-and-gameplay
description: >
  Focus Flight 专注飞行模式与核心游戏化机制规划指南。
  涵盖“标准飞行模式（轻度）”与“深度巡航模式（严格迫降）”的业务逻辑、系统生命周期判定、10秒宽限期算法、UI交互规范及未来落地架构。
---

# Focus Flight 专注飞行模式与游戏化机制规划

本文档作为 Focus Flight 后续专注机制研发与演进的基准技术与产品规范。

---

## 一、 双专注模式产品定义

### 1. 标准飞行模式（轻度 / Standard Flight Mode）
- **适用场景**: 日常轻度工作、多任务协同（需要偶尔查阅资料、回复消息等）。
- **运行逻辑**:
  - **允许后台挂机**: 用户切出应用或锁屏时，专注倒计时与飞行里程在后台持续推进；
  - **时间戳恢复机制**: 重新切回应用时，根据挂机期间的物理时间差（`Date.now() - backgroundStartTime`）平滑补齐航程与彩虹光带；
  - **无惩罚**: 随时可切出或查看其他软件，飞行不会中断或失败。

---

### 2. 深度巡航模式（严格 / Deep Cruise Mode）
- **适用场景**: 高强度沉浸式学习、备考、不被打扰的深度工作（Deep Work）。
- **核心机制 —— “离开即迫降”**:
  - **生命周期检测**: 监听应用切入后台（`onBackground` / `onPageHide`）；
  - **10 秒紧急返航宽限期**:
    - 用户一旦切离 Focus Flight，系统立即记录离屏时间戳 `leaveTimestamp = Date.now()`；
    - 系统可触发短促警示震动或发送高优先级本地通知提示：*“⚠️ 飞机偏离航线！请在 10 秒内返回座舱，否则将迫降失败”*；
  - **判定规则**:
    - **10 秒内返回**: 解除警报，恢复正常巡航，专注继续；
    - **超过 10 秒未返回**: 立即判定**专注失败**。触发迫降结算（记录迫降地点、航程作废、无法获得机长勋章）。

---

## 二、 鸿蒙系统端技术实现架构

### 1. 防挂起的时间戳判定机制（First Principles）
在鸿蒙系统（HarmonyOS）中，后台定时器可能会被系统能效调度挂起（Throttled/Frozen），因此**严禁仅依赖 `setInterval` 倒计时**，必须采用**基于绝对物理时间戳的差值校验**：

```ts
// 伪代码架构示范
export class FocusModeManager {
  private static leaveTimestamp: number = 0;
  private static readonly GRACE_PERIOD_MS: number = 10 * 1000; // 10秒宽限期

  /** 切入后台时触发 */
  public static onAppBackground(isDeepCruiseMode: boolean): void {
    if (!isDeepCruiseMode) {
      return; // 标准模式不受影响
    }
    this.leaveTimestamp = Date.now();
  }

  /** 切回前台时触发 */
  public static onAppForeground(isDeepCruiseMode: boolean, onFailedCallback: () => void): void {
    if (!isDeepCruiseMode || this.leaveTimestamp === 0) {
      return;
    }
    const elapsed = Date.now() - this.leaveTimestamp;
    this.leaveTimestamp = 0;

    if (elapsed > this.GRACE_PERIOD_MS) {
      // 超过 10 秒，触发迫降失败
      onFailedCallback();
    }
  }
}
```

### 2. 屏幕常亮与沉浸态支持
在开启深度巡航模式时，自动调用系统窗口 API 开启屏幕常亮：
- `windowClass.setWindowKeepScreenOn(true)`
- 在结束专注或迫降时恢复 `windowClass.setWindowKeepScreenOn(false)`。

---

## 三、 UI 与游戏化沉浸表达

1. **起飞前模式选择**:
   - 在图2起飞面板/设置弹窗中，提供优雅清晰的模式切换 Switch 或卡片单选：
     - ✈️ **标准飞行**（轻松自由 · 允许后台）
     - 🚀 **深度巡航**（极度自律 · 离开 10 秒迫降）

2. **迫降失败视觉呈现**:
   - 飞机平滑降落在当前坐标地貌上，伴随温柔解压的警示文案（如 *“航线中断，飞机已就近安全备降。休息片刻，准备下次启航吧！”*）；
   - 保持温馨可爱的产品调性，避免给用户带来负罪感或挫败感。

---

## 四、 突发气象与航路事件系统规划（Weather & Route Events System）

在专注飞行过程中引入随机或地域性突发气象事件，以“**沉浸陪伴、正向激励、绝不打扰用户**”为最高准则。

### 1. 氛围向（Atmosphere & White Noise）
- **🌧️ 积雨云与高空骤雨**:
  - **视效**: 地图/座舱上方平滑叠加半透明细密雨丝动效，光线微微柔和收暗；
  - **听效**: 自动平滑淡入高品质**高空细雨白噪音（Rain White Noise）**，营造深度心流空间。
- **🌬️ 平流层清风与云雾穿梭**:
  - **视效**: 飞机穿过轻盈云团，云雾在机翼两侧散开；
  - **听效**: 舒缓的高空气流白噪音，减压放松。
- **🌌 极光与夜航星轨（夜间专注专属）**:
  - **视效**: 夜间航段（20:00后）穿过极光气流，机尾彩虹光带泛起柔美波光粒子。

### 2. 玩法向（Gameplay & Gamification Rewards）
- **💨 高空顺风急流（Jet Stream Boost）**:
  - **机制**: 航途中偶遇顺风气流，尾迹光带微亮加速；
  - **收益**: 本轮专注顺利完成后，**额外获得 +10% ~ +15% 飞行里程奖励**。
- **📖 航线气象日志（Captain's Flight Log）**:
  - 专注完成后生成的专属登机牌/飞行报告中，精确记录本趟航程的气象足迹（如：*“航途遭遇【高原云雾】与【顺风急流】，机长保持极高专注度，安全平稳降落”*）。
- **🏅 专属气象成就勋章（Badges & Achievements）**:
  - 解锁【穿越风暴者】、【顺风骑士】、【极光漫游者】、【云端漫步】等稀有气象成就勋章与航线图鉴。

### 3. 客舱向（Cabin Immersion & Passenger Interaction）
- **🐱 小猫机长/乘务长暖心广播**:
  - 在客舱透视模式下，浮现可爱温馨的气泡广播：
    - *“叮咚～前方正在穿过秦岭颠簸气流，请各位乘客系好专注安全带，乘务组正在为大家递送热可可 ☕”*
    - *“报告机长，窗外出现美丽晚霞，祝您专注愉快 🌅”*
- **🪟 舷窗天气微动效**:
  - 客舱透视模式下，飞机舷窗玻璃上实时呈现**水滴滑落、水雾弥漫或微结霜花**的轻量化细腻动效。

### 4. 技术实现与架构规范
- **无打扰原则**: 气象事件与广播均为全自动环境音画表现，**严禁弹出需要用户点击的阻塞式窗口**。
- **音频平滑渐变**: 使用鸿蒙 `@ohos.multimedia.audio` 实现白噪音音量 2~3 秒平滑淡入淡出（Cross-fade），避免突兀吓到用户。
- **低功耗渲染**: 雨丝与舷窗粒子动效采用纯轻量 Canvas 或预渲染动画帧，确保后台常亮低发热、低耗电。

