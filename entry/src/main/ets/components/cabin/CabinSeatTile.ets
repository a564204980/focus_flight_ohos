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
import { CABIN_FOCUS_TAGS, FocusTagItem } from './CabinTypes';

/**
 * 舷窗组件 (深色机身下的微蓝透光舷窗)
 */
@Component
export struct CabinWindowTile {
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 外框轮廓 (深色机身金属反光框)
      Column()
        .width(12)
        .height(18)
        .borderRadius(6)
        .backgroundColor('rgba(255, 255, 255, 0.15)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.22)' })

      // 内舷窗玻璃微蓝透光
      Column()
        .width(6.5)
        .height(11)
        .borderRadius(3.25)
        .backgroundColor('rgba(56, 189, 248, 0.40)')
        .border({ width: 0.8, color: 'rgba(56, 189, 248, 0.65)' })
    }
    .opacity(0.85)
  }
}

/**
 * 👑 豪华头等舱宽体大座组件 (50×33vp)
 */
@Component
export struct FirstClassSeatTile {
  @Prop seatId: string;
  @Prop selectedSeatId: string = '';
  @Prop selectedTagId: string = 'study';
  @Prop tags: FocusTagItem[] = CABIN_FOCUS_TAGS;
  @Prop seatedPassengerIds: string[] = [];
  @Prop speakingSeatId: string = '';
  passengers: Map<string, CabinPassenger> = new Map();

  onSeatClick?: (seatId: string) => void;
  onPassengerClick?: (passenger: CabinPassenger) => void;

  private getSelectedTagName(): string {
    const found = this.tags.find((t: FocusTagItem): boolean => t.id === this.selectedTagId);
    return found ? found.name : '专注';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 0. 顶部悬浮定位气泡 (与头等舱座椅等宽 50vp 绝对居中对齐，悬浮于座椅上方)
      Column() {
        Text(this.getSelectedTagName())
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .maxLines(1)
      }
      .width(50)
      .height(15)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FA6B56')
      .borderRadius(7.5)
      .shadow({
        radius: 6,
        color: 'rgba(250, 107, 86, 0.45)',
        offsetY: 1.5
      })
      .position({
        x: 0,
        y: this.selectedSeatId === this.seatId ? -18 : -13
      })
      .opacity(this.selectedSeatId === this.seatId ? 1 : 0)
      .scale({
        x: this.selectedSeatId === this.seatId ? 1.0 : 0.7,
        y: this.selectedSeatId === this.seatId ? 1.0 : 0.7
      })
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      .hitTestBehavior(HitTestMode.None)
      .zIndex(1000)

      // 1. 左右实木金属扶手
      Row() {
        Column()
          .width(4.5)
          .height(23)
          .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : '#334155')
          .borderRadius(2.25)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

        Blank()

        Column()
          .width(4.5)
          .height(23)
          .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : '#334155')
          .borderRadius(2.25)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      }
      .width(48)
      .height(28)
      .padding({ left: 1, right: 1 })
      .margin({ top: 3.5 })

      // 2. 上部宽体座垫区
      Column() {
        if (!this.passengers.has(this.seatId)) {
          if (this.selectedSeatId === this.seatId) {
            Text('👑')
              .fontSize(7.5)
              .opacity(0.85)
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
          } else {
            Text('👑')
              .fontSize(7.5)
              .fontColor('#FBBF24')
              .opacity(0.65)
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
          }
        }
      }
      .width(34)
      .height(11)
      .margin({ top: 3.5 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.20)' : 'rgba(15, 23, 42, 0.65)')
      .border({
        width: 1,
        color: this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : 'rgba(245, 158, 11, 0.25)',
        radius: 4
      })
      .borderRadius(4)
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })

      // 3. 底部宽大双曲面头枕 (深金色暗夜皮革)
      Column()
        .width(36)
        .height(10)
        .backgroundColor(this.selectedSeatId === this.seatId ? '#FA6B56' : 'rgba(217, 119, 6, 0.30)')
        .border({
          width: this.selectedSeatId === this.seatId ? 0 : 1,
          color: 'rgba(245, 158, 11, 0.40)'
        })
        .borderRadius({ topLeft: 5, topRight: 5, bottomLeft: 7, bottomRight: 7 })
        .animation({ duration: 250, curve: Curve.FastOutSlowIn })

      // 4. 萌宠乘客端坐居中 (严格左右绝对水平居中，仅在落座后显现)
      if (this.passengers.has(this.seatId) && this.seatedPassengerIds.includes(this.seatId)) {
        Column() {
          Image(this.passengers.get(this.seatId)!.icon)
            .width(25)
            .height(25)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height(25)
        .position({ x: 0, y: 2.5 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.None)
        .zIndex(20)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.6, y: 0.6 })))
      }
    }
    .width(50)
    .height(33)
    .backgroundColor(this.selectedSeatId === this.seatId ? '#FA6B56' : '#1E293B')
    .border({
      width: this.selectedSeatId === this.seatId ? 1.6 : 1.2,
      color: this.selectedSeatId === this.seatId ? '#FA6B56' : 'rgba(245, 158, 11, 0.35)',
      radius: { topLeft: 7, topRight: 7, bottomLeft: 9, bottomRight: 9 }
    })
    .borderRadius({ topLeft: 7, topRight: 7, bottomLeft: 9, bottomRight: 9 })
    .shadow({
      radius: this.selectedSeatId === this.seatId ? 10 : 2,
      color: this.selectedSeatId === this.seatId ? 'rgba(250, 107, 86, 0.50)' : 'rgba(0, 0, 0, 0.25)',
      offsetY: 2
    })
    .scale({
      x: this.selectedSeatId === this.seatId ? 1.06 : 1.0,
      y: this.selectedSeatId === this.seatId ? 1.06 : 1.0
    })
    .translate({
      y: this.selectedSeatId === this.seatId ? -1.5 : 0
    })
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    .zIndex(this.selectedSeatId === this.seatId ? 999 : 1)
    .onClick(() => {
      if (this.passengers.has(this.seatId) && this.seatedPassengerIds.includes(this.seatId)) {
        if (this.onPassengerClick) {
          this.onPassengerClick(this.passengers.get(this.seatId)!);
        }
        return;
      }
      if (this.onSeatClick) {
        this.onSeatClick(this.seatId);
      }
    })
  }
}

