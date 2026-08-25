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
import { CloseButton } from './CloseButton';
import { AgreementSheetModal } from './AgreementSheetModal';

/**
 * 专注航行 Pro 全屏订阅弹窗 (1:1 像素级还原 Flighty Pro 真实旗舰手机边框与沉浸式暗黑星空会员系统)
 */
@Component
export struct FocusVoyageProPaywallModal {
  @Prop isVisible: boolean = false;
  onClose?: () => void;

  @State currentHeroIndex: number = 0;
  @State selectedPlanIndex: number = 0; // 0: 年度会员, 1: 终身买断
  @State isAgreementSheetOpen: boolean = false;
  @State agreementType: 'service' | 'privacy' = 'service';

  private showToast(msg: string): void {
    try {
      promptAction.showToast({
        message: msg,
        duration: 2000
      });
    } catch (e) { }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 1. 深度沉浸式暗夜星空紫渐变背景
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#060110', 0.0],
            ['#150534', 0.22],
            ['#2C0B5E', 0.50],
            ['#581C87', 0.78],
            ['#3B0764', 1.0]
          ]
        })

      // 2. 核心内容区域 (全屏可滚动)
      Column() {
        // 2.1 顶部导航栏 (与专注飞行统计全屏页顶部 48vp 绝对对齐)
        Row() {
          // PRO 尊享紫色双色胶囊
          Row() {
            Text('专注航行')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 6, top: 4, bottom: 4 })
              .backgroundColor('rgba(255, 255, 255, 0.16)')
              .borderRadius({ topLeft: 12, bottomLeft: 12 })

            Text('PRO')
              .fontSize(12)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')
              .padding({ left: 6, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#9333EA')
              .borderRadius({ topRight: 12, bottomRight: 12 })
          }
          .borderRadius(12)
          .shadow({ radius: 8, color: 'rgba(147, 51, 234, 0.45)', offsetY: 2 })

          Blank()

          // 极简半透明关闭圆钮
          CloseButton({
            circleColor: 'rgba(255, 255, 255, 0.18)',
            iconColor: '#FFFFFF',
            buttonSize: 34,
            onClickAction: () => {
              if (this.onClose) {
                this.onClose();
              }
            }
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 48, bottom: 8 })

        // 2.2 顶部主打特性轮播与真实旗舰手机模型展示 (Realistic Device Frame)
        Swiper() {
          // Feature 1: 智能气流颠簸预警 (1:1 对标 Late Aircraft Alerts)
          this.buildHeroSlide(
            '智能气流颠簸预警',
            '离开应用自动触发气流颠簸与迫降广播',
            '⚠️ 正在巡航 · 气流颠簸',
            '#EF4444'
          )

          // Feature 2: 全机型与专属涂装
          this.buildHeroSlide(
            '全机型与专属机身涂装',
            '解锁波音787、空客A350及「鲸喜起飞」专属涂装',
            '✈️ 旗舰机队 · 波音 787',
            '#38BDF8'
          )
        }
        .loop(true)
        .indicator(false)
        .displayCount(1)
        .itemSpace(0)
        .height(315)
        .width('100%')
        .clip(true)

        // 2.3 底部订阅方案卡片轮播 (1. 月付, 2. 年付, 3. 终生)
        Swiper() {
          // 方案 1: 月度会员 (MONTHLY 8元/月)
          this.buildMonthlyPlanCard()

          // 方案 2: 年度会员 (ANNUAL 48元/年)
          this.buildAnnualPlanCard()

          // 方案 3: 终身机长买断 (LIFETIME 88元)
          this.buildLifetimePlanCard()
        }
        .loop(false)
        .indicator(false)
        .itemSpace(12)
        .displayCount(1)
        .padding({ left: 16, right: 16 })
        .margin({ top: -38 })
        .layoutWeight(1)
        .clip(true)

        // 2.4 底部协议与恢复购买
        Row({ space: 16 }) {
          Text('恢复购买')
            .fontSize(11)
            .fontColor('rgba(255, 255, 255, 0.45)')
            .onClick(() => {
              this.showToast('已成功恢复您的「专注航行 Pro」会员权益');
            })

          Text('·')
            .fontSize(11)
            .fontColor('rgba(255, 255, 255, 0.3)')

          Text('服务协议')
            .fontSize(11)
            .fontColor('rgba(255, 255, 255, 0.45)')
            .onClick(() => {
              this.agreementType = 'service';
              this.isAgreementSheetOpen = true;
            })

          Text('·')
            .fontSize(11)
            .fontColor('rgba(255, 255, 255, 0.3)')

          Text('隐私政策')
            .fontSize(11)
            .fontColor('rgba(255, 255, 255, 0.45)')
            .onClick(() => {
              this.agreementType = 'privacy';
              this.isAgreementSheetOpen = true;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 26 })
      }
      .width('100%')
      .height('100%')

      // 3. 独立协议详情弹出抽屉
      if (this.isAgreementSheetOpen) {
        AgreementSheetModal({
          isVisible: this.isAgreementSheetOpen,
          agreementType: this.agreementType,
          onClose: () => {
            this.isAgreementSheetOpen = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: this.isVisible ? 0 : '100%' })
    .opacity(this.isVisible ? 1 : 0)
    .animation({ duration: 380, curve: Curve.FastOutSlowIn })
    .hitTestBehavior(this.isVisible ? HitTestMode.Default : HitTestMode.None)
    .zIndex(999)
  }

  // 1:1 像素级真实旗舰手机机身框架与内屏航班追踪卡 (Authentic Titanium Phone Chassis Mockup)
  @Builder
  private buildHeroSlide(title: string, subtitle: string, badgeText: string, badgeColor: string) {
    Column({ space: 3 }) {
      // 1. 主标题
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .letterSpacing(-0.4)

      // 2. 副标题
      Text(subtitle)
        .fontSize(13)
        .fontColor('rgba(255, 255, 255, 0.72)')
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
        .margin({ bottom: 8 })

      // 3. 真实手机外框结构 (宽度与下方卡片 100% 严格对齐，右侧金属按键清晰外凸)
      Row() {
        // 3.1 手机主体 (占据主体宽度)
        Column() {
          // 手机外壳第 2 层：内嵌深黑中框槽
          Column() {
            // 手机外壳第 3 层：纯黑 OLED 超窄内屏 (OLED Display Screen)
            Column() {
              // 听筒微槽与星空顶
              Row() {
                // 微型听筒凹槽
                Row()
                  .width(42)
                  .height(3.5)
                  .backgroundColor('#18181B')
                  .borderRadius(2)
              }
              .width('100%')
              .height(10)
              .justifyContent(FlexAlign.Center)

              // 警示 / 状态胶囊标签 (如 ⚠️ RUNNING LATE)
              Row({ space: 5 }) {
                Text('▲')
                  .fontSize(8)
                  .fontColor('#FFFFFF')

                Text(badgeText)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#FFFFFF')
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(badgeColor)
              .borderRadius(10)
              .margin({ top: 2, bottom: 4 })

              // 飞机侧视悬浮图与深邃星空
              Stack({ alignContent: Alignment.Center }) {
                // 细碎星光粒子
                Text('✦')
                  .fontSize(8)
                  .fontColor('rgba(255, 255, 255, 0.45)')
                  .position({ x: 25, y: 8 })

                Text('·')
                  .fontSize(14)
                  .fontColor('rgba(255, 255, 255, 0.35)')
                  .position({ x: 280, y: 10 })

                Text('✦')
                  .fontSize(7)
                  .fontColor('rgba(255, 255, 255, 0.4)')
                  .position({ x: 260, y: 35 })

                Image($r('app.media.ic_plane_b787_side'))
                  .width('75%')
                  .height(60)
                  .objectFit(ImageFit.Contain)
              }
              .width('100%')
              .height(60)

              // 底部垂直航线卡片 (Flight Tracker Timeline Card)
              Column({ space: 6 }) {
                // 顶部状态行
                Row() {
                  Row({ space: 4 }) {
                    Text('↑')
                      .fontSize(11)
                      .fontColor('#94A3B8')

                    Text('我的航班')
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#94A3B8')
                  }

                  Blank()

                  Text('35m 预计专注巡航')
                    .fontSize(11)
                    .fontColor('#FA6B56')
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')

                // 起降地与航线状态行
                Row({ space: 8 }) {
                  // 垂直航线指示点
                  Column({ space: 3 }) {
                    Circle({ width: 7, height: 7 })
                      .stroke('#94A3B8')
                      .strokeWidth(1.5)
                      .fill('transparent')

                    Line()
                      .width(1.5)
                      .height(14)
                      .backgroundColor('#64748B')

                    Text('✈')
                      .fontSize(10)
                      .fontColor('#FFFFFF')
                  }
                  .alignItems(HorizontalAlign.Center)
                  .margin({ top: 3 })

                  // 城市代码与详情
                  Column({ space: 3 }) {
                    Text('成都天府 TFU ✈ 巴黎戴高乐 CDG')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')

                    Row({ space: 8 }) {
                      Text('预计 1h 10m 后抵达')
                        .fontSize(10)
                        .fontColor('rgba(255, 255, 255, 0.6)')

                      Text('气流平稳')
                        .fontSize(10)
                        .fontColor('#34D399')
                        .fontWeight(FontWeight.Medium)
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .width('92%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor('rgba(255, 255, 255, 0.08)')
              .borderRadius(14)
              .margin({ top: 4 })
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#070210')
            .borderRadius({ topLeft: 40, topRight: 40 })
            .clip(true)
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#18181B')
          .borderRadius({ topLeft: 43, topRight: 43 })
          .padding({ left: 2, right: 2, top: 2 })
        }
        .layoutWeight(1)
        .height(250)
        .backgroundColor('#94A3B8')
        .borderRadius({ topLeft: 46, topRight: 46 })
        .padding({ left: 2.5, right: 2.5, top: 2.5 })
        .shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.75)', offsetY: 14 })

        // 3.2 右侧实体金属按键柱 (紧贴右侧边框，清晰突出可见)
        Column({ space: 6 }) {
          // 音量 +
          Row()
            .width(4)
            .height(24)
            .backgroundColor('#E2E8F0')
            .borderRadius({ topRight: 2, bottomRight: 2 })
            .shadow({ radius: 3, color: 'rgba(0,0,0,0.5)', offsetX: 1 })

          // 音量 -
          Row()
            .width(4)
            .height(24)
            .backgroundColor('#E2E8F0')
            .borderRadius({ topRight: 2, bottomRight: 2 })
            .shadow({ radius: 3, color: 'rgba(0,0,0,0.5)', offsetX: 1 })

          // 锁屏 / 电源键
          Row()
            .width(4)
            .height(38)
            .backgroundColor('#E2E8F0')
            .borderRadius({ topRight: 2, bottomRight: 2 })
            .shadow({ radius: 3, color: 'rgba(0,0,0,0.5)', offsetX: 1 })
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 98 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .height(250)
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .clip(true)
    .alignItems(HorizontalAlign.Center)
  }

  // 方案 1: 年度会员 (BEST VALUE 48元/年)
  @Builder
  private buildAnnualPlanCard() {
    Column() {
      // 1. 超值推荐 药丸徽章 (高亮尊贵紫)
      Row() {
        Text('超值推荐')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#7E22CE')
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#F3E8FF')
      .borderRadius(12)
      .margin({ bottom: 8 })

      // 2. 方案标题
      Text('年度会员 · 畅享全年')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .margin({ bottom: 12 })

      // 4. 价格与优惠徽章
      Row() {
        Row({ space: 4 }) {
          Text('¥ 48.00')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#0F172A')

          Text('/ 年')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
            .margin({ top: 6 })
        }

        Blank()

        // 优惠折扣标签
        Row() {
          Text('立省 50%')
            .fontSize(11)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#9333EA')
        .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('按年支付，随心畅享一整年')
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ top: 2, bottom: 14 })

      // 5. 立即开启按钮 (Continue CTA)
      Button() {
        Text('立即开启专注之旅')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(48)
      .backgroundColor('#2563EB')
      .borderRadius(24)
      .shadow({ radius: 12, color: 'rgba(37, 99, 235, 0.4)', offsetY: 4 })
      .onClick(() => {
        this.showToast('恭喜成为「专注航行 Pro」年度机长！');
        if (this.onClose) {
          this.onClose();
        }
      })
      .margin({ bottom: 8 })

      // 6. PRO 完整尊享权益清单
      this.buildVipFeatureList()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.35)', offsetY: 6 })
  }

  // 方案 2: 月度会员 (MONTHLY PLAN 8元/月)
  @Builder
  private buildMonthlyPlanCard() {
    Column() {
      // 1. 灵活体验 药丸徽章
      Row() {
        Text('灵活随心')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#475569')
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#F1F5F9')
      .borderRadius(12)
      .margin({ bottom: 8 })

      // 2. 方案标题
      Text('月度会员 · 灵活畅享')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .margin({ bottom: 12 })

      // 4. 价格与优惠徽章
      Row() {
        Row({ space: 4 }) {
          Text('¥ 8.00')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#0F172A')

          Text('/ 月')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
            .margin({ top: 6 })
        }

        Blank()

        // 优惠折扣标签
        Row() {
          Text('随心订阅')
            .fontSize(11)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#9333EA')
        .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('按月支付 ¥8.00 / 月，可随时取消')
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ top: 2, bottom: 14 })

      // 5. 立即开启按钮 (Continue CTA)
      Button() {
        Text('立即开启专注之旅')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(48)
      .backgroundColor('#2563EB')
      .borderRadius(24)
      .shadow({ radius: 12, color: 'rgba(37, 99, 235, 0.4)', offsetY: 4 })
      .onClick(() => {
        this.showToast('恭喜成为「专注航行 Pro」月度机长！');
        if (this.onClose) {
          this.onClose();
        }
      })
      .margin({ bottom: 8 })

      // 6. PRO 完整尊享权益清单
      this.buildVipFeatureList()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.35)', offsetY: 6 })
  }

  // 👑 PRO 会员全部尊享权益列表 (无序圆点列表版)
  @Builder
  private buildVipFeatureList() {
    Column({ space: 5.5 }) {
      // 细分割线
      Row()
        .width('100%')
        .height(0.5)
        .backgroundColor('#E2E8F0')
        .margin({ top: 3, bottom: 4 })

      this.buildBulletItem('无限飞行架次')
      this.buildBulletItem('沉浸机舱舷窗')
      this.buildBulletItem('沉浸机上白噪音')
      this.buildBulletItem('灵动实况窗')
      this.buildBulletItem('专注生涯护照')
      this.buildBulletItem('全维度飞行护照')
      this.buildBulletItem('3D 动态航迹复盘')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildBulletItem(title: string) {
    Row({ space: 7 }) {
      Circle({ width: 3.5, height: 3.5 })
        .fill('#64748B')
        .margin({ top: 0.5 })

      Text(title)
        .fontSize(12)
        .fontColor('#475569')
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // 方案 2: 终身机长买断 (LIFETIME)
  @Builder
  private buildLifetimePlanCard() {
    Column() {
      // 1. 终身永久 药丸徽章 (典雅琥珀金)
      Row() {
        Text('终身永久')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#B45309')
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#FEF3C7')
      .borderRadius(12)
      .margin({ bottom: 8 })

      // 2. 方案标题
      Text('终身机长 · 一次买断')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .margin({ bottom: 12 })

      // 4. 价格与优惠徽章
      Row() {
        Row({ space: 4 }) {
          Text('¥ 88.00')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#0F172A')

          Text('终身买断')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#D97706')
            .margin({ top: 6 })
        }

        Blank()

        Row() {
          Text('一次性买断')
            .fontSize(11)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#D97706')
        .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('永久买断，无需续费')
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ top: 2, bottom: 14 })

      // 5. 立即开启按钮 (Continue CTA)
      Button() {
        Text('永久买断终身特权')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(48)
      .backgroundColor('#D97706')
      .borderRadius(24)
      .shadow({ radius: 12, color: 'rgba(217, 119, 6, 0.4)', offsetY: 4 })
      .onClick(() => {
        this.showToast('恭喜成为「专注航行」终身荣誉机长！');
        if (this.onClose) {
          this.onClose();
        }
      })
      // 6. PRO 完整尊享权益清单
      this.buildVipFeatureList()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.35)', offsetY: 6 })
  }
}
