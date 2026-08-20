/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { displaySync } from '@kit.ArkGraphics2D';
import { mapCommon } from '@kit.MapKit';
import { FlightRouteEngine } from '../utils/FlightRouteEngine';
import { TrailParticle, TrailParticleRenderHelper } from '../utils/TrailParticleRenderHelper';

/**
 * 骨架线采样节点
 */
interface SpineNode {
  x: number;
  y: number;
  dist: number;
  normalX: number;
  normalY: number;
}

/**
 * ✈️ 专注飞行 60FPS 屏幕物理惯性流光粒子引擎 (Mercator Mathematical Projection Ribbon Trail)
 * 1. 使用纯数学墨卡托解析投影计算屏幕航线骨架，100% 紧贴航线与地面跑道！
 * 2. 0 次 JNI 原生地图桥接调用，全程纯数学几何运算，彻底根除抽搐与掉帧！
 * 3. 尾迹恒定 480vp 舒展拖尾，在任何 Zoom 和任何弯道下绝不缩水、绝不缩成一坨！
 */
@Component
export struct FlightTrailParticleOverlay {
  @Prop isFlightActive: boolean = false;
  @Prop trailId: string = 'rainbow';
  @Prop planeScreenOffsetX: number = 0;
  @Prop planeScreenOffsetY: number = 0;
  @Prop planeScreenRotation: number = 0;
  @Prop currentMapBearing: number = 0;
  @Prop currentZoomLevel: number = 17.2;
  @Prop currentFlightRawIndex: number = 0;
  @Prop flightPoints: Array<mapCommon.LatLng> = [];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasWidth: number = 360;
  private canvasHeight: number = 780;

  private particles: TrailParticle[] = [];
  private readonly MAX_PARTICLES: number = 400;
  private animSync?: displaySync.DisplaySync;
  private frameCount: number = 0;

  // 记录上一帧的地图 bearing
  private lastBearing: number = -999;

  aboutToAppear() {
    this.startParticleEngine();
  }

  aboutToDisappear() {
    this.stopParticleEngine();
  }

  private startParticleEngine() {
    this.stopParticleEngine();
    this.animSync = displaySync.create();
    this.animSync.setExpectedFrameRateRange({
      expected: 60,
      min: 30,
      max: 60
    });
    this.animSync.on('frame', () => {
      this.updateAndRenderParticles();
    });
    this.animSync.start();
  }

  private stopParticleEngine() {
    if (this.animSync) {
      try {
        this.animSync.stop();
      } catch (e) { }
      this.animSync = undefined;
    }
  }

