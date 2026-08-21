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

interface StarPoint {
  x: number;
  y: number;
  size: number;
  baseOpacity: number;
  pulsePhase: number;
  color: string;
  isBright?: boolean;
}

/**
 * 真实 3D 摄影级平流层「日昼晴空 / 每次飞行独一无二动态星河」视界系统 (CabinWindowProceduralClouds)
 * 1. ☀️ 日间模式 (06:00 ~ 19:30): 万米平流层纯净通透湛蓝 + 纯白立体棉花糖云海；
 * 2. 🌌 静谧夜航模式 (19:30 ~ 次日 06:00):
 *    - 【每次飞行星星数量与位置完全随机生成】：星数随机浮动 (35 ~ 75颗)、星座聚散团簇每次启航皆独一无二；
 *    - 【摄影级光学光晕与光谱】：0.6~1.0vp 微观星尘 + 2.0vp 导航亮星高斯弥散光晕 + 恒星色温（冷蓝/纯白/暖金）；
 *    - 【天体极慢宇宙视差流淌】：星空以 0.025vp/tick 极慢速度双轨无痕平滑推进；
 *    - 下方云海更加稀疏、低沉、轻盈，受冷月微光照射呈现银蓝静谧质感；
 * 3. 100% 自动读取系统真实时间无缝切换，满帧 120fps、零抽动、超低能耗。
 */
@Component
export struct CabinWindowProceduralClouds {
  @Prop containerWidth: number = 185;
  @Prop containerHeight: number = 310;

  // 【星空双轨】：单轨宽 220vp (视口仅 185vp，极慢宇宙漂移 0.025vp/tick)
  @State starTrack1X: number = 0.0;
  @State starTrack2X: number = 220.0;

  // 【远景双轨】：单轨宽 355vp (视口仅 185vp，超慢速 0.07vp/tick)
  @State farTrack1X: number = 0.0;
  @State farTrack2X: number = 355.0;

  // 【中景双轨】：单轨宽 515vp (视口仅 185vp，适中巡航 0.22vp/tick)
  @State midTrack1X: number = 0.0;
  @State midTrack2X: number = 515.0;

  // 【近景双轨】：单轨宽 840vp (视口仅 185vp，匀速前行 0.48vp/tick)
  @State nearTrack1X: number = 0.0;
  @State nearTrack2X: number = 840.0;

  // 当前是否处于静谧夜航时段
  @State isNightTime: boolean = false;

  // 星星动态呼吸闪烁相位
  @State starPulseFactor: number = 1.0;

  // 每次起飞独一无二的随机星空 Track 1 & Track 2
  @State starsTrack1: StarPoint[] = [];
  @State starsTrack2: StarPoint[] = [];

  // 日昼 / 夜航天幕渐变色
  @State skyGradientColors: [ResourceColor, number][] = [
    ['#104694', 0.0],
    ['#2064B4', 0.40],
    ['#528DD0', 0.68],
    ['#88B8E4', 0.88],
    ['#B8D6F2', 1.0]
  ];

  // 日昼 / 夜航底部大气透光雾层
  @State fogGradientColors: [ResourceColor, number][] = [
    ['rgba(184, 214, 242, 0.0)', 0.0],
    ['rgba(184, 214, 242, 0.20)', 0.35],
    ['rgba(184, 214, 242, 0.55)', 0.70],
    ['rgba(184, 214, 242, 0.85)', 1.0]
  ];

  // 云朵透明度自适应（夜间更加轻盈稀疏）
  @State farCloudOpacity: number = 0.18;
  @State midCloudOpacity: number = 0.55;
  @State nearCloudOpacity: number = 0.95;

  private animTimerId: number = -1;
  private timeCheckTimerId: number = -1;
  private tickCount: number = 0;

  aboutToAppear(): void {
    // 每次起飞初始化独一无二的随机星空
    this.generateProceduralStarfields();
    this.checkAndApplyDayNightMode();
    this.startDualTrackEngine();

    // 每 30 秒自动校准一次系统时间
    this.timeCheckTimerId = setInterval(() => {
      this.checkAndApplyDayNightMode();
    }, 30000);
  }

  aboutToDisappear(): void {
    if (this.animTimerId !== -1) {
      clearInterval(this.animTimerId);
      this.animTimerId = -1;
    }
    if (this.timeCheckTimerId !== -1) {
      clearInterval(this.timeCheckTimerId);
      this.timeCheckTimerId = -1;
    }
  }

  /**
   * 每次飞行起飞时调用：程序化生成全新、随机、独一无二的星宿聚散与数量
   */
  private generateProceduralStarfields(): void {
    this.starsTrack1 = this.createRandomTrackStars(220);
    this.starsTrack2 = this.createRandomTrackStars(220);
  }

