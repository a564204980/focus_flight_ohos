---
name: smooth-spline-flight-animation
description: "提供使用 Catmull-Rom 样条曲线（而非线性插值）来平滑动画模拟物体（如飞机）沿路径移动的数学和架构模式。"
---

# 平滑样条飞行动画 (Catmull-Rom)

## 分段线性动画的问题
在使用分段线性插值，使飞机或物体沿着由数百个离散 `LatLng` 坐标点定义的路径生成动画时：
- 路径会变成一个多边形折线。
- 物体呈直线飞行，然后在顶点处其速度矢量瞬间折跃捕捉（突变）。
- 如果航向（方位角）是基于线性线段计算的，旋转角度会以离散的“阶梯”方式更新（直行 -> 瞬间跳跃旋转 -> 直行）。

## 解决方案：Catmull-Rom 样条曲线
Catmull-Rom 样条曲线通过控制点提供完美的连续 C1 平滑度，确保逼真的曲线路径且没有突变的折点。

### 实现模式

1. **连续位置插值**
给定一个连续的 `rawIndex`（例如从 `0.0` 到 `points.length - 1`），计算 Catmull-Rom 位置：

```typescript
const getSmoothPos = (idx: number, points: mapCommon.LatLng[]): mapCommon.LatLng => {
  const maxIdx = points.length - 1;
  if (idx <= 0) return points[0];
  if (idx >= maxIdx) return points[maxIdx];
  
  const i = Math.floor(idx);
  const t = idx - i;
  
  const p0 = points[Math.max(0, i - 1)];
  const p1 = points[i];
  const p2 = points[Math.min(maxIdx, i + 1)];
  const p3 = points[Math.min(maxIdx, i + 2)];
  
  const t2 = t * t;
  const t3 = t2 * t;
  
  // Catmull-Rom 样条公式
  const lat = 0.5 * (
    (2 * p1.latitude) +
    (-p0.latitude + p2.latitude) * t +
    (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2 +
    (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3
  );
  
  const lng = 0.5 * (
    (2 * p1.longitude) +
    (-p0.longitude + p2.longitude) * t +
    (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2 +
    (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3
  );
  
  return { latitude: lat, longitude: lng };
};
```

2. **平滑的目标航向 (前视角度)**
不要使用离散的线段索引来计算角度变化。取而代之，计算朝向曲线上略微靠前的一个平滑点位的航向，以此模拟飞行员往前看的动作：

```typescript
// 在平滑曲线上向前看 1.2 个点距
const lookAheadPos = getSmoothPos(rawIndex + 1.2, points);
const interpPos = getSmoothPos(rawIndex, points);
const targetRotation = MapRenderHelper.calculateBearing(interpPos, lookAheadPos);

// 计算最短的角差
let angleDiff = targetRotation - this.currentRotation;
while (angleDiff < -180) angleDiff += 360;
while (angleDiff > 180) angleDiff -= 360;

// 应用缓动（阻尼）以表现惯性重量（如重型客机）
this.currentRotation = this.currentRotation + angleDiff * 0.08;
```

## 何时使用此 Skill
- 当用户要求“平滑化 (smooth out)”动画路径时。
- 当物体的转弯或跟随行为看起来“僵硬”、“机械化”、“呈Z字形”或“呈多边形折线”时。
- 当设计飞行航线、移动摄像机轨道或 GPS 车辆跟随状态时。
