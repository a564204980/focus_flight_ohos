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

import { CloseButton } from '../CloseButton';
import { FlightRecordDateFilter } from '../../database/FlightRecordRepository';

import { FlightCalendarView } from './FlightCalendarView';

/**
 * 航行日志 · 年月日灵活时间检索与日历筛选弹窗
 * (Flight Date Picker Modal)
 */
@Component
export struct FlightDatePickerModal {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop currentFilter: FlightRecordDateFilter = { type: 'all' };
  @Prop availableYears: Array<number> = [2026, 2025];
  onApplyFilter?: (filter: FlightRecordDateFilter) => void;
  onClose?: () => void;

  @State private activeTab: 'day' | 'month' | 'year' = 'day';
  @State private curYear: number = 2026;
  @State private curMonth: number = 8; // 1-12
  @State private selectedDay: number = 26; // 1-31
  @State private selectedMonthOnly: number = 8;
  @State private selectedYearOnly: number = 2026;
  @State private modalOffsetY: number = 1200;

  @State private maskOpacity: number = 0;

  aboutToAppear(): void {
    this.initFromFilter();
    this.modalOffsetY = 1200;
    this.maskOpacity = 0;
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
        this.modalOffsetY = 0;
        this.maskOpacity = 1;
      });
    }, 16);
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.initFromFilter();
      this.getUIContext()?.animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
        this.modalOffsetY = 0;
        this.maskOpacity = 1;
      });
    } else {
      this.modalOffsetY = 1200;
      this.maskOpacity = 0;
    }
  }

  private initFromFilter(): void {
    const today = new Date();
    this.curYear = this.currentFilter.year || today.getFullYear();
    this.curMonth = this.currentFilter.month || (today.getMonth() + 1);
    this.selectedDay = this.currentFilter.day || today.getDate();
    this.selectedMonthOnly = this.currentFilter.month || (today.getMonth() + 1);
    this.selectedYearOnly = this.currentFilter.year || today.getFullYear();

    if (this.currentFilter.type === 'month') {
      this.activeTab = 'month';
    } else if (this.currentFilter.type === 'year') {
      this.activeTab = 'year';
    } else {
      this.activeTab = 'day';
    }
  }


  private handleClose(): void {
    this.getUIContext()?.animateTo({ duration: 260, curve: Curve.EaseInOut }, () => {
      this.modalOffsetY = 1200;
      this.maskOpacity = 0;
    });
    setTimeout(() => {
      if (this.onClose) {
        this.onClose();
      }
    }, 280);
  }

  private applyAll(): void {
    if (this.onApplyFilter) {
      this.onApplyFilter({ type: 'all' });
    }
    this.handleClose();
  }

  private applyCurrentSelection(): void {
    let result: FlightRecordDateFilter = {
      type: 'day',
      year: this.curYear,
      month: this.curMonth,
      day: this.selectedDay
    };

    if (this.onApplyFilter) {
      this.onApplyFilter(result);
    }
    this.handleClose();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 半透明暗色背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(10, 8, 28, 0.75)')
        .opacity(this.maskOpacity)
        .onClick(() => {
          this.handleClose();
        })

      // 2. 弹窗面板主体 (加入航图暗纹背景)
      Stack({ alignContent: Alignment.Top }) {
        // 2.1 底层航图暗纹
        Image($r('app.media.bg_real_world_silhouette'))
          .width('140%')
          .opacity(0.04)
          .objectFit(ImageFit.Contain)
          .offset({ y: -100 })
          .hitTestBehavior(HitTestMode.None)
          .animation({ duration: 1000, curve: Curve.LinearOutSlowIn }) // 随页面呼吸

        // 2.2 核心内容
        Column({ space: 16 }) {
          // A. 弹窗头部
          Row() {
            Text('选择时间')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')

            Blank()

            Row({ space: 12 }) {
              // 返回今日按钮
              Row() {
                Text('今')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
              .width(36)
              .height(36)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(18)
              .onClick(() => {
                const now = new Date();
                this.curYear = now.getFullYear();
                this.curMonth = now.getMonth() + 1;
                this.selectedDay = now.getDate();
                this.applyCurrentSelection();
              })

              CloseButton({
                circleColor: 'rgba(255, 255, 255, 0.1)',
                iconColor: '#FFFFFF',
                buttonSize: 36,
                onClickAction: () => {
                  this.handleClose();
                }
              })
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 24 })

          // B. 核心内容：无限滚动日历
          FlightCalendarView({
            curYear: $curYear,
            curMonth: $curMonth,
            selectedDay: $selectedDay,
            onDateSelected: () => {
              this.applyCurrentSelection();
            }
          })
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('92%')
      .borderRadius({ topLeft: 32, topRight: 32 })
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)' })
      .backgroundColor('#161324')
      .clip(true)
      .offset({ y: this.modalOffsetY })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.isVisible ? HitTestMode.Default : HitTestMode.None)
  }
}

