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

import { MapRenderHelper, TrailEffectConfig } from '../utils/MapRenderHelper';

/**
 * ✈️ 巡航尾迹切换抽屉（Apple & Flighty 级极简轻量流光药丸滑轨）
 * 占屏仅 218vp，无任何冗余假视窗，真机地图实时联动
 */
@Component
export struct FlightTrailSettingsOverlay {
  @Prop isVisible: boolean = false;
  @Link currentTrailId: string;

  public onSelectTrail: (trailId: string) => void = () => {};
  public onClose: () => void = () => {};

  private readonly trailList: TrailEffectConfig[] = [
    MapRenderHelper.TRAIL_EFFECTS_CONFIG['rainbow'],
    MapRenderHelper.TRAIL_EFFECTS_CONFIG['stardust'],
    MapRenderHelper.TRAIL_EFFECTS_CONFIG['bubbles'],
    MapRenderHelper.TRAIL_EFFECTS_CONFIG['melody'],
    MapRenderHelper.TRAIL_EFFECTS_CONFIG['contrail']
  ];

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 1. 纯净半透明遮罩 (点击空白安全收起)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.35)')
          .backdropBlur(20)
          .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          .onClick(() => {
            this.onClose();
          })

        // 2. 极简轻量主题抽屉 (高仅 218vp，保持通透呼吸感)
        Column() {
          // 2.1 顶部精致拖拽条
          Row()
            .width(36)
            .height(4)
            .borderRadius(2)
            .backgroundColor('#CBD5E1')
            .margin({ top: 10, bottom: 8 })

          // 2.2 极简标题栏
          Row() {
            Text('巡航尾迹')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')

            Blank()

            // 极简关闭圆钮
            Stack({ alignContent: Alignment.Center }) {
              Text('✕')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#64748B')
            }
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor('#F1F5F9')
            .onClick(() => {
              this.onClose();
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 12 })

          // 2.3 极简灵动主题卡片滑轨
          List({ space: 10 }) {
            ForEach(this.trailList, (item: TrailEffectConfig) => {
              ListItem() {
                this.buildMinimalistThemeCard(item)
              }
            }, (item: TrailEffectConfig) => item.id)
          }
          .listDirection(Axis.Horizontal)
          .width('100%')
          .height(108)
          .padding({ left: 20, right: 20 })
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height(218)
        .backgroundColor('#FAFAF8') // 极简温润香草奶霜底
        .borderRadius({ topLeft: 28, topRight: 28 })
        .shadow({ radius: 25, color: 'rgba(0, 0, 0, 0.16)', offsetY: -6 })
        .padding({ bottom: 24 })
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 280, curve: Curve.FastOutSlowIn }))
      }
      .width('100%')
      .height('100%')
      .zIndex(300)
    }
  }

  /**
   * 🎴 极简灵动主题卡片 (大圆角 + 纯净流光条 + 清爽排版)
   */
  @Builder
  private buildMinimalistThemeCard(item: TrailEffectConfig) {
    Column() {
      // 1. 卡片顶部：专属流光微条
      this.buildGlowRibbon(item.id)

      // 2. 特效名称
      Text(item.name)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTrailId === item.id ? '#F06553' : '#1E293B')
        .maxLines(1)
        .margin({ top: 12 })

      // 3. 场景副标
      Text(item.badge)
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ top: 4, bottom: 8 })
    }
    .width(122)
    .height(98)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .border({
      width: this.currentTrailId === item.id ? 2 : 1,
      color: this.currentTrailId === item.id ? '#F06553' : 'rgba(0, 0, 0, 0.05)'
    })
    .shadow({
      radius: this.currentTrailId === item.id ? 8 : 2,
      color: this.currentTrailId === item.id ? 'rgba(240, 101, 83, 0.16)' : 'rgba(0, 0, 0, 0.02)',
      offsetY: 2
    })
    .onClick(() => {
      this.currentTrailId = item.id;
      this.onSelectTrail(item.id);
    })
  }

  /**
   * 🌈 卡片顶部专属流光微条
   */
  @Builder
  private buildGlowRibbon(trailId: string) {
    if (trailId === 'rainbow') {
      Row()
        .width(84)
        .height(7)
        .borderRadius(3.5)
        .linearGradient({
          angle: 90,
          colors: [
            ['#AF52DE', 0.0],
            ['#0A84FF', 0.20],
            ['#34C759', 0.40],
            ['#FFCC00', 0.60],
            ['#FF9500', 0.80],
            ['#FF3B30', 1.0]
          ]
        })
        .margin({ top: 14 })
    } else if (trailId === 'stardust') {
      Row()
        .width(84)
        .height(7)
        .borderRadius(3.5)
        .linearGradient({
          angle: 90,
          colors: [
            ['#FFD700', 0.0],
            ['#FFE066', 0.35],
            ['#FFFFFF', 0.70],
            ['#FFAA33', 1.0]
          ]
        })
        .margin({ top: 14 })
    } else if (trailId === 'bubbles') {
      Row()
        .width(84)
        .height(7)
        .borderRadius(3.5)
        .linearGradient({
          angle: 90,
          colors: [
            ['#F472B6', 0.0],
            ['#38BDF8', 0.40],
            ['#A78BFA', 0.75],
            ['#34D399', 1.0]
          ]
        })
        .margin({ top: 14 })
    } else if (trailId === 'aurora') {
      Row()
        .width(84)
        .height(7)
        .borderRadius(3.5)
        .linearGradient({
          angle: 90,
          colors: [
            ['#00FF88', 0.0],
            ['#00F5D4', 0.35],
            ['#00BBF9', 0.70],
            ['#7209B7', 1.0]
          ]
        })
        .margin({ top: 14 })
    } else {
      // ☁️ 凝结尾迹云：左右双发纯白水汽微条
      Row({ space: 4 }) {
        Row()
          .width(38)
          .height(6)
          .borderRadius(3)
          .linearGradient({
            angle: 90,
            colors: [['rgba(186, 230, 253, 0.4)', 0.0], ['#FFFFFF', 1.0]]
          })

        Row()
          .width(38)
          .height(6)
          .borderRadius(3)
          .linearGradient({
            angle: 90,
            colors: [['rgba(186, 230, 253, 0.4)', 0.0], ['#FFFFFF', 1.0]]
          })
      }
      .width(84)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 14 })
    }
  }
}