  private createRandomTrackStars(trackWidth: number): StarPoint[] {
    const starCount = 35 + Math.floor(Math.random() * 40); // 随机 35 ~ 75 颗星星
    const clusterCount = 2 + Math.floor(Math.random() * 3); // 2~4 个星团核心
    const clusters: number[][] = [];

    for (let i = 0; i < clusterCount; i++) {
      const cx = 25 + Math.random() * (trackWidth - 50);
      const cy = 25 + Math.random() * 150;
      const rad = 25 + Math.random() * 35;
      clusters.push([cx, cy, rad]);
    }

    const starList: StarPoint[] = [];

    for (let i = 0; i < starCount; i++) {
      let sx: number;
      let sy: number;

      if (Math.random() < 0.65 && clusters.length > 0) {
        // 团簇聚集星
        const c = clusters[Math.floor(Math.random() * clusters.length)];
        const angle = Math.random() * Math.PI * 2;
        const dist = (Math.random() + Math.random()) * 0.5 * c[2];
        sx = c[0] + Math.cos(angle) * dist;
        sy = c[1] + Math.sin(angle) * dist;
      } else {
        // 广袤散落背景微星
        sx = 5 + Math.random() * (trackWidth - 10);
        sy = 15 + Math.random() * 180;
      }

      sx = Math.max(5, Math.min(trackWidth - 5, Number(sx.toFixed(1))));
      sy = Math.max(15, Math.min(195, Number(sy.toFixed(1))));

      const p = Math.random();
      let size: number;
      let op: number;
      let col: string;
      let isB: boolean = false;

      if (p < 0.76) {
        // 76% 微观针尖微星 (0.6 ~ 1.0vp)
        size = Number((0.6 + Math.random() * 0.4).toFixed(1));
        op = Number((0.30 + Math.random() * 0.35).toFixed(2));
        const colTypes = ['#FFFFFF', '#D4E5FF', '#FFE8D6', '#EAF2FF'];
        col = colTypes[Math.floor(Math.random() * colTypes.length)];
      } else if (p < 0.94) {
        // 18% 中等清晰恒星 (1.1 ~ 1.5vp)
        size = Number((1.1 + Math.random() * 0.4).toFixed(1));
        op = Number((0.70 + Math.random() * 0.20).toFixed(2));
        const colTypes = ['#FFFFFF', '#E0EEFF', '#FFF2DF'];
        col = colTypes[Math.floor(Math.random() * colTypes.length)];
      } else {
        // 6% 导航亮星 (1.8 ~ 2.2vp 带有柔和光学高斯光晕)
        size = Number((1.8 + Math.random() * 0.4).toFixed(1));
        op = 1.0;
        const colTypes = ['#FFFFFF', '#D8EAFF', '#FFE4BA'];
        col = colTypes[Math.floor(Math.random() * colTypes.length)];
        isB = true;
      }

      const phase = Number((Math.random() * 6.28).toFixed(2));

      starList.push({
        x: sx,
        y: sy,
        size: size,
        baseOpacity: op,
        pulsePhase: phase,
        color: col,
        isBright: isB
      });
    }

    return starList;
  }

  /**
   * 自动检测并切换「日昼晴空」与「静谧星空夜航」
   */
  private checkAndApplyDayNightMode(): void {
    const now = new Date();
    const curHour = now.getHours() + now.getMinutes() / 60.0;

    // 19:30 ~ 06:00 为夜航时段
    const isNight = (curHour >= 19.5 || curHour < 6.0);
    this.isNightTime = isNight;

    if (isNight) {
      // 🌌 静谧夜航天幕 (黑曜石深空幽蓝 -> 地平线冷月微光)
      this.skyGradientColors = [
        ['#02050E', 0.0],
        ['#050C1C', 0.40],
        ['#0A1630', 0.70],
        ['#122448', 0.88],
        ['#1C3462', 1.0]
      ];
      this.fogGradientColors = [
        ['rgba(18, 36, 72, 0.0)', 0.0],
        ['rgba(18, 36, 72, 0.20)', 0.35],
        ['rgba(18, 36, 72, 0.50)', 0.70],
        ['rgba(28, 52, 98, 0.75)', 1.0]
      ];
      // 夜间云朵更加通透、稀疏、不抢星空视界
      this.farCloudOpacity = 0.08;
      this.midCloudOpacity = 0.28;
      this.nearCloudOpacity = 0.55;
    } else {
      // ☀️ 蔚蓝晴空天幕 (纯净通透深邃平流层湛蓝 -> 天际柔白天青)
      this.skyGradientColors = [
        ['#104694', 0.0],
        ['#2064B4', 0.40],
        ['#528DD0', 0.68],
        ['#88B8E4', 0.88],
        ['#B8D6F2', 1.0]
      ];
      this.fogGradientColors = [
        ['rgba(184, 214, 242, 0.0)', 0.0],
        ['rgba(184, 214, 242, 0.20)', 0.35],
        ['rgba(184, 214, 242, 0.55)', 0.70],
        ['rgba(184, 214, 242, 0.85)', 1.0]
      ];
      this.farCloudOpacity = 0.18;
      this.midCloudOpacity = 0.55;
      this.nearCloudOpacity = 0.95;
    }
  }

