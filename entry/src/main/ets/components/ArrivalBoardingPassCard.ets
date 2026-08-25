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
import { vibrator } from '@kit.SensorServiceKit';
import { Airport } from '../models/AirportModel';

interface CityStampMeta {
  title: string;
  sub: string;
  icon: string;
  color: string;
}

/**
 * 获取城市专属金色通关印章元数据
 */
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
 * 专属【落地通关登机牌】结算卡片组件 (ArrivalBoardingPassCard)
 * Dribbble 顶级视觉设计：撕边折痕、微光渐变、烫金印章、核心专注数据沉淀
 */
@Component
export struct ArrivalBoardingPassCard {
  @Prop isVisible: boolean = false;
  @Prop durationMinutes: number = 45;
  @Prop flightDistanceKm: number = 920;
  @Prop focusTagTitle: string = '深度学习';
  @Prop originAirport: Airport | null = null;
  @Prop destinationAirport: Airport | null = null;
  @Prop seatId: string = '01A';

  public onCompleteAndExit: () => void = () => {};
  public onShareCard: () => void = () => {};

  private triggerHapticFeedback(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) { }
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 全屏沉浸式暗色毛玻璃遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(5, 8, 15, 0.65)')
          .backdropBlur(40)
          .animation({ duration: 400, curve: Curve.EaseInOut })
          .onClick(() => {})
          .onTouch((event: TouchEvent) => {
            event.stopPropagation();
          })

