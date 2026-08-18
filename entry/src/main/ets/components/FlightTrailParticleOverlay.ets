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

/**
 * 🎨 屏幕物理惯性粒子模型
 */
interface TrailParticle {
  x: number;               // 屏幕实时渲染 X (vp)
  y: number;               // 屏幕实时渲染 Y (vp)
  lateralOffset: number;   // 航线法线横向初始偏移 (vp)
  driftLateral: number;    // 随时间的微风横向飘散
  size: number;            // 初始尺寸 (vp)
  maxSize: number;         // 最大膨胀尺寸 (vp)
  alpha: number;           // 基础透明度
  maxLife: number;         // 总寿命 (帧数)
  life: number;            // 剩余寿命 (帧数)
  color: string;           // 主颜色
  subColor: string;        // 辅颜色/高光色
  rotation: number;        // 当前旋转角 (弧度)
  vRot: number;            // 自旋角速度 (弧度/帧)
  shapeType: number;       // 粒子形状: 0-微星, 1-尖角八角星芒, 2-钻石星屑, 3-水漾气泡, 4-水汽云雾
  swayPhase: number;       // 摇摆相位
  swaySpeed: number;       // 摇摆频率
  swayAmp: number;         // 摇摆振幅
}

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
  private readonly MAX_PARTICLES: number = 600;
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

    // 2. 机尾物理基准点（根据飞机屏幕旋转角计算）
    const planeRotRad = this.planeScreenRotation * (Math.PI / 180.0);
    const curTailX = this.canvasWidth / 2.0 + this.planeScreenOffsetX - Math.sin(planeRotRad) * 24.0;
    const curTailY = this.canvasHeight / 2.0 + this.planeScreenOffsetY + Math.cos(planeRotRad) * 24.0;

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

    const TRAIL_LENGTH = 480.0;
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

      // 如果已到航线最起点，沿最后一段切线方向延伸补足 480vp
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
      const totalLateral = p.lateralOffset + progress * p.driftLateral + sway;

      p.x = spineX + normX * totalLateral;
      p.y = spineY + normY * totalLateral;
      p.rotation += p.vRot;

      if (this.trailId === 'stardust') {
        this.renderStardustParticle(ctx, p, progress);
      } else if (this.trailId === 'bubbles') {
        this.renderBubbleParticle(ctx, p, progress);
      } else if (this.trailId === 'contrail') {
        this.renderContrailParticle(ctx, p, progress);
      } else if (this.trailId === 'melody' || this.trailId === 'aurora') {
        this.renderMelodyParticle(ctx, p, progress);
      } else {
        this.renderRainbowParticle(ctx, p, progress);
      }
    }

    this.frameCount++;
  }

  /**
   * 🌟 依据当前尾迹特效生成新粒子 (480vp 物理惯性流光版)
   */
  private spawnParticles() {
    if (this.particles.length >= this.MAX_PARTICLES) {
      return;
    }

    const planeRotRad = this.planeScreenRotation * (Math.PI / 180.0);
    const tailX = this.canvasWidth / 2 + this.planeScreenOffsetX - Math.sin(planeRotRad) * 24.0;
    const tailY = this.canvasHeight / 2 + this.planeScreenOffsetY + Math.cos(planeRotRad) * 24.0;
    const normX = Math.cos(planeRotRad);
    const normY = Math.sin(planeRotRad);

    if (this.trailId === 'stardust') {
      // ✨ 星光粉尘：修长璀璨的银河星屑长河 (寿命 150~200 帧，形成贯穿 480vp 弯曲银河拖尾)
      if (this.frameCount % 2 === 0) {
        const spread = (Math.random() - 0.5) * 8.0;
        const colors = ['#FFE066', '#FFD700', '#FFFFFF', '#FFF3B0', '#FBBF24', '#FDE68A'];
        const chosenColor = colors[Math.floor(Math.random() * colors.length)];
        
        const rand = Math.random();
        const shape = rand < 0.55 ? 0 : (rand < 0.8 ? 2 : 1);
        const life = 150 + Math.floor(Math.random() * 50);

        this.particles.push({
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: (Math.random() - 0.5) * 6.0,
          size: shape === 0 ? (1.5 + Math.random() * 2.0) : (shape === 2 ? 3.5 + Math.random() * 2.5 : 4.5 + Math.random() * 3.0),
          maxSize: 10.0,
          alpha: 0.95,
          maxLife: life,
          life: life,
          color: chosenColor,
          subColor: '#FFFFFF',
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.06,
          shapeType: shape,
          swayPhase: Math.random() * Math.PI * 2,
          swaySpeed: 0.03 + Math.random() * 0.02,
          swayAmp: 2.5
        });
      }
    } else if (this.trailId === 'bubbles') {
      // 🫧 解压梦幻泡泡：长长的水漾马卡龙气泡之河 (寿命 150~210 帧，贯穿 480vp 弯曲气泡链)
      if (this.frameCount % 2 === 0) {
        const spread = (Math.random() - 0.5) * 10.0;
        const bubbleColors = [
          'rgba(244, 114, 182, 0.72)',
          'rgba(56, 189, 248, 0.72)',
          'rgba(167, 139, 250, 0.72)',
          'rgba(52, 211, 153, 0.72)',
          'rgba(251, 146, 60, 0.72)'
        ];
        const chosenColor = bubbleColors[Math.floor(Math.random() * bubbleColors.length)];
        const initSize = 4.0 + Math.random() * 4.5;
        const maxSize = initSize * (1.6 + Math.random() * 0.6);
        const life = 150 + Math.floor(Math.random() * 60);

        this.particles.push({
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: (Math.random() - 0.5) * 8.0,
          size: initSize,
          maxSize: maxSize,
          alpha: 0.88,
          maxLife: life,
          life: life,
          color: chosenColor,
          subColor: '#FFFFFF',
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.02,
          shapeType: 0,
          swayPhase: Math.random() * Math.PI * 2,
          swaySpeed: 0.03 + Math.random() * 0.02,
          swayAmp: 3.0
        });
      }
    } else if (this.trailId === 'contrail') {
      // ☁️ 经典凝结尾迹云：左右双发高空极长羽流水汽 (寿命 180~240 帧，贯穿 500vp 弯曲气溶胶)
      const count = 2;
      const offsets = [-7.0, 7.0];
      for (let k = 0; k < count; k++) {
        const lateralOffset = offsets[k] + (Math.random() - 0.5) * 2.0;
        const initSize = 4.5 + Math.random() * 3.5;
        const maxSize = initSize * (2.8 + Math.random() * 1.2);
        const life = 170 + Math.floor(Math.random() * 60);

        this.particles.push({
          x: tailX + normX * lateralOffset,
          y: tailY + normY * lateralOffset,
          lateralOffset: lateralOffset,
          driftLateral: (k === 0 ? -1 : 1) * (3.0 + Math.random() * 3.0),
          size: initSize,
          maxSize: maxSize,
          alpha: 0.75,
          maxLife: life,
          life: life,
          color: 'rgba(255, 255, 255, 0.85)',
          subColor: 'rgba(241, 245, 249, 0.50)',
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.02,
          shapeType: 3,
          swayPhase: 0,
          swaySpeed: 0,
          swayAmp: 0
        });
      }
    } else if (this.trailId === 'melody' || this.trailId === 'aurora') {
      // 🎵 治愈律动音符：修长舒展的五线谱旋律长河 (每5帧发射，寿命 150~210 帧，长达 480vp 弯曲乐谱)
      if (this.frameCount % 5 === 0) {
        const spread = (Math.random() - 0.5) * 6.0;
        const melodyColors = [
          '#AF52DE', '#0EA5E9', '#F59E0B', '#F43F5E', '#10B981', '#6366F1'
        ];
        const chosenColor = melodyColors[Math.floor(Math.random() * melodyColors.length)];
        const rand = Math.random();
        const shape = rand < 0.6 ? 0 : 1;
        const initSize = 5.0 + Math.random() * 2.5;
        const life = 150 + Math.floor(Math.random() * 60);

        this.particles.push({
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: (Math.random() - 0.5) * 4.0,
          size: initSize,
          maxSize: 9.0,
          alpha: 0.92,
          maxLife: life,
          life: life,
          color: chosenColor,
          subColor: '#FFFFFF',
          rotation: (Math.random() - 0.5) * 0.25,
          vRot: (Math.random() - 0.5) * 0.02,
          shapeType: shape,
          swayPhase: Math.random() * Math.PI * 2,
          swaySpeed: 0.04 + Math.random() * 0.02,
          swayAmp: 2.0
        });
      }

      // 偶发极细微光旋律星尘 (每 8 帧 1 颗)
      if (this.frameCount % 8 === 0) {
        const spread = (Math.random() - 0.5) * 5.0;
        const life = 130 + Math.floor(Math.random() * 40);

        this.particles.push({
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: 0,
          size: 1.5 + Math.random() * 1.5,
          maxSize: 3.0,
          alpha: 0.85,
          maxLife: life,
          life: life,
          color: '#FDE68A',
          subColor: '#FFFFFF',
          rotation: 0,
          vRot: 0,
          shapeType: 3,
          swayPhase: 0,
          swaySpeed: 0,
          swayAmp: 0
        });
      }
    } else {
      // 🌈 缤纷彩虹：喷射 6 色彩虹微星 (寿命 150~200 帧，长达 480vp 弯曲彩虹长河)
      if (this.frameCount % 2 === 0) {
        const spread = (Math.random() - 0.5) * 8.0;
        const rainbowPalette = ['#AF52DE', '#0A84FF', '#34C759', '#FFCC00', '#FF9500', '#FF3B30'];
        const chosenColor = rainbowPalette[Math.floor(Math.random() * rainbowPalette.length)];
        const life = 150 + Math.floor(Math.random() * 50);

        this.particles.push({
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: (Math.random() - 0.5) * 5.0,
          size: 3.0 + Math.random() * 3.0,
          maxSize: 8.0,
          alpha: 0.92,
          maxLife: life,
          life: life,
          color: chosenColor,
          subColor: '#FFFFFF',
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.04,
          shapeType: 1,
          swayPhase: 0,
          swaySpeed: 0,
          swayAmp: 0
        });
      }
    }
  }

  /**
   * ✨ 绘制星光粉尘粒子（具备出生放量 Pop-In、星光闪烁 Twinkle、平滑淡出 Fade-Out）
   */
  private renderStardustParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
    let scale = 1.0;
    if (progress < 0.08) {
      scale = progress / 0.08;
    } else {
      scale = 1.0 - (progress - 0.08) * 0.2;
    }

    let alpha = p.alpha;
    if (progress < 0.05) {
      alpha = p.alpha * (progress / 0.05);
    } else if (progress > 0.85) {
      alpha = p.alpha * Math.pow(1.0 - (progress - 0.85) / 0.15, 1.4);
    }

    const twinkle = 0.85 + 0.15 * Math.sin(this.frameCount * 0.35 + p.rotation * 3);
    const curAlpha = Math.max(0, Math.min(1.0, alpha * twinkle));
    const curSize = Math.max(0.4, p.size * scale);

    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rotation);
    ctx.globalAlpha = curAlpha;

    if (p.shapeType === 1) {
      // 璀璨八角星芒
      ctx.fillStyle = p.color;
      ctx.beginPath();
      const rOut = curSize * 1.3;
      const rIn = curSize * 0.24;
      for (let i = 0; i < 8; i++) {
        const r = (i % 2 === 0) ? rOut : rIn;
        const angle = (i * Math.PI) / 4;
        const px = Math.cos(angle) * r;
        const py = Math.sin(angle) * r;
        if (i === 0) {
          ctx.moveTo(px, py);
        } else {
          ctx.lineTo(px, py);
        }
      }
      ctx.closePath();
      ctx.fill();

      // 中心纯白闪光核
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(0, 0, Math.max(0.6, curSize * 0.25), 0, Math.PI * 2);
      ctx.fill();
    } else if (p.shapeType === 2) {
      // 旋转钻石星屑
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.moveTo(0, -curSize * 1.2);
      ctx.lineTo(curSize * 0.5, 0);
      ctx.lineTo(0, curSize * 1.2);
      ctx.lineTo(-curSize * 0.5, 0);
      ctx.closePath();
      ctx.fill();
    } else {
      // 碎金微粒
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(0, 0, curSize * 0.7, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  /**
   * 🫧 绘制梦幻泡泡（具备水漾渐变、极细白圈高光、反光点、左右摇曳、破裂消散动画）
   */
  private renderBubbleParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
    let curSize = p.size;
    if (progress < 0.1) {
      curSize = p.size * (progress / 0.1);
    } else {
      curSize = p.size + (p.maxSize - p.size) * ((progress - 0.1) / 0.9);
    }

    let curAlpha = p.alpha;
    if (progress > 0.85) {
      curAlpha = p.alpha * Math.pow(1.0 - (progress - 0.85) / 0.15, 1.4);
    }
    curAlpha = Math.max(0, Math.min(1.0, curAlpha));

    const sway = Math.sin(this.frameCount * p.swaySpeed + p.swayPhase) * (curSize * 0.4);

    ctx.save();
    ctx.translate(p.x + sway, p.y);
    ctx.globalAlpha = curAlpha;

    // 1. 半透明水漾内胆
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(0, 0, curSize, 0, Math.PI * 2);
    ctx.fill();

    // 2. 晶莹极细外圈高光
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.90)';
    ctx.lineWidth = Math.max(0.8, curSize * 0.1);
    ctx.beginPath();
    ctx.arc(0, 0, curSize, 0, Math.PI * 2);
    ctx.stroke();

    // 3. 左上方微型反光斑
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(-curSize * 0.38, -curSize * 0.38, Math.max(0.8, curSize * 0.22), 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }

  /**
   * ☁️ 绘制凝结尾迹云（蓬松多层纯白水汽雾化羽流）
   */
  private renderContrailParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
    const curSize = p.size + (p.maxSize - p.size) * progress;
    let curAlpha = p.alpha;
    if (progress > 0.82) {
      curAlpha = p.alpha * Math.pow(1.0 - (progress - 0.82) / 0.18, 1.4);
    }
    curAlpha = Math.max(0, Math.min(1.0, curAlpha));

    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.globalAlpha = curAlpha;

    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(0, 0, curSize, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }

  /**
   * 🎵 绘制治愈律动音符（具备节拍律动跳跃、单音符♪、双连音♫、四分音符♩、中心高光晶莹感）
   */
  private renderMelodyParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
    let scale = 1.0;
    if (progress < 0.08) {
      scale = progress / 0.08;
    } else {
      scale = 1.0 - (progress - 0.08) * 0.2;
    }

    let alpha = p.alpha;
    if (progress < 0.05) {
      alpha = p.alpha * (progress / 0.05);
    } else if (progress > 0.85) {
      alpha = p.alpha * Math.pow(1.0 - (progress - 0.85) / 0.15, 1.4);
    }

    // 音符随节拍律动跳跃位移
    const sway = Math.sin(p.swayPhase + this.frameCount * p.swaySpeed) * 3.5;
    const curAlpha = Math.max(0, Math.min(1.0, alpha));
    const curSize = Math.max(0.6, p.size * scale);

    ctx.save();
    ctx.translate(p.x + sway, p.y);
    ctx.rotate(p.rotation);
    ctx.globalAlpha = curAlpha;

    if (p.shapeType === 0) {
      // 🎶 单八分音符 ♪
      ctx.fillStyle = p.color;
      // 1. 倾斜椭圆音头
      ctx.beginPath();
      const headRadiusX = curSize * 0.46;
      const headRadiusY = curSize * 0.32;
      ctx.ellipse(-curSize * 0.25, curSize * 0.4, headRadiusX, headRadiusY, -Math.PI / 6, 0, Math.PI * 2);
      ctx.fill();

      // 2. 竖直向上符干
      const stemWidth = Math.max(1.0, curSize * 0.14);
      const stemHeight = curSize * 1.3;
      const stemX = -curSize * 0.25 + headRadiusX * 0.7;
      const stemY = curSize * 0.4 - stemHeight;
      ctx.fillRect(stemX, stemY, stemWidth, stemHeight);

      // 3. 飘逸符尾
      ctx.beginPath();
      ctx.moveTo(stemX + stemWidth, stemY);
      ctx.bezierCurveTo(
        stemX + stemWidth + curSize * 0.6, stemY + curSize * 0.3,
        stemX + stemWidth + curSize * 0.7, stemY + curSize * 0.7,
        stemX + stemWidth + curSize * 0.2, stemY + curSize * 1.0
      );
      ctx.lineWidth = stemWidth * 1.1;
      ctx.strokeStyle = p.color;
      ctx.stroke();

      // 4. 音头晶莹微光斑
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(-curSize * 0.3, curSize * 0.34, Math.max(0.4, curSize * 0.12), 0, Math.PI * 2);
      ctx.fill();

    } else if (p.shapeType === 1) {
      // 🎶 双连八分音符 ♫
      ctx.fillStyle = p.color;
      const headRadiusX = curSize * 0.38;
      const headRadiusY = curSize * 0.26;
      const stemWidth = Math.max(1.0, curSize * 0.12);
      const stemHeight = curSize * 1.2;
      const noteSpacing = curSize * 0.95;

      // 左音头与符干
      const leftX = -noteSpacing / 2;
      ctx.beginPath();
      ctx.ellipse(leftX, curSize * 0.4, headRadiusX, headRadiusY, -Math.PI / 6, 0, Math.PI * 2);
      ctx.fill();
      const stem1X = leftX + headRadiusX * 0.65;
      const stem1Y = curSize * 0.4 - stemHeight;
      ctx.fillRect(stem1X, stem1Y, stemWidth, stemHeight);

      // 右音头与符干
      const rightX = noteSpacing / 2;
      ctx.beginPath();
      ctx.ellipse(rightX, curSize * 0.32, headRadiusX, headRadiusY, -Math.PI / 6, 0, Math.PI * 2);
      ctx.fill();
      const stem2X = rightX + headRadiusX * 0.65;
      const stem2Y = curSize * 0.32 - stemHeight;
      ctx.fillRect(stem2X, stem2Y, stemWidth, stemHeight);

      // 顶部加粗连接连梁
      ctx.beginPath();
      ctx.moveTo(stem1X, stem1Y);
      ctx.lineTo(stem2X + stemWidth, stem2Y);
      ctx.lineTo(stem2X + stemWidth, stem2Y + stemWidth * 2.2);
      ctx.lineTo(stem1X, stem1Y + stemWidth * 2.2);
      ctx.closePath();
      ctx.fill();

      // 微光斑
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(leftX - 0.5, curSize * 0.35, Math.max(0.3, curSize * 0.1), 0, Math.PI * 2);
      ctx.arc(rightX - 0.5, curSize * 0.27, Math.max(0.3, curSize * 0.1), 0, Math.PI * 2);
      ctx.fill();

    } else if (p.shapeType === 2) {
      // 🎶 四分音符 ♩
      ctx.fillStyle = p.color;
      const headRadiusX = curSize * 0.46;
      const headRadiusY = curSize * 0.32;
      ctx.beginPath();
      ctx.ellipse(-curSize * 0.2, curSize * 0.35, headRadiusX, headRadiusY, -Math.PI / 6, 0, Math.PI * 2);
      ctx.fill();

      const stemWidth = Math.max(1.0, curSize * 0.14);
      const stemHeight = curSize * 1.2;
      const stemX = -curSize * 0.2 + headRadiusX * 0.7;
      const stemY = curSize * 0.35 - stemHeight;
      ctx.fillRect(stemX, stemY, stemWidth, stemHeight);

      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(-curSize * 0.25, curSize * 0.3, Math.max(0.4, curSize * 0.12), 0, Math.PI * 2);
      ctx.fill();

    } else {
      // 🎶 律动金色微光音尘（跳动的旋律星尘）
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(0, 0, curSize * 0.6, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(0, 0, curSize * 0.25, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  /**
   * 🌈 绘制经典彩虹微星（旋转八角星芒）
   */
  private renderRainbowParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
    let curAlpha = p.alpha;
    if (progress > 0.7) {
      curAlpha = p.alpha * (1.0 - (progress - 0.7) / 0.3);
    }
    curAlpha = Math.max(0, Math.min(1.0, curAlpha));
    const curSize = p.size * (1.0 - progress * 0.3);

    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rotation);
    ctx.globalAlpha = curAlpha;

    ctx.fillStyle = p.color;
    ctx.beginPath();
    const rOut = curSize;
    const rIn = curSize * 0.25;
    for (let i = 0; i < 8; i++) {
      const r = (i % 2 === 0) ? rOut : rIn;
      const angle = (i * Math.PI) / 4;
      const px = Math.cos(angle) * r;
      const py = Math.sin(angle) * r;
      if (i === 0) {
        ctx.moveTo(px, py);
      } else {
        ctx.lineTo(px, py);
      }
    }
    ctx.closePath();
    ctx.fill();

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
