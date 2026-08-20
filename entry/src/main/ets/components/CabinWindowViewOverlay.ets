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

import { vibrator } from '@kit.SensorServiceKit';
import { Airport } from '../models/AirportModel';
import { CabinWindowProceduralFrame } from './CabinWindowProceduralFrame';
import { CabinWindowShadePanel } from './CabinWindowShadePanel';

@Component
export struct CabinWindowViewOverlay {
  @Prop remainingTimeString: string = '45:00';
  @Prop currentFocusTagTitle: string = '深度学习';
  @Prop originAirport: Airport | null = null;
  @Prop destinationAirport: Airport | null = null;
  @Prop isFlightPaused: boolean = false;
  @Prop isTurbulenceActive: boolean = false;

  // 遮阳板闭合进度：0.0 (全开) ~ 1.0 (全关)
  @State shadeProgress: number = 0.0;

  public onToggleWindowView: () => void = () => {};
  public onPauseResumeFlight: () => void = () => {};
  public onExitFlight: () => void = () => {};

  private triggerHapticFeedback(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) { }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 1. 周围全黑 OLED 纯黑背景 (Pure Pitch Black Screen)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 2. 居中纯代码程序化客机舷窗总成 (包含动态风景 + 可交互手势遮阳板 + 动态光影程序化窗框)
      Stack({ alignContent: Alignment.Center }) {
        // 2.1 底层：动态风景与可交互遮阳板容器 (精准贴合舷窗跑道形开孔)
        Stack({ alignContent: Alignment.Center }) {
          // 2.1.1 基础动态天空/风景层
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({
              angle: 180,
              colors: [
                ['#1E549F', 0.0],
                ['#4D8BD1', 0.35],
                ['#8BBCEB', 0.60],
                ['#C2DFF8', 0.82],
                ['#EAF4FD', 1.0]
              ]
            })

          // 2.1.2 可手势拖拽交互客机遮光板 (双向绑定 shadeProgress)
          CabinWindowShadePanel({
            containerWidth: 185,
            containerHeight: 310,
            shadeProgress: $shadeProgress
          })
        }
        .width(185)
        .height(310)
        .borderRadius(70)
        .clip(true)

        // 2.2 前景：100% 纯代码 Canvas 程序化渲染客机舷窗框架 (受光高光随 shadeProgress 实时消退)
        CabinWindowProceduralFrame({
          frameWidth: 272,
          frameHeight: 442,
          lightingMode: 'day',
          shadeProgress: this.shadeProgress
        })
      }
      .position({ x: '50%', y: '50%' })
      .markAnchor({ x: '50%', y: '50%' })

      // 3. 顶部控制栏 (带平滑过渡动画，与精修机场地图界面 1:1 对齐)
      Row() {
        // 3.1 左侧：返回退出飞行按钮
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.ic_hw_back_white'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .opacity(0.85)
            .animation({ duration: 400, curve: Curve.EaseInOut })
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(0, 0, 0, 0.50)')
        .backdropBlur(25)
        .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.16)', radius: 20 })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
        .animation({ duration: 400, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.triggerHapticFeedback();
          this.onExitFlight();
        })

        Blank()

        // 3.2 顶部中央：巡航航线信息胶囊
        Row() {
          Text(`${this.originAirport ? this.originAirport.code : 'CTU'} ✈ ${this.destinationAirport ? this.destinationAirport.code : 'PEK'}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#8E8E93')
            .margin({ right: 6 })
            .animation({ duration: 400, curve: Curve.EaseInOut })

          Text('· 巡航 10,800M')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6E6E73')
            .animation({ duration: 400, curve: Curve.EaseInOut })
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .borderRadius(20)
        .backgroundColor('rgba(0, 0, 0, 0.50)')
        .backdropBlur(25)
        .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.16)', radius: 20 })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
        .animation({ duration: 400, curve: Curve.EaseInOut })

        Blank()

        // 3.3 右侧：切回大地图视角按钮
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.ic_map_layers_white'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .opacity(0.85)
            .animation({ duration: 400, curve: Curve.EaseInOut })
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(0, 0, 0, 0.50)')
        .backdropBlur(25)
        .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.16)', radius: 20 })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
        .animation({ duration: 400, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.triggerHapticFeedback();
          this.onToggleWindowView();
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52 })
      .alignItems(VerticalAlign.Top)
      .position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(200)

      // 4. 底部专注任务名称 (左下角) 与 倒计时数字 (右下角) —— 包含平滑颜色过渡动画
      Row() {
        // 左下角：当前专注任务名称
        Text(this.currentFocusTagTitle)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#8E8E93')
          .fontFamily('sans-serif')
          .lineHeight(38)
          .height(38)
          .animation({ duration: 400, curve: Curve.EaseInOut })

        Blank()

        // 右下角：纯数字大号倒计时
        Text(this.remainingTimeString)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#8E8E93')
          .fontFamily('monospace')
          .lineHeight(38)
          .height(38)
          .animation({ duration: 400, curve: Curve.EaseInOut })
      }
      .width('100%')
      .height(38)
      .padding({ left: 22, right: 22 })
      .margin({ bottom: 44 })
      .alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.None)
      .zIndex(160)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