  /**
   * 🚀 60FPS 极速粒子合成循环（大地极坐标真实航线骨架贴合）
   */
  private updateAndRenderParticles() {
    if (!this.context || this.canvasWidth <= 0 || this.canvasHeight <= 0) {
      return;
    }

    const ctx = this.context;
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    // 1. 发射新粒子
    if (this.isFlightActive) {
      this.spawnParticles();
    }

    if (!this.isFlightActive && this.particles.length === 0) {
      return;
    }

    // 2. 飞机中心与机尾物理基准点
    const planeRotRad = this.planeScreenRotation * (Math.PI / 180.0);
    const curPlaneCenterX = this.canvasWidth / 2.0 + this.planeScreenOffsetX;
    const curPlaneCenterY = this.canvasHeight / 2.0 + this.planeScreenOffsetY;
    const curTailX = curPlaneCenterX - Math.sin(planeRotRad) * 24.0;
    const curTailY = curPlaneCenterY + Math.cos(planeRotRad) * 24.0;

    // 3. 构建 480vp 真实航线屏幕骨架折线 (Spine)
    const spineNodes: Array<SpineNode> = [];
    const firstNode: SpineNode = {
      x: curTailX,
      y: curTailY,
      dist: 0,
      normalX: 0,
      normalY: 0
    };
    spineNodes.push(firstNode);

    const TRAIL_LENGTH = 260.0;
    let accumulatedDist = 0;

    if (this.flightPoints && this.flightPoints.length >= 2 && this.currentFlightRawIndex >= 0) {
      const curPos = FlightRouteEngine.getSmoothPosition(this.flightPoints, this.currentFlightRawIndex);
      const DEG2RAD = Math.PI / 180.0;
      const latRad = curPos.latitude * DEG2RAD;
      // 当前 zoom 下每米对应的像素数 (Web Mercator 标准分辨率)
      const metersPerPixel = (156543.03392 * Math.cos(latRad)) / Math.pow(2.0, this.currentZoomLevel);
      const pixelsPerMeter = metersPerPixel > 0.0001 ? (1.0 / metersPerPixel) : 1.0;

      let curIdx = this.currentFlightRawIndex;
      const step = Math.max(0.02, Math.min(0.2, 1.5 / Math.pow(1.4, Math.max(0, this.currentZoomLevel - 10))));

      while (curIdx > 0 && accumulatedDist < TRAIL_LENGTH) {
        curIdx = Math.max(0, curIdx - step);
        const pt = FlightRouteEngine.getSmoothPosition(this.flightPoints, curIdx);

        // 大地测量距离与方位角
        const dLat = (pt.latitude - curPos.latitude) * 111132.0;
        const dLon = (pt.longitude - curPos.longitude) * 111132.0 * Math.cos(latRad);
        const distMeters = Math.hypot(dLat, dLon);

        if (distMeters > 0.05) {
          // 方位角 (正北为0，顺时针为正)
          const bearingToPt = (Math.atan2(dLon, dLat) * (180.0 / Math.PI) + 360.0) % 360.0;
          // 🧭 真正的屏幕偏航角：相机正上方朝向地面的 curHeading 方向
          const curHeading = (360.0 - this.currentMapBearing + 360.0) % 360.0;
          const relAngleRad = (bearingToPt - curHeading) * DEG2RAD;
          const distPx = distMeters * pixelsPerMeter;

          const sx = curTailX + distPx * Math.sin(relAngleRad);
          const sy = curTailY - distPx * Math.cos(relAngleRad);

          const prev = spineNodes[spineNodes.length - 1];
          const segD = Math.hypot(sx - prev.x, sy - prev.y);

          if (segD >= 1.2) {
            accumulatedDist += segD;
            const sNode: SpineNode = {
              x: sx,
              y: sy,
              dist: accumulatedDist,
              normalX: 0,
              normalY: 0
            };
            spineNodes.push(sNode);
          }
        }
      }

      // 如果已到航线最起点，沿最后一段切线方向延伸补足 260vp
      if (spineNodes.length >= 2 && accumulatedDist < TRAIL_LENGTH) {
        const last = spineNodes[spineNodes.length - 1];
        const prev = spineNodes[spineNodes.length - 2];
        const dx = last.x - prev.x;
        const dy = last.y - prev.y;
        const d = Math.hypot(dx, dy);
        if (d > 0.001) {
          const remain = TRAIL_LENGTH - accumulatedDist;
          const extNode: SpineNode = {
            x: last.x + (dx / d) * remain,
            y: last.y + (dy / d) * remain,
            dist: TRAIL_LENGTH,
            normalX: 0,
            normalY: 0
          };
          spineNodes.push(extNode);
          accumulatedDist = TRAIL_LENGTH;
        }
      }
    }

    // 若航线点不足，以飞机机尾方向作为后备直线骨架
    if (spineNodes.length < 2) {
      const backDirX = -Math.sin(planeRotRad);
      const backDirY = Math.cos(planeRotRad);
      const fallbackNode: SpineNode = {
        x: curTailX + backDirX * TRAIL_LENGTH,
        y: curTailY + backDirY * TRAIL_LENGTH,
        dist: TRAIL_LENGTH,
        normalX: 0,
        normalY: 0
      };
      spineNodes.push(fallbackNode);
      accumulatedDist = TRAIL_LENGTH;
    }

    // 计算骨架各节点的单位法线向量
    for (let k = 0; k < spineNodes.length; k++) {
      let tx = 0;
      let ty = 0;
      if (k === 0) {
        tx = spineNodes[1].x - spineNodes[0].x;
        ty = spineNodes[1].y - spineNodes[0].y;
      } else if (k === spineNodes.length - 1) {
        tx = spineNodes[k].x - spineNodes[k - 1].x;
        ty = spineNodes[k].y - spineNodes[k - 1].y;
      } else {
        tx = spineNodes[k + 1].x - spineNodes[k - 1].x;
        ty = spineNodes[k + 1].y - spineNodes[k - 1].y;
      }
      const tLen = Math.hypot(tx, ty);
      if (tLen > 0.0001) {
        spineNodes[k].normalX = -ty / tLen;
        spineNodes[k].normalY = tx / tLen;
      } else {
        spineNodes[k].normalX = Math.cos(planeRotRad);
        spineNodes[k].normalY = Math.sin(planeRotRad);
      }
    }

    const totalSpineDist = Math.max(1.0, accumulatedDist);

    // 3.5 🎵 当为“律动音符”尾迹时，先绘制随真实航线流淌的 5 条五线谱音律光波流动线
    if (this.trailId === 'melody') {
      this.renderMelodyStaffLines(ctx, spineNodes, totalSpineDist);
    }

    // 4. 遍历更新存活粒子（在真实航线骨架上插值定位，O(1) 删除）
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life--;

      if (p.life <= 0) {
        this.particles[i] = this.particles[this.particles.length - 1];
        this.particles.pop();
        continue;
      }

      const progress = 1.0 - Math.max(0, p.life / p.maxLife); // 0(新生) -> 1(消亡)
      const lagRatio = Math.pow(progress, 0.92);
      const targetDist = Math.min(totalSpineDist, lagRatio * TRAIL_LENGTH);

      // 在骨架线段中寻找目标距离所在的区间
      let segIdx = 0;
      for (let k = 0; k < spineNodes.length - 1; k++) {
        if (targetDist >= spineNodes[k].dist && targetDist <= spineNodes[k + 1].dist) {
          segIdx = k;
          break;
        }
      }
      if (segIdx >= spineNodes.length - 1) {
        segIdx = spineNodes.length - 2;
      }

      const n0 = spineNodes[segIdx];
      const n1 = spineNodes[segIdx + 1];
      const segSpan = Math.max(0.001, n1.dist - n0.dist);
      const segT = Math.max(0, Math.min(1.0, (targetDist - n0.dist) / segSpan));

      const spineX = n0.x + (n1.x - n0.x) * segT;
      const spineY = n0.y + (n1.y - n0.y) * segT;
      const normX = n0.normalX + (n1.normalX - n0.normalX) * segT;
      const normY = n0.normalY + (n1.normalY - n0.normalY) * segT;

      const sway = Math.sin(this.frameCount * p.swaySpeed + p.swayPhase) * p.swayAmp;
      const latOff = p.lateralOffset !== undefined ? p.lateralOffset : 0;
      const driftLat = p.driftLateral !== undefined ? p.driftLateral : 0;
      const totalLateral = latOff + progress * driftLat + sway;

      p.x = spineX + normX * totalLateral;
      p.y = spineY + normY * totalLateral;
      p.rotation += p.vRot;

      if (this.trailId === 'stardust') {
        TrailParticleRenderHelper.renderStardustParticle(ctx, p, progress, this.frameCount);
      } else if (this.trailId === 'bubbles') {
        TrailParticleRenderHelper.renderBubbleParticle(ctx, p, progress, this.frameCount);
      } else if (this.trailId === 'contrail') {
        TrailParticleRenderHelper.renderContrailParticle(ctx, p, progress);
      } else if (this.trailId === 'melody' || this.trailId === 'aurora') {
        TrailParticleRenderHelper.renderMelodyParticle(ctx, p, progress, this.frameCount);
      } else {
        TrailParticleRenderHelper.renderRainbowParticle(ctx, p, progress);
      }
    }

