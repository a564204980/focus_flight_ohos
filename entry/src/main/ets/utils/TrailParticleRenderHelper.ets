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

/**
 * 🎨 专注飞行屏幕物理惯性粒子模型（全应用通用）
 */
export interface TrailParticle {
  x: number;               // 屏幕实时渲染 X (vp)
  y: number;               // 屏幕实时渲染 Y (vp)
  lateralOffset?: number;  // 航线法线横向初始偏移 (vp)
  driftLateral?: number;   // 随时间的微风横向飘散
  size: number;            // 初始尺寸 (vp)
  maxSize: number;         // 最大膨胀尺寸 (vp)
  alpha: number;           // 基础透明度
  maxLife: number;         // 总寿命 (帧数)
  life: number;            // 剩余寿命 (帧数)
  color: string;           // 主颜色
  subColor?: string;       // 辅颜色/高光色
  rotation: number;        // 当前旋转角 (弧度)
  vRot: number;            // 自旋角速度 (弧度/帧)
  shapeType: number;       // 粒子形状: 0-微星/单音符/气泡, 1-八角星/双连音, 2-钻石星屑/四分音符, 3-水汽云/音尘
  swayPhase: number;       // 摇摆相位
  swaySpeed: number;       // 摇摆频率
  swayAmp: number;         // 摇摆振幅
  trailType?: string;      // 尾迹类型标识
}

/**
 * 💫 专注飞行通用粒子渲染与物理生成引擎（大地图与设置视窗 100% 共享统一的物理与绘制逻辑）
 */
