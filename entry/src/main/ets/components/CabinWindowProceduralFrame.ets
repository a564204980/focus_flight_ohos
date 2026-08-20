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
 * 纯代码程序化渲染客机舷窗框架组件 (CabinWindowProceduralFrame)
 * 完美还原图 1 顶级视觉质感 + 120fps 满帧性能：
 * 1. 100% 原生多层精密渐变、物理高光倒角、顶部遮阳槽与玻璃内阴影 (仅初始化渲染 1 次)；
 * 2. 遮阳板拉下时的光晕消退采用 GPU 硬件 Opacity 遮罩层，零 CPU 重绘，零卡顿。
 */
@Component
export struct CabinWindowProceduralFrame {
  @Prop frameWidth: number = 272;
  @Prop frameHeight: number = 442;
  @Prop lightingMode: string = 'day';
  @Prop shadeProgress: number = 0.0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private drawPhotorealisticFrame(): void {
    const ctx = this.context;
    const w = this.frameWidth;
    const h = this.frameHeight;
    if (w <= 0 || h <= 0) {
      return;
    }

    ctx.clearRect(0, 0, w, h);
    ctx.save();

    const cx = w / 2;
    const cy = h / 2;

    // 视窗开孔几何尺寸 (黄金比例 1 : 1.58 跑道圆角矩形)
    const gw = w * 0.68;
    const gh = h * 0.70;
    const gr = gw * 0.38;

    // 外框几何尺寸
    const fw = w * 0.94;
    const fh = h * 0.96;
    const fr = fw * 0.44;

    // 1. 周围纯黑底色填满
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, w, h);

    // 2. 客舱外壁内凹柔和光影 (Outer Wall Bezel & Ambient Falloff)
    for (let i = 18; i >= 0; i--) {
      const pad = i * 2.0;
      const bw = fw - pad;
      const bh = fh - pad;
      const br = Math.max(8, fr - pad * 0.5);
      const t = i / 18.0;

      const gray = Math.floor(18 * (1.0 - t));
      ctx.fillStyle = `rgb(${gray}, ${gray + 1}, ${gray + 3})`;
      this.drawRoundedRectPath(ctx, cx - bw / 2, cy - bh / 2, bw, bh, br);
      ctx.fill();
    }

    // 3. 主框立体斜面外轮廓线
    const mw = fw - 16;
    const mh = fh - 16;
    const mr = fr - 8;
    ctx.strokeStyle = 'rgba(55, 60, 75, 0.45)';
    ctx.lineWidth = 1.5;
    this.drawRoundedRectPath(ctx, cx - mw / 2, cy - mh / 2, mw, mh, mr);
    ctx.stroke();

    // 4. 中层导角斜切过渡层 (Mid-Frame Bevel Shroud)
    for (let i = 12; i >= 0; i--) {
      const t = i / 12.0;
      const curW = gw + 36 + (mw - (gw + 36)) * t;
      const curH = gh + 36 + (mh - (gh + 36)) * t;
      const curR = gr + 18 + (mr - (gr + 18)) * t;

      const baseVal = Math.floor(22 + 16 * (1.0 - t));
      ctx.fillStyle = `rgb(${baseVal}, ${baseVal + 2}, ${baseVal + 5})`;
      this.drawRoundedRectPath(ctx, cx - curW / 2, cy - curH / 2, curW, curH, curR);
      ctx.fill();
    }

    // 5. 顶部遮光板收纳槽与提手凹痕 (Top Shade Pocket & Grip Notch)
    const slotY = cy - gh / 2 + 12;
    const slotW = gw * 0.72;
    const slotH = 34;

