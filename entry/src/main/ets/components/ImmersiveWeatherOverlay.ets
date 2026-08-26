/*
 * ImmersiveWeatherOverlay.ets
 * 电影级渐进式天气演化系统 (天色渐暗 -> 细雨初起 -> 暴雨成型 -> 惊雷炸响 -> 平滑放晴)
 */

interface RainParticle {
  relX: number; // 相对于天气中心的相对 X 偏移
  relY: number; // 相对于天气中心的相对 Y 偏移
  length: number;
  speed: number;
  baseOpacity: number;
  width: number;
  threshold: number; // 激活阈值 (0.0 ~ 1.0)，决定在雨势演化的哪个阶段登场
}

interface SnowParticle {
  relX: number;
  relY: number;
  radius: number;
  speedY: number;
  speedX: number;
  opacity: number;
  swayOffset: number;
  threshold: number;
}

@Component
export struct ImmersiveWeatherOverlay {
  @Watch('onWeatherTypeChange') @Prop weatherType: 'clear' | 'thunderstorm' | 'snow' = 'thunderstorm';
  @Prop planeScreenOffsetX: number = 0; // 飞机/天气中心相对于屏幕中心的 X 偏移 (拖拽地图时实时变动)
  @Prop planeScreenOffsetY: number = 0; // 飞机/天气中心相对于屏幕中心的 Y 偏移 (拖拽地图时实时变动)

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private timerId: number = -1;
  private lightningTimerId: number = -1;
  
  private rainDrops: RainParticle[] = [];
  private snowflakes: SnowParticle[] = [];
  
  private canvasWidth: number = 400;
  private canvasHeight: number = 800;

  // 物理阵风与呼吸扰动时间
  private timeTick: number = 0;

  // 🌧️ 天气演化生命周期进度 (0.0: 晴朗无雨 -> 0.3: 天暗小雨 -> 0.7: 中雨 -> 1.0: 暴雨雷鸣)
  private weatherProgress: number = 0;
  private targetWeatherProgress: number = 0;
  private currentActiveWeather: 'clear' | 'thunderstorm' | 'snow' = 'clear';

  // ⚡ 闪电爆发强度 (0.0 ~ 1.0)
  private lightningIntensity: number = 0;

  aboutToAppear(): void {
    this.handleWeatherChange();
  }

  aboutToDisappear(): void {
    this.stopAllTimers();
  }

  private onWeatherTypeChange(): void {
    this.handleWeatherChange();
  }

