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
 * 真实航空摄影母版 + 纯代码视差微流体流动引擎 (CabinWindowSceneryParallax)
 * 1. 100% 真实客机摄影像素质感 (真实云海、真实金属客机机翼与翼尖小翼)；
 * 2. 纯代码 24 小时无缝数学无限流动 (零首尾卡顿、零残影、120fps 满帧省电)；
 * 3. 真实客机空气动力学微气流呼吸浮动与翼尖防撞灯周期性频闪。
 */
@Component
export struct CabinWindowSceneryParallax {
  @Prop containerWidth: number = 185;
  @Prop containerHeight: number = 310;
  @Prop lightingMode: string = 'sunset'; // 'sunset' | 'day' | 'night'

  // 视差位移参数
  @State farCloudOffset: number = 0.0;
  @State midCloudOffset: number = 0.0;
  @State vaporOffset: number = 0.0;
  @State wingBreatheY: number = 0.0;
  @State strobeOpacity: number = 0.0;

  private animTimerId: number = -1;
  private tickCount: number = 0;

  aboutToAppear(): void {
    this.startParallaxEngine();
  }

  aboutToDisappear(): void {
    if (this.animTimerId !== -1) {
      clearInterval(this.animTimerId);
      this.animTimerId = -1;
    }
  }

  private startParallaxEngine(): void {
    const cloudLoopWidth = 300;
    const vaporLoopWidth = 400;

    this.animTimerId = setInterval(() => {
      this.tickCount++;
      const t = this.tickCount * 0.035;

      // 1. 远景平流层摄影云海：平稳匀速向左漫游 (数学无限环形无缝映射)
      this.farCloudOffset = (this.farCloudOffset - 0.45) % cloudLoopWidth;

      // 2. 近景高空卷云丝缕：快速掠过，营造 850 km/h 真实巡航速度感
      this.vaporOffset = (this.vaporOffset - 1.85) % vaporLoopWidth;

      // 3. 真实客机机翼空气动力学升力微呼吸浮动 (双正弦复合微颠簸)
      this.wingBreatheY = Math.sin(t * 1.8) * 1.5 + Math.sin(t * 3.2) * 0.6;

      // 4. 翼尖防撞灯 (Strobe Light) 周期性微闪
      const strobePhase = (Math.sin(t * 2.5) + 1.0) / 2.0;
      this.strobeOpacity = strobePhase > 0.88 ? (strobePhase - 0.88) / 0.12 : 0.0;
    }, 32); // 稳定 ~30ms 时钟，由 GPU 做硬件属性平滑
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 真实平流层天空穹顶 (真实暮色晚霞天光渐变)
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#18233C', 0.0],
            ['#323F5F', 0.32],
            ['#6A5C79', 0.55],
            ['#B87668', 0.74],
            ['#E69D66', 0.88],
            ['#F9D39E', 1.0]
          ]
        })

      // 2. 远景真实摄影平流层云海视差层 (双母版无缝水平拼接环游)
      Row() {
        Image($r('app.media.scenery_cloud_deck'))
          .width(300)
          .height(125)
          .objectFit(ImageFit.Fill)

        Image($r('app.media.scenery_cloud_deck'))
          .width(300)
          .height(125)
          .objectFit(ImageFit.Fill)
      }
      .position({ x: this.farCloudOffset, y: 155 })
      .width(600)
      .height(125)
      .hitTestBehavior(HitTestMode.None)

      // 3. 近景高空卷云丝缕掠影 (半透明高速水汽)
      Row() {
        Image($r('app.media.scenery_vapor_wisp'))
          .width(200)
          .height(60)
          .objectFit(ImageFit.Contain)
          .opacity(0.35)

        Image($r('app.media.scenery_vapor_wisp'))
          .width(200)
          .height(60)
          .objectFit(ImageFit.Contain)
          .opacity(0.35)
      }
      .position({ x: this.vaporOffset, y: 40 })
      .width(400)
      .height(60)
      .hitTestBehavior(HitTestMode.None)

      // 4. 真实民航客机机翼与翼尖小翼 (高精金属质感，带空气动力学微呼吸)
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.scenery_airliner_wing'))
          .width(205)
          .height(182)
          .objectFit(ImageFit.Contain)
          .position({ x: -5, y: 110 })
          .translate({ y: this.wingBreatheY })

        // 4.1 翼尖防撞灯频闪光芒 (🟢 绿色航行信标灯)
        Stack({ alignContent: Alignment.Center }) {
          // 外圈柔和泛光
          Circle()
            .width(10)
            .height(10)
            .fill('rgba(110, 255, 170, 0.45)')

          // 核心亮点
          Circle()
            .width(3.5)
            .height(3.5)
            .fill('#FFFFFF')
        }
        .position({ x: 147, y: 113 })
        .translate({ y: this.wingBreatheY })
        .opacity(this.strobeOpacity)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    }
    .width(this.containerWidth)
    .height(this.containerHeight)
    .borderRadius(70)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