    ctx.fillStyle = '#0E1015';
    ctx.beginPath();
    ctx.ellipse(cx, slotY, slotW / 2, slotH / 2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(60, 66, 80, 0.50)';
    ctx.lineWidth = 1.0;
    ctx.stroke();

    // 提手凹槽
    ctx.fillStyle = '#08090C';
    ctx.beginPath();
    ctx.ellipse(cx, slotY - 4, 28, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(80, 88, 105, 0.60)';
    ctx.lineWidth = 0.8;
    ctx.stroke();

    // 6. 内圈滑轨与双层精密台阶 (Inner Frame Track Ring)
    const trW = gw + 16;
    const trH = gh + 16;
    const trR = gr + 8;
    ctx.fillStyle = '#181A20';
    this.drawRoundedRectPath(ctx, cx - trW / 2, cy - trH / 2, trW, trH, trR);
    ctx.fill();
    ctx.strokeStyle = 'rgba(40, 44, 55, 0.85)';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // 7. 内圈受光高光轮廓 (Specular Rim Highlight & Ambient Edge Glow) —— 图 1 原生顶级光影
    for (let i = 10; i >= 1; i--) {
      const rimW = gw + i * 1.6;
      const rimH = gh + i * 1.6;
      const rimR = gr + i * 0.8;
      const alpha = Math.pow((11 - i) / 10.0, 1.3) * 0.85;

      const rimGrad = ctx.createLinearGradient(cx, cy - gh / 2, cx, cy + gh / 2);
      rimGrad.addColorStop(0.0, `rgba(40, 44, 55, ${alpha * 0.3})`);
      rimGrad.addColorStop(0.25, `rgba(220, 230, 245, ${alpha * 0.80})`);
      rimGrad.addColorStop(0.70, `rgba(245, 250, 255, ${alpha * 0.95})`);
      rimGrad.addColorStop(1.0, `rgba(230, 240, 255, ${alpha * 0.85})`);

      ctx.strokeStyle = rimGrad;
      ctx.lineWidth = 1.2;
      this.drawRoundedRectPath(ctx, cx - rimW / 2, cy - rimH / 2, rimW, rimH, rimR);
      ctx.stroke();
    }

    // 8. 核心透光开孔 (Punch 100% Transparent Aperture Cutout)
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = '#000000';
    this.drawRoundedRectPath(ctx, cx - gw / 2, cy - gh / 2, gw, gh, gr);
    ctx.fill();

    // 9. 恢复正常混合模式并绘制玻璃边缘微弱环境内阴影 (Subtle Inner Glass AO)
    ctx.globalCompositeOperation = 'source-over';
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.40)';
    ctx.lineWidth = 1.0;
    this.drawRoundedRectPath(ctx, cx - gw / 2 + 0.5, cy - gh / 2 + 0.5, gw - 1, gh - 1, gr - 0.5);
    ctx.stroke();

    ctx.restore();
  }

  private drawRoundedRectPath(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    w: number,
    h: number,
    r: number
  ): void {
    const radius = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.arcTo(x + w, y, x + w, y + radius, radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
    ctx.lineTo(x + radius, y + h);
    ctx.arcTo(x, y + h, x, y + h - radius, radius);
    ctx.lineTo(x, y + radius);
    ctx.arcTo(x, y, x + radius, y, radius);
    ctx.closePath();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 图 1 原生极致质感 Canvas (仅挂载初始化绘制一次，零 CPU 拖拽重绘开销)
      Canvas(this.context)
        .width(this.frameWidth)
        .height(this.frameHeight)
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.drawPhotorealisticFrame();
        })

      // 2. 遮阳板拉下时的极暗消光遮罩层 (GPU 原生硬件合成，拉下时遮盖内圈高光，满帧丝滑)
      Stack()
        .width(this.frameWidth * 0.68 + 18)
        .height(this.frameHeight * 0.70 + 18)
        .borderRadius(this.frameWidth * 0.68 * 0.38 + 9)
        .border({
          width: 9,
          color: '#15171C'
        })
        .opacity(this.shadeProgress)
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.frameWidth)
    .height(this.frameHeight)
    .hitTestBehavior(HitTestMode.None)
  }
}
