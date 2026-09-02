/**
 * HomeFocusPanel.ets
 * 首页底部专注沉浸面板 (Start Flight 暖珊瑚红/高定暖阳流光主按钮、行程信息与底部导航)
 */

import { router, promptAction } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { PassportStatsView } from './PassportStatsView'
import { FlightPassportFullReport } from './FlightPassportFullReport';
import { DestinationSelectDialog } from './DestinationSelectDialog';
import { FlightMapSelectOverlay } from './FlightMapSelectOverlay';
import { FocusTagSelectDialog } from './FocusTagSelectDialog';
import { FocusTagItem } from '../models/FocusTagModel';

@Component
export struct HomeFocusPanel {
  @State selectedTab: number = 0;
  @State timerMinutes: number = 45;
  @Watch('onStatsSheetChange') @StorageLink('isStatsSheetVisible') isStatsSheetVisible: boolean = false;
  @Watch('onSettingsSheetChange') @StorageLink('isSettingsSheetVisible') isSettingsSheetVisible: boolean = false;
  @StorageLink('isBookFlightSheetVisible') isBookFlightSheetVisible: boolean = false;
  @StorageLink('isFullReportVisible') isFullReportVisible: boolean = false;
  @Prop isFlightInProgress: boolean = false;
  @Watch('onDestinationChange') @StorageLink('selectedDestinationAirport') selectedDestination?: Airport = undefined;
  
  @StorageLink('userMemberTier') userMemberTier: string = 'standard';
  @State shadowAlpha: number = 0.4;
  
  // Focus Tag StorageLinks
  @StorageLink('currentFocusTagId') currentFocusTagId: string = 'study';
  @StorageLink('currentFocusTagTitle') currentFocusTagTitle: string = '深度学习';
  @StorageLink('currentFocusTagIcon') currentFocusTagIcon: string = '📚';
  @StorageLink('currentFocusTagColor') currentFocusTagColor: string = '#F06553';
  @StorageLink('currentFocusTagBg') currentFocusTagBg: string = '#FFF5F3';
  
  @State isTagPressed: boolean = false;
  @State isRoutePressed: boolean = false;
  @State routeDistanceKm: number = 0;
  
  // 水波纹扩散动效状态
  @State rippleX: number = 0;
  @State rippleY: number = 0;
  @State rippleScale: number = 0;
  @State rippleOpacity: number = 0;
  @State isRippling: boolean = false;
  @State isBtnPressed: boolean = false;
  private isClickLocked: boolean = false;
  
  onStatsSheetChange(): void {
    if (!this.isStatsSheetVisible && this.selectedTab === 1) {
      this.selectedTab = 0;
    }
  }

