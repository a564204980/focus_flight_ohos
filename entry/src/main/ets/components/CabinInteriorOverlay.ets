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
import {
  CabinPassenger,
  WalkingPassengerState,
  generateRandomCabinPassengers,
  getSeatAisleWalkingTarget
} from '../models/CabinPassengerModel';
import { FocusTagItem, CABIN_FOCUS_TAGS } from './cabin/CabinTypes';
import { WalkingPassengerSprite } from './cabin/WalkingPassengerSprite';
import { CabinBottomActionSheet } from './cabin/CabinBottomActionSheet';
import { CabinWindowTile, FirstClassSeatTile, EconomySeatTile } from './cabin/CabinSeatTile';
import { CustomTagDialog } from './cabin/CustomTagDialog';

export { FocusTagItem };

/**
 * CabinInteriorOverlay.ets
 * Focus Flight - 2.5D 高精精致航线客舱主控总装容器
 */
@Component
export struct CabinInteriorOverlay {
  @State selectedSeatId: string = ''; // 默认不选座
  @State selectedTagId: string = 'study';
  @State customTags: FocusTagItem[] = [];
  @State isCustomTagDialogVisible: boolean = false;
  @State speakingSeatId: string = ''; // 当前正在头顶冒气泡发言的萌宠座位号
  @State passengers: Map<string, CabinPassenger> = new Map();
  @State seatedPassengerIds: string[] = [];
  @State walkingPassengers: WalkingPassengerState[] = [];

  private autoDismissTimerId: number = -1;
  private boardingTimerIds: number[] = [];

  onSeatClick?: (seatId: string) => void;
  onConfirmFlight?: (seatId: string, tagId: string, durationMinutes: number) => void;

  aboutToAppear(): void {
    this.passengers = generateRandomCabinPassengers();
    this.seatedPassengerIds = [];
    this.walkingPassengers = [];
    // 待 3D 飞机放大剖开与机舱完全清晰呈现给用户后 (1.1s)，再启动全量空座排队登机
    const startTimer = setTimeout(() => {
      this.startBoardingSequence();
    }, 1100);
    this.boardingTimerIds.push(startTimer);
  }

  aboutToDisappear(): void {
    if (this.autoDismissTimerId !== -1) {
      clearTimeout(this.autoDismissTimerId);
      this.autoDismissTimerId = -1;
    }
    this.boardingTimerIds.forEach(id => clearTimeout(id));
    this.boardingTimerIds = [];
  }

  private getAllTags(): FocusTagItem[] {
    return [...CABIN_FOCUS_TAGS, ...this.customTags];
  }

  private startBoardingSequence(): void {
    const list: CabinPassenger[] = Array.from(this.passengers.values());
    
    // 初始状态：100% 全舱空座，没有任何小动物提前就座！
    this.seatedPassengerIds = [];
    this.walkingPassengers = [];

    // 随机打乱登机次序（自然生动！）
    const shuffled: CabinPassenger[] = [...list].sort((): number => Math.random() - 0.5);

    shuffled.forEach((p: CabinPassenger, index: number) => {
      const target = getSeatAisleWalkingTarget(p.seatId);
      // 错峰排队间隔 (150ms ~ 170ms)
      const spawnDelay = index * 160 + Math.floor(Math.random() * 20);
      // 舒缓从容的走道漫步时长 (1.1s ~ 1.8s)
      const walkDuration = Math.max(1100, Math.floor((target.targetY / 500) * 1600) + Math.floor(Math.random() * 80));
      const slideDuration = 420;

      const timerId = setTimeout(() => {
        // 如果该座位在登机前已经被用户先占了，小动物取消登机
        if (this.selectedSeatId === p.seatId) {
          return;
        }
        const wp: WalkingPassengerState = {
          seatId: p.seatId,
          icon: p.icon,
          emoji: p.emoji,
          targetX: target.targetX,
          targetY: target.targetY,
          walkDuration: walkDuration,
          slideDuration: slideDuration
        };
        this.walkingPassengers = [...this.walkingPassengers, wp];
      }, spawnDelay);

      this.boardingTimerIds.push(timerId);
    });
  }

