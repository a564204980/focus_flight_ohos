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

/**
 * Focus Flight 设置中心 (1:1 像素级还原 Flighty 极简单行 Inset-Grouped 中文设计规范)
 */
@Component
export struct PilotProfileSettingsDrawer {
  onClose?: () => void;

  @StorageLink('isProPaywallVisible') isProPaywallVisible: boolean = false;
  @State liveViewEnabled: boolean = true;
  @State calendarSyncEnabled: boolean = false;
  @State flightUnit: string = '公里 (km/h, 米)';
  @State lockScreenEnabled: boolean = true;

  private showToast(msg: string): void {
    try {
      promptAction.showToast({
        message: msg,
        duration: 1800
      });
    } catch (e) { }
  }

  build() {
    Column() {
      // 1. 顶部右上角极简关闭按钮 (X)
      Row() {
        Blank()

        Button({ type: ButtonType.Circle }) {
          Text('✕')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
        }
        .width(36)
        .height(36)
        .backgroundColor('#F1F5F9')
        .onClick(() => {
          if (this.onClose) {
            this.onClose();
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 20, top: 12, bottom: 4 })

      // 2. 大标题 "设置"
      Row() {
        Text('设置')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .letterSpacing(-0.5)
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 18 })

      // 3. 可滚动列表主体
      Scroll() {
        Column() {
          // 3.1 👑 Focus Flight Pro 尊享卡片
          this.buildProBanner()

          // 3.2 飞行提醒 (ALERTS)
          this.buildSectionHeader('飞行提醒 · ALERTS')
          this.buildAlertsGroup()

          // 3.3 自动化 (AUTOMATIONS)
          this.buildSectionHeader('自动化 · AUTOMATIONS')
          this.buildAutomationsGroup()

          // 3.4 系统生态拓展 (EXTENSIONS)
          this.buildSectionHeader('系统生态拓展 · EXTENSIONS')
          this.buildExtensionsGroup()

          // 3.5 个性化定制 (CUSTOMIZE)
          this.buildSectionHeader('个性化定制 · CUSTOMIZE')
          this.buildCustomizeGroup()

          // 3.6 数据与管理 (MANAGE)
          this.buildSectionHeader('数据与管理 · MANAGE')
          this.buildManageGroup()

          // 3.7 帮助中心 (HELP CENTER)
          this.buildSectionHeader('帮助中心 · HELP CENTER')
          this.buildHelpCenterGroup()

          // 3.8 更多 (MORE)
          this.buildSectionHeader('更多 · MORE')
          this.buildMoreGroup()

          // 3.9 底部治愈小诗
          Column({ space: 6 }) {
            Text('“ 翱翔于专注的天际，静享心流时光 ”')
              .fontSize(12)
              .fontStyle(FontStyle.Italic)
              .fontColor('#94A3B8')

            Text('专注航行 · HarmonyOS NEXT · v1.2.0')
              .fontSize(10)
              .fontColor('#CBD5E1')
          }
          .width('100%')
          .padding({ top: 32, bottom: 96 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // 👑 PRO Banner (紫色胶囊徽章 + 双行文本 + 箭头)
  @Builder
  private buildProBanner() {
    Row() {
      // PRO 徽章
      Row() {
        Text('PRO')
          .fontSize(11)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#7C3AED')
      }
      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
      .backgroundColor('rgba(124, 58, 237, 0.12)')
      .borderRadius(6)
      .margin({ right: 14 })

      // 文本信息
      Column({ space: 2 }) {
        Text('专注航行 Pro')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6D28D9')

        Text('解锁全部高阶航线与专属机身涂装')
          .fontSize(13)
          .fontColor('#7C3AED')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右箭头
      Text('›')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#A78BFA')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .border({
      width: { top: 1, bottom: 1 },
      color: '#F1F5F9'
    })
    .onClick(() => {
      this.isProPaywallVisible = true;
    })
  }

  // 分组小标题
  @Builder
  private buildSectionHeader(title: string) {
    Column() {
      Text(title)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#64748B')
        .letterSpacing(0.8)
        .width('100%')
        .padding({ left: 24, right: 24, top: 26, bottom: 8 })

      Divider()
        .color('#F1F5F9')
        .strokeWidth(1)
    }
    .width('100%')
  }

  // 1. 飞行提醒组 (ALERTS)
  @Builder
  private buildAlertsGroup() {
    Column() {
      this.buildListRow('🛫', '我的专注航班', () => {
        this.showToast('航班起飞与降落提醒已开启');
      })
      this.buildInnerDivider()
      this.buildListRow('👥', '同行好友动态', () => {
        this.showToast('支持与好友共同登机开启专注');
      })
    }
    .width('100%')
  }

  // 2. 自动化组 (AUTOMATIONS)
  @Builder
  private buildAutomationsGroup() {
    Column() {
      this.buildListRow('📅', '系统日历行程同步', () => {
        this.calendarSyncEnabled = !this.calendarSyncEnabled;
        this.showToast(this.calendarSyncEnabled ? '已开启系统日历同步' : '已关闭日历同步');
      })
      this.buildInnerDivider()
      this.buildListRow('✈️', '行程助手排期联动', () => {
        this.showToast('专注时刻自动排期已就绪');
      })
      this.buildInnerDivider()
      this.buildListRow('✉️', '通过邮件导入计划', () => {
        this.showToast('邮件航班计划解析已启用');
      })
    }
    .width('100%')
  }

  // 3. 系统生态拓展组 (EXTENSIONS)
  @Builder
  private buildExtensionsGroup() {
    Column() {
      this.buildListRow('📱', '灵动胶囊 / 实况窗', () => {
        this.liveViewEnabled = !this.liveViewEnabled;
        this.showToast(this.liveViewEnabled ? '实况窗已开启' : '实况窗已关闭');
      })
      this.buildInnerDivider()
      this.buildListRow('🪟', '锁屏与熄屏微件', () => {
        this.lockScreenEnabled = !this.lockScreenEnabled;
        this.showToast(this.lockScreenEnabled ? '锁屏航程微件已启用' : '锁屏微件已停用');
      })
      this.buildInnerDivider()
      this.buildListRow('📱', '桌面万能卡片微件', () => {
        this.showToast('长按手机桌面空白处即可添加 Focus Flight 微件');
      })
      this.buildInnerDivider()
      this.buildListRow('⌚', '智能手表抬腕联动', () => {
        this.showToast('智能手表抬腕同步已就绪');
      })
    }
    .width('100%')
  }

  // 4. 个性化定制组 (CUSTOMIZE)
  @Builder
  private buildCustomizeGroup() {
    Column() {
      this.buildListRow('🎨', '应用图标与机身涂装', () => {
        this.showToast('提供经典珊瑚红、夕阳金霞、极夜星空等多款涂装');
      })
      this.buildInnerDivider()
      this.buildListRow('📏', '航行情报单位', () => {
        if (this.flightUnit.includes('公里')) {
          this.flightUnit = '航空节 (Knots, 英尺)';
          this.showToast('已切换为航空节单位 (Knots / ft)');
        } else {
          this.flightUnit = '公里 (km/h, 米)';
          this.showToast('已切换为公制单位 (km/h / m)');
        }
      }, this.flightUnit)
    }
    .width('100%')
  }

  // 5. 数据与管理 (MANAGE)
  @Builder
  private buildManageGroup() {
    Column() {
      this.buildListRow('📦', '导入历史航行记录', () => {
        this.showToast('支持从外部 CSV 或番茄钟记录导入');
      })
      this.buildInnerDivider()
      this.buildListRow('👤', '账户与云端数据备份', () => {
        this.showToast('已与华为账号云空间完成数据加密同步');
      })
    }
    .width('100%')
  }

  // 6. 帮助中心组 (HELP CENTER)
  @Builder
  private buildHelpCenterGroup() {
    Column() {
      this.buildListRow('❓', '常见问题与飞行指南', () => {
        this.showToast('航线巡航：设定时长起飞\n舷窗视界：沉浸云海放松\n气流颠簸：离开应用提示');
      })
      this.buildInnerDivider()
      this.buildListRow('📢', '向机务团队发送反馈', () => {
        this.showToast('感谢支持！机务团队将不断优化航行体验');
      })
      this.buildInnerDivider()
      this.buildListRow('✨', '版本新特性', () => {
        this.showToast('新增 60fps 真实客机舷窗平流层视频引擎');
      })
    }
    .width('100%')
  }

  // 7. 更多组 (MORE)
  @Builder
  private buildMoreGroup() {
    Column() {
      this.buildListRow('🎁', '赠送好友 Pro 体验卡', () => {
        this.showToast('已生成好友同行邀请卡');
      })
      this.buildInnerDivider()
      this.buildListRow('✉️', '加入先锋机长俱乐部', () => {
        this.showToast('欢迎加入「专注航行」先锋机长体验计划');
      })
      this.buildInnerDivider()
      this.buildListRow('✈️', '关于 专注航行', () => {
        this.showToast('专注航行 Focus Voyage v1.2.0');
      })
    }
    .width('100%')
  }

  // 1:1 极简列表项 (左图标 + 标题 + [可选右侧标签] + 右箭头)
  @Builder
  private buildListRow(icon: string, title: string, onClick?: () => void, rightValue?: string) {
    Row() {
      // 左侧图标
      Text(icon)
        .fontSize(18)
        .width(28)
        .textAlign(TextAlign.Center)
        .margin({ right: 14 })

      // 中间文本
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F172A')
        .layoutWeight(1)

      // 右侧可选属性值
      if (rightValue) {
        Text(rightValue)
          .fontSize(13)
          .fontColor('#94A3B8')
          .margin({ right: 6 })
      }

      // 右侧浅灰箭头 ›
      Text('›')
        .fontSize(22)
        .fontWeight(FontWeight.Normal)
        .fontColor('#CBD5E1')
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 15, bottom: 15 })
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      if (onClick) {
        onClick();
      }
    })
  }

  // 缩进分割线 (从文本位置开始缩进)
  @Builder
  private buildInnerDivider() {
    Divider()
      .color('#F8FAFC')
      .strokeWidth(1)
      .padding({ left: 66, right: 24 })
  }
}
