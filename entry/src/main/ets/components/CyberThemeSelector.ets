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

import { CloseButton } from './CloseButton';

export class ThemeItem {
  name: string = '';
  image: Resource;
  locked: boolean = false;
  constructor(name: string, image: Resource, locked: boolean = false) {
    this.name = name;
    this.image = image;
    this.locked = locked;
  }
}

export class PlaneSkinItem {
  name: string = '';
  image: Resource;
  previewImage: Resource;
  tag?: string;
  constructor(name: string, image: Resource, previewImage: Resource, tag?: string) {
    this.name = name;
    this.image = image;
    this.previewImage = previewImage;
    this.tag = tag;
  }
}

/**
 * 停机坪与飞机皮肤装扮底部抽屉内容组件
 */
@Component
export struct ThemeSelectSheetContent {
  @StorageLink('currentThemeIndex') currentThemeIndex: number = 0;
  @StorageLink('selectedPlaneSkinIndex') selectedPlaneSkinIndex: number = 0;
  @StorageLink('userMemberTier') userMemberTier: string = 'standard';
  onThemeSelected?: (index: number) => void;
  onSkinSelected?: (index: number) => void;
  onClose?: () => void;

  @State activeTab: number = 0; // 0: 停机坪主题, 1: 飞机皮肤
  @State tempThemeIndex: number = 0;
  @State tempPlaneSkinIndex: number = 0;

  private getThemeAccentColor(): string {
    return this.userMemberTier === 'lifetime' ? '#9B84EC' : '#FA6B56';
  }

  private getThemeShadowColor(): string {
    return this.userMemberTier === 'lifetime' ? 'rgba(155, 132, 236, 0.32)' : 'rgba(250, 107, 86, 0.28)';
  }

  private readonly themes: ThemeItem[] = [
    new ThemeItem('默认', $r('app.media.bg_1')),
    new ThemeItem('晴空航迹', $r('app.media.skytrace')),
    new ThemeItem('云鲸航线', $r('app.media.skywhale')),
    new ThemeItem('戴竹蜻蜓蓝色胖子', $r('app.media.theme_doraemon')),
    new ThemeItem('空港幻想', $r('app.media.theme_skyreverie')),
    new ThemeItem('机修大队', $r('app.media.skymechacrev')),
    new ThemeItem('星港先锋', $r('app.media.starportvanguard')),
    new ThemeItem('苍穹机甲', $r('app.media.skyframe'))
  ];

  // ✈️ 官方机身涂装皮肤库
  private readonly planeSkins: PlaneSkinItem[] = [
    new PlaneSkinItem('萌猫机长', $r('app.media.plane_skin_cat'), $r('app.media.plane_skin_cat'), '默认'),
    new PlaneSkinItem('鲸喜起飞', $r('app.media.plane_skin_whale'), $r('app.media.plane_skin_whale'), '限定'),
    new PlaneSkinItem('极光失控', $r('app.media.plane_skin_aurora'), $r('app.media.plane_skin_aurora'), '限定')
  ];

  aboutToAppear(): void {
    this.tempThemeIndex = this.currentThemeIndex;
    this.tempPlaneSkinIndex = this.selectedPlaneSkinIndex;
  }

  build() {
    Column() {
      // 1. 顶部 Segmented 分段切换药丸与通用关闭按钮 (Apple 级实体物理内嵌分段控制器)
      Row() {
        Stack({ alignContent: Alignment.Start }) {
          // 底槽背景 (纯净浅灰内嵌质感)
          Row()
            .width(178)
            .height(36)
            .backgroundColor('#F1F5F9')
            .borderRadius(18)

          // 平滑滑动的立体白色高亮胶囊 (比底槽微内缩 2.5vp，物理悬浮阴影)
          Row()
            .width(85)
            .height(30)
            .backgroundColor('#FFFFFF')
            .borderRadius(15)
            .shadow({ radius: 8, color: 'rgba(15, 23, 42, 0.10)', offsetY: 2 })
            .offset({ x: 3 + this.activeTab * 87 })
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })

          // 选项文字层
          Row() {
            Text('停机坪主题')
              .fontSize(13)
              .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeTab === 0 ? '#0F172A' : '#64748B')
              .textAlign(TextAlign.Center)
              .width(88)
              .height(36)
              .onClick(() => {
                if (this.activeTab !== 0) {
                  this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                    this.activeTab = 0;
                  });
                }
              })

