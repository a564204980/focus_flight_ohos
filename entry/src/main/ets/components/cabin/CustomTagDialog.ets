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
import { FocusTagItem } from './CabinTypes';

/**
 * 萌系自定义专属专注任务标签弹窗 (包含 36 款精选生产力与生活图标)
 */
@Component
export struct CustomTagDialog {
  @State tagName: string = '';
  @State selectedEmoji: string = '🎯';
  @Prop isVisible: boolean = false;

  onCancel?: () => void;
  onConfirm?: (newTag: FocusTagItem) => void;

  private readonly emojiOptions: string[] = [
    // 目标与高能
    '🎯', '⚡', '🚀', '🌟', '🏆', '🔥',
    // 学习与研读
    '📚', '📖', '📝', '✏️', '🎓', '🔬',
    // 工作与编程
    '💻', '💼', '📊', '💡', '⌨️', '🔍',
    // 创意与艺术
    '🎨', '🎵', '🎹', '🎬', '📷', '✒️',
    // 生活与健康
    '☕', '🍵', '🧘', '🏃', '🚴', '🌱',
    // 旅程与远方
    '✈️', '🏔️', '🧭', '⏳', '🌈', '🐾'
  ];

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 半透明背景遮罩，点击取消
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.45)')
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel();
            }
          })

        // 2. 自定义弹窗卡片主体
        Column({ space: 14 }) {
          // 头部标题与萌趣副标
          Row() {
            Column({ space: 3 }) {
              Text('✨ 自定义专属专注')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')

              Text('为本次航程设定专属专注目标')
                .fontSize(11)
                .fontColor('#94A3B8')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            // 选中的 Emoji 预览大徽章
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(40)
                .height(40)
                .fill('#FFF1EE')
              Text(this.selectedEmoji)
                .fontSize(22)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 任务名称输入框 (限长 6 字符，保证胶囊显示美观)
          Column({ space: 4 }) {
            Row() {
              TextInput({
                text: this.tagName,
                placeholder: '输入任务（如：考研数学、背单词、写周报）'
              })
                .maxLength(6)
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#0F172A')
                .placeholderColor('#94A3B8')
                .backgroundColor('#F8FAFC')
                .borderRadius(12)
                .border({ width: 1, color: '#E2E8F0' })
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.tagName = value.trim();
                })
            }
            .width('100%')

            Row() {
              Text('最多 6 个字，将显示在座椅头枕悬浮气泡中')
                .fontSize(10.5)
                .fontColor('#94A3B8')
            }
            .width('100%')
            .padding({ left: 4 })
          }

          // 图标挑选选择器 (6 列网格，涵盖 36 款丰富图标)
          Column({ space: 6 }) {
            Row() {
              Text('选择专注图标')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#475569')

              Blank()

              Text('36 款精选图标')
                .fontSize(10.5)
                .fontColor('#94A3B8')
            }
            .width('100%')

            Grid() {
              ForEach(this.emojiOptions, (emoji: string) => {
                GridItem() {
                  Stack({ alignContent: Alignment.Center }) {
                    Text(emoji)
                      .fontSize(18)
                  }
                  .width(36)
                  .height(36)
                  .borderRadius(10)
                  .backgroundColor(this.selectedEmoji === emoji ? '#FFF1EE' : '#F8FAFC')
                  .border({
                    width: this.selectedEmoji === emoji ? 1.6 : 1.0,
                    color: this.selectedEmoji === emoji ? '#FA6B56' : '#E2E8F0'
                  })
                  .shadow({
                    radius: this.selectedEmoji === emoji ? 6 : 0,
                    color: 'rgba(250, 107, 86, 0.25)',
                    offsetY: 1
                  })
                  .animation({ duration: 180, curve: Curve.FastOutSlowIn })
                  .onClick(() => {
                    this.selectedEmoji = emoji;
                    this.triggerHaptic();
                  })
                }
              })
            }
            .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
            .rowsGap(8)
            .columnsGap(6)
            .padding({ top: 4, bottom: 4, left: 2, right: 2 })
            .width('100%')
            .height(140)
            .scrollBar(BarState.Off)
            .clip(false)
          }

          // 底部操作按钮：取消 + 确定添加
          Row({ space: 10 }) {
            Button({ type: ButtonType.Normal }) {
              Text('取消')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#64748B')
            }
            .layoutWeight(1)
            .height(42)
            .backgroundColor('#F1F5F9')
            .borderRadius(21)
            .onClick(() => {
              if (this.onCancel) {
                this.onCancel();
              }
            })

            Button({ type: ButtonType.Normal }) {
              Text('确定添加')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1.4)
            .height(42)
            .backgroundColor(this.tagName.length > 0 ? '#FA6B56' : 'rgba(250, 107, 86, 0.45)')
            .borderRadius(21)
            .shadow({
              radius: this.tagName.length > 0 ? 12 : 0,
              color: 'rgba(250, 107, 86, 0.35)',
              offsetY: 3
            })
            .enabled(this.tagName.length > 0)
            .onClick(() => {
              if (this.tagName.length === 0) {
                return;
              }
              this.triggerHaptic();
              const newTag: FocusTagItem = {
                id: `custom_${Date.now()}`,
                name: this.tagName,
                sub: '专属目标',
                icon: this.selectedEmoji,
                color: '#FA6B56',
                pastelBg: '#FFF1EE',
                borderColor: '#FEE2E2',
                activeBg: '#FA6B56',
                shadowColor: 'rgba(250, 107, 86, 0.35)',
                isCustom: true
              };
              if (this.onConfirm) {
                this.onConfirm(newTag);
              }
            })
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('88%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(22)
        .shadow({
          radius: 28,
          color: 'rgba(15, 23, 42, 0.20)',
          offsetY: 8
        })
        .border({ width: 1.2, color: '#FEE2E2' })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })).animation({ duration: 240, curve: Curve.FastOutSlowIn }),
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })).animation({ duration: 180, curve: Curve.EaseOut })
        ))
        .onClick(() => {
          // 拦截内部点击
        })
      }
      .width('100%')
      .height('100%')
      .zIndex(3000)
    }
  }
}
