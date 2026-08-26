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
import { Airport, findAirportByCode } from '../models/AirportModel';

export type MemberTierType = 'free' | 'monthly' | 'annual' | 'lifetime';

export interface MemberTierStyle {
  tier: MemberTierType;
  title: string;
  badgeName: string;
  mrzBadge: string;
  tagColor: string;
}

/**
 * PreFlightBoardingPassOverlay.ets
 * 拟物航空机票卡片 (精悍黄金比例300x500 / 终生会员专属彩虹小飞机编队 / 目的地中文大字 / 纯净底板三层物理凹陷雕刻压印MRZ / 专注航行 Pro)
 */
@Component
export struct PreFlightBoardingPassOverlay {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isPreviewOnly: boolean = false; // 🧪 是否仅为测试预览模式 (不跳转起飞界面)
  @Prop originAirport?: Airport = undefined;
  @Prop destAirport?: Airport = undefined;
  @Prop durationMinutes: number = 45;
  @Prop focusTagTitle: string = '深度工作';
  @Prop seatId: string = '01A';
  @Prop initialMemberTier: MemberTierType = 'free'; // 初始会员等级
  onFinish?: () => void;
  onClose?: () => void;

  @State private currentTier: MemberTierType = 'free';
  @State private posterOpacity: number = 0;
  @State private posterScale: number = 0.94;
  @State private cardOffsetY: number = 20;
  @State private isSkipped: boolean = false;

  // 会员等级色彩与数据配置矩阵 (Dribbble 顶级航空尊贵体系)
  private readonly tierStyles: Record<MemberTierType, MemberTierStyle> = {
    'free': {
      tier: 'free',
      title: '标准会员 (深蓝底)',
      badgeName: '标准舱位',
      mrzBadge: 'MEMBER',
      tagColor: 'rgba(210, 228, 252, 0.72)'
    },
    'monthly': {
      tier: 'monthly',
      title: '月度会员 (极光青底)',
      badgeName: '银翼先锋',
      mrzBadge: 'MONTHLY<PRO',
      tagColor: 'rgba(110, 235, 250, 0.74)'
    },
    'annual': {
      tier: 'annual',
      title: '年度会员 (香槟金底)',
      badgeName: '金翼领航',
      mrzBadge: 'ANNUAL<GOLD<VIP',
      tagColor: 'rgba(250, 220, 125, 0.76)'
    },
    'lifetime': {
      tier: 'lifetime',
      title: '终生会员 (曜石紫底)',
      badgeName: '黑曜创世',
      mrzBadge: 'LIFETIME<BLACK<FOUNDER',
      tagColor: 'rgba(228, 195, 255, 0.76)'
    }
  };

  // 卡片海报尺寸 (精悍黄金比例 300x500)
  private readonly CARD_W: number = 300;
  private readonly CARD_H: number = 500;

  // 切口与撕票打孔线基准 Y 坐标 (像素级绝对对齐)
  private readonly NOTCH_Y: number = 165;

  // 底栏交界水平线 Y 与底栏总高度
  private readonly FOOTER_TOP_Y: number = 462;
  private readonly FOOTER_HEIGHT: number = 38; // 500 - 462 = 38vp

  // 100% 工业级 Code 128 航空登机牌条形码真实宽隙数据 (精确拉长至 266vp，高度加长至 42vp)
  private readonly barcodePattern: number[] = [
    3.3, 1.65, 1.65, 3.3, 4.96, 3.3, 1.65, 1.32, 3.3, 1.32, 1.98, 1.65, 1.65, 2.48, 1.65, 2.97, 2.97, 1.65, 1.65,
    1.32, 2.48, 1.32, 4.13, 1.65, 1.98, 2.48, 4.96, 1.32, 2.97, 2.48, 1.65, 1.32, 4.96, 1.98, 2.97, 1.65, 1.98, 1.65,
    1.65, 1.32, 2.97, 1.65, 2.97, 1.65, 3.3, 1.32, 4.13, 2.48, 1.65, 1.65, 1.65, 2.97, 2.97, 2.48, 1.98, 2.48, 1.65,
    1.32, 4.13, 1.65, 2.97, 1.32, 2.48, 1.32, 2.97, 2.48, 3.97, 2.48, 3.3, 1.32, 2.97, 2.48, 1.98, 2.48, 3.3, 2.97,
    4.13, 1.65, 1.98, 2.48, 2.48, 1.32, 2.97, 2.48, 2.97, 2.48, 2.48, 2.97, 2.97, 1.65, 1.98, 1.32, 3.3, 1.98, 2.97,
    1.65, 1.98, 2.48, 3.3, 1.32, 4.13, 2.48, 3.3, 4.96, 4.96, 1.65, 1.65, 1.65, 3.47
  ];