        // 2. 登机牌卡片主体 (上下分体式裂变设计 Split Ticket，极具现代高级感)
        Column({ space: 4 }) { // 4vp 的微小缝隙，构成撕裂感
          // ==========================================
          // 2.1 上半部分 (Top Half)：航线、盖章与身份
          // ==========================================
          Column() {
            // 顶部标识
            Row() {
              Row({ space: 6 }) {
                Text('✈️')
                  .fontSize(14)
                Text('FOCUS FLIGHT · ARRIVAL')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F59E0B')
                  .letterSpacing(1.5)
              }
              Blank()
              Text(`SEAT ${this.seatId}`)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#CBD5E1')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('rgba(255, 255, 255, 0.08)')
                .borderRadius(6)
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 24, bottom: 16 })

            // 航线大字
            Row() {
              // 出发
              Column({ space: 6 }) {
                Text(this.originAirport ? this.originAirport.code : 'CTU')
                  .fontSize(36)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#FFFFFF')
                  .fontFamily('monospace')
                  .letterSpacing(2)
                Text(this.originAirport ? this.originAirport.city : '成都')
                  .fontSize(13)
                  .fontColor('#94A3B8')
                  .letterSpacing(1)
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              // 飞行动画占位与指示
              Column({ space: 6 }) {
                Image($r('app.media.ic_plane_topview'))
                  .width(20)
                  .height(20)
                  .fillColor('#F59E0B')
                  .rotate({ angle: 90 })
                Text(`${this.flightDistanceKm} KM`)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#64748B')
                  .letterSpacing(1)
              }

              Blank()

              // 降落
              Column({ space: 6 }) {
                Text(this.destinationAirport ? this.destinationAirport.code : 'PEK')
                  .fontSize(36)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#FFFFFF')
                  .fontFamily('monospace')
                  .letterSpacing(2)
                Text(this.destinationAirport ? this.destinationAirport.city : '北京')
                  .fontSize(13)
                  .fontColor('#94A3B8')
                  .letterSpacing(1)
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding({ left: 28, right: 28, top: 12, bottom: 28 })

            // 金色印章 (绝对定位，悬浮于右下角)
            Stack() {
              this.GoldenCityClearanceStamp()
            }
            .position({ x: '65%', y: '40%' })
            .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .backgroundColor('rgba(30, 36, 50, 0.85)')
          .backdropBlur(50)
          .borderRadius({ topLeft: 24, topRight: 24, bottomLeft: 8, bottomRight: 8 })
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
          .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.4)', offsetY: 8 })

          // ==========================================
          // 2.2 视觉连接虚线 (Perforation Line)
          // ==========================================
          Row() {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], () => {
              Line()
                .width(6)
                .height(1.5)
                .backgroundColor('rgba(255, 255, 255, 0.15)')
                .margin({ right: 6 })
            })
          }
          .width('90%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: -2, bottom: -2 })
          .zIndex(2)

          // ==========================================
          // 2.3 下半部分 (Bottom Half)：数据统计与操作
          // ==========================================
          Column() {
            // 数据统计矩阵
            Row() {
              Column({ space: 4 }) {
                Text('FOCUS TIME')
                  .fontSize(10)
                  .fontColor('#64748B')
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(1)
                Text(`${this.durationMinutes}:00`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#F8FAFC')
                  .fontFamily('monospace')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 4 }) {
                Text('MILEAGE EARNED')
                  .fontSize(10)
                  .fontColor('#64748B')
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(1)
                Text(`+${this.flightDistanceKm}`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#38BDF8')
                  .fontFamily('monospace')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 28, right: 28, top: 24, bottom: 20 })

            // 标签与评价
            Row({ space: 12 }) {
              Row({ space: 6 }) {
                Text('🏷️')
                  .fontSize(12)
                Text(this.focusTagTitle)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F59E0B')
              }
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('rgba(245, 158, 11, 0.12)')
              .borderRadius(12)

              Row({ space: 6 }) {
                Text('✨')
                  .fontSize(12)
                Text('100% 极佳专注')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#CBD5E1')
              }
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('rgba(255, 255, 255, 0.06)')
              .borderRadius(12)
            }
            .width('100%')
            .padding({ left: 28, right: 28, bottom: 28 })

            // 底部双按钮 (纯净毛玻璃 vs 品牌高亮)
            Row({ space: 16 }) {
              Button() {
                Row({ space: 8 }) {
                  Text('📸')
                    .fontSize(14)
                  Text('保存海报')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F8FAFC')
                }
              }
              .layoutWeight(1)
              .height(48)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(24)
              .onClick(() => {
                this.triggerHapticFeedback();
                promptAction.showToast({ message: '✨ 通关海报已保存！', duration: 2500 });
                if (this.onShareCard) this.onShareCard();
              })

              Button() {
                Row({ space: 8 }) {
                  Text('🛬')
                    .fontSize(14)
                  Text('返回停机坪')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0A0F1D')
                }
              }
              .layoutWeight(1.2)
              .height(48)
              .backgroundColor('#F59E0B')
              .borderRadius(24)
              .shadow({ radius: 16, color: 'rgba(245, 158, 11, 0.4)', offsetY: 4 })
              .onClick(() => {
                this.triggerHapticFeedback();
                this.onCompleteAndExit();
              })
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 24 })
          }
          .width('100%')
          .backgroundColor('rgba(22, 27, 40, 0.85)')
          .backdropBlur(50)
          .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 24, bottomRight: 24 })
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
          .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.4)', offsetY: 8 })
        }
        .width('88%')
        .onClick(() => {
          // 拦截卡片内部点击
        })
        .onTouch((event: TouchEvent) => {
          event.stopPropagation();
        })
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
              .combine(TransitionEffect.translate({ y: 80 }))
              .animation({ duration: 550, curve: Curve.FastOutSlowIn }),
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 60 }))
              .animation({ duration: 350, curve: Curve.EaseIn })
          )
        )
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        // 拦截全屏点击
      })
      .onTouch((event: TouchEvent) => {
        event.stopPropagation();
      })
      .zIndex(300)
    }
  }

  private getDestCode(): string {
    return this.destinationAirport ? this.destinationAirport.code : 'PEK';
  }

  private getCityName(): string {
    return this.destinationAirport ? this.destinationAirport.city : '北京';
  }

  private getStampMeta(): CityStampMeta {
    return getCityStampMeta(this.getDestCode(), this.getCityName());
  }

  /**
   * 目的地专属金色通关戳印组件
   */
  @Builder
  GoldenCityClearanceStamp() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 外层金色同心双圆环
      Column()
        .width(104)
        .height(104)
        .borderRadius(52)
        .border({ width: 2.5, color: this.getStampMeta().color })
        .opacity(0.85)

      Column()
        .width(92)
        .height(92)
        .borderRadius(46)
        .border({ width: 1.2, color: this.getStampMeta().color, style: BorderStyle.Dashed })
        .opacity(0.85)

      // 2. 内部印章文字与图案
      Column({ space: 2 }) {
        Text('FOCUS VERIFIED')
          .fontSize(7)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStampMeta().color)
          .letterSpacing(1.2)
          .opacity(0.9)

        Row({ space: 4 }) {
          Text(this.getStampMeta().icon)
            .fontSize(14)
          Text(this.getStampMeta().title)
            .fontSize(12)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.getStampMeta().color)
            .letterSpacing(1)
        }
        .margin({ top: 2, bottom: 2 })

        Text(`ARRIVED · ${this.getDestCode()}`)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStampMeta().color)
          .fontFamily('monospace')
          .letterSpacing(1)
      }
    }
    .width(110)
    .height(110)
    .rotate({ angle: -15 }) // 经典航空签证斜盖 15 度
  }
}