  private showPassengerSpeech(passenger: CabinPassenger): void {
    if (this.autoDismissTimerId !== -1) {
      clearTimeout(this.autoDismissTimerId);
    }

    // 动态轮换台词：每次点击小动物，都从其专属语录库中随机挑选一句全新的不同台词
    if (passenger.quotes && passenger.quotes.length > 0) {
      let nextIdx = Math.floor(Math.random() * passenger.quotes.length);
      if (passenger.quotes.length > 1 && passenger.quotes[nextIdx] === passenger.quote) {
        nextIdx = (nextIdx + 1) % passenger.quotes.length;
      }
      passenger.quote = passenger.quotes[nextIdx];
    }

    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.speakingSeatId = passenger.seatId;
    });
    this.triggerHaptic();
    this.autoDismissTimerId = setTimeout(() => {
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        if (this.speakingSeatId === passenger.seatId) {
          this.speakingSeatId = '';
        }
      });
      this.autoDismissTimerId = -1;
    }, 3200);
  }

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

  private handleSeatSelection(seatId: string): void {
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      if (this.selectedSeatId === seatId) {
        this.selectedSeatId = '';
      } else {
        this.selectedSeatId = seatId;
        this.passengers.delete(seatId);
        this.seatedPassengerIds = this.seatedPassengerIds.filter((id: string): boolean => id !== seatId);
        this.walkingPassengers = this.walkingPassengers.filter((item: WalkingPassengerState): boolean => item.seatId !== seatId);
      }
    });
    this.triggerHaptic();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 机舱固定全景 (100% 居中显示，包含座椅网格与萌宠走道动效层)
      Column() {
        Stack({ alignContent: Alignment.TopStart }) {
          Column({ space: 6 }) {
            // 1a. 第 1 ~ 2 排：👑 豪华头等舱 (2-2 宽体大座布局)
            ForEach([1, 2], (rowNum: number) => {
              Row() {
                // 左侧舷窗
                Stack() {
                  CabinWindowTile()
                }
                .margin({ right: 8 })

                // 左侧 2 座头等舱 (A, C)
                Row({ space: 20 }) {
                  FirstClassSeatTile({
                    seatId: `${rowNum}A`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  FirstClassSeatTile({
                    seatId: `${rowNum}C`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                }
                .width(120)
                .justifyContent(FlexAlign.Center)

                // 宽敞中央过道 (极简暗调走道)
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(30)
                    .height(28)
                    .backgroundColor('rgba(255, 255, 255, 0.04)')
                    .border({
                      width: { left: 1, right: 1 },
                      color: 'rgba(255, 255, 255, 0.10)',
                      style: BorderStyle.Dashed
                    })

                  Text(`${rowNum}`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.45)')
                }
                .width(48)

                // 右侧 2 座头等舱 (D, F)
                Row({ space: 20 }) {
                  FirstClassSeatTile({
                    seatId: `${rowNum}D`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  FirstClassSeatTile({
                    seatId: `${rowNum}F`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                }
                .width(120)
                .justifyContent(FlexAlign.Center)

                // 右侧舷窗
                Stack() {
                  CabinWindowTile()
                }
                .margin({ left: 8 })
              }
              .alignItems(VerticalAlign.Center)
              .zIndex(this.selectedSeatId.startsWith(`${rowNum}`) || this.speakingSeatId.startsWith(`${rowNum}`) ? 999 : (15 - rowNum))
            })

            // 头等舱 / 经济舱优雅分隔幕帘线
            Row({ space: 6 }) {
              Row().layoutWeight(1).height(1).backgroundColor('rgba(255, 255, 255, 0.12)')
              Row({ space: 3 }) {
                Text('👑').fontSize(8.5)
                Text('头等舱专区')
                  .fontSize(8.5)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FBBF24')
                  .letterSpacing(0.8)
              }
              Row().layoutWeight(1).height(1).backgroundColor('rgba(255, 255, 255, 0.12)')
            }
            .width('85%')
            .margin({ top: 1, bottom: 1 })

            // 1c. 普通舱座椅列标题：A B C | (中央过道) | D E F
            Row() {
              Row({ space: 6 }) {
                Text('A').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
                Text('B').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
                Text('C').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
              }
              .margin({ left: 20 })

              Blank().width(48)

              Row({ space: 6 }) {
                Text('D').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
                Text('E').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
                Text('F').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#94A3B8').width(36).textAlign(TextAlign.Center)
              }
              .margin({ right: 20 })
            }
            .margin({ top: 1, bottom: 1 })

            // 1d. 第 3 ~ 13 排：专注客舱 (3-3 饱满大气布局)
            ForEach([3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], (rowNum: number) => {
              Row() {
                // 左侧舷窗
                Stack() {
                  CabinWindowTile()
                }
                .margin({ right: 8 })

                // 左侧 3 座 A, B, C
                Row({ space: 6 }) {
                  EconomySeatTile({
                    seatId: `${rowNum}A`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  EconomySeatTile({
                    seatId: `${rowNum}B`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  EconomySeatTile({
                    seatId: `${rowNum}C`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                }
                .width(120)

                // 宽敞中央过道 (极简暗调走道)
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(30)
                    .height(28)
                    .backgroundColor('rgba(255, 255, 255, 0.04)')
                    .border({
                      width: { left: 1, right: 1 },
                      color: 'rgba(255, 255, 255, 0.10)',
                      style: BorderStyle.Dashed
                    })

                  Text(`${rowNum}`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.45)')
                }
                .width(48)

                // 右侧 3 座 D, E, F
                Row({ space: 6 }) {
                  EconomySeatTile({
                    seatId: `${rowNum}D`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  EconomySeatTile({
                    seatId: `${rowNum}E`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                  EconomySeatTile({
                    seatId: `${rowNum}F`,
                    selectedSeatId: this.selectedSeatId,
                    selectedTagId: this.selectedTagId,
                    tags: this.getAllTags(),
                    seatedPassengerIds: this.seatedPassengerIds,
                    speakingSeatId: this.speakingSeatId,
                    passengers: this.passengers,
                    onSeatClick: (id: string) => this.handleSeatSelection(id),
                    onPassengerClick: (p: CabinPassenger) => this.showPassengerSpeech(p)
                  })
                }
                .width(120)

                // 右侧舷窗
                Stack() {
                  CabinWindowTile()
                }
                .margin({ left: 8 })
              }
              .alignItems(VerticalAlign.Center)
              .zIndex(this.selectedSeatId.startsWith(`${rowNum}`) || this.speakingSeatId.startsWith(`${rowNum}`) ? 999 : (15 - rowNum))
            })
          }
          .width(328)
          .alignItems(HorizontalAlign.Center)

          // 萌宠登机走道与起跳入座动效层
          ForEach(this.walkingPassengers, (wp: WalkingPassengerState) => {
            WalkingPassengerSprite({
              wp: wp,
              selectedUserSeatId: this.selectedSeatId,
              onSeated: (seatId: string) => {
                if (this.selectedSeatId === seatId) {
                  return; // 用户已占座，小动物放弃入座
                }
                this.seatedPassengerIds = [...this.seatedPassengerIds, seatId];
                this.walkingPassengers = this.walkingPassengers.filter((item: WalkingPassengerState): boolean => item.seatId !== seatId);
              }
            })
          }, (wp: WalkingPassengerState) => wp.seatId)

          // 🌟 顶层全局悬浮萌宠心声名言 (暗夜幽蓝微光气泡 + 纯白高对比度文字 #F8FAFC)
          if (this.speakingSeatId !== '' && this.passengers.has(this.speakingSeatId)) {
            Row() {
              Text(this.passengers.get(this.speakingSeatId)!.quote)
                .fontSize(10.5)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
                .textAlign(TextAlign.Center)
                .maxLines(1)
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('rgba(15, 23, 42, 0.90)')
            .border({ width: 1, color: 'rgba(56, 189, 248, 0.45)', radius: 12 })
            .borderRadius(12)
            .shadow({ radius: 10, color: 'rgba(56, 189, 248, 0.35)', offsetY: 2 })
            .width(180)
            .justifyContent(FlexAlign.Center)
            .hitTestBehavior(HitTestMode.None)
            .position({
              x: 164 + getSeatAisleWalkingTarget(this.speakingSeatId).targetX - 90 +
                 ((getSeatAisleWalkingTarget(this.speakingSeatId).targetX < -60) ? 35 : ((getSeatAisleWalkingTarget(this.speakingSeatId).targetX > 60) ? -35 : 0)),
              y: getSeatAisleWalkingTarget(this.speakingSeatId).targetY - 28
            })
            .zIndex(99999)
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 6 })).animation({ duration: 240, curve: Curve.FastOutSlowIn }),
              TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })).animation({ duration: 200, curve: Curve.EaseOut })
            ))
          }
        }
        .width(328)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 2. 底部悬浮一体化选座卡片 (双排布局 + ➕ 自定义按钮)
      if (this.selectedSeatId !== '') {
        CabinBottomActionSheet({
          selectedSeatId: this.selectedSeatId,
          selectedTagId: this.selectedTagId,
          tags: this.getAllTags(),
          onTagChange: (tagId: string) => {
            animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
              this.selectedTagId = tagId;
            });
            this.triggerHaptic();
          },
          onOpenCustomDialog: () => {
            this.isCustomTagDialogVisible = true;
            this.triggerHaptic();
          },
          onConfirm: (seatId: string, tagId: string, durationMinutes: number) => {
            this.triggerHaptic();
            if (this.onConfirmFlight) {
              this.onConfirmFlight(seatId, tagId, durationMinutes);
            } else if (this.onSeatClick) {
              this.onSeatClick(seatId);
            }
          }
        })
      }

      // 3. 自定义专属专注任务标签弹窗 (含 36 款精选图标，无滚动条，边框清晰)
      CustomTagDialog({
        isVisible: this.isCustomTagDialogVisible,
        onCancel: () => {
          this.isCustomTagDialogVisible = false;
        },
        onConfirm: (newTag: FocusTagItem) => {
          this.isCustomTagDialogVisible = false;
          this.customTags = [...this.customTags, newTag];
          animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
            this.selectedTagId = newTag.id;
          });
        }
      })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      if (this.speakingSeatId) {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.speakingSeatId = '';
        });
      }
      if (this.selectedSeatId) {
        animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
          this.selectedSeatId = '';
        });
        this.triggerHaptic();
      }
    })
  }
}
