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
export struct FlightAbortConfirmDialog {
  @Prop isVisible: boolean = false;
  public onCancel: () => void = () => {};
  public onConfirmAbort: () => void = () => {};

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        // 全屏深色毛玻璃遮罩 (点击空白处安全关闭弹窗)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.55)')
          .backdropBlur(25)
          .onClick(() => {
            console.info('[FlightAbortConfirmDialog] Mask background clicked');
            this.onCancel();
          })

        // 核心极简纯净对话框卡片 (KISS 原则：无多余装饰，聚焦核心信息)
        Column({ space: 14 }) {
          // 1. 标题
          Text('确定提前备降返航？')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .fontFamily('sans-serif')
            .margin({ top: 4 })

          // 2. 说明文案
          Text('当前专注飞行仍在进行中。若现在返航，本趟航班将就近备降终止，本次专注也将判定为未完成。')
            .fontSize(14)
            .fontColor('#475569')
            .lineHeight(22)
            .textAlign(TextAlign.Center)
            .padding({ left: 6, right: 6 })

          // 3. 底部双操作按钮组 (采用原生 Button 组件，确保 100% 灵敏响应)
          Row({ space: 12 }) {
            // 次级按钮：确认返航
            Button('确认返航')
              .type(ButtonType.Capsule)
              .fontSize(14.5)
              .fontWeight(FontWeight.Medium)
              .fontColor('#64748B')
              .backgroundColor('#F1F5F9')
              .border({ width: 1, color: '#E2E8F0', radius: 22 })
              .layoutWeight(1)
              .height(44)
              .onClick(() => {
                console.info('[FlightAbortConfirmDialog] Button 确认返航 clicked!');
                this.onConfirmAbort();
              })

            // 主按钮：继续专注
            Button('继续专注')
              .type(ButtonType.Capsule)
              .fontSize(14.5)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .linearGradient({
                angle: 135,
                colors: [['#F97316', 0.0], ['#FB923C', 1.0]]
              })
              .shadow({ radius: 12, color: 'rgba(249, 115, 22, 0.3)', offsetY: 3 })
              .layoutWeight(1.2)
              .height(44)
              .onClick(() => {
                console.info('[FlightAbortConfirmDialog] Button 继续专注 clicked!');
                this.onCancel();
              })
          }
          .width('100%')
          .padding({ top: 10 })
        }
        .width(300)
        .padding({ left: 22, right: 22, top: 22, bottom: 20 })
        .backgroundColor('rgba(255, 255, 255, 0.98)')
        .border({ width: 1.5, color: '#FFFFFF', radius: 24 })
        .borderRadius(24)
        .shadow({ radius: 35, color: 'rgba(15, 23, 42, 0.22)', offsetY: 12 })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
  }
}