  onSettingsSheetChange(): void {
    if (!this.isSettingsSheetVisible && this.selectedTab === 2) {
      this.selectedTab = 0;
    }
  }
  
  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 15
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }
  
  onStartFlight?: (minutes?: number, dest?: Airport, isRoaming?: boolean) => void;
  onShowTopToast?: (msg: string) => void;

  tagDialogController: CustomDialogController = new CustomDialogController({
    builder: FocusTagSelectDialog({
      currentTagId: this.currentFocusTagId,
      onTagSelected: (tag: FocusTagItem) => {
        this.currentFocusTagId = tag.id;
        this.currentFocusTagTitle = tag.title;
        this.currentFocusTagIcon = tag.icon;
        this.currentFocusTagColor = tag.color;
        this.currentFocusTagBg = tag.bg;
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(0, 0, 0, 0.4)',
    customStyle: true,
    openAnimation: {
      duration: 300,
      curve: Curve.Friction,
      playMode: PlayMode.Normal
    }
  });

  destinationDialogController: CustomDialogController = new CustomDialogController({
    builder: FlightMapSelectOverlay({
      selectedCode: this.selectedDestination ? this.selectedDestination.code : '',
      initialMinutes: this.timerMinutes,
      onDestinationSelected: (airport: Airport, minutes?: number) => {
        this.selectedDestination = airport;
        AppStorage.setOrCreate('selectedDestinationAirport', airport);
        AppStorage.setOrCreate('selectedDestinationCode', airport.code);
        this.calculateRouteDistance(airport);
        if (minutes && minutes > 0) {
          this.timerMinutes = minutes;
        }
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(0, 0, 0, 0)',
    customStyle: true,
    openAnimation: {
      duration: 360,
      curve: Curve.FastOutSlowIn,
      playMode: PlayMode.Normal
    }
  });

  aboutToAppear(): void {
    const cached = AppStorage.get<Airport>('selectedDestinationAirport');
    if (cached) {
      this.selectedDestination = cached;
      this.calculateRouteDistance(cached);
    } else {
      this.selectedDestination = undefined;
      this.routeDistanceKm = 0;
    }
  }

  private onDestinationChange(): void {
    if (this.selectedDestination) {
      this.calculateRouteDistance(this.selectedDestination);
    } else {
      this.routeDistanceKm = 0;
    }
  }

  private calculateRouteDistance(dest: Airport): void {
    const origin = findAirportByCode('CTU');
    if (origin && dest) {
      const oLat = Number(origin.lat);
      const oLon = Number(origin.lon);
      const dLat = Number(dest.lat);
      const dLon = Number(dest.lon);
      this.routeDistanceKm = getDistanceKm(oLat, oLon, dLat, dLon);
      return;
    }
    this.routeDistanceKm = 0;
  }
  
  private startGradientFlow() {
    if (this.userMemberTier === 'lifetime') {
      let uiCtx = this.getUIContext();
      if (uiCtx) {
        uiCtx.animateTo({
          duration: 3000,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate,
        }, () => {
          this.shadowAlpha = 0.85;
        });
      }
    }
  }

  private getThemeAccentColor(): string {
    return this.userMemberTier === 'lifetime' ? '#9B84EC' : '#FA6B56';
  }

  private triggerRippleAndProceed(isRoaming: boolean): void {
    if (this.isClickLocked) {
      return;
    }
    this.isClickLocked = true;

    // 触感反馈
    this.triggerHaptic();

    // 启动水波纹扩散动效 (以触点为圆心，向全按钮扩散)
    this.isRippling = true;
    this.rippleScale = 0.05;
    this.rippleOpacity = 0.6;

    this.getUIContext()?.animateTo({
      duration: 260,
      curve: Curve.EaseOut
    }, () => {
      this.rippleScale = 1.0;
      this.rippleOpacity = 0;
    });

    // 波纹动效完整结束后 (260ms)，再触发业务逻辑与界面跳转
    setTimeout(() => {
      this.isRippling = false;
      this.isClickLocked = false;
      this.handleStartFlightClick(isRoaming);
    }, 260);
  }

  build() {
    Column() {
      // 1. Start Flight 主按钮 (Stack 分割点击区，内置触点水波纹)
      Stack({ alignContent: Alignment.Center }) {
        // 水波纹扩散层 (位于渐变背景之上、文字交互层之下，以点击触点为圆心)
        if (this.isRippling) {
          Circle({ width: 340, height: 340 })
            .fill('rgba(255, 255, 255, 0.45)')
            .position({
              x: this.rippleX - 170,
              y: this.rippleY - 170
            })
            .scale({ x: this.rippleScale, y: this.rippleScale })
            .opacity(this.rippleOpacity)
            .hitTestBehavior(HitTestMode.None)
            .zIndex(1.5)
        }

        Row() {
          // 左侧主按钮交互区
          Row()
            .layoutWeight(1)
            .height('100%')
            .onClick(() => {
              this.triggerRippleAndProceed(false);
            })

          // 垂直分割线
          Divider()
            .vertical(true)
            .height(20)
            .color('rgba(255, 255, 255, 0.35)')
            .strokeWidth(1)

          // 右侧漫游按钮交互区
          Row() {
            Column({ space: 0 }) {
              Text('∞').fontSize(20).fontColor('#FFFFFF').opacity(0.9)
              Text('漫游').fontSize(9).fontColor('#FFFFFF').opacity(0.8)
            }
            .justifyContent(FlexAlign.Center)
          }
            .width(62)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.triggerRippleAndProceed(true);
            })
        }
        .width('100%')
        .height('100%')
        .zIndex(2)

        // 中间文本绝对居中显示（脱离左右点击热区的布局影响）
        Row() {
          Text(this.isFlightInProgress ? '飞行中...' : '开始飞行')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(1)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.None)
        .zIndex(1)
      }
      .width('86%')
      .height(52)
      .clip(true)
      .scale({ x: this.isBtnPressed ? 0.97 : 1.0, y: this.isBtnPressed ? 0.97 : 1.0 })
      .animation({ duration: 150, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down && e.touches.length > 0) {
          this.rippleX = e.touches[0].x;
          this.rippleY = e.touches[0].y;
          this.isBtnPressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.isBtnPressed = false;
        }
      })
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
      .borderRadius(26)
      .shadow(
        this.userMemberTier === 'lifetime'
          ? { radius: 24, color: `rgba(155, 132, 236, ${this.shadowAlpha})`, offsetY: 8 }
          : { radius: 20, color: `rgba(250, 107, 86, ${this.shadowAlpha * 0.7})`, offsetY: 8 }
      )
      .onAppear(() => {
        this.startGradientFlow();
      })

      // 2. 方案 1：极简通透微磨砂信息栏 (Apple 级轻量高级感，不抢戏、无死白、通透融入地面)
      Row({ space: 0 }) {
        // 2.1 左分区：专注主题
        Row({ space: 5 }) {
          Text(this.currentFocusTagIcon || '📚')
            .fontSize(13)

          Text(this.currentFocusTagTitle || '深度学习')
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor('#334155')

          Text('▾')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#94A3B8')
            .margin({ left: -1 })
        }
        .height('100%')
        .padding({ left: 14, right: 10 })
        .scale({ x: this.isTagPressed ? 0.95 : 1.0, y: this.isTagPressed ? 0.95 : 1.0 })
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.isTagPressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.isTagPressed = false;
          }
        })
        .onClick(() => {
          this.triggerHaptic();
          this.tagDialogController.open();
        })

        // 2.2 极轻微垂直中分割线
        Divider()
          .vertical(true)
          .height(12)
          .color('rgba(0, 0, 0, 0.08)')
          .strokeWidth(1)

        // 2.3 右分区：航线与目的地
        Row({ space: 6 }) {
          Text('成都')
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor('#334155')

          Image($r('app.media.ic_nav_flight'))
            .width(13)
            .height(13)
            .rotate({ angle: 90 })
            .fillColor(this.selectedDestination ? '#94A3B8' : '#FA6B56')

          Text(this.selectedDestination ? this.selectedDestination.city : '选择目的地')
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedDestination ? '#334155' : '#FA6B56')

          if (this.selectedDestination) {
            Text('·')
              .fontSize(12)
              .fontColor('#CBD5E1')
              .fontWeight(FontWeight.Bold)

            Text(`${this.routeDistanceKm}km`)
              .fontSize(11)
              .fontColor('#94A3B8')
              .fontWeight(FontWeight.Regular)
          }

          Image($r('app.media.ic_arrow_right_fine'))
            .width(8)
            .height(8)
            .fillColor(this.selectedDestination ? '#94A3B8' : '#FA6B56')
            .margin({ left: 2 })
        }
        .height('100%')
        .padding({ left: 10, right: 14 })
        .scale({ x: this.isRoutePressed ? 0.95 : 1.0, y: this.isRoutePressed ? 0.95 : 1.0 })
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.isRoutePressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.isRoutePressed = false;
          }
        })
        .onClick(() => {
          this.triggerHaptic();
          this.destinationDialogController.open();
        })
      }
      .height(32)
      .margin({ top: 10, bottom: 20 })
    }
    .width('100%')
    .padding({ top: 20, bottom: 84 })
    .linearGradient({
      angle: 180,
      colors: [
        ['rgba(232, 225, 218, 0.0)', 0.0],
        ['rgba(232, 225, 218, 0.75)', 0.25],
        ['rgba(232, 225, 218, 1.0)', 0.6],
        ['rgba(232, 225, 218, 1.0)', 1.0]
      ]
    })
  }

  private handleStartFlightClick(isRoaming: boolean): void {
    if (!this.selectedDestination && !isRoaming) {
      if (this.onShowTopToast) {
        this.onShowTopToast('✈️ 请先选择您的飞行目的地');
      } else {
        try {
          promptAction.showToast({
            message: '✈️ 请先选择您的飞行目的地',
            duration: 2000
          });
        } catch (e) { }
      }
      this.destinationDialogController.open();
      return;
    }
    if (this.onStartFlight) {
      if (!isRoaming && this.selectedDestination) {
        AppStorage.setOrCreate('selectedDestinationAirport', this.selectedDestination);
        AppStorage.setOrCreate('selectedDestinationCode', this.selectedDestination.code);
        this.onStartFlight(this.timerMinutes, this.selectedDestination, false);
      } else {
        this.onStartFlight(0, undefined, true);
      }
    }
  }
}