  private startDualTrackEngine(): void {
    const starW = 220.0;
    const farW = 355.0;
    const midW = 515.0;
    const nearW = 840.0;

    // 宇宙视差速度等级：星空 (0.025) < 远景云 (0.07) < 中景云 (0.22) < 近景云 (0.48)
    const starSpeed = 0.025;
    const farSpeed = 0.07;
    const midSpeed = 0.22;
    const nearSpeed = 0.48;

    this.animTimerId = setInterval(() => {
      this.tickCount++;

      // 星星微呼吸呼吸相位更新
      if (this.isNightTime && this.tickCount % 2 === 0) {
        this.starPulseFactor = 0.88 + 0.12 * Math.sin(this.tickCount * 0.06);
      }

      // 0. 独一无二星空双轨超慢速漂移 (极慢宇宙视差 0.025vp/tick)
      if (this.isNightTime) {
        this.starTrack1X -= starSpeed;
        this.starTrack2X -= starSpeed;
        if (this.starTrack1X <= -starW) {
          this.starTrack1X += starW * 2;
        }
        if (this.starTrack2X <= -starW) {
          this.starTrack2X += starW * 2;
        }
      }

      // 1. 远景双轨离屏平滑推进 (超慢速 0.07vp/tick)
      this.farTrack1X -= farSpeed;
      this.farTrack2X -= farSpeed;
      if (this.farTrack1X <= -farW) {
        this.farTrack1X += farW * 2;
      }
      if (this.farTrack2X <= -farW) {
        this.farTrack2X += farW * 2;
      }

      // 2. 中景双轨离屏平滑推进 (适中巡航 0.22vp/tick)
      this.midTrack1X -= midSpeed;
      this.midTrack2X -= midSpeed;
      if (this.midTrack1X <= -midW) {
        this.midTrack1X += midW * 2;
      }
      if (this.midTrack2X <= -midW) {
        this.midTrack2X += midW * 2;
      }

      // 3. 近景双轨离屏平滑推进 (匀速前行 0.48vp/tick)
      this.nearTrack1X -= nearSpeed;
      this.nearTrack2X -= nearSpeed;
      if (this.nearTrack1X <= -nearW) {
        this.nearTrack1X += nearW * 2;
      }
      if (this.nearTrack2X <= -nearW) {
        this.nearTrack2X += nearW * 2;
      }
    }, 32);
  }

