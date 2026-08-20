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

/**
 * 真实民航客机可交互遮光板组件 (CabinWindowShadePanel)
 * 极致流畅版本：
 * 1. 采用 GPU 原生 Translate 变换，拖拽零掉帧；
 * 2. 智能吸附与触觉震动反馈；
 * 3. 单击快速升降。
 */
@Component
export struct CabinWindowShadePanel {
  @Prop containerWidth: number = 185;
  @Prop containerHeight: number = 310;

  // 遮阳板闭合进度：0.0 (全开) ~ 1.0 (全关)
  @Link shadeProgress: number;
  @State private dragStartProgress: number = 0.0;
  @State private isDragging: boolean = false;

  private triggerHapticFeedback(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) { }
  }

  // 切换遮光板升降 (全开 / 全关)
  public toggleShade(): void {
    this.triggerHapticFeedback();
    const target = this.shadeProgress > 0.5 ? 0.0 : 1.0;
    animateTo({ duration: 360, curve: Curve.FastOutSlowIn }, () => {
      this.shadeProgress = target;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 遮阳板总成：根据 shadeProgress 垂直位移 (GPU 合成器极速位移)
      Column() {
        // 1. 遮阳板主板体 (深灰哑光航空复合板材与立体阴影)
        Column() {
          Row() {
            Divider().vertical(true).strokeWidth(0.6).color('rgba(255, 255, 255, 0.04)').height('100%')
            Divider().vertical(true).strokeWidth(0.6).color('rgba(255, 255, 255, 0.04)').height('100%').margin({ left: 30 })
            Divider().vertical(true).strokeWidth(0.6).color('rgba(255, 255, 255, 0.04)').height('100%').margin({ left: 30 })
            Divider().vertical(true).strokeWidth(0.6).color('rgba(255, 255, 255, 0.04)').height('100%').margin({ left: 30 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(this.containerHeight)
        .linearGradient({
          angle: 180,
          colors: [
            ['#15171D', 0.0],
            ['#1E2129', 0.3],
            ['#272B36', 0.7],
            ['#1F222B', 1.0]
          ]
        })

        // 2. 遮阳板底部机械拉手总成 (Bottom Handle Lip & Grip Recess)
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height(28)
            .linearGradient({
              angle: 180,
              colors: [
                ['#2C313D', 0.0],
                ['#1C1F27', 0.7],
                ['#111318', 1.0]
              ]
            })
            .border({ width: { top: 0.8 }, color: { top: 'rgba(255, 255, 255, 0.18)' } })

          // 中央提手拉环凹槽 (Finger Grip Notch)
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(46)
              .height(13)
              .borderRadius(6.5)
              .backgroundColor('#090A0D')
              .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.15)' })

            Column()
              .width(26)
              .height(3)
              .borderRadius(1.5)
              .backgroundColor('rgba(255, 255, 255, 0.30)' )
          }
        }
        .width('100%')
        .height(28)
        .shadow({
          radius: 10,
          color: 'rgba(0, 0, 0, 0.70)',
          offsetY: 4
        })
        .onClick(() => {
          this.toggleShade();
        })
      }
      .width('100%')
      .translate({
        y: -this.containerHeight + this.shadeProgress * this.containerHeight
      })
      .animation(this.isDragging ? { duration: 0 } : { duration: 360, curve: Curve.FastOutSlowIn })
    }
    .width(this.containerWidth)
    .height(this.containerHeight)
    .clip(true)
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionStart(() => {
          this.isDragging = true;
          this.dragStartProgress = this.shadeProgress;
        })
        .onActionUpdate((event?: GestureEvent) => {
          if (!event) return;
          const deltaProgress = event.offsetY / this.containerHeight;
          let nextProgress = this.dragStartProgress + deltaProgress;
          nextProgress = Math.max(0.0, Math.min(1.0, nextProgress));
          this.shadeProgress = nextProgress;
        })
        .onActionEnd((event?: GestureEvent) => {
          this.isDragging = false;
          let target = this.shadeProgress;
          const velocity = event ? event.velocityY : 0;

          if (velocity > 300) {
            target = 1.0;
          } else if (velocity < -300) {
            target = 0.0;
          } else {
            if (this.shadeProgress < 0.25) {
              target = 0.0;
            } else if (this.shadeProgress > 0.75) {
              target = 1.0;
            } else {
              target = 0.5;
            }
          }

          this.triggerHapticFeedback();
          animateTo({ duration: 360, curve: Curve.FastOutSlowIn }, () => {
            this.shadeProgress = target;
          });
        })
    )
  }
}
