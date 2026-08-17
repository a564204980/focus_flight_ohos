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

import { FocusTagItem, CABIN_FOCUS_TAGS, getSeatTypeLabel } from './CabinTypes';

/**
 * 底部一体化轻奢选座登机牌浮动卡片
 */
@Component
export struct CabinBottomActionSheet {
  @Prop selectedSeatId: string = '';
  @Prop selectedTagId: string = 'study';
  @Prop selectedDurationMinutes: number = 15;
  @Prop tags: FocusTagItem[] = CABIN_FOCUS_TAGS;
  onTagChange?: (tagId: string) => void;
  onOpenCustomDialog?: () => void;
  onConfirm?: (seatId: string, tagId: string, durationMinutes: number) => void;

  build() {
    Column({ space: 14 }) {
      // 1. 登机牌头部 (Header - 纯中文)
      Row() {
        // 左侧：大字号座位号 + 航旅专注标签
        Row({ space: 10 }) {
          // 座位徽章卡
          Column() {
            Text(this.selectedSeatId)
              .fontSize(19)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#0F172A')
              .letterSpacing(0.5)
          }
          .width(44)
          .height(40)
          .backgroundColor('#F8FAFC')
          .borderRadius(10)
          .border({ width: 1, color: '#E2E8F0' })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 舱位及航旅信息 (纯中文)
          Column({ space: 2 }) {
            Row({ space: 4 }) {
              Text('专注航班')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#94A3B8')
                .letterSpacing(0.8)

              Text('· 2026次')
                .fontSize(10)
                .fontColor('#CBD5E1')
            }

            Text(getSeatTypeLabel(this.selectedSeatId))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#475569')
          }
          .alignItems(HorizontalAlign.Start)
        }

        Blank()

        // 右侧：时长状态标签 (纯中文 ⏱️ 45分钟)
        Row({ space: 4 }) {
          Text('⏱️')
            .fontSize(12)
          Text('45分钟')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FA6B56')
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#FFF1EE')
        .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 2. 现代极简双排药丸胶囊选项卡 (3列 × 2排整齐布局 + 末尾加号按钮)
      Grid() {
        ForEach(this.tags, (tag: FocusTagItem) => {
          GridItem() {
            Row({ space: 4 }) {
              Text(tag.icon)
                .fontSize(12)

              Text(tag.name)
                .fontSize(12)
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedTagId === tag.id ? '#FA6B56' : '#64748B')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(this.selectedTagId === tag.id ? '#FFF1EE' : '#F8FAFC')
            .borderRadius(10)
            .border({
              width: 1,
              color: this.selectedTagId === tag.id ? '#FA6B56' : '#E2E8F0'
            })
            .animation({ duration: 200, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              if (this.onTagChange) {
                this.onTagChange(tag.id);
              }
            })
          }
        })

        // 末尾常驻加号按钮 ➕ 自定义
        GridItem() {
          Row({ space: 4 }) {
            Text('➕')
              .fontSize(11)

            Text('自定义')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FA6B56')
          }
          .width('100%')
          .height(36)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#FFF9F8')
          .borderRadius(10)
          .border({
            width: 1,
            color: 'rgba(250, 107, 86, 0.45)',
            style: BorderStyle.Dashed
          })
          .animation({ duration: 200, curve: Curve.FastOutSlowIn })
          .onClick(() => {
            if (this.onOpenCustomDialog) {
              this.onOpenCustomDialog();
            }
          })
        }
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsGap(6)
      .columnsGap(6)
      .width('100%')
      .height(this.tags.length <= 5 ? 78 : Math.ceil((this.tags.length + 1) / 3) * 42)

      // 3. 极简触感起飞大按钮 (统一采用首页标准主题暖珊瑚红 #FA6B56)
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text('开始专注')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(0.8)
      }
      .width('100%')
      .height(48)
      .backgroundColor('#FA6B56')
      .borderRadius(24)
      .shadow({
        radius: 16,
        color: 'rgba(250, 107, 86, 0.35)',
        offsetY: 4
      })
      .onClick(() => {
        if (this.onConfirm) {
          const actualDuration = this.selectedDurationMinutes > 0 ? this.selectedDurationMinutes : 15;
          this.onConfirm(this.selectedSeatId, this.selectedTagId, actualDuration);
        }
      })
    }
    .width('92%')
    .padding({ top: 16, bottom: 16, left: 16, right: 16 })
    .backgroundColor('rgba(255, 255, 255, 0.98)')
    .borderRadius(22)
    .border({ width: 1.2, color: '#E8ECF2' })
    .shadow({
      radius: 24,
      color: 'rgba(15, 23, 42, 0.12)',
      offsetY: 6
    })
    .margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.Default)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 100 })).animation({ duration: 250, curve: Curve.FastOutSlowIn }),
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 100 })).animation({ duration: 180, curve: Curve.EaseOut })
    ))
  }
}