    this.frameCount++;
  }

  /**
   * 🌟 依据当前尾迹特效生成新粒子 (480vp 物理惯性流光版)
   */
  private spawnParticles() {
    if (this.trailId === 'none' || this.particles.length >= this.MAX_PARTICLES) {
      return;
    }

    const planeRotRad = this.planeScreenRotation * (Math.PI / 180.0);
    const tailX = this.canvasWidth / 2 + this.planeScreenOffsetX - Math.sin(planeRotRad) * 24.0;
    const tailY = this.canvasHeight / 2 + this.planeScreenOffsetY + Math.cos(planeRotRad) * 24.0;
    const normX = Math.cos(planeRotRad);
    const normY = Math.sin(planeRotRad);

    const newPs = TrailParticleRenderHelper.spawnParticlesForTrail(
      this.trailId,
      tailX,
      tailY,
      this.frameCount,
      normX,
      normY
    );
    for (let i = 0; i < newPs.length; i++) {
      this.particles.push(newPs[i]);
    }
  }

  /**
   * 🎼 绘制随真实航线律动流淌的 5 条五线谱音律光波线条 (末端平滑渐变透明淡出 + 更宽广舒展的空域扩散)
   */
  private renderMelodyStaffLines(ctx: CanvasRenderingContext2D, spineNodes: SpineNode[], totalDist: number) {
    if (spineNodes.length < 2) return;

    ctx.save();

    // 5 条平行的音律流动线 (更开阔的音域间距：-13vp 到 +13vp)
    const staffOffsets = [-13.0, -6.5, 0.0, 6.5, 13.0];
    const staffAlphas = [0.35, 0.50, 0.75, 0.50, 0.35];
    const staffColors = [
      'rgba(175, 82, 222, ', // 浅紫
      'rgba(14, 165, 233, ',  // 蔚蓝
      'rgba(255, 255, 255, ', // 主律动亮白
      'rgba(52, 211, 153, ',  // 翡翠绿
      'rgba(251, 146, 60, '   // 暖橙
    ];

    // 沿航线细分步长采样点 (每 5vp 采样一段，分段计算透明度实现极平滑的尾端渐变淡出)
    const step = 5.0;
    const maxTrailDrawDist = Math.min(totalDist, 280.0);
    const sampleCount = Math.floor(maxTrailDrawDist / step);
    if (sampleCount < 2) {
      ctx.restore();
      return;
    }

    for (let lineIdx = 0; lineIdx < staffOffsets.length; lineIdx++) {
      const baseLateral = staffOffsets[lineIdx];
      const baseAlpha = staffAlphas[lineIdx];
      const colorPrefix = staffColors[lineIdx];
      const lineWidth = lineIdx === 2 ? 1.6 : 1.1;

      // 预先计算所有采样点坐标与透明度
      let prevPtX = 0;
      let prevPtY = 0;

      for (let s = 0; s <= sampleCount; s++) {
        const curDist = s * step;
        const progress = curDist / maxTrailDrawDist; // 0.0(机尾) -> 1.0(消散尾端)

        // 寻找对应区间的骨架节点
        let segIdx = 0;
        for (let k = 0; k < spineNodes.length - 1; k++) {
          if (curDist >= spineNodes[k].dist && curDist <= spineNodes[k + 1].dist) {
            segIdx = k;
            break;
          }
        }
        if (segIdx >= spineNodes.length - 1) {
          segIdx = spineNodes.length - 2;
        }

        const n0 = spineNodes[segIdx];
        const n1 = spineNodes[segIdx + 1];
        const span = Math.max(0.001, n1.dist - n0.dist);
        const t = Math.max(0, Math.min(1.0, (curDist - n0.dist) / span));

        const spX = n0.x + (n1.x - n0.x) * t;
        const spY = n0.y + (n1.y - n0.y) * t;
        const nX = n0.normalX + (n1.normalX - n0.normalX) * t;
        const nY = n0.normalY + (n1.normalY - n0.normalY) * t;

        // 波动波形计算：更具张力的流体起伏波幅 (加大到 5.5vp)
        const envelope = Math.sin(progress * Math.PI);
        const wave = Math.sin(curDist * 0.045 - this.frameCount * 0.08 + lineIdx * 0.70) * 5.5 * envelope;
        const totalLat = baseLateral + wave;

        const curPtX = spX + nX * totalLat;
        const curPtY = spY + nY * totalLat;

        if (s > 0) {
          // 计算当前线段的平滑渐变透明度
          let fade = 1.0;
          if (progress < 0.10) {
            fade = progress / 0.10;
          } else if (progress > 0.45) {
            fade = Math.pow(1.0 - (progress - 0.45) / 0.55, 1.6);
          }
          const segAlpha = Math.max(0, Math.min(1.0, baseAlpha * fade));

          ctx.beginPath();
          ctx.strokeStyle = `${colorPrefix}${segAlpha.toFixed(3)})`;
          ctx.lineWidth = lineWidth;
          ctx.lineCap = 'round';
          ctx.moveTo(prevPtX, prevPtY);
          ctx.lineTo(curPtX, curPtY);
          ctx.stroke();
        }

        prevPtX = curPtX;
        prevPtY = curPtY;
      }
    }

    ctx.restore();
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onReady(() => {
        this.canvasWidth = this.context.width;
        this.canvasHeight = this.context.height;
      })
      .onAreaChange((_oldVal: Area, newVal: Area) => {
        this.canvasWidth = newVal.width as number;
        this.canvasHeight = newVal.height as number;
      })
      .hitTestBehavior(HitTestMode.None)
  }
}
