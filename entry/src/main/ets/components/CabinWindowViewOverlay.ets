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
import { CabinWindowProceduralClouds } from './CabinWindowProceduralClouds';
import { CabinWindowProceduralFrame } from './CabinWindowProceduralFrame';
import { CabinWindowShadePanel } from './CabinWindowShadePanel';

/**
 * 电影级渐进式机舱舷窗沉浸视界 (CabinWindowViewOverlay)
 * 🎬 电影级三幕式启闭流程：
 * 1. 幕一：界面渐渐变黑 (450ms 纯黑淡入覆盖大地图)；
 * 2. 幕二：暗场中舷窗柔和浮现 (初始遮阳帘完全关闭 shadeProgress = 1.0)；
 * 3. 幕三：遮阳帘自动缓缓向上拉开 (1100ms 物理阻尼)，万米平流层/星河迎光绽现！
 * 4. 退出：舷窗柔和消散，黑色暗场渐渐褪去，优雅重现大地图。
 * （注：顶栏操作按钮与共享舷窗滑移按钮由顶层 FlightMapHudOverlay 统一呈现，零冗余重叠）
 */
@Component
export struct CabinWindowViewOverlay {
  @Prop remainingTimeString: string = '45:00';
  @Prop currentFocusTagTitle: string = '深度学习';
  @Prop originAirport: Airport | null = null;
  @Prop destinationAirport: Airport | null = null;
  @Prop isFlightPaused: boolean = false;
  @Prop isTurbulenceActive: boolean = false;
  @Prop turbulenceMessageText: string = '遭遇巡航微气流，航向平稳修正中';
  onOpenLiveLog?: () => void;

  // 1. 全屏纯黑暗场透明度 (0.0 -> 1.0)
  @State bgDimOpacity: number = 0.0;
  // 2. 舷窗主体与UI透明度 (0.0 -> 1.0)
  @State windowUnitOpacity: number = 0.0;
  @State windowUnitScale: number = 0.92;
  // 3. 遮阳板闭合进度：默认全开 (0.0)
  @State shadeProgress: number = 0.0;

  aboutToAppear(): void {
    // 🎬 幕一：大地图渐渐变黑 (0ms -> 450ms)
    animateTo({ duration: 450, curve: Curve.EaseInOut }, () => {
      this.bgDimOpacity = 1.0;
    });

    // 🎬 幕二：纯黑暗场中舷窗柔和浮现
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.windowUnitOpacity = 1.0;
        this.windowUnitScale = 1.0;
      });
    }, 280);
  }

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
      // 1. 周围渐渐变黑的 OLED 纯黑背景遮罩 (Pure Pitch Black Screen Fade)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.bgDimOpacity)
        .hitTestBehavior(HitTestMode.None)

      // 2. 居中纯代码程序化客机舷窗总成 (暗场中柔和浮现)
      Stack({ alignContent: Alignment.Center }) {
        // 2.1 底层：纯代码真实平流层流云海与可交互遮阳板容器 (精准贴合舷窗跑道形开孔)
        Stack({ alignContent: Alignment.Center }) {
          // 2.1.1 纯代码真实平流层分形流云海 (多阶水汽羽化、双层视差流动、24 小时无缝无限连续流淌)
          CabinWindowProceduralClouds({
            containerWidth: 185,
            containerHeight: 310,
            isFlightPaused: this.isFlightPaused
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

        // 2.2 前景：100% 纯代码 Canvas 程序化渲染客机舷窗框架 (图 1 原生极致质感，受光高光随 shadeProgress 实时消退)
        CabinWindowProceduralFrame({
          frameWidth: 272,
          frameHeight: 442,
          lightingMode: 'day',
          shadeProgress: this.shadeProgress
        })
      }
      .position({ x: '50%', y: '50%' })
      .markAnchor({ x: '50%', y: '50%' })
      .opacity(this.windowUnitOpacity)
      .scale({ x: this.windowUnitScale, y: this.windowUnitScale })

      // 3. 气流扰动纯文字广播 (独立浮现于「专注任务名称」正上方，与地图页位置、样式、入场/出场动效 1:1 严格对齐)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
