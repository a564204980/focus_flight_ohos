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

/**
 * 专注航行 独立协议抽屉弹窗组件 (服务协议与隐私政策)
 * 具备完整的 350ms FastOutSlowIn 底部上滑展开与回弹收起动效
 */
@Component
export struct AgreementSheetModal {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop agreementType: 'service' | 'privacy' = 'service';
  onClose?: () => void;

  @State private sheetOffset: string = '120%';
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
    this.sheetOffset = '120%';
    this.maskOpacity = 0;
    setTimeout(() => {
      this.getUIContext()?.animateTo({
        duration: 350,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.sheetOffset = '22%';
        this.maskOpacity = 1.0;
      });
    }, 20);
  }

  private animateOut(callback?: () => void): void {
    this.getUIContext()?.animateTo({
      duration: 280,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (callback) {
          callback();
        }
      }
    }, () => {
      this.sheetOffset = '120%';
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 半透明黑色背景遮罩 (淡入淡出动效)
      Rect()
        .width('100%')
        .height('100%')
        .fill('rgba(0, 0, 0, 0.45)')
        .opacity(this.maskOpacity)
        .onClick(() => {
          this.handleClose();
        })

      // 2. 上滑抽屉内容卡片主体 (标准 350ms FastOutSlowIn 从 120% 平滑上滑至 22%)
      Column() {
        // 2.1 顶部手势抓手指示条
        Row() {
          Row()
            .width(36)
            .height(4)
            .backgroundColor('#D1D5DB')
            .borderRadius(2)
        }
        .width('100%')
        .height(18)
        .justifyContent(FlexAlign.Center)

        // 2.2 顶栏：标题与项目通用 CloseButton
        Row() {
          Text(this.agreementType === 'service' ? '用户服务与订阅协议' : '隐私保护政策')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Blank()

          // 项目统一几何绘制 CloseButton 关闭按钮
          CloseButton({
            circleColor: '#F1F5F9',
            iconColor: '#0F172A',
            buttonSize: 32,
            onClickAction: () => {
              this.handleClose();
            }
          })
        }
        .width('100%')
        .padding({ left: 24, right: 20, top: 4, bottom: 12 })
        .border({ width: { bottom: 0.5 }, color: '#E2E8F0' })

        // 2.3 可滚动的协议正文
        Scroll() {
          Column({ space: 14 }) {
            if (this.agreementType === 'service') {
              this.buildServiceAgreementContent()
            } else {
              this.buildPrivacyPolicyContent()
            }
          }
          .padding({ left: 24, right: 24, top: 16, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('78%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 25, color: 'rgba(0, 0, 0, 0.35)', offsetY: -6 })
      .position({ x: 0, y: this.sheetOffset })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1000)
  }

  // 服务协议正文
  @Builder
  private buildServiceAgreementContent() {
    Column({ space: 12 }) {
      Text('【更新及生效日期：2026年8月23日】')
        .fontSize(12)
        .fontColor('#94A3B8')

      Text('欢迎使用「专注航行（Focus Flight）」。在您使用本应用及 PRO 会员服务前，请仔细阅读本协议。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('一、 协议确认与服务说明')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('本应用是一款结合飞行巡航沉浸式体验的专注力与番茄钟时间管理工具。当您点击“立即开启专注之旅”或购买相关会员方案时，即视为您已同意并接受本协议。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('二、 PRO 会员服务与订阅规则')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('1. 会员权益：享有无限飞行架次、沉浸机舱舷窗、机上白噪音、灵动实况窗与小组件、全维度飞行护照统计、3D 航迹复盘等特权。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('2. 方案与计费：月度会员（¥8.00/月）、年度会员（¥48.00/年）、终身机长（¥88.00 一次买断）。订阅款项由应用商店官方支付渠道扣除。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('3. 自动续订与取消：月度/年度会员到期前 24 小时会自动续期。您可随时在「系统设置 → 华为账号 → 付款与账单 → 订阅/自动续费」中取消。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('三、 免责声明与知识产权')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('本应用中所有的机型涂装、UI 设计与机上音频均由我们独立创作并享有知识产权。专注飞行过程中的颠簸判定仅用于仪式感辅助，不作强制设备控制。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 隐私政策正文
  @Builder
  private buildPrivacyPolicyContent() {
    Column({ space: 12 }) {
      Text('【更新及生效日期：2026年8月23日】')
        .fontSize(12)
        .fontColor('#94A3B8')

      Text('专注航行（Focus Flight）高度重视您的隐私保护。本政策向您说明我们如何收集、使用与保护您的信息。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('一、 数据的收集与使用')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('本应用在运行期间记录的专注时长、飞行架次、航线记录、自定义皮肤等数据均优先存储在您的设备本地，我们不会在未经授权的情况下上传您的私人隐私。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('二、 设备权限使用说明')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('1. 通知与实况窗权限：用于在锁屏与灵动胶囊中显示实时航况进度；\n2. 后台持续运行权限：保障您在锁屏或离开当前页面时巡航计时不被中断；\n3. 震动权限：用于气流颠簸或降落时的轻量触感反馈。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)

      Text('三、 数据安全与隐私保障')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('我们采取业界标准的安全措施保护您的本地与同步数据，绝不向任何第三方出售或滥用您的个人信息。')
        .fontSize(13)
        .fontColor('#475569')
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
