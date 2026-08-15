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

import { WalkingPassengerState } from '../../models/CabinPassengerModel';

/**
 * 走道萌宠登机行走与微弹入座动效精灵组件
 */
@Component
export struct WalkingPassengerSprite {
  @Prop wp: WalkingPassengerState;
  @Prop selectedUserSeatId: string = '';
  @State currentX: number = 0;
  @State currentY: number = -25;
  @State hopY: number = 0;
  @State spriteOpacity: number = 0;
  @State spriteScale: number = 0.85;
  @State bubbleBgOpacity: number = 1.0;

  onSeated?: (seatId: string) => void;

  aboutToAppear(): void {
    // 1. 登机口自然淡入 (0.3s)
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.spriteOpacity = 1.0;
      this.spriteScale = 1.0;
    });

    // 2. 沿着中央过道从容悠闲漫步到对应的排 (1.1s ~ 1.8s)
    animateTo({ duration: this.wp.walkDuration, curve: Curve.Linear }, () => {
      this.currentY = this.wp.targetY;
    });

    // 3. 拐弯并轻盈起跳跃向座椅 (阶段一：起跳与弧形滑动 220ms)
    setTimeout(() => {
      if (this.selectedUserSeatId === this.wp.seatId) {
        // 用户已选定该座位，小动物礼貌避让淡出
        animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
          this.spriteOpacity = 0;
        });
        return;
      }
      
      // 走道背景气泡淡出，萌宠轻盈起跳向座位
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.currentX = this.wp.targetX;
        this.hopY = -5; // 起跳抛物线弧度
        this.spriteScale = 1.16;
        this.bubbleBgOpacity = 0; // 气泡自然融解
      });

      // 阶段二：软糯下落触垫 (180ms)
      setTimeout(() => {
        animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
          this.hopY = 0;
          this.spriteScale = 0.93; // 触垫轻微受压软糯形变
        });

        // 阶段三：舒适回弹定格 (140ms)
        setTimeout(() => {
          animateTo({ duration: 140, curve: Curve.FastOutSlowIn }, () => {
            this.spriteScale = 1.0; // 恢复舒适坐姿
          });

          // 阶段四：无缝落座常驻
          setTimeout(() => {
            if (this.selectedUserSeatId === this.wp.seatId) {
              return;
            }
            if (this.onSeated) {
              this.onSeated(this.wp.seatId);
            }
          }, 140);
        }, 180);
      }, 220);
    }, this.wp.walkDuration + 40);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 走道漫步时的柔和白底气泡（入座起跳时自然淡出）
      Column()
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('rgba(255, 255, 255, 0.96)')
        .border({ width: 1, color: 'rgba(203, 213, 225, 0.75)' })
        .shadow({ radius: 5, color: 'rgba(0, 0, 0, 0.12)', offsetY: 1.5 })
        .opacity(this.bubbleBgOpacity)

      // 萌宠高清图标（适度放大，起跳入座更清晰可爱）
      Image(this.wp.icon)
        .width(21)
        .height(21)
        .objectFit(ImageFit.Contain)
    }
    .width(30)
    .height(30)
    .position({
      x: 164 + this.currentX - 15,
      y: this.currentY + this.hopY - 15
    })
    .opacity(this.spriteOpacity)
    .scale({ x: this.spriteScale, y: this.spriteScale })
    .zIndex(600)
    .hitTestBehavior(HitTestMode.None)
  }
}
