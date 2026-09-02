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
 * 悬浮胶囊底部导航栏 (Floating Capsule Navigation Bar)
 * 高层级 (zIndex: 600) 悬浮在停机坪与所有弹窗抽屉之上，支持一键切换与取消返回
 */
@Component
export struct FloatingCapsuleNavBar {
  @StorageLink('isStatsSheetVisible') isStatsSheetVisible: boolean = false;
  @StorageLink('isSettingsSheetVisible') isSettingsSheetVisible: boolean = false;
  @StorageLink('isThemeSelectSheetVisible') isThemeSelectSheetVisible: boolean = false;
  @StorageLink('isBookFlightSheetVisible') isBookFlightSheetVisible: boolean = false;
  @StorageLink('userMemberTier') userMemberTier: string = 'standard';
  @Prop isFlightInProgress: boolean = false;
  @Prop isFullFocusMode: boolean = false;

  private getThemeAccentColor(): string {
    return this.userMemberTier === 'lifetime' ? '#9B84EC' : '#FA6B56';
  }

  private isDrawerOpen(): boolean {
    return this.isStatsSheetVisible || this.isSettingsSheetVisible;
  }

  private shouldHideNavBar(): boolean {
    return this.isThemeSelectSheetVisible || this.isBookFlightSheetVisible;
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 15
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) { }
  }

  private getActiveTab(): number {
    if (this.isStatsSheetVisible) {
      return 1;
    }
    if (this.isSettingsSheetVisible) {
      return 2;
    }
    return 0;
  }

  private handleTabClick(index: number): void {
    this.triggerHaptic();
    if (index === 0) {
      // 点击首页：平滑收起所有弹窗抽屉，返回主界面停机坪
      this.isStatsSheetVisible = false;
      this.isSettingsSheetVisible = false;
    } else if (index === 1) {
      // 点击数据：收起我的，展开数据护照抽屉
      this.isSettingsSheetVisible = false;
      this.isStatsSheetVisible = true;
    } else if (index === 2) {
      // 点击我的：收起数据，展开设置中心抽屉
      this.isStatsSheetVisible = false;
      this.isSettingsSheetVisible = true;
    }
  }

  build() {
    Row() {
      // Tab 0: ✈️ 首页 (Home / Flights)
      Column({ space: 4 }) {
        Image($r('app.media.ic_nav_flight'))
          .width(24)
          .height(24)
          .fillColor(this.getActiveTab() === 0 ? '#1E293B' : '#94A3B8')
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

        Circle({ width: 5, height: 5 })
          .fill(this.getThemeAccentColor())
          .opacity(this.getActiveTab() === 0 ? 1 : 0)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.handleTabClick(0);
      })

      // Tab 1: 📊 数据 (Stats / Passport)
      Column({ space: 4 }) {
        Image($r('app.media.ic_nav_stats'))
          .width(24)
          .height(24)
          .fillColor(this.getActiveTab() === 1 ? '#1E293B' : '#94A3B8')
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

        Circle({ width: 5, height: 5 })
          .fill(this.getThemeAccentColor())
          .opacity(this.getActiveTab() === 1 ? 1 : 0)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.handleTabClick(1);
      })

      // Tab 2: 👤 我的 (Profile / Settings)
      Column({ space: 4 }) {
        Image($r('app.media.ic_nav_mine'))
          .width(24)
          .height(24)
          .fillColor(this.getActiveTab() === 2 ? '#1E293B' : '#94A3B8')
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

        Circle({ width: 5, height: 5 })
          .fill(this.getThemeAccentColor())
          .opacity(this.getActiveTab() === 2 ? 1 : 0)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.handleTabClick(2);
      })
    }
    .width(256)
    .height(56)
    .backgroundColor(this.isDrawerOpen() ? '#FFFFFF' : 'rgba(255, 255, 255, 0.0)')
    .borderRadius(28)
    .border({
      width: this.isDrawerOpen() ? 1 : 0,
      color: 'rgba(0, 0, 0, 0.05)'
    })
    .shadow(this.isDrawerOpen() ? { radius: 24, color: 'rgba(0, 0, 0, 0.14)', offsetY: 6 } : { radius: 0, color: 'transparent' })
    .padding({ left: 18, right: 18 })
    .opacity(this.shouldHideNavBar() ? 0 : 1)
    .hitTestBehavior(this.shouldHideNavBar() ? HitTestMode.None : HitTestMode.Default)
    .animation({ duration: this.isDrawerOpen() ? 0 : 250, curve: Curve.FastOutSlowIn })
  }
}
