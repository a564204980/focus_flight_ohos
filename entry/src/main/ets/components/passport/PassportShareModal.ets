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

import { promptAction } from '@kit.ArkUI';
import { FlightRecordRepository, FlightStatsSummary, HistoricalRouteSegment } from '../../database/FlightRecordRepository';
import { LocationService } from '../../services/LocationService';
import { CloseButton } from '../CloseButton';
import { PassportPaperCard } from './PassportPaperCard';

/**
 * 机长心流护照 · 实体防伪分享弹窗 (极致流畅满帧动效)
 */
@Component
export struct PassportShareModal {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop stats: FlightStatsSummary = {
    totalFlights: 0,
    totalMinutes: 0,
    totalDistanceKm: 0,
    uniqueDestinationsCount: 0,
    currentStreakDays: 0,
    shortHaulCount: 0,
    longHaulCount: 0,
    abortedFlightsCount: 0,
    avgDistractedMin: 0
  };
  @Prop timeTabLabel: string = '总记录';
  @Prop yearFilter: number = 0;
  onClose?: () => void;

  @State private isBlacklight: boolean = false;
  @State private modalOffsetY: number = 650;
  @State private maskOpacity: number = 0;
  @State private routes: HistoricalRouteSegment[] = [];

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadHistoricalRoutes();
      this.animateIn();
    }
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.loadHistoricalRoutes();
      this.animateIn();
    } else {
      this.animateOut();
    }
  }

  private async loadHistoricalRoutes(): Promise<void> {
    try {
      LocationService.getInitialIssueAirportName(getContext(this));
      const year = this.yearFilter > 0 ? this.yearFilter : undefined;
      const data = await FlightRecordRepository.getHistoricalRouteSegments(year);
      this.routes = data;
    } catch (e) {
      this.routes = [];
    }
  }

  private animateIn(): void {
    this.modalOffsetY = 650;
    this.maskOpacity = 0;
    this.getUIContext()?.animateTo({
      duration: 320,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.modalOffsetY = 0;
      this.maskOpacity = 1.0;
    });
  }

  private animateOut(callback?: () => void): void {
    this.getUIContext()?.animateTo({
      duration: 250,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        if (callback) {
          callback();
        }
      }
    }, () => {
      this.modalOffsetY = 650;
      this.maskOpacity = 0;
    });
  }

  private handleClose(): void {
    this.animateOut(() => {
      if (this.onClose) {
        this.onClose();
      }
    });
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({
        message: msg,
        duration: 1800
      });
    } catch (e) { }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 全屏沉浸展台背景 (柔和通透渐变，拦截所有点击穿透)
      Row()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: this.isBlacklight
            ? [['#1E1656', 0.0], ['#140E3D', 0.38], ['#0C0826', 0.75], ['#070514', 1.0]]
            : [['#EBF1F6', 0.0], ['#DFE7EF', 0.5], ['#D0DCE7', 1.0]]
        })
        .opacity(this.maskOpacity)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          // 拦截背景空白处点击，防止穿透到下层页面
        })

      // 2. 护照分享操作面板主体 (GPU 平移动画)
      Column() {
        // 2.1 顶部导航栏
        Row() {
          CloseButton({
            circleColor: this.isBlacklight ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.85)',
            iconColor: this.isBlacklight ? '#FFFFFF' : '#0F172A',
            buttonSize: 36,
            onClickAction: () => {
              this.handleClose();
            }
          })

          Blank()

          Column({ space: 2 }) {
            Text(this.timeTabLabel === '总记录' ? '生涯专注护照' : `${this.timeTabLabel}专注护照`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isBlacklight ? '#FFFFFF' : '#0F172A')

            Text('预览与分享')
              .fontSize(11.5)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isBlacklight ? '#A5B4FC' : '#64748B')
          }
          .alignItems(HorizontalAlign.Center)

          Blank()

          // 右侧下载保存卡片图标按钮 (与左侧关闭按钮 100% 材质对称)
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(36)
              .height(36)
              .backgroundColor(this.isBlacklight ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.85)')
              .borderRadius(18)
              .border({
                width: 1,
                color: this.isBlacklight ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.05)'
              })

            Image($r('app.media.ic_passport_download'))
              .width(18)
              .height(18)
              .fillColor(this.isBlacklight ? '#FFFFFF' : '#0F172A')
          }
          .width(36)
          .height(36)
          .onClick(() => {
            // 静默触发下载保存
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 48, bottom: 4 })

        Blank()

        // 2.2 核心实体纸质防伪护照卡片 (接入真实航线)
        PassportPaperCard({
          isBlacklight: this.isBlacklight,
          stats: this.stats,
          timeTabLabel: this.timeTabLabel,
          routes: this.routes
        })

        // 2.3 双格分段滑动开关 (Segmented Switch: 100% 像素级绝对对称居中)
        Stack({ alignContent: Alignment.Start }) {
          // 1. 底座背景 (总宽 192, 左右 padding 各 3, 可用宽 186)
          Row()
            .width(192)
            .height(34)
            .borderRadius(17)
            .backgroundColor(this.isBlacklight ? 'rgba(255, 255, 255, 0.08)' : 'rgba(15, 23, 42, 0.07)')
            .border({
              width: 1,
              color: this.isBlacklight ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.04)'
            })

          // 2. 滑动的活动高亮滑块 (宽度刚好为可用区域的一半 93)
          Row()
            .width(93)
            .height(28)
            .borderRadius(14)
            .backgroundColor(this.isBlacklight ? '#7C3AED' : '#FFFFFF')
            .shadow({
              radius: this.isBlacklight ? 8 : 5,
              color: this.isBlacklight ? 'rgba(124, 58, 237, 0.45)' : 'rgba(15, 23, 42, 0.12)',
              offsetY: 1
            })
            .margin({ left: 3 })
            .translate({ x: this.isBlacklight ? 93 : 0 })
            .animation({ duration: 250, curve: Curve.FastOutSlowIn })

          // 3. 上层文字选项层 (左右严格等分各占 50% = 93vp，与滑块中心 100.0% 重合)
          Row() {
            // 左侧格: 日光纸质
            Text('日光纸质')
              .layoutWeight(1)
              .height('100%')
              .fontSize(12)
              .fontWeight(this.isBlacklight ? FontWeight.Medium : FontWeight.Bold)
              .fontColor(this.isBlacklight ? 'rgba(255, 255, 255, 0.55)' : '#0F172A')
              .textAlign(TextAlign.Center)
              .onClick(() => {
                if (this.isBlacklight) {
                  this.isBlacklight = false;
                }
              })

            // 右侧格: 紫外荧光
            Text('紫外荧光')
              .layoutWeight(1)
              .height('100%')
              .fontSize(12)
              .fontWeight(this.isBlacklight ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.isBlacklight ? '#FFFFFF' : '#64748B')
              .textAlign(TextAlign.Center)
              .onClick(() => {
                if (!this.isBlacklight) {
                  this.isBlacklight = true;
                }
              })
          }
          .width(192)
          .height(34)
          .padding({ left: 3, right: 3 })
        }
        .width(192)
        .height(34)
        .margin({ top: 16, bottom: 18 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 20 })
      .translate({ y: this.modalOffsetY })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1200)
  }
}