  private dropTimerId: number = -1;
  private blastoffTimerId: number = -1;

  aboutToAppear(): void {
    this.currentTier = this.initialMemberTier;
    if (this.isVisible) {
      this.playCeremonySequence();
    }
  }

  aboutToDisappear(): void {
    this.clearAllTimers();
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.currentTier = this.initialMemberTier;
      this.playCeremonySequence();
    } else {
      this.clearAllTimers();
    }
  }

  private clearAllTimers(): void {
    if (this.dropTimerId !== -1) clearTimeout(this.dropTimerId);
    if (this.blastoffTimerId !== -1) clearTimeout(this.blastoffTimerId);
  }

  private triggerHaptic(durationMs: number = 30): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: durationMs
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {}
  }

  /**
   * 获取当前会员等级对应的底板矢量图资源 (动态切换底部背景颜色)
   */
  private getTierBgResource(): Resource {
    switch (this.currentTier) {
      case 'monthly':
        return $r('app.media.bg_ticket_monthly');
      case 'annual':
        return $r('app.media.bg_ticket_annual');
      case 'lifetime':
        return $r('app.media.bg_ticket_lifetime');
      case 'free':
      default:
        return $r('app.media.bg_ticket_free');
    }
  }

  /**
   * 切换下一级会员等级 (循环切换：标准 -> 月度 -> 年度 -> 终生)
   */
  private toggleNextMemberTier(): void {
    this.triggerHaptic(20);
    const tiers: MemberTierType[] = ['free', 'monthly', 'annual', 'lifetime'];
    const currentIndex = tiers.indexOf(this.currentTier);
    const nextIndex = (currentIndex + 1) % tiers.length;
    this.currentTier = tiers[nextIndex];
  }

  /**
   * 图 2 同款彩虹渐变色算法 (橙黄 #F6C492 -> 魅紫 #C074E1 -> 极光青 #81E8E6)
   */
  private getStreamerGradientColor(index: number, total: number): string {
    const t = index / Math.max(1, total - 1);
    if (t < 0.5) {
      const t2 = t * 2;
      const r = Math.round(0xF6 + (0xC0 - 0xF6) * t2);
      const g = Math.round(0xC4 + (0x74 - 0xC4) * t2);
      const b = Math.round(0x92 + (0xE1 - 0x92) * t2);
      return `rgb(${r},${g},${b})`;
    } else {
      const t2 = (t - 0.5) * 2;
      const r = Math.round(0xC0 + (0x81 - 0xC0) * t2);
      const g = Math.round(0x74 + (0xE8 - 0x74) * t2);
      const b = Math.round(0xE1 + (0xE6 - 0xE1) * t2);
      return `rgb(${r},${g},${b})`;
    }
  }

  private playCeremonySequence(): void {
    this.isSkipped = false;
    this.posterOpacity = 0;
    this.posterScale = 0.94;
    this.cardOffsetY = 20;

    // 阶段 1：卡片淡入浮现 (350ms)
    this.triggerHaptic(30);
    this.getUIContext()?.animateTo({
      duration: 350,
      curve: Curve.EaseOut
    }, () => {
      this.posterOpacity = 1.0;
      this.posterScale = 1.0;
      this.cardOffsetY = 0;
    });

    // 如果不是测试预览模式，在 2600ms 后自动起飞
    if (!this.isPreviewOnly) {
      this.blastoffTimerId = setTimeout(() => {
        this.triggerBlastoff();
      }, 2600);
    }
  }

  private handleCloseOnly(): void {
    if (this.isSkipped) return;
    this.isSkipped = true;
    this.clearAllTimers();

    this.getUIContext()?.animateTo({
      duration: 280,
      curve: Curve.EaseOut,
      onFinish: () => {
        if (this.onClose) {
          this.onClose();
        }
      }
    }, () => {
      this.posterOpacity = 0;
      this.posterScale = 0.9;
    });
  }

  private triggerBlastoff(): void {
    if (this.isPreviewOnly) {
      this.handleCloseOnly();
      return;
    }
    if (this.isSkipped) return;
    this.isSkipped = true;
    this.clearAllTimers();

    this.getUIContext()?.animateTo({
      duration: 380,
      curve: Curve.EaseIn,
      onFinish: () => {
        if (this.onFinish) {
          this.onFinish();
        }
      }
    }, () => {
      this.cardOffsetY = -600;
      this.posterScale = 1.05;
      this.posterOpacity = 0;
    });
  }

  /**
   * 存根完整日期格式（如 26 AUGUST 2026）
   */
  private getStubFullDateString(): string {
    const d = new Date();
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    const day = d.getDate().toString().padStart(2, '0');
    const month = months[d.getMonth()];
    const year = d.getFullYear();
    return `${day} ${month} ${year}`;
  }

  /**
   * 航班简写日期（如 2026.08.26）
   */
  private getShortDateString(): string {
    const d = new Date();
    const year = d.getFullYear();
    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${year}.${month}.${day}`;
  }

  /**
   * 出发时间（当前时间，如 11:01 AM）
   */
  private getDepartureTimeString(): string {
    const d = new Date();
    let hours = d.getHours();
    const minutes = d.getMinutes().toString().padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    hours = hours ? hours : 12;
    const hoursStr = hours.toString().padStart(2, '0');
    return `${hoursStr}:${minutes} ${ampm}`;
  }

  /**
   * 预计到达/降落时间（当前出发时间 + 专注时长，如 11:16 AM）
   */
  private getLandingTimeString(): string {
    const d = new Date(Date.now() + this.durationMinutes * 60 * 1000);
    let hours = d.getHours();
    const minutes = d.getMinutes().toString().padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    hours = hours ? hours : 12;
    const hoursStr = hours.toString().padStart(2, '0');
    return `${hoursStr}:${minutes} ${ampm}`;
  }

  /**
   * MRZ 机读码行 1 (严格 48 字符等宽满幅排布)
   */
  private getMrzLine1(): string {
    const d = new Date();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const day = d.getDate().toString().padStart(2, '0');
    const mon = months[d.getMonth()];
    const yr = d.getFullYear().toString().slice(-2);
    const badge = this.tierStyles[this.currentTier].mrzBadge;
    const prefix = `ALLTIME<<FOCUS<PILOT<<${badge}${day}${mon}${yr}`;
    const targetLen = 48;
    if (prefix.length >= targetLen) {
      return prefix.slice(0, targetLen);
    }
    return prefix + '<'.repeat(targetLen - prefix.length);
  }

  /**
   * MRZ 机读码行 2 (严格 48 字符等宽满幅排布)
   */
  private getMrzLine2(): string {
    const d = new Date();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const day = d.getDate().toString().padStart(2, '0');
    const mon = months[d.getMonth()];
    const yr = d.getFullYear().toString().slice(-2);
    const dest = (this.destAirport?.code || 'PEK').toUpperCase();
    const prefix = `ISSUED${day}${mon}${yr}${dest}`;
    const suffix = `FOCUSFLIGHT.PRO`;
    const targetLen = 48;
    const middleCount = Math.max(2, targetLen - prefix.length - suffix.length);
    return prefix + '<'.repeat(middleCount) + suffix;
  }

  /**
   * 获取目的地城市中文大名 (动态读取当前选中机场城市名)
   */
  private getDestCityNameChinese(): string {
    const dest = this.destAirport || findAirportByCode('PEK') || { city: '北京', code: 'PEK' };
    return dest.city || '北京';
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 全屏沉浸极简磨砂暗场 (半透明夜色背景)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.78)')
          .backdropBlur(30)
          .opacity(this.posterOpacity)
          .onClick(() => {
            if (this.isPreviewOnly) {
              this.handleCloseOnly();
            } else {
              this.triggerBlastoff();
            }
          })

        // 2. 拟物机票卡片 (精悍黄金比例 300x500，终生会员专属彩虹小飞机编队)
        Stack({ alignContent: Alignment.TopStart }) {
          // A. 完整覆盖的 1:1 会员专属矢量底板 (300x500精悍版，左上角微光渐变，底部底栏透明度 0.88)
          Image(this.getTierBgResource())
            .width(this.CARD_W)
            .height(this.CARD_H)
            .objectFit(ImageFit.Fill)

          // B. 图 1 同款高级科技微点阵世界地图 (7600+ 独立蜂窝微点，以中国为中心，透明度 0.18，微光优雅)
          Stack({ alignContent: Alignment.Top }) {
            Image($r('app.media.bg_real_world_silhouette'))
              .width(520)
              .height(330)
              .objectFit(ImageFit.Contain)
              .margin({ top: -14 }) // 向上提拉，使北冰洋/欧亚大陆北端零距离紧挨撕票打孔线
              .opacity(0.18) // 优雅微光暗纹，完美烘托前景信息
              .hitTestBehavior(HitTestMode.None)
          }
          .width(this.CARD_W)
          .height(330)
          .position({ x: 0, y: 170 })
          .borderRadius({ bottomLeft: 24, bottomRight: 24 })
          .clip(true)
          .hitTestBehavior(HitTestMode.None)

          // C. 顶部存根区 (Stub Header - 纯净无双斜杠)
          Column() {
            // 行 1：专注航行 Pro 标签 (纯净大方)
            Row() {
              Text('专注航行 Pro')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(255, 255, 255, 0.88)')
                .letterSpacing(0.6)
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ left: 18, right: 18, top: 12, bottom: 4 })

            // 极细分割线
            Divider()
              .color('rgba(255, 255, 255, 0.12)')
              .strokeWidth(0.8)
              .margin({ left: 18, right: 18, bottom: 14 })

            // 拟物真实 Code 128 工业级条形码 (加长至 42vp 高度，266vp 宽度)
            Row({ space: 0 }) {
              ForEach(this.barcodePattern, (w: number, index: number) => {
                Row()
                  .width(w)
                  .height(42)
                  .backgroundColor(index % 2 === 0 ? 'rgba(255, 255, 255, 0.86)' : Color.Transparent)
              })
            }
            .width(266)
            .height(42)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ left: 17, right: 17, bottom: 10 })

            // 条形码编号小字
            Text(`Boarding pass 89456-1285`)
              .fontSize(9.5)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255, 255, 255, 0.55)')
              .letterSpacing(0.5)
              .margin({ bottom: 7 })

            // 存根居中日期 (整体下沉，匀称贴近撕票打孔线)
            Text(this.getStubFullDateString())
              .fontSize(12.5)
              .fontWeight(FontWeight.Bolder)
              .fontColor('rgba(255, 255, 255, 0.88)')
              .letterSpacing(0.8)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .position({ x: 0, y: 0 })

          // D. 中部拟物物理打孔撕票线 (33个精细冲压打孔圆孔，深陷透底立体质感，直抵两端 S 型切口)
          Row({ space: 4.5 }) {
            ForEach(new Array(33).fill(0), () => {
              Row()
                .width(3.2)
                .height(3.2)
                .borderRadius(1.6)
                .backgroundColor('#1A1B1D')
                .shadow({
                  radius: 1,
                  color: 'rgba(255, 255, 255, 0.22)',
                  offsetY: 1
                })
            })
          }
          .position({ x: 23, y: this.NOTCH_Y - 1.6 })

          // E. 下半部：航程核心与专注参数矩阵 (从 y=182 开始排布)
          Column() {
            // 1. 目的地中文大城市名 (如 北京 / 上海 / 广州 / 成都 / 东京 / 纽约)
            Row() {
              Text(this.getDestCityNameChinese())
                .fontSize(30)
                .fontWeight(FontWeight.Bolder)
                .fontColor('rgba(255, 255, 255, 0.92)')
                .letterSpacing(2)
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ left: 20, right: 20, bottom: 12 })

            // 2. 航线轨迹栏：ORG ┄┄ ✈(图中同款纯白正向朝右客机) ┄┄ DEST
            Row() {
              Text(this.originAirport?.code || 'CTU')
                .fontSize(20)
                .fontWeight(FontWeight.Bolder)
                .fontColor('rgba(255, 255, 255, 0.88)')
                .letterSpacing(1)

              Row({ space: 6 }) {
                Row()
                  .width(18)
                  .height(1)
                  .backgroundColor('rgba(255, 255, 255, 0.28)')

                // 图中同款经典俯视客机 (ic_plane_topview.svg / 顺时针旋转90°正向朝右 / 纯白高光填充)
                Image($r('app.media.ic_plane_topview'))
                  .width(19)
                  .height(19)
                  .objectFit(ImageFit.Contain)
                  .fillColor('rgba(255, 255, 255, 0.92)')
                  .rotate({ angle: 90 })

                Row()
                  .width(18)
                  .height(1)
                  .backgroundColor('rgba(255, 255, 255, 0.28)')
              }
              .padding({ left: 6, right: 6 })
              .alignItems(VerticalAlign.Center)

              Text(this.destAirport?.code || 'PEK')
                .fontSize(20)
                .fontWeight(FontWeight.Bolder)
                .fontColor('rgba(255, 255, 255, 0.88)')
                .letterSpacing(1)

              Blank()
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ left: 20, right: 20, bottom: 16 })

            // 3. 3 行 2 列专注高价值参数信息网格
            Column({ space: 12 }) {
              // 行 1：座位 ┆ 专注主题
              Row() {
                Column({ space: 2.5 }) {
                  Text('座位')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(this.seatId || '01A')
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')

                Column({ space: 2.5 }) {
                  Text('专注主题')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(this.focusTagTitle || '深度工作')
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')
              }
              .width('100%')

              // 行 2：日期 ┆ 专注时长
              Row() {
                Column({ space: 2.5 }) {
                  Text('日期')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(this.getShortDateString())
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')

                Column({ space: 2.5 }) {
                  Text('专注时长')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(`${this.durationMinutes} 分钟`)
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')
              }
              .width('100%')

              // 行 3：出发时间 ┆ 预计到达 (专注完成时间)
              Row() {
                Column({ space: 2.5 }) {
                  Text('出发时间')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(this.getDepartureTimeString())
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')

                Column({ space: 2.5 }) {
                  Text('预计到达')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255, 255, 255, 0.52)')

                  Text(this.getLandingTimeString())
                    .fontSize(12.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('rgba(255, 255, 255, 0.88)')
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .position({ x: 0, y: 182 })

          // ★ F. 全排彩虹渐变朝右小飞机编队 (仅限终生会员 Lifetime 黑曜创世 专属尊贵特权)
          if (this.currentTier === 'lifetime') {
            Row({ space: 8 }) {
              ForEach(new Array(13).fill(0), (_: number, index: number) => {
                Image($r("app.media.ic_nav_flight"))
                  .width(11)
                  .height(11)
                  .fillColor(this.getStreamerGradientColor(index, 13))
                  .rotate({ angle: 90 })
              })
            }
            .width('100%')
            .height(18)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .position({ x: 0, y: 443 })
          }

          // ★ G. 图 2 同款 MRZ 航空机读码等宽文本区 (三层物理凹陷雕刻压印)
          Column({ space: 2.2 }) {
            // 行 1 MRZ
            Stack({ alignContent: Alignment.Center }) {
              // 1. 迎光反光底边 (向下微移 0.8vp，高亮切边)
              Text(this.getMrzLine1())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(255, 255, 255, 0.28)')
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .translate({ y: 0.8 })
                .hitTestBehavior(HitTestMode.None)

              // 2. 背光深凹阴影顶边 (向上微移 0.8vp，深邃遮光凹陷)
              Text(this.getMrzLine1())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(0, 0, 0, 0.75)')
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .translate({ y: -0.8 })
                .hitTestBehavior(HitTestMode.None)

              // 3. 核心压印文字本体
              Text(this.getMrzLine1())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tierStyles[this.currentTier].tagColor)
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .opacity(0.72)
            }

            // 行 2 MRZ
            Stack({ alignContent: Alignment.Center }) {
              // 1. 迎光反光底边 (向下微移 0.8vp)
              Text(this.getMrzLine2())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(255, 255, 255, 0.28)')
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .translate({ y: 0.8 })
                .hitTestBehavior(HitTestMode.None)

              // 2. 背光深凹阴影顶边 (向上微移 0.8vp)
              Text(this.getMrzLine2())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(0, 0, 0, 0.75)')
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .translate({ y: -0.8 })
                .hitTestBehavior(HitTestMode.None)

              // 3. 核心压印文字本体
              Text(this.getMrzLine2())
                .fontSize(7.4)
                .fontFamily('monospace')
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(215, 228, 245, 0.72)')
                .letterSpacing(0.5)
                .lineHeight(9.5)
                .textAlign(TextAlign.Center)
                .opacity(0.72)
            }
          }
          .width('100%')
          .height(this.FOOTER_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({ x: 0, y: this.FOOTER_TOP_Y })
        }
        .width(this.CARD_W)
        .height(this.CARD_H)
        .scale({ x: this.posterScale, y: this.posterScale })
        .translate({ y: this.cardOffsetY })
        .opacity(this.posterOpacity)
        .onClick(() => {
          if (this.isPreviewOnly) {
            // 测试模式下：轻触卡片自由切换会员身份 (标准 ➔ 月度 ➔ 年度 ➔ 终生)
            this.toggleNextMemberTier();
          } else {
            this.triggerBlastoff();
          }
        })

        // 3. 测试预览模式下的会员切换浮动药丸小提示 (方便随时切换验收)
        if (this.isPreviewOnly) {
          Row({ space: 6 }) {
            Circle({ width: 8, height: 8 })
              .fill(this.tierStyles[this.currentTier].tagColor)

            Text(`当前等级：${this.tierStyles[this.currentTier].title} (点击卡片切换)`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor('rgba(20, 22, 28, 0.85)')
          .borderRadius(20)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.18)' })
          .position({ x: '50%', y: '86%' })
          .markAnchor({ x: '50%', y: 0 })
          .onClick(() => {
            this.toggleNextMemberTier();
          })
        }
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(990)
    }
  }
}