            Text('飞机皮肤')
              .fontSize(13)
              .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeTab === 1 ? '#0F172A' : '#64748B')
              .textAlign(TextAlign.Center)
              .width(88)
              .height(36)
              .onClick(() => {
                if (this.activeTab !== 1) {
                  this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                    this.activeTab = 1;
                  });
                }
              })
          }
        }

        Blank()

        CloseButton({
          circleColor: '#FFFFFF',
          iconColor: '#000000',
          buttonSize: 32,
          onClickAction: () => {
            if (this.onClose) {
              this.onClose();
            }
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 2, bottom: 12 })

      // 2. 内容区域：Swiper 平滑横向联动滑动
      Swiper() {
        // 2.1 停机坪主题列表
        Scroll() {
          Row({ space: 16 }) {
            ForEach(this.themes, (theme: ThemeItem, index: number) => {
              Column() {
                Stack({ alignContent: Alignment.BottomEnd }) {
                  Image(theme.image)
                    .width(110)
                    .height(145)
                    .borderRadius(14)
                    .objectFit(ImageFit.Cover)

                  // 选中时的弹性对勾徽章
                  Row() {
                    Text('✓')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(24)
                  .height(24)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .backgroundColor(this.getThemeAccentColor())
                  .borderRadius(12)
                  .margin(8)
                  .border({ width: 2, color: '#FFFFFF' })
                  .scale({
                    x: this.tempThemeIndex === index ? 1.0 : 0.0,
                    y: this.tempThemeIndex === index ? 1.0 : 0.0
                  })
                  .opacity(this.tempThemeIndex === index ? 1.0 : 0.0)
                  .animation({ duration: 250, curve: Curve.FastOutSlowIn })
                }
                .border(this.tempThemeIndex === index ? 
                  { width: 2.5, color: this.getThemeAccentColor(), radius: 16 } : 
                  { width: 1.5, color: '#EAE1D8', radius: 16 })
                .padding(2)
                .scale({
                  x: this.tempThemeIndex === index ? 1.05 : 0.96,
                  y: this.tempThemeIndex === index ? 1.05 : 0.96
                })
                .shadow(this.tempThemeIndex === index ? 
                  { radius: 14, color: this.getThemeShadowColor(), offsetY: 5 } : 
                  { radius: 5, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })

                Text(theme.name)
                  .fontSize(13)
                  .fontWeight(this.tempThemeIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.tempThemeIndex === index ? this.getThemeAccentColor() : '#334155')
                  .margin({ top: 10 })
                  .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              }
              .onClick(() => {
                this.getUIContext()?.animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
                  this.tempThemeIndex = index;
                });
              })
            })
          }
          .padding({ left: 24, right: 24, top: 4, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // 2.2 飞机涂装列表 (萌猫机长 与 萌犬机长)
        Scroll() {
          Row({ space: 18 }) {
            ForEach(this.planeSkins, (skin: PlaneSkinItem, index: number) => {
              Column() {
                Stack({ alignContent: Alignment.BottomEnd }) {
                  Column() {
                    Image(skin.previewImage)
                      .width(105)
                      .height(135)
                      .objectFit(ImageFit.Contain)
                  }
                  .width(115)
                  .height(145)
                  .backgroundColor('rgba(255, 255, 255, 0.9)')
                  .borderRadius(14)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)

                  // 选中时的弹性对勾徽章
                  Row() {
                    Text('✓')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(24)
                  .height(24)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .backgroundColor(this.getThemeAccentColor())
                  .borderRadius(12)
                  .margin(8)
                  .border({ width: 2, color: '#FFFFFF' })
                  .scale({
                    x: this.tempPlaneSkinIndex === index ? 1.0 : 0.0,
                    y: this.tempPlaneSkinIndex === index ? 1.0 : 0.0
                  })
                  .opacity(this.tempPlaneSkinIndex === index ? 1.0 : 0.0)
                  .animation({ duration: 250, curve: Curve.FastOutSlowIn })
                }
                .border(this.tempPlaneSkinIndex === index ? 
                  { width: 2.5, color: this.getThemeAccentColor(), radius: 16 } : 
                  { width: 1.5, color: '#EAE1D8', radius: 16 })
                .padding(2)
                .scale({
                  x: this.tempPlaneSkinIndex === index ? 1.05 : 0.96,
                  y: this.tempPlaneSkinIndex === index ? 1.05 : 0.96
                })
                .shadow(this.tempPlaneSkinIndex === index ? 
                  { radius: 14, color: this.getThemeShadowColor(), offsetY: 5 } : 
                  { radius: 5, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })

                Text(skin.name)
                  .fontSize(13)
                  .fontWeight(this.tempPlaneSkinIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.tempPlaneSkinIndex === index ? this.getThemeAccentColor() : '#334155')
                  .margin({ top: 10 })
                  .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              }
              .onClick(() => {
                this.getUIContext()?.animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
                  this.tempPlaneSkinIndex = index;
                });
              })
            })
          }
          .padding({ left: 24, right: 24, top: 4, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .index(this.activeTab)
      .onChange((index: number) => {
        this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
          this.activeTab = index;
        });
      })
      .loop(false)
      .indicator(false)
      .duration(300)
      .curve(Curve.FastOutSlowIn)
      .width('100%')

      // 3. 底部应用按钮 (动态流光渐变 / 暖珊瑚红)
      Row() {
        Row() {
          Text(this.activeTab === 0 ? '应用停机坪主题' : '应用飞机皮肤')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(48)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.userMemberTier === 'lifetime' ? '#00000000' : '#FA6B56')
        .linearGradient(
          this.userMemberTier === 'lifetime'
            ? {
                angle: 135,
                colors: [
                  ['#F875C8', 0.0],
                  ['#9B84EC', 0.50],
                  ['#51DFD5', 1.0]
                ]
              }
            : {
                angle: 180,
                colors: [
                  ['#FC7561', 0.0],
                  ['#F6604B', 1.0]
                ]
              }
        )
        .borderRadius(24)
        .shadow({
          radius: 12,
          color: this.userMemberTier === 'lifetime' ? 'rgba(155, 132, 236, 0.35)' : 'rgba(250, 107, 86, 0.35)',
          offsetY: 4
        })
        .onClick(() => {
          if (this.activeTab === 0) {
            if (this.onThemeSelected) {
              this.onThemeSelected(this.tempThemeIndex);
            }
            this.currentThemeIndex = this.tempThemeIndex;
          } else {
            if (this.onSkinSelected) {
              this.onSkinSelected(this.tempPlaneSkinIndex);
            } else {
              this.selectedPlaneSkinIndex = this.tempPlaneSkinIndex;
            }
          }
          if (this.onClose) {
            this.onClose();
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 20 })
    }
    .width('100%')
  }
}

/**
 * 停机坪机位地标互动组件 (机位 01 / 个性装扮)
 */
@Component
export struct CyberThemeSelector {
  @StorageLink('currentThemeIndex') currentThemeIndex: number = 0;
  @StorageLink('isThemeSelectSheetVisible') isThemeSelectSheetVisible: boolean = false;
  @State isPressed: boolean = false;
  private readonly themeNames: string[] = ['默认', '晴空航迹', '云鲸航线', '戴竹蜻蜓蓝色胖子', '空港幻想', '机修大队', '星港先锋', '苍穹机甲'];

  private getDisplayText(): string {
    if (this.currentThemeIndex === 0 || !this.themeNames[this.currentThemeIndex]) {
      return '机位装扮';
    }
    return this.themeNames[this.currentThemeIndex];
  }

  build() {
    // 停机位地面标牌 ([ 机位 01 ] 动态主题名/机位装扮)
    Row({ space: 6 }) {
      // 停机位地标编号 (航空安全警戒黄)
      Row() {
        Text('机位 01')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
      }
      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
      .backgroundColor('#FBBF24')
      .borderRadius(3)

      // 地面标牌功能说明：默认主题显示“机位装扮”，已选主题显示具体主题名称
      Text(this.getDisplayText())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#475569')
    }
    .padding({ left: 6, right: 8, top: 4, bottom: 4 })
    .backgroundColor('rgba(255, 255, 255, 0.92)')
    .border({ width: 1, color: '#E2E8F0', radius: 6 })
    .borderRadius(6)
    .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.08)', offsetY: 2 })
    .scale({ x: this.isPressed ? 0.93 : 1.0, y: this.isPressed ? 0.93 : 1.0 })
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      this.isThemeSelectSheetVisible = true;
    })
  }
}

