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

import { CabinPassenger } from '../../models/CabinPassengerModel';

/**
 * 萌宠机友同行心声对话弹窗卡片
 */
@Component
export struct CabinPassengerDialog {
  @Prop passenger: CabinPassenger | null = null;
  onClose?: () => void;

  build() {
    if (this.passenger !== null) {
      Stack({ alignContent: Alignment.Center }) {
        // 半透明背景遮罩，点击关闭
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.35)')
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })

        // 萌宠心声卡片主体
        Column({ space: 12 }) {
          // 1. 头部：萌宠大头像 + 姓名 + 座位号 + 专注标签
          Row({ space: 10 }) {
            // 萌宠圆形头像
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(42)
                .height(42)
                .fill('#FFF1EE')
              Image(this.passenger.icon)
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
            }

            Column({ space: 3 }) {
              Row({ space: 6 }) {
                Text(this.passenger.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F172A')

                Text(`${this.passenger.seatId} 座`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#94A3B8')
              }

              Row({ space: 4 }) {
                Text(this.passenger.role)
                  .fontSize(11)
                  .fontColor('#64748B')

                Text('·')
                  .fontSize(11)
                  .fontColor('#CBD5E1')

                Text(this.passenger.focusTask)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FA6B56')
              }
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            // 专注同行徽章
            Row() {
              Text('专注机友')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FA6B56')
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FFF1EE')
            .borderRadius(8)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 2. 心声台词引文
          Row() {
            Text(`“${this.passenger.quote}”`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#334155')
              .lineHeight(19)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor('#F8FAFC')
          .borderRadius(12)
          .border({ width: 1, color: '#E2E8F0' })

          // 3. 底部温馨提示
          Row({ space: 4 }) {
            Text('🐾')
              .fontSize(11)
            Text('该座位已有萌宠在专注，选旁边的空座做Ta的邻座机友吧~')
              .fontSize(11)
              .fontColor('#94A3B8')
              .layoutWeight(1)
          }
          .width('100%')
        }
        .width('88%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .shadow({
          radius: 28,
          color: 'rgba(15, 23, 42, 0.18)',
          offsetY: 8
        })
        .border({ width: 1.2, color: '#FEE2E2' })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })).animation({ duration: 240, curve: Curve.FastOutSlowIn }),
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })).animation({ duration: 180, curve: Curve.EaseOut })
        ))
        .onClick(() => {
          // 阻止点击向外穿透
        })
      }
      .width('100%')
      .height('100%')
      .zIndex(2000)
    }
  }
}
