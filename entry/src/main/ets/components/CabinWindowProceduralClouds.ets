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
 * 真实 4K 60fps 平流层云海视界引擎 (CabinWindowProceduralClouds / Video Edition)
 * 1. ☀️ 日间模式 (06:00 ~ 17:30): 晴空万米平流层纯净蔚蓝云海 (day_cloud_loop.mp4)
 * 2. 🌅 傍晚/夕阳模式 (17:30 ~ 19:30): 金光落霞与粉紫幻彩晚霞云海 (sunset_cloud_loop.mp4)
 * 3. 🌌 静谧夜航模式 (19:30 ~ 次日 06:00): 深邃极夜幽蓝月光云海 (night_cloud_loop.mp4)
 * 4. 具备光学级舷窗曲面玻璃双层高光反射与暗角抗眩光滤镜，完美呈现真实客机高空巡航体验。
 */
@Component
export struct CabinWindowProceduralClouds {
  @Prop containerWidth: number = 185;
  @Prop containerHeight: number = 310;
  @Watch('onFlightStateChange') @Prop isFlightPaused: boolean = false;
  @Watch('onForegroundStateChange') @StorageProp('isAppForeground') isAppForeground: boolean = true;

  // 当前激活的时段模式：'day' | 'sunset' | 'night'
  @State currentMode: 'day' | 'sunset' | 'night' = 'day';
  @State videoSrc: Resource = $rawfile('videos/day_cloud_loop.mp4');

  private videoController: VideoController = new VideoController();
  private timeCheckTimerId: number = -1;

  aboutToAppear(): void {
    this.updateTimeMode();

    // 定时检查时间以平滑切换时段
    this.timeCheckTimerId = setInterval(() => {
      this.updateTimeMode();
    }, 30000);
  }

  aboutToDisappear(): void {
    if (this.timeCheckTimerId !== -1) {
      clearInterval(this.timeCheckTimerId);
      this.timeCheckTimerId = -1;
    }
  }

  onForegroundStateChange(): void {
    if (this.isAppForeground && !this.isFlightPaused) {
      setTimeout(() => {
        try {
          this.videoController.start();
        } catch (e) { }
      }, 150);
    }
  }

  onFlightStateChange(): void {
    if (!this.isFlightPaused && this.isAppForeground) {
      setTimeout(() => {
        try {
          this.videoController.start();
        } catch (e) { }
      }, 150);
    }
  }

  private updateTimeMode(): void {
    const hour = new Date().getHours();
    const minute = new Date().getMinutes();
    const timeVal = hour + minute / 60.0;

    let targetMode: 'day' | 'sunset' | 'night' = 'day';
    let targetSrc: Resource = $rawfile('videos/day_cloud_loop.mp4');

    if (timeVal >= 6.0 && timeVal < 17.5) {
      targetMode = 'day';
      targetSrc = $rawfile('videos/day_cloud_loop.mp4');
    } else if (timeVal >= 17.5 && timeVal < 19.5) {
      targetMode = 'sunset';
      targetSrc = $rawfile('videos/sunset_cloud_loop.mp4');
    } else {
      targetMode = 'night';
      targetSrc = $rawfile('videos/night_cloud_loop.mp4');
    }

    if (this.currentMode !== targetMode) {
      this.currentMode = targetMode;
      this.videoSrc = targetSrc;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 底层真实 60fps 平流层云海无缝循环视频 (Day / Sunset / Night - 硬件加速 60fps 极速循环)
      Video({
        src: this.videoSrc,
        controller: this.videoController
      })
        .muted(true)
        .autoPlay(true)
        .loop(true)
        .controls(false)
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .onPrepared(() => {
          this.videoController.start();
        })
        .onError(() => {
          setTimeout(() => {
            this.videoController.start();
          }, 300);
        })

      // 2. 光学级双层舷窗曲面玻璃微反光与天际暗角 (Double-Pane Aviation Acrylic Glass Sheen)
      Column()
        .width(this.containerWidth)
        .height(this.containerHeight)
        .borderRadius(70)
        .linearGradient({
          angle: 135,
          colors: [
            ['rgba(255, 255, 255, 0.16)', 0.0],
            ['rgba(255, 255, 255, 0.05)', 0.28],
            ['rgba(255, 255, 255, 0.0)', 0.50],
            ['rgba(0, 0, 0, 0.0)', 0.75],
            ['rgba(0, 0, 0, 0.15)', 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.None)

      // 3. 舷窗边缘防眩晕内暗角光晕
      Column()
        .width(this.containerWidth)
        .height(this.containerHeight)
        .borderRadius(70)
        .border({
          width: 1.5,
          color: 'rgba(0, 0, 0, 0.25)',
          radius: 70
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.containerWidth)
    .height(this.containerHeight)
    .borderRadius(70)
    .clip(true)
  }
}