/**
 * 停机坪拟物微缩机票/登机票根互动小徽章 (FlightBookingSignboard)
 */
@Component
export struct FlightBookingSignboard {
  @StorageLink('isBookFlightSheetVisible') isBookFlightSheetVisible: boolean = false;
  @StorageLink('userMemberTier') userMemberTier: string = 'standard';
  @State isPressed: boolean = false;

  build() {
    // 🎫 拟物微缩机票票根小徽章 (主联 + 撕票细虚线 + 副联 FLT)
    Row({ space: 0 }) {
      // 1. 机票主联 (Main Ticket)：日历小图标 + "预订"
      Row({ space: 4 }) {
        Image($r('app.media.ic_flight_booking'))
          .width(12)
          .height(12)
          .objectFit(ImageFit.Contain)

        Text('预订')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
      }
      .padding({ left: 7, right: 5, top: 3, bottom: 3 })

      // 2. 机票中间微型撕票虚线 (Perforated Line)
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Rect().width(1).height(2.5).fill('#CBD5E1').margin({ bottom: 1.5 })
          Rect().width(1).height(2.5).fill('#CBD5E1').margin({ bottom: 1.5 })
          Rect().width(1).height(2.5).fill('#CBD5E1')
        }
        .height(14)
        .justifyContent(FlexAlign.Center)
      }
      .width(3)
      .height(18)

      // 3. 机票副联 (Stub Tail)：航空专属 FLT 标签 (动态主题色)
      Row() {
        Text('FLT')
          .fontSize(9)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.userMemberTier === 'lifetime' ? '#9B84EC' : '#FA6B56')
      }
      .padding({ left: 4, right: 6, top: 3, bottom: 3 })
    }
    .height(23)
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .border({ width: 1, color: '#E2E8F0', radius: 5 })
    .borderRadius(5)
    .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.08)', offsetY: 2 })
    .scale({ x: this.isPressed ? 0.93 : 1.0, y: this.isPressed ? 0.93 : 1.0 })
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      this.isBookFlightSheetVisible = true;
    })
  }
}
