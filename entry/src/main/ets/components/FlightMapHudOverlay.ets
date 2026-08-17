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

@Component
export struct FlightMapHudOverlay {
  @Prop isMapBackgroundVisible: boolean = false;
  @Prop isCabinExposed: boolean = false;
  @Prop isCameraFollowLocked: boolean = true;
  @Prop currentFocusTagTitle: string = '深度学习';
  @Prop remainingTimeString: string = '45:00';

  public onOpenSettings: () => void = () => {};
  public onToggleMapType: () => void = () => {};
  public onToggleCameraFollow: () => void = () => {};
  public onExitFlight: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 1. 顶部控制工具栏 (仅在客舱透视或地图飞行模式下呈现)
      if (this.isCabinExposed || (this.isMapBackgroundVisible && !this.isCabinExposed)) {
        Row() {
          // 1.1 左侧：返回退出飞行按钮 (HitTestMode.Block 确保精准拦截点击)
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.ic_hw_back_white'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor('rgba(15, 23, 42, 0.45)')
          .backdropBlur(25)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
          .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.onExitFlight();
          })

          Blank()

          // 1.2 右侧：地图模式专属控制组 (垂直竖排：设置 -> 层级 -> 定位)
          if (this.isMapBackgroundVisible && !this.isCabinExposed) {
            Column({ space: 12 }) {
              // 1. 设置按钮 (超清透水晶圆钮 + 纯白极简细线齿轮设置图标)
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.ic_settings_white'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
              }
              .width(38)
              .height(38)
              .borderRadius(19)
              .backgroundColor('rgba(15, 23, 42, 0.45)')
              .backdropBlur(25)
              .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
              .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                this.onOpenSettings();
              })

              // 2. 地图图层/层级切换 (超清透水晶圆钮 + 纯白极简细线图层图标)
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.ic_map_layers_white'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
              }
              .width(38)
              .height(38)
              .borderRadius(19)
              .backgroundColor('rgba(15, 23, 42, 0.45)')
              .backdropBlur(25)
              .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
              .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                this.onToggleMapType();
              })

              // 3. 视角跟随/定位锁定切换 (超清透水晶圆钮 + 纯白/青蓝航空罗盘指针)
              Stack({ alignContent: Alignment.Center }) {
                Image(this.isCameraFollowLocked ? $r('app.media.ic_location_cyan') : $r('app.media.ic_location_white'))
                  .width(15)
                  .height(15)
                  .objectFit(ImageFit.Contain)
              }
              .width(38)
              .height(38)
              .borderRadius(19)
              .backgroundColor('rgba(15, 23, 42, 0.45)')
              .backdropBlur(25)
              .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
              .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                this.onToggleCameraFollow();
              })
            }
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 52 })
        .alignItems(VerticalAlign.Top)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(200)
      }

      // 2. 飞行地图界面底部黑色透明渐变遮罩 (自上而下平滑过渡，增强底部信息对比度)
      if (this.isMapBackgroundVisible && !this.isCabinExposed) {
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
          .hitTestBehavior(HitTestMode.None)
          .zIndex(150)
      }

      // 3. 飞行地图界面底部：极致纯净透明悬浮信息排布 (微调至44vp，极致紧凑贴近花瓣地图上方，零多余空隙)
      if (this.isMapBackgroundVisible && !this.isCabinExposed) {
        Row() {
          // 左下角：当前专注类型 (纯粹通透大字标签，行高精确统一)
          Text(this.currentFocusTagTitle)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('sans-serif')
            .lineHeight(38)
            .height(38)

          Blank()

          // 右下角：纯数字大号倒计时 (行高精确统一，上下完美居中对齐)
          Text(this.remainingTimeString)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .lineHeight(38)
            .height(38)
        }
        .width('100%')
        .height(38)
        .padding({ left: 22, right: 22 })
        .margin({ bottom: 44 })
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.None)
        .zIndex(160)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