  private stopAllTimers(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.lightningTimerId !== -1) {
      clearTimeout(this.lightningTimerId);
      this.lightningTimerId = -1;
    }
    this.lightningIntensity = 0;
    if (this.context && this.canvasWidth > 0 && this.canvasHeight > 0) {
      try {
        this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
      } catch (_e) {}
    }
  }

  private handleWeatherChange(): void {
    if (this.weatherType !== 'clear') {
      this.currentActiveWeather = this.weatherType;
      this.targetWeatherProgress = 1.0; // 目标：逐渐演化到大雨/大雪
      this.initParticles();

      // 确保帧循环启动
      if (this.timerId === -1) {
        this.timerId = setInterval(() => {
          this.renderFrame();
        }, 1000 / 60);
      }
    } else {
      // 切换到晴天：不立即切断，而是渐进放晴
      this.targetWeatherProgress = 0.0;
      if (this.lightningTimerId !== -1) {
        clearTimeout(this.lightningTimerId);
        this.lightningTimerId = -1;
      }
      this.lightningIntensity = 0;
    }
  }

  private initParticles(): void {
    const weatherRadius = 340; // 局部雷暴气象团半径

    if (this.currentActiveWeather === 'thunderstorm') {
      this.rainDrops = [];
      for (let i = 0; i < 140; i++) {
        const isNear = Math.random() > 0.45;
        // 分配梯度激活阈值：前 20% 雨滴最早登场(细雨)，后面的雨滴随着暴雨升级陆续加入
        const thresh = Math.random() * 0.85;

        this.rainDrops.push({
          relX: (Math.random() - 0.5) * (weatherRadius * 2.2),
          relY: (Math.random() - 0.5) * (weatherRadius * 2.2),
          length: isNear ? (Math.random() * 12 + 18) : (Math.random() * 8 + 10),
          speed: isNear ? (Math.random() * 8 + 26) : (Math.random() * 6 + 16),
          baseOpacity: isNear ? (Math.random() * 0.25 + 0.32) : (Math.random() * 0.18 + 0.15),
          width: isNear ? 1.3 : 0.85,
          threshold: thresh
        });
      }
    } else if (this.currentActiveWeather === 'snow') {
      this.snowflakes = [];
      for (let i = 0; i < 65; i++) {
        this.snowflakes.push({
          relX: (Math.random() - 0.5) * (weatherRadius * 2.2),
          relY: (Math.random() - 0.5) * (weatherRadius * 2.2),
          radius: Math.random() * 2.8 + 1.2,
          speedY: Math.random() * 1.4 + 0.8,
          speedX: (Math.random() - 0.5) * 0.5,
          opacity: Math.random() * 0.5 + 0.25,
          swayOffset: Math.random() * Math.PI * 2,
          threshold: Math.random() * 0.85
        });
      }
    }
  }

  private renderFrame(): void {
    if (!this.context) return;
    const width = this.canvasWidth > 0 ? this.canvasWidth : 400;
    const height = this.canvasHeight > 0 ? this.canvasHeight : 800;

    // 🌊 天气生命周期平滑演化插值 (入场耗时约 4 秒，放晴离场约 2 秒)
    if (this.weatherProgress < this.targetWeatherProgress) {
      this.weatherProgress = Math.min(1.0, this.weatherProgress + 0.0045); // 约 3.7 秒完整渐入
      // 当雨势达到 85% 暴雨级别时，触发闪电循环
      if (this.weatherProgress >= 0.85 && this.lightningTimerId === -1 && this.currentActiveWeather === 'thunderstorm') {
        this.triggerLightningLoop();
      }
    } else if (this.weatherProgress > this.targetWeatherProgress) {
      this.weatherProgress = Math.max(0.0, this.weatherProgress - 0.009); // 约 1.8 秒平滑放晴
      if (this.weatherProgress <= 0.001) {
        this.weatherProgress = 0;
        this.currentActiveWeather = 'clear';
        this.context.clearRect(0, 0, width, height);
        return; // 彻底放晴，停止本帧绘制
      }
    }

    if (this.weatherProgress <= 0.001) {
      return;
    }

    // 清空透明画布
    this.context.clearRect(0, 0, width, height);
    this.timeTick += 0.025;

    // 🎯 核心世界坐标投影：计算天气中心在当前屏幕上的像素坐标 (随地图拖拽实时平移)
    const centerX = (width / 2) + this.planeScreenOffsetX;
    const centerY = (height / 2) + this.planeScreenOffsetY;
    const weatherRadius = 340; // 局部雷暴气象团半径

    // 如果天气中心完全离开屏幕视野，跳过绘制
    if (centerX + weatherRadius < 0 || centerX - weatherRadius > width ||
        centerY + weatherRadius < 0 || centerY - weatherRadius > height) {
      return;
    }

    if (this.currentActiveWeather === 'thunderstorm') {
      // 1. ⛈️ 阶段一：天色显著变暗 (全屏风暴阴云基底 + 核心雷雨区深度乌云)
      // 1.1 全屏基础天色昏暗层 (平滑压暗整个视野至 36% 沉浸风暴色，肉眼对比极其明显)
      const baseOvercastAlpha = 0.38 * Math.min(1.0, this.weatherProgress * 1.6);
      this.context.fillStyle = `rgba(10, 16, 32, ${baseOvercastAlpha})`;
      this.context.fillRect(0, 0, width, height);

      // 1.2 核心雷雨区深度乌云加深 (核心区额外叠加密集乌云，暗度高达 55%，边缘柔和羽化)
      const coreDarkness = 0.55 * Math.min(1.0, this.weatherProgress * 1.3);
      const envGrad = this.context.createRadialGradient(
        centerX, centerY, 0,
        centerX, centerY, weatherRadius
      );
      envGrad.addColorStop(0.0, `rgba(8, 12, 24, ${coreDarkness})`);
      envGrad.addColorStop(0.5, `rgba(10, 15, 30, ${coreDarkness * 0.70})`);
      envGrad.addColorStop(0.85, `rgba(15, 23, 42, ${coreDarkness * 0.25})`);
      envGrad.addColorStop(1.0, 'rgba(15, 23, 42, 0.0)');

      this.context.beginPath();
      this.context.arc(centerX, centerY, weatherRadius, 0, Math.PI * 2);
      this.context.fillStyle = envGrad;
      this.context.fill();

      // 2. ⚡ 阶段四：自然冷白大气漫闪 (仅在暴雨成型后活跃)
      if (this.lightningIntensity > 0.01 && this.weatherProgress > 0.6) {
        const flashGrad = this.context.createRadialGradient(
          centerX, centerY, 0,
          centerX, centerY, weatherRadius * 1.5
        );
        const flashAlpha = this.lightningIntensity * (this.weatherProgress * 0.35);
        flashGrad.addColorStop(0.0, `rgba(240, 246, 255, ${flashAlpha})`);
        flashGrad.addColorStop(0.7, `rgba(224, 235, 255, ${flashAlpha * 0.5})`);
        flashGrad.addColorStop(1.0, 'rgba(255, 255, 255, 0.0)');

        this.context.fillStyle = flashGrad;
        this.context.fillRect(0, 0, width, height);
      }

      // 3. 🌧️ 阶段二与三：小雨 -> 中雨 -> 暴雨渐进演化
      const windAngle = Math.sin(this.timeTick * 0.8) * 0.035 + 0.035;

      for (let drop of this.rainDrops) {
        // 雨滴只有在演化进度超过其激活阈值时才开始落下
        if (this.weatherProgress < drop.threshold) {
          continue;
        }

        // 该雨滴当前的成熟度因子 (0.0 ~ 1.0)
        const dropGrowth = Math.min(1.0, (this.weatherProgress - drop.threshold) / 0.25);

        // 速度和长度随着雨势渐进拉大
        const currentSpeed = drop.speed * (0.6 + dropGrowth * 0.4);
        const currentLength = drop.length * (0.5 + dropGrowth * 0.5);

        drop.relY += currentSpeed;
        drop.relX += currentSpeed * windAngle;

        // 在局部天气圆环范围内做往复循环
        if (drop.relY > weatherRadius) {
          drop.relY = -weatherRadius - Math.random() * 20;
          drop.relX = (Math.random() - 0.5) * (weatherRadius * 2.0);
        }

        const absX = centerX + drop.relX;
        const absY = centerY + drop.relY;

        if (absX < -20 || absX > width + 20 || absY < -40 || absY > height + 40) {
          continue;
        }

        const distToCenter = Math.hypot(drop.relX, drop.relY);
        if (distToCenter > weatherRadius) {
          continue;
        }
        const edgeFactor = distToCenter > (weatherRadius - 70) ? (weatherRadius - distToCenter) / 70 : 1.0;

        const startX = absX;
        const startY = absY - currentLength;
        const endX = absX + currentLength * windAngle;
        const endY = absY;

        const rainGrad = this.context.createLinearGradient(startX, startY, endX, endY);
        const dynamicAlpha = Math.min(1.0, (drop.baseOpacity + this.lightningIntensity * 0.40) * edgeFactor * dropGrowth);

        rainGrad.addColorStop(0.0, 'rgba(255, 255, 255, 0.0)');
        rainGrad.addColorStop(0.5, `rgba(215, 230, 255, ${dynamicAlpha * 0.45})`);
        rainGrad.addColorStop(1.0, `rgba(255, 255, 255, ${dynamicAlpha})`);

        this.context.beginPath();
        this.context.moveTo(startX, startY);
        this.context.lineTo(endX, endY);
        this.context.strokeStyle = rainGrad;
        this.context.lineWidth = drop.width * (0.7 + dropGrowth * 0.3);
        this.context.stroke();
      }

    } else if (this.currentActiveWeather === 'snow') {
      // ❄️ 局部暴雪渐进演化
      const maxDarkness = 0.12;
      const currentDarkness = maxDarkness * this.weatherProgress;

      const envGrad = this.context.createRadialGradient(
        centerX, centerY, 0,
        centerX, centerY, weatherRadius
      );
      envGrad.addColorStop(0.0, `rgba(15, 23, 42, ${currentDarkness})`);
      envGrad.addColorStop(0.8, `rgba(15, 23, 42, ${currentDarkness * 0.3})`);
      envGrad.addColorStop(1.0, 'rgba(15, 23, 42, 0.0)');

      this.context.beginPath();
      this.context.arc(centerX, centerY, weatherRadius, 0, Math.PI * 2);
      this.context.fillStyle = envGrad;
      this.context.fill();

      for (let s of this.snowflakes) {
        if (this.weatherProgress < s.threshold) {
          continue;
        }
        const snowGrowth = Math.min(1.0, (this.weatherProgress - s.threshold) / 0.25);

        s.relY += s.speedY * (0.6 + snowGrowth * 0.4);
        s.relX += s.speedX + Math.sin(this.timeTick + s.swayOffset) * 0.6;

        if (s.relY > weatherRadius) {
          s.relY = -weatherRadius - 10;
          s.relX = (Math.random() - 0.5) * (weatherRadius * 2.0);
        }

        const absX = centerX + s.relX;
        const absY = centerY + s.relY;

        if (absX < -20 || absX > width + 20 || absY < -20 || absY > height + 20) {
          continue;
        }

        const dist = Math.hypot(s.relX, s.relY);
        if (dist > weatherRadius) {
          continue;
        }
        const edgeFactor = dist > (weatherRadius - 50) ? (weatherRadius - dist) / 50 : 1.0;

        const grad = this.context.createRadialGradient(absX, absY, 0, absX, absY, s.radius * snowGrowth);
        grad.addColorStop(0.0, `rgba(255, 255, 255, ${s.opacity * edgeFactor * snowGrowth})`);
        grad.addColorStop(0.7, `rgba(240, 245, 255, ${s.opacity * 0.5 * edgeFactor * snowGrowth})`);
        grad.addColorStop(1.0, 'rgba(255, 255, 255, 0.0)');

        this.context.beginPath();
        this.context.arc(absX, absY, s.radius * snowGrowth, 0, Math.PI * 2);
        this.context.fillStyle = grad;
        this.context.fill();
      }
    }
  }

  private triggerLightningLoop(): void {
    const nextTime = Math.random() * 5000 + 4000;
    this.lightningTimerId = setTimeout(() => {
      if (this.weatherProgress > 0.7 && this.currentActiveWeather === 'thunderstorm') {
        this.playNaturalLightningFlicker();
      }
      this.triggerLightningLoop();
    }, nextTime);
  }

  private playNaturalLightningFlicker(): void {
    this.lightningIntensity = 0.55;
    setTimeout(() => {
      this.lightningIntensity = 0.12;
      setTimeout(() => {
        this.lightningIntensity = 0.85;
        setTimeout(() => {
          this.lightningIntensity = 0.30;
          setTimeout(() => {
            this.lightningIntensity = 0;
          }, 180);
        }, 60);
      }, 35);
    }, 45);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 始终挂载纯透明 Canvas，由 weatherProgress 平滑过渡，不引起布局重排
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((_oldArea, newArea) => {
          const w = Number(newArea.width);
          const h = Number(newArea.height);
          if (w > 0 && h > 0 && (w !== this.canvasWidth || h !== this.canvasHeight)) {
            this.canvasWidth = w;
            this.canvasHeight = h;
            this.initParticles();
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.None)
  }
}