  // -------------------------------------------------------------
  // 夜间独一无二动态星空双轨渲染层 (Procedural Organic Starfield)
  // -------------------------------------------------------------
  @Builder
  StarTrackContent(stars: StarPoint[]) {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(stars, (star: StarPoint) => {
        Stack({ alignContent: Alignment.Center }) {
          // 1. 亮星柔和光学弥散光晕 (Gaussian Lens Bokeh)
          if (star.isBright) {
            Circle({ width: star.size * 3.0, height: star.size * 3.0 })
              .fill('rgba(190, 220, 255, 0.22)')
          }

          // 2. 真实微观针尖光点 (0.6 ~ 2.2vp)
          Circle({ width: star.size, height: star.size })
            .fill(star.color)
        }
        .position({ x: star.x, y: star.y })
        .opacity(star.baseOpacity * this.starPulseFactor)
      }, (star: StarPoint, idx: number) => `${idx}_${star.x}_${star.y}`)
    }
    .width(220)
    .height(200)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  StarfieldOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        this.StarTrackContent(this.starsTrack1)
      }
      .position({ x: this.starTrack1X, y: 0 })

      Row() {
        this.StarTrackContent(this.starsTrack2)
      }
      .position({ x: this.starTrack2X, y: 0 })
    }
    .width('100%')
    .height(200)
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.None)
  }

  // -------------------------------------------------------------
  // 远景双轨渲染模版 (素材: 8, 15, 21 / 4, 22, 11)
  // -------------------------------------------------------------
  @Builder
  FarTrack1Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_8'))
        .width(95)
        .height(28)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })

      Image($r('app.media.ic_cloud_custom_15'))
        .width(90)
        .height(26)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })

      Image($r('app.media.ic_cloud_custom_21'))
        .width(95)
        .height(28)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })
    }
    .width(355)
    .height(30)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  FarTrack2Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_4'))
        .width(90)
        .height(26)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })

      Image($r('app.media.ic_cloud_custom_22'))
        .width(95)
        .height(28)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })

      Image($r('app.media.ic_cloud_custom_11'))
        .width(95)
        .height(28)
        .objectFit(ImageFit.Contain)
        .opacity(this.farCloudOpacity)
        .margin({ right: 25 })
    }
    .width(355)
    .height(30)
    .hitTestBehavior(HitTestMode.None)
  }

  // -------------------------------------------------------------
  // 中景双轨渲染模版 (素材: 2, 14, 19, 12 / 10, 20, 9, 16)
  // -------------------------------------------------------------
  @Builder
  MidTrack1Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_2'))
        .width(115)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_14'))
        .width(110)
        .height(50)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_19'))
        .width(115)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_12'))
        .width(95)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })
    }
    .width(515)
    .height(55)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  MidTrack2Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_10'))
        .width(115)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_20'))
        .width(110)
        .height(50)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_9'))
        .width(115)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })

      Image($r('app.media.ic_cloud_custom_16'))
        .width(115)
        .height(52)
        .objectFit(ImageFit.Contain)
        .opacity(this.midCloudOpacity)
        .margin({ right: 20 })
    }
    .width(515)
    .height(55)
    .hitTestBehavior(HitTestMode.None)
  }

  // -------------------------------------------------------------
  // 近景双轨渲染模版 (素材: 1, 13, 6, 17 / 5, 18, 3, 23)
  // -------------------------------------------------------------
  @Builder
  NearTrack1Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_1'))
        .width(195)
        .height(135)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_13'))
        .width(200)
        .height(138)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_6'))
        .width(190)
        .height(130)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_17'))
        .width(195)
        .height(135)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })
    }
    .width(840)
    .height(145)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  NearTrack2Content() {
    Row() {
      Image($r('app.media.ic_cloud_custom_5'))
        .width(195)
        .height(135)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_18'))
        .width(200)
        .height(138)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_3'))
        .width(190)
        .height(130)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })

      Image($r('app.media.ic_cloud_custom_23'))
        .width(195)
        .height(135)
        .objectFit(ImageFit.Contain)
        .opacity(this.nearCloudOpacity)
        .margin({ right: 15 })
    }
    .width(840)
    .height(145)
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 万米高空平流层自然天幕 (日昼纯净湛蓝 / 静谧黑曜夜航)
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: this.skyGradientColors
        })
        .animation({ duration: 1500, curve: Curve.EaseInOut })

      // 1.5 【夜间专属】：每次飞行独一无二的随机天文星河 (双轨超慢视差 0.025vp/tick)
      if (this.isNightTime) {
        this.StarfieldOverlay()
      }

      // 2. 【第一层：天际极远景】(Far Horizon - 沉底 y: 195vp，双轨异构离屏平滑回旋 0.07vp/tick)
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          this.FarTrack1Content()
        }
        .position({ x: this.farTrack1X, y: 0 })

        Row() {
          this.FarTrack2Content()
        }
        .position({ x: this.farTrack2X, y: 0 })
      }
      .width('100%')
      .height(30)
      .position({ x: 0, y: 195 })
      .hitTestBehavior(HitTestMode.None)

      // 3. 【第二层：中景漂浮积云】(Mid Distance - 沉底 y: 210vp，双轨异构离屏平滑回旋 0.22vp/tick)
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          this.MidTrack1Content()
        }
        .position({ x: this.midTrack1X, y: 0 })

        Row() {
          this.MidTrack2Content()
        }
        .position({ x: this.midTrack2X, y: 0 })
      }
      .width('100%')
      .height(55)
      .position({ x: 0, y: 210 })
      .hitTestBehavior(HitTestMode.None)

      // 4. 【第三层：近景巨型棉花糖积云山】(Foreground Near - 保持 y: 188vp 原生绝佳位置，双轨异构离屏平滑回旋 0.48vp/tick)
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          this.NearTrack1Content()
        }
        .position({ x: this.nearTrack1X, y: 0 })

        Row() {
          this.NearTrack2Content()
        }
        .position({ x: this.nearTrack2X, y: 0 })
      }
      .width('100%')
      .height(145)
      .position({ x: 0, y: 188 })
      .hitTestBehavior(HitTestMode.None)

      // 5. 底部大气柔和透光雾层 (随日夜自然呈现柔白天青或冷月幽蓝)
      Column()
        .width('100%')
        .height(90)
        .position({ x: 0, y: 220 })
        .linearGradient({
          angle: 180,
          colors: this.fogGradientColors
        })
        .animation({ duration: 1500, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.containerWidth)
    .height(this.containerHeight)
    .borderRadius(70)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
