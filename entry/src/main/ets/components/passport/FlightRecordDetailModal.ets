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

import { FlightRecordItem } from '../../database/FlightRecordRepository';
import { findAirportByCode } from '../../models/AirportModel';
import { CloseButton } from '../CloseButton';

interface CityStampMeta {
  title: string;
  sub: string;
  icon: string;
  color: string;
}

function getCityStampMeta(destCode: string, cityName: string): CityStampMeta {
  const map: Record<string, CityStampMeta> = {
    'PEK': { title: '首都之星', sub: 'BEIJING STAR', icon: '🌟', color: '#F59E0B' },
    'PKX': { title: '大兴之凤', sub: 'DAXING PHOENIX', icon: '🪶', color: '#F59E0B' },
    'PVG': { title: '东方明珠', sub: 'SHANGHAI PEARL', icon: '🗼', color: '#38BDF8' },
    'SHA': { title: '虹桥枢纽', sub: 'HONGQIAO HUB', icon: '🏙️', color: '#38BDF8' },
    'CTU': { title: '蓉城天府', sub: 'CHENGDU PANDA', icon: '🐼', color: '#10B981' },
    'TFU': { title: '天府之翼', sub: 'TIANFU WINGS', icon: '🪽', color: '#10B981' },
    'CAN': { title: '羊城之光', sub: 'GUANGZHOU LIGHT', icon: '🌸', color: '#EC4899' },
    'SZX': { title: '鹏城万里', sub: 'SHENZHEN TECH', icon: '🚀', color: '#6366F1' },
    'XIY': { title: '古都丝路', sub: 'XI AN SILK', icon: '🏛️', color: '#D97706' },
    'HGH': { title: '西子湖畔', sub: 'HANGZHOU LAKE', icon: '⛵', color: '#06B6D4' }
  };
  if (map[destCode]) {
    return map[destCode];
  }
  return {
    title: `${cityName}之光`,
    sub: `${destCode} ARRIVAL`,
    icon: '✨',
    color: '#F59E0B'
  };
}

/**
 * 历史航班详情复盘弹窗 (Flight Record Detail Modal)
 */
@Component
export struct FlightRecordDetailModal {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop record: FlightRecordItem | undefined = undefined;
  onClose?: () => void;

