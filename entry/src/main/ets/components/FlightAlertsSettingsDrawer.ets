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
import { common, Want } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CloseButton } from './CloseButton';

/**
 * ✈️ 我的专注提醒 独立抽屉弹窗 (1:1 像素级还原 Flighty My Flight Alerts 规范)
 */
@Component
export struct FlightAlertsSettingsDrawer {
  onClose?: () => void;

  @StorageLink('isProPaywallVisible') isProPaywallVisible: boolean = false;
  @StorageLink('alertBasics') alertBasics: boolean = true;
  @StorageLink('alertApproach') alertApproach: boolean = true;
  @StorageLink('alertMilestone') alertMilestone: boolean = true;
  @StorageLink('alertArrival') alertArrival: boolean = true;
  @StorageLink('liveViewEnabled') liveViewEnabled: boolean = true;
  @StorageLink('alertHapticEnabled') alertHapticEnabled: boolean = true;

  private showToast(msg: string): void {
    try {
      promptAction.showToast({
        message: msg,
        duration: 1800
      });
    } catch (e) { }
  }

  /**
   * 📲 核心：直接唤起鸿蒙系统「通知和状态栏」及本应用的系统通知管理设置页
   */
  private openSystemNotificationSettings(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      // 1. 优先尝试通过 Want 拉起系统设置中本应用的通知与横幅管理页
      let want: Want = {
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'application_info_entry',
        parameters: {
          pushParams: 'com.example.focus_flight_ohos'
        }
      };
      context.startAbility(want).catch((err: BusinessError) => {
        // 2. 备选：请求系统通知权限弹窗
        notificationManager.requestEnableNotification(context).then(() => {
          this.showToast('系统通知权限已开启');
        }).catch(() => {
          // 3. 降级：拉起系统通用设置
          let fallbackWant: Want = {
            bundleName: 'com.huawei.hmos.settings',
            abilityName: 'com.huawei.hmos.settings.MainAbility'
          };
          context.startAbility(fallbackWant).catch(() => {});
        });
      });
    } catch (e) {
      this.showToast('正在打开系统通知设置...');
    }
  }

  build() {
    Column() {
      // 1. 顶部 Header: 大标题 "我的专注提醒" + 水平对齐右侧 CloseButton
      Row() {
        Column({ space: 4 }) {
          Text('我的专注提醒')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('自定义专注飞行期间接收的各项系统通知与阶段提醒。')
            .fontSize(12.5)
            .fontColor('#64748B')
            .lineHeight(16)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding({ right: 12 })

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
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Top)

      Scroll() {
        Column({ space: 16 }) {
          // 2. 👑 PRO 权益卡片 (参考原版设计)
          Row() {
            Row() {
              Text('PRO')
                .fontSize(10)
                .fontWeight(FontWeight.Bolder)
                .fontColor('#7C3AED')
            }
            .padding({ left: 6, right: 6, top: 2.5, bottom: 2.5 })
            .backgroundColor('rgba(124, 58, 237, 0.12)')
            .borderRadius(4)
            .margin({ right: 10 })

            Text('获取全航程准点进近与阶段动态提醒...')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#7C3AED')
              .layoutWeight(1)

            Text('›')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#A78BFA')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          .backgroundColor('rgba(124, 58, 237, 0.04)')
          .borderRadius(14)
          .border({ width: 1, color: 'rgba(124, 58, 237, 0.15)' })
          .onClick(() => {
            this.isProPaywallVisible = true;
          })

          // 3. 系统通知与横幅管理组 (SYSTEM NOTIFICATIONS)
          this.buildSectionTitle('系统通知与横幅权限')
          Column({ space: 10 }) {
            // 3.1 跳转系统通知和状态栏设置项
            Row() {
              Row({ space: 14 }) {
                Row() {
                  Image($r('app.media.ic_set_feedback'))
                    .width(17)
                    .height(17)
                    .fillColor('#FFFFFF')
                }
                .width(30)
                .height(30)
                .borderRadius(8)
                .backgroundColor('#EF4444')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ top: 2 })

                Column({ space: 4 }) {
                  Text('系统通知与横幅提醒')
                    .fontSize(15.5)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')

                  Text('管理应用在状态栏、锁屏及横幅的推送权限与声音提示。')
                    .fontSize(12)
                    .fontColor('#64748B')
                    .lineHeight(16)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .alignItems(VerticalAlign.Top)
              .layoutWeight(1)
              .padding({ right: 8 })

              // 右侧去设置胶囊按钮
              Row() {
                Text('去设置')
                  .fontSize(12.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#3B82F6')

                Text('›')
                  .fontSize(16)
                  .fontWeight(FontWeight.Normal)
                  .fontColor('#3B82F6')
                  .margin({ left: 2 })
              }
              .padding({ left: 10, right: 8, top: 6, bottom: 6 })
              .backgroundColor('rgba(59, 130, 246, 0.08)')
              .borderRadius(12)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .backgroundColor('#F8FAFC')
            .borderRadius(16)
            .border({ width: 1, color: '#F1F5F9' })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.openSystemNotificationSettings();
            })

            // 3.2 实况窗与灵动胶囊
            this.buildAlertCard(
              $r('app.media.ic_set_capsule'),
              '#8B5CF6',
              '灵动胶囊 / 实况窗',
              '在手机状态栏、灭屏常显 AOD 和锁屏胶囊中实时同步专注剩余时间。',
              this.liveViewEnabled,
              (isOn: boolean) => {
                this.liveViewEnabled = isOn;
                this.showToast(isOn ? '已开启实况窗动态同步' : '已关闭实况窗同步');
              }
            )
          }
          .width('100%')

          // 4. 航程阶段提醒 (FLIGHT PHASE ALERTS)
          this.buildSectionTitle('航程阶段提醒')
          Column({ space: 10 }) {
            // 4.1 基础起降提醒 (Basics)
            this.buildAlertCard(
              $r('app.media.ic_set_flights'),
              '#3B82F6',
              '基础起降提醒',
              '起飞就绪确认、进入平稳巡航与顺利降落通关核心提醒。',
              this.alertBasics,
              (isOn: boolean) => {
                this.alertBasics = isOn;
                this.showToast(isOn ? '已开启基础起降提醒' : '已关闭基础起降提醒');
              }
            )

            // 4.2 进近与收尾提醒 (Above & Beyond)
            this.buildAlertCard(
              $r('app.media.ic_set_sparkle'),
              '#10B981',
              '进近与收尾提醒',
              '航程最后 5 分钟发出准备进近提醒，助您从容收拢思绪并完成手头任务。',
              this.alertApproach,
              (isOn: boolean) => {
                this.alertApproach = isOn;
                this.showToast(isOn ? '已开启进近与收尾提醒' : '已关闭进近与收尾提醒');
              }
            )

            // 4.3 心流里程碑脉冲 (Milestones)
            this.buildAlertCard(
              $r('app.media.ic_set_schedule'),
              '#8B5CF6',
              '心流里程碑脉冲',
              '专注达到 50% 与 80% 进度时发送轻柔震动与正向激励，强化专注成就感。',
              this.alertMilestone,
              (isOn: boolean) => {
                this.alertMilestone = isOn;
                this.showToast(isOn ? '已开启心流里程碑提醒' : '已关闭心流里程碑提醒');
              }
            )

            // 4.4 落地通关与登机牌归档 (Arrival Information)
            this.buildAlertCard(
              $r('app.media.ic_checkin_gate'),
              '#F59E0B',
              '落地通关与登机牌归档',
              '完成专注时即刻推送通关登机牌结算通知，自动累加飞行里程与护照印章。',
              this.alertArrival,
              (isOn: boolean) => {
                this.alertArrival = isOn;
                this.showToast(isOn ? '已开启落地通关归档提醒' : '已关闭落地通关归档提醒');
              }
            )
          }
          .width('100%')

          // 5. 提示反馈偏好 (FEEDBACK PREFERENCES)
          this.buildSectionTitle('提醒方式')
          Column({ space: 10 }) {
            this.buildAlertCard(
              $r('app.media.ic_set_watch'),
              '#06B6D4',
              '触感震动与提示音',
              '到达阶段节点时以轻柔低频触感反馈提示，不打断沉浸心流。',
              this.alertHapticEnabled,
              (isOn: boolean) => {
                this.alertHapticEnabled = isOn;
                this.showToast(isOn ? '已开启触感震动反馈' : '已关闭触感震动反馈');
              }
            )
          }
          .width('100%')
          .padding({ bottom: 48 })
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // 小节标题
  @Builder
  private buildSectionTitle(title: string) {
    Row() {
      Text(title)
        .fontSize(12.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#64748B')
    }
    .width('100%')
    .padding({ top: 8, bottom: 2 })
    .alignItems(VerticalAlign.Center)
  }

  // 🔔 提醒单项卡片组件 (图标底座 + 标题描述 + Toggle 开关)
  @Builder
  private buildAlertCard(
    iconRes: Resource,
    bgColor: string,
    title: string,
    description: string,
    isOn: boolean,
    onToggle: (val: boolean) => void
  ) {
    Row() {
      // 左侧图标 + 文字 Column
      Row({ space: 14 }) {
        // 彩色圆角图标底座
        Row() {
          Image(iconRes)
            .width(17)
            .height(17)
            .fillColor('#FFFFFF')
        }
        .width(30)
        .height(30)
        .borderRadius(8)
        .backgroundColor(bgColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 2 })

        // 标题 + 详细描述
        Column({ space: 4 }) {
          Text(title)
            .fontSize(15.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text(description)
            .fontSize(12)
            .fontColor('#64748B')
            .lineHeight(16)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .layoutWeight(1)
      .padding({ right: 12 })

      // 右侧 Toggle 开关
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#10B981')
        .switchPointColor('#FFFFFF')
        .onChange((val: boolean) => {
          onToggle(val);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#F8FAFC')
    .borderRadius(16)
    .border({ width: 1, color: '#F1F5F9' })
    .alignItems(VerticalAlign.Center)
  }
}