/**
 * 💺 航空经济座椅组件 (36×30vp)
 */
@Component
export struct EconomySeatTile {
  @Prop seatId: string;
  @Prop selectedSeatId: string = '';
  @Prop selectedTagId: string = 'study';
  @Prop tags: FocusTagItem[] = CABIN_FOCUS_TAGS;
  @Prop seatedPassengerIds: string[] = [];
  @Prop speakingSeatId: string = '';
  passengers: Map<string, CabinPassenger> = new Map();

  onSeatClick?: (seatId: string) => void;
  onPassengerClick?: (passenger: CabinPassenger) => void;

  private getSelectedTagName(): string {
    const found = this.tags.find((t: FocusTagItem): boolean => t.id === this.selectedTagId);
    return found ? found.name : '专注';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 0. 顶部悬浮定位气泡 (与经济舱座椅等宽 36vp 绝对居中对齐，悬浮于座椅上方)
      Column() {
        Text(this.getSelectedTagName())
          .fontSize(8.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .maxLines(1)
      }
      .width(36)
      .height(13.5)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FA6B56')
      .borderRadius(6.75)
      .shadow({
        radius: 5,
        color: 'rgba(250, 107, 86, 0.45)',
        offsetY: 1.5
      })
      .position({
        x: 0,
        y: this.selectedSeatId === this.seatId ? -16.5 : -11
      })
      .opacity(this.selectedSeatId === this.seatId ? 1 : 0)
      .scale({
        x: this.selectedSeatId === this.seatId ? 1.0 : 0.7,
        y: this.selectedSeatId === this.seatId ? 1.0 : 0.7
      })
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      .hitTestBehavior(HitTestMode.None)
      .zIndex(1000)

      // 1. 左右工学细扶手
      Row() {
        Column()
          .width(3.2)
          .height(20)
          .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : '#334155')
          .borderRadius(1.6)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

        Blank()

        Column()
          .width(3.2)
          .height(20)
          .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : '#334155')
          .borderRadius(1.6)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      }
      .width(34)
      .height(25)
      .padding({ left: 1, right: 1 })
      .margin({ top: 3.5 })

      // 2. 上部座垫区
      Column()
        .width(23)
        .height(10)
        .margin({ top: 3.5 })
        .backgroundColor(this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.20)' : 'rgba(15, 23, 42, 0.65)')
        .border({
          width: 1,
          color: this.selectedSeatId === this.seatId ? 'rgba(255, 255, 255, 0.35)' : 'rgba(148, 163, 184, 0.18)',
          radius: 3.5
        })
        .borderRadius(3.5)
        .animation({ duration: 250, curve: Curve.FastOutSlowIn })

      // 3. 底部靠背/头枕
      Column()
        .width(25)
        .height(8.5)
        .backgroundColor(this.selectedSeatId === this.seatId ? '#FA6B56' : 'rgba(56, 189, 248, 0.22)')
        .borderRadius({ topLeft: 4, topRight: 4, bottomLeft: 6, bottomRight: 6 })
        .animation({ duration: 250, curve: Curve.FastOutSlowIn })

      // 4. 萌宠乘客端坐居中 (严格左右绝对水平居中，仅在落座后显现)
      if (this.passengers.has(this.seatId) && this.seatedPassengerIds.includes(this.seatId)) {
        Column() {
          Image(this.passengers.get(this.seatId)!.icon)
            .width(21)
            .height(21)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height(21)
        .position({ x: 0, y: 3.5 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.None)
        .zIndex(20)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })))
      }
    }
    .width(36)
    .height(30)
    .backgroundColor(this.selectedSeatId === this.seatId ? '#FA6B56' : '#1E293B')
    .border({
      width: this.selectedSeatId === this.seatId ? 1.5 : 1.0,
      color: this.selectedSeatId === this.seatId ? '#FA6B56' : 'rgba(148, 163, 184, 0.25)',
      radius: { topLeft: 6, topRight: 6, bottomLeft: 7.5, bottomRight: 7.5 }
    })
    .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 7.5, bottomRight: 7.5 })
    .shadow({
      radius: this.selectedSeatId === this.seatId ? 10 : 2,
      color: this.selectedSeatId === this.seatId ? 'rgba(250, 107, 86, 0.50)' : 'rgba(0, 0, 0, 0.25)',
      offsetY: 1.5
    })
    .scale({
      x: this.selectedSeatId === this.seatId ? 1.06 : 1.0,
      y: this.selectedSeatId === this.seatId ? 1.06 : 1.0
    })
    .translate({
      y: this.selectedSeatId === this.seatId ? -1.5 : 0
    })
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    .zIndex(this.selectedSeatId === this.seatId ? 999 : 1)
    .onClick(() => {
      if (this.passengers.has(this.seatId) && this.seatedPassengerIds.includes(this.seatId)) {
        if (this.onPassengerClick) {
          this.onPassengerClick(this.passengers.get(this.seatId)!);
        }
        return;
      }
      if (this.onSeatClick) {
        this.onSeatClick(this.seatId);
      }
    })
  }
}