  @State private modalOffsetY: number = 600;
  @State private maskOpacity: number = 0;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.animateIn();
    }
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.animateIn();
    } else {
      this.animateOut();
    }
  }

  private animateIn(): void {
    this.getUIContext().animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
      this.maskOpacity = 1;
      this.modalOffsetY = 0;
    });
  }

  private animateOut(): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
      this.maskOpacity = 0;
      this.modalOffsetY = 600;
    });
  }

  private formatTimestamp(ts: number): string {
    if (!ts) return '--:--';
    const date = new Date(ts);
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    return `${date.getFullYear()}-${m}-${d} ${hh}:${mm}`;
  }

  @Builder
  private buildStampView(destCode: string, cityName: string) {
    Stack({ alignContent: Alignment.Center }) {
      Circle({ width: 76, height: 76 })
        .fill(Color.Transparent)
        .stroke('#F59E0B')
        .strokeWidth(2)
        .strokeDashArray([4, 2])

      Circle({ width: 70, height: 70 })
        .fill(Color.Transparent)
        .stroke('rgba(245, 158, 11, 0.4)')
        .strokeWidth(1)

      Column({ space: 1 }) {
        Text(getCityStampMeta(destCode, cityName).icon)
          .fontSize(16)
        Text(getCityStampMeta(destCode, cityName).title)
          .fontSize(10)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#F59E0B')
        Text(destCode)
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor('rgba(245, 158, 11, 0.7)')
          .letterSpacing(1)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(76)
    .height(76)
    .rotate({ angle: -12 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(15, 23, 42, 0.65)')
        .opacity(this.maskOpacity)
        .animation({ duration: 300 })
        .onClick(() => {
          if (this.onClose) {
            this.onClose();
          }
        })

      if (this.record) {
        // 浮层卡片主体
        Column() {
          // 顶部小抓手
          Row()
            .width(40)
            .height(4)
            .backgroundColor('#CBD5E1')
            .borderRadius(2)
            .margin({ top: 12, bottom: 8 })

          // 标题与关闭按钮
          Row() {
            Column({ space: 2 }) {
              Text('航班复盘档案')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
              Text(`FOCUS FLIGHT · ${this.record.flightNo}`)
                .fontSize(11)
                .fontColor('#64748B')
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            CloseButton({
              circleColor: '#F1F5F9',
              iconColor: '#0F172A',
              buttonSize: 32,
              onClickAction: () => {
                if (this.onClose) {
                  this.onClose();
                }
              }
            })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 8, bottom: 16 })

          // 核心复盘登机牌
          Column() {
            // 登机牌上半部分 (航线与状态)
            Column() {
              // 顶栏状态徽章
              Row() {
                Row({ space: 6 }) {
                  Text(this.record.status === 'completed' ? '✈️ 准点降落' : '⚠️ 中途迫降')
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.record.status === 'completed' ? '#10B981' : '#EF4444')
                }
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(this.record.status === 'completed' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(239, 68, 68, 0.12)')
                .borderRadius(6)

                Blank()

                Text(`座位 ${this.record.seatId || '01A'}`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#94A3B8')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('rgba(255, 255, 255, 0.08)')
                  .borderRadius(6)
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 16, bottom: 12 })

              // 航线三字码
              Stack({ alignContent: Alignment.BottomEnd }) {
                Row() {
                  // 起飞
                  Column({ space: 4 }) {
                    Text(this.record.originCode)
                      .fontSize(32)
                      .fontWeight(FontWeight.Bolder)
                      .fontColor('#FFFFFF')
                      .fontFamily('monospace')
                    Text(findAirportByCode(this.record.originCode)?.city || '起飞机场')
                      .fontSize(12)
                      .fontColor('#94A3B8')
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank()

                  // 飞机指示
                  Column({ space: 4 }) {
                    Text('➔')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#F59E0B')
                    Text(`${Math.round(this.record.distanceKm)} KM`)
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#64748B')
                  }

                  Blank()

                  // 降落
                  Column({ space: 4 }) {
                    Text(this.record.destCode)
                      .fontSize(32)
                      .fontWeight(FontWeight.Bolder)
                      .fontColor('#FFFFFF')
                      .fontFamily('monospace')
                    Text(findAirportByCode(this.record.destCode)?.city || '降落机场')
                      .fontSize(12)
                      .fontColor('#94A3B8')
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding({ left: 24, right: 24, top: 8, bottom: 20 })

                // 成功降落盖章
                if (this.record.status === 'completed') {
                  this.buildStampView(this.record.destCode, findAirportByCode(this.record.destCode)?.city || '')
                }
              }
              .width('100%')
            }
            .width('100%')
            .linearGradient({ angle: 135, colors: [['#0F172A', 0], ['#1E293B', 1]] })
            .borderRadius({ topLeft: 18, topRight: 18 })

            // 虚线撕边效果
            Row() {
              ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], () => {
                Line()
                  .width(6)
                  .height(2)
                  .backgroundColor('#E2E8F0')
                  .margin({ left: 4, right: 4 })
              }, (i: number) => i.toString())
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 10, bottom: 10 })

            // 登机牌下半部分 (数据明细)
            Column({ space: 14 }) {
              // 任务标题
              Row() {
                Text('专注任务')
                  .fontSize(12)
                  .fontColor('#64748B')
                Blank()
                Text(this.record.taskTitle || '自由专注航行')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F172A')
              }
              .width('100%')

              // 实际专注时长
              Row() {
                Text('专注时长')
                  .fontSize(12)
                  .fontColor('#64748B')
                Blank()
                Row({ space: 4 }) {
                  Text(`${this.record.actualDurationMin}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.record.status === 'completed' ? '#0F172A' : '#EF4444')
                  Text(`分钟 (计划 ${this.record.durationMin} 分)`)
                    .fontSize(12)
                    .fontColor('#94A3B8')
                }
              }
              .width('100%')

              // 起始与结束时间
              Row() {
                Text('执飞时间')
                  .fontSize(12)
                  .fontColor('#64748B')
                Blank()
                Text(this.formatTimestamp(this.record.startTime))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')
              }
              .width('100%')

              // 状态描述
              Row() {
                Text('执飞总结')
                  .fontSize(12)
                  .fontColor('#64748B')
                Blank()
                Text(this.record.status === 'completed' ? '🌟 完美巡航，顺利落地' : '⛈️ 偶遇干扰，提前返航迫降')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.record.status === 'completed' ? '#10B981' : '#EF4444')
              }
              .width('100%')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius({ bottomLeft: 18, bottomRight: 18 })
          }
          .width('100%')
          .borderRadius(18)
          .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.08)', offsetY: 4 })
          .margin({ bottom: 24 })
        }
        .width('100%')
        .backgroundColor('#F8FAFC')
        .borderRadius({ topLeft: 24, topRight: 24 })
        .padding({ left: 20, right: 20, bottom: 32 })
        .offset({ y: this.modalOffsetY })
        .animation({ duration: 320, curve: Curve.FastOutSlowIn })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.isVisible ? HitTestMode.Default : HitTestMode.None)
  }
}