export class TrailParticleRenderHelper {
  /**
   * 🌟 统一粒子生成工厂（大地图与预览视窗 100% 一致的发射频率、大小、寿命与色彩）
   */
  public static spawnParticlesForTrail(
    trailId: string,
    tailX: number,
    tailY: number,
    frameCount: number,
    normX: number = 0,
    normY: number = 1
  ): TrailParticle[] {
    const result: TrailParticle[] = [];

    if (trailId === 'stardust') {
      // ✨ 星光粉尘：修长璀璨的银河星屑 (每 2 帧发射一颗，寿命 85~120 帧)
      if (frameCount % 2 === 0) {
        const spread = (Math.random() - 0.5) * 8.0;
        const colors = ['#FFE066', '#FFD700', '#FFFFFF', '#FFF3B0', '#FBBF24', '#FDE68A'];
        const chosenColor = colors[Math.floor(Math.random() * colors.length)];
        const rand = Math.random();
        const shape = rand < 0.55 ? 0 : (rand < 0.8 ? 2 : 1);
        const life = 85 + Math.floor(Math.random() * 35);

        result.push({
          trailType: 'stardust',
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
    } else if (trailId === 'bubbles') {
      // 🫧 解压梦幻泡泡：水漾马卡龙气泡之河 (每 2 帧发射一颗，寿命 85~125 帧)
      if (frameCount % 2 === 0) {
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
        const life = 85 + Math.floor(Math.random() * 40);

        result.push({
          trailType: 'bubbles',
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
    } else if (trailId === 'contrail') {
      // ☁️ 经典凝结尾迹云：左右双发高空水汽云 (每帧发射 2 颗，寿命 95~135 帧)
      const offsets = [-7.0, 7.0];
      for (let k = 0; k < 2; k++) {
        const lateralOffset = offsets[k] + (Math.random() - 0.5) * 2.0;
        const initSize = 4.5 + Math.random() * 3.5;
        const maxSize = initSize * (2.8 + Math.random() * 1.2);
        const life = 95 + Math.floor(Math.random() * 40);

        result.push({
          trailType: 'contrail',
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
    } else if (trailId === 'melody' || trailId === 'aurora') {
      // 🎵 治愈律动音符：修长舒展的五线谱旋律长河 (每 4 帧发射一个音符)
      if (frameCount % 4 === 0) {
        const spread = (Math.random() - 0.5) * 24.0;
        const melodyColors = [
          '#AF52DE', '#0EA5E9', '#F59E0B', '#F43F5E', '#10B981', '#6366F1'
        ];
        const chosenColor = melodyColors[Math.floor(Math.random() * melodyColors.length)];
        const rand = Math.random();
        const shape = rand < 0.5 ? 0 : (rand < 0.85 ? 1 : 2);
        const initSize = 5.2 + Math.random() * 2.8;
        const life = 95 + Math.floor(Math.random() * 40);

        result.push({
          trailType: 'melody',
          x: tailX + normX * spread,
          y: tailY + normY * spread,
          lateralOffset: spread,
          driftLateral: (Math.random() - 0.5) * 8.0,
          size: initSize,
          maxSize: 10.0,
          alpha: 0.95,
          maxLife: life,
          life: life,
          color: chosenColor,
          subColor: '#FFFFFF',
          rotation: (Math.random() - 0.5) * 0.25,
          vRot: (Math.random() - 0.5) * 0.02,
          shapeType: shape,
          swayPhase: Math.random() * Math.PI * 2,
          swaySpeed: 0.05 + Math.random() * 0.03,
          swayAmp: 4.5
        });
      }

      // 偶发极细微光旋律星尘 (每 6 帧 1 颗)
      if (frameCount % 6 === 0) {
        const spread = (Math.random() - 0.5) * 20.0;
        const life = 80 + Math.floor(Math.random() * 30);

        result.push({
          trailType: 'melody',
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
    }

    return result;
  }

  /**
   * 🎼 绘制 5 条随节拍律动起伏的彩色五线谱流动线 (全屏/大视窗通用)
   */
  public static renderMelodyStaff(
    ctx: CanvasRenderingContext2D,
    tailX: number,
    centerY: number,
    frameCount: number,
    alphaMultiplier: number,
    trailLength: number = 260.0
  ) {
    if (alphaMultiplier <= 0.01) return;

    ctx.save();
    const staffOffsets = [-13.0, -6.5, 0.0, 6.5, 13.0];
    const staffAlphas = [0.35, 0.50, 0.75, 0.50, 0.35];
    const staffColors = [
      'rgba(175, 82, 222, ', // 浅紫
      'rgba(14, 165, 233, ',  // 蔚蓝
      'rgba(255, 255, 255, ', // 主律动亮白
      'rgba(52, 211, 153, ',  // 翡翠绿
      'rgba(251, 146, 60, '   // 暖橙
    ];

    const step = 4.0;
    const maxTrailDrawDist = Math.min(tailX + 40, trailLength);
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

      let prevPtX = tailX;
      let prevPtY = centerY + baseLateral;

      for (let s = 1; s <= sampleCount; s++) {
        const curDist = s * step;
        const curPtX = tailX - curDist;
        const progress = curDist / maxTrailDrawDist;

        // 波动波形计算：与大地图完全相同的流体起伏波幅
        const envelope = Math.sin(progress * Math.PI);
        const wave = Math.sin(curDist * 0.045 - frameCount * 0.08 + lineIdx * 0.70) * 5.5 * envelope;
        const totalLat = baseLateral + wave;
        const curPtY = centerY + totalLat;

        let fade = 1.0;
        if (progress < 0.10) {
          fade = progress / 0.10;
        } else if (progress > 0.45) {
          fade = Math.pow(1.0 - (progress - 0.45) / 0.55, 1.6);
        }
        const segAlpha = Math.max(0, Math.min(1.0, baseAlpha * fade * alphaMultiplier));

        ctx.beginPath();
        ctx.strokeStyle = `${colorPrefix}${segAlpha.toFixed(3)})`;
        ctx.lineWidth = lineWidth;
        ctx.lineCap = 'round';
        ctx.moveTo(prevPtX, prevPtY);
        ctx.lineTo(curPtX, curPtY);
        ctx.stroke();

        prevPtX = curPtX;
        prevPtY = curPtY;
      }
    }
    ctx.restore();
  }

  /**
   * ✨ 绘制星光粉尘粒子（具备出生放量 Pop-In、星光闪烁 Twinkle、平滑淡出 Fade-Out）
   */
  public static renderStardustParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number, frameCount: number) {
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

    const twinkle = 0.85 + 0.15 * Math.sin(frameCount * 0.35 + p.rotation * 3);
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
  public static renderBubbleParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number, frameCount: number) {
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

    const sway = Math.sin(frameCount * p.swaySpeed + p.swayPhase) * (curSize * 0.4);

    ctx.save();
    ctx.translate(p.x, p.y + sway);
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
  public static renderContrailParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
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
  public static renderMelodyParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number, frameCount: number) {
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
    const sway = Math.sin(p.swayPhase + frameCount * p.swaySpeed) * 3.5;
    const curAlpha = Math.max(0, Math.min(1.0, alpha));
    const curSize = Math.max(0.6, p.size * scale);

    ctx.save();
    ctx.translate(p.x, p.y + sway);
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
  public static renderRainbowParticle(ctx: CanvasRenderingContext2D, p: TrailParticle, progress: number) {
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
}
