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
  onThemeSelected?: (index: number) => void;
  onSkinSelected?: (index: number) => void;
  onClose?: () => void;

  @State activeTab: number = 0; // 0: 停机坪主题, 1: 飞机皮肤
  @State tempThemeIndex: number = 0;
  @State tempPlaneSkinIndex: number = 0;

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
      // 1. 顶部 Segmented 分段切换药丸与通用关闭按钮 (1:1 对标 PassportStatsView 滑动高亮胶囊动效)
      Row() {
        Stack({ alignContent: Alignment.Start }) {
          // 底槽背景
          Row()
            .width(168)
            .height(32)
            .backgroundColor('rgba(0, 0, 0, 0.05)')
            .borderRadius(16)

          // 平滑滑动的白色高亮胶囊 (完全与槽体等高居中)
          Row()
            .width(84)
            .height(32)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.06)', offsetY: 1 })
            .offset({ x: this.activeTab * 84 })
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })

          // 选项文字层
          Row() {
            Text('停机坪主题')
              .fontSize(13)
              .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeTab === 0 ? '#000000' : '#94A3B8')
              .textAlign(TextAlign.Center)
              .width(84)
              .height(32)
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
              .fontColor(this.activeTab === 1 ? '#000000' : '#94A3B8')
              .textAlign(TextAlign.Center)
              .width(84)
              .height(32)
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
                  .backgroundColor('#F06553')
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
                  { width: 2.5, color: '#F06553', radius: 16 } : 
                  { width: 1.5, color: '#EAE1D8', radius: 16 })
                .padding(2)
                .scale({
                  x: this.tempThemeIndex === index ? 1.05 : 0.96,
                  y: this.tempThemeIndex === index ? 1.05 : 0.96
                })
                .shadow(this.tempThemeIndex === index ? 
                  { radius: 14, color: 'rgba(240, 101, 83, 0.28)', offsetY: 5 } : 
                  { radius: 5, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })

                Text(theme.name)
                  .fontSize(13)
                  .fontWeight(this.tempThemeIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.tempThemeIndex === index ? '#F06553' : '#334155')
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
                  .backgroundColor('#F06553')
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
                  { width: 2.5, color: '#F06553', radius: 16 } : 
                  { width: 1.5, color: '#EAE1D8', radius: 16 })
                .padding(2)
                .scale({
                  x: this.tempPlaneSkinIndex === index ? 1.05 : 0.96,
                  y: this.tempPlaneSkinIndex === index ? 1.05 : 0.96
                })
                .shadow(this.tempPlaneSkinIndex === index ? 
                  { radius: 14, color: 'rgba(240, 101, 83, 0.28)', offsetY: 5 } : 
                  { radius: 5, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })

                Text(skin.name)
                  .fontSize(13)
                  .fontWeight(this.tempPlaneSkinIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.tempPlaneSkinIndex === index ? '#F06553' : '#334155')
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

      // 3. 底部应用按钮
      Row() {
        Button(this.activeTab === 0 ? '应用停机坪主题' : '应用飞机皮肤')
          .width('100%')
          .height(48)
          .backgroundColor('#F06553')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .borderRadius(24)
          .shadow({ radius: 12, color: 'rgba(240, 101, 83, 0.35)', offsetY: 4 })
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
    .onClick(() => {
      this.isThemeSelectSheetVisible = true;
    })
  }
}
