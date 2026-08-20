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

import { mapCommon } from '@kit.MapKit';

@Component
export struct FlightMapHudOverlay {
  @Watch('onVisibilityStateChange') @Prop isMapBackgroundVisible: boolean = false;
  @Watch('onVisibilityStateChange') @Prop isCabinExposed: boolean = false;
  @Prop isCameraFollowLocked: boolean = true;
  @Prop currentMapType: number = mapCommon.MapType.SATELLITE;
  @Prop currentFocusTagTitle: string = '深度学习';
  @Prop remainingTimeString: string = '45:00';
  @Prop isTurbulenceAlertVisible: boolean = false;
  @Prop turbulenceMessageText: string = '遭遇巡航微气流，航向平稳修正中';

  @State private isMapControlsVisible: boolean = false;

  public onOpenSettings: () => void = () => {};
  public onToggleWindowView: () => void = () => {};
  public onToggleMapType: () => void = () => {};
  public onToggleCameraFollow: () => void = () => {};
  public onExitFlight: () => void = () => {};

  aboutToAppear() {
    this.updateControlsVisibility(false);
  }

  private onVisibilityStateChange() {
    this.updateControlsVisibility(true);
  }

  private isTerrainMode(): boolean {
    return this.currentMapType === mapCommon.MapType.TERRAIN;
  }

