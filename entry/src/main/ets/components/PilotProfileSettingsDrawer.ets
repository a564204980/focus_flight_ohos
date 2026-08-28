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

/**
 * Focus Flight 设置中心 (1:1 像素级还原 Flighty 极简单行 Inset-Grouped 中文设计规范)
 */
@Component
export struct PilotProfileSettingsDrawer {
  onClose?: () => void;

  @StorageLink('isProPaywallVisible') isProPaywallVisible: boolean = false;
  @State liveViewEnabled: boolean = true;
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
      // 1. 顶部 Header: 大标题 "设置" + 水平对齐右侧 CloseButton (与飞行护照抽屉 1:1 一致)
      Row() {
        Text('设置')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')

        Blank()

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
      .padding({ left: 24, right: 24, top: 12, bottom: 14 })

      // 2. 可滚动列表主体
      Scroll() {
        Column() {
          // 2.1 👑 Focus Flight Pro 尊享卡片
          this.buildProBanner()

          // 2.2 飞行提醒
          this.buildSectionHeader('飞行提醒')
          this.buildAlertsGroup()

          // 2.3 系统生态拓展
          this.buildSectionHeader('系统生态拓展')
          this.buildExtensionsGroup()

          // 2.5 个性化定制
          this.buildSectionHeader('个性化定制')
          this.buildCustomizeGroup()

          // 2.6 数据与管理
          this.buildSectionHeader('数据与管理')
          this.buildManageGroup()

          // 2.7 帮助中心
          this.buildSectionHeader('帮助中心')
          this.buildHelpCenterGroup()

          // 2.8 更多
          this.buildSectionHeader('更多')
          this.buildMoreGroup()

          // 2.9 底部治愈小诗
          Column({ space: 6 }) {
            Text('“ 翱翔于专注的天际，静享心流时光 ”')
              .fontSize(12)
              .fontStyle(FontStyle.Italic)
              .fontColor('#94A3B8')

            Text('专注航行 Pro · HarmonyOS NEXT · v1.2.0')
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

        Text('解锁全部高阶功能带来极致用户体验')
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
        .fontSize(12.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#64748B')
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 8 })

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
      this.buildListRow($r('app.media.ic_set_flights'), '#3B82F6', '我的专注提醒', () => {
        AppStorage.setOrCreate('isFlightAlertsSheetVisible', true);
      })
    }
    .width('100%')
  }

  // 2. 系统生态拓展组 (EXTENSIONS)
  @Builder
  private buildExtensionsGroup() {
    Column() {
      this.buildListRow($r('app.media.ic_set_capsule'), '#8B5CF6', '灵动胶囊 / 实况窗', () => {
        this.liveViewEnabled = !this.liveViewEnabled;
        this.showToast(this.liveViewEnabled ? '实况窗已开启' : '实况窗已关闭');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_lockscreen'), '#6366F1', '锁屏与熄屏微件', () => {
        this.lockScreenEnabled = !this.lockScreenEnabled;
        this.showToast(this.lockScreenEnabled ? '锁屏航程微件已启用' : '锁屏微件已停用');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_widget'), '#F59E0B', '桌面万能卡片微件', () => {
        this.showToast('长按手机桌面空白处即可添加 Focus Flight 微件');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_watch'), '#14B8A6', '智能手表抬腕联动', () => {
        this.showToast('智能手表抬腕同步已就绪');
      })
    }
    .width('100%')
  }

  // 4. 个性化定制组 (CUSTOMIZE)
  @Builder
  private buildCustomizeGroup() {
    Column() {
      this.buildListRow($r('app.media.ic_set_paint'), '#EC4899', '应用图标与机身涂装', () => {
        this.showToast('提供经典珊瑚红、夕阳金霞、极夜星空等多款涂装');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_unit'), '#64748B', '航行情报单位', () => {
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
      this.buildListRow($r('app.media.ic_set_import'), '#0EA5E9', '导入历史航行记录', () => {
        this.showToast('支持从外部 CSV 或番茄钟记录导入');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_cloud'), '#2563EB', '账户与云端数据备份', () => {
        this.showToast('已与华为账号云空间完成数据加密同步');
      })
    }
    .width('100%')
  }

  // 6. 帮助中心组 (HELP CENTER)
  @Builder
  private buildHelpCenterGroup() {
    Column() {
      this.buildListRow($r('app.media.ic_set_faq'), '#84CC16', '常见问题与飞行指南', () => {
        this.showToast('航线巡航：设定时长起飞\n舷窗视界：沉浸云海放松\n气流颠簸：离开应用提示');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_feedback'), '#F97316', '向机务团队发送反馈', () => {
        this.showToast('感谢支持！机务团队将不断优化航行体验');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_sparkle'), '#EAB308', '版本新特性', () => {
        this.showToast('新增 60fps 真实客机舷窗平流层视频引擎');
      })
    }
    .width('100%')
  }

  // 7. 更多组 (MORE)
  @Builder
  private buildMoreGroup() {
    Column() {
      this.buildListRow($r('app.media.ic_set_gift'), '#A855F7', '赠送好友 Pro 体验卡', () => {
        this.showToast('已生成好友同行邀请卡');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_club'), '#1E293B', '加入先锋机长俱乐部', () => {
        this.showToast('欢迎加入「专注航行」先锋机长体验计划');
      })
      this.buildInnerDivider()
      this.buildListRow($r('app.media.ic_set_about'), '#475569', '关于 专注航行 Pro', () => {
        this.showToast('专注航行 Pro (Focus Flight Pro) v1.2.0');
      })
    }
    .width('100%')
  }

  // 1:1 极简精致列表项 (圆角多彩底座 + 纯白高清矢量 SVG 图标 + 标题 + [可选右侧标签] + 右箭头)
  @Builder
  private buildListRow(
    iconRes: Resource,
    bgColor: string,
    title: string,
    onClick?: () => void,
    rightValue?: string
  ) {
    Row() {
      // 左侧：iOS / Flighty 顶级圆角微光彩色徽章底座
      Row() {
        Image(iconRes)
          .width(16)
          .height(16)
          .fillColor('#FFFFFF')
      }
      .width(28)
      .height(28)
      .borderRadius(7)
      .backgroundColor(bgColor)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ right: 14 })

      // 中间文本
      Text(title)
        .fontSize(15)
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
        .fontSize(20)
        .fontWeight(FontWeight.Normal)
        .fontColor('#CBD5E1')
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 13, bottom: 13 })
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