  private updateControlsVisibility(animate: boolean) {
    const shouldShow = this.isMapBackgroundVisible && !this.isCabinExposed;
    if (animate) {
      this.getUIContext()?.animateTo({
        duration: 700,
        curve: Curve.EaseOut
      }, () => {
        this.isMapControlsVisible = shouldShow;
      });
    } else {
      this.isMapControlsVisible = shouldShow;
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 1. 顶部控制工具栏 (仅在客舱透视或地图飞行模式下呈现)
      if (this.isCabinExposed || this.isMapBackgroundVisible) {
        Row() {
          // 1.1 左侧：返回退出飞行按钮 (HitTestMode.Block 确保精准拦截点击)
          Stack({ alignContent: Alignment.Center }) {
            Image(this.isTerrainMode() ? $r('app.media.ic_hw_back') : $r('app.media.ic_hw_back_white'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(this.isTerrainMode() ? 'rgba(255, 255, 255, 0.90)' : 'rgba(0, 0, 0, 0.50)')
          .backdropBlur(25)
          .border({ width: 0.8, color: this.isTerrainMode() ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.16)', radius: 20 })
          .shadow({ radius: 10, color: this.isTerrainMode() ? 'rgba(0, 0, 0, 0.08)' : 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
          .animation({ duration: 300, curve: Curve.EaseInOut })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.onExitFlight();
          })

          Blank()

          // 1.2 右侧：地图专属高级毛玻璃胶囊控制坞 (垂直聚合：外观定制 -> 舷窗视角 -> 图层切换 -> 视角回正)
          Column() {
            // 1. 设置按钮 (飞行外观定制)
            Stack({ alignContent: Alignment.Center }) {
              Image(this.isTerrainMode() ? $r('app.media.ic_settings_dark') : $r('app.media.ic_settings_white'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onOpenSettings();
            })

            // 极细微透分割线 1
            Divider()
              .width(22)
              .strokeWidth(0.5)
              .color(this.isTerrainMode() ? 'rgba(0, 0, 0, 0.06)' : 'rgba(255, 255, 255, 0.10)')

            // 2. 🪟 机舱舷窗沉浸专注视角切换
            Stack({ alignContent: Alignment.Center }) {
              Text('🪟')
                .fontSize(16)
            }
            .width(40)
            .height(40)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onToggleWindowView();
            })

            // 极细微透分割线 2
            Divider()
              .width(22)
              .strokeWidth(0.5)
              .color(this.isTerrainMode() ? 'rgba(0, 0, 0, 0.06)' : 'rgba(255, 255, 255, 0.10)')

            // 3. 地图图层/层级切换 (标准矢量 / 卫星遥感)
            Stack({ alignContent: Alignment.Center }) {
              Image(this.isTerrainMode() ? $r('app.media.ic_map_layers') : $r('app.media.ic_map_layers_white'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onToggleMapType();
            })

            // 极细微透分割线 3
            Divider()
              .width(22)
              .strokeWidth(0.5)
              .color(this.isTerrainMode() ? 'rgba(0, 0, 0, 0.06)' : 'rgba(255, 255, 255, 0.10)')

            // 4. 视角跟随/定位锁定切换 (Heading-Up 航向朝上)
            Stack({ alignContent: Alignment.Center }) {
              Image(this.isCameraFollowLocked ? $r('app.media.ic_location_cyan') : (this.isTerrainMode() ? $r('app.media.ic_location_dark') : $r('app.media.ic_location_white')))
                .width(16)
                .height(16)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onToggleCameraFollow();
            })
          }
          .width(40)
          .borderRadius(20)
          .backgroundColor(this.isTerrainMode() ? 'rgba(255, 255, 255, 0.90)' : 'rgba(0, 0, 0, 0.50)')
          .backdropBlur(25)
          .border({
            width: 0.8,
            color: this.isTerrainMode() ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.16)',
            radius: 20
          })
          .shadow({
            radius: 10,
            color: this.isTerrainMode() ? 'rgba(0, 0, 0, 0.08)' : 'rgba(0, 0, 0, 0.25)',
            offsetY: 2
          })
          .opacity(this.isMapControlsVisible ? 1.0 : 0.0)
          .translate({ y: this.isMapControlsVisible ? 0 : -14 })
          .animation({ duration: 600, curve: Curve.EaseOut })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 52 })
        .alignItems(VerticalAlign.Top)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(200)
      }

      // 2. 飞行地图界面底部黑色透明渐变遮罩 (自上而下平滑过渡，增强底部信息对比度)
      Column()
        .width('100%')
        .height(200)
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(0, 0, 0, 0.0)', 0.0],
            ['rgba(0, 0, 0, 0.25)', 0.40],
            ['rgba(0, 0, 0, 0.65)', 1.0]
          ]
        })
        .opacity(this.isMapControlsVisible ? 1.0 : 0.0)
        .animation({ duration: 600, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.None)
        .zIndex(150)

      // 3. 飞行地图界面底部：气流扰动纯文字广播 (独立浮现于「专注任务名称」正上方，常规字重，绝不引起下方组件跳动)
      if (this.isTurbulenceAlertVisible) {
        Text(this.turbulenceMessageText)
          .fontSize(12)
          .fontWeight(FontWeight.Normal)
          .fontColor(this.isTerrainMode() ? '#334155' : 'rgba(255, 255, 255, 0.90)')
          .textShadow({ radius: 6, color: 'rgba(0, 0, 0, 0.60)', offsetY: 1 })
          .padding({ left: 22, right: 22 })
          .margin({ bottom: 88 })
          .opacity(this.isMapControlsVisible ? 1.0 : 0.0)
          .hitTestBehavior(HitTestMode.None)
          .zIndex(165)
          .transition(
            TransitionEffect.asymmetric(
              // 入场：由下方 +8vp 处轻柔滑入并淡入
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: 8 }))
                .animation({ duration: 380, curve: Curve.EaseOut }),
              // 出场：向空中向上轻盈消散淡出，极为自然从容
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: -6 }))
                .animation({ duration: 420, curve: Curve.EaseIn })
            )
          )
      }

      // 4. 飞行地图界面底部：专注类型与时间倒计时 (底座稳固，绝对零抖动)
      Row() {
        // 左下角：当前专注类型 (纯粹通透大字标签，行高精确统一)
        Text(this.currentFocusTagTitle)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .animation({ duration: 400, curve: Curve.EaseInOut })
          .fontFamily('sans-serif')
          .lineHeight(38)
          .height(38)

        Blank()

        // 右下角：纯数字大号倒计时 (行高精确统一，上下完美居中对齐)
        Text(this.remainingTimeString)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .animation({ duration: 400, curve: Curve.EaseInOut })
          .fontFamily('monospace')
          .lineHeight(38)
          .height(38)
      }
      .width('100%')
      .height(38)
      .padding({ left: 22, right: 22 })
      .margin({ bottom: 44 })
      .alignItems(VerticalAlign.Center)
      .opacity(this.isMapControlsVisible ? 1.0 : 0.0)
      .translate({ y: this.isMapControlsVisible ? 0 : 28 })
      .animation({ duration: 700, curve: Curve.FastOutSlowIn })
      .hitTestBehavior(HitTestMode.None)
      .zIndex(160)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
