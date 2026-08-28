/**
 * HomeFocusPanel.ets
 * 首页底部专注沉浸面板 (Start Flight 暖珊瑚红/高定暖阳流光主按钮、行程信息与底部导航)
 */

import { router, promptAction } from '@kit.ArkUI';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { PassportStatsView } from './PassportStatsView'
import { FlightPassportFullReport } from './FlightPassportFullReport';
import { DestinationSelectDialog } from './DestinationSelectDialog';
import { FlightMapSelectOverlay } from './FlightMapSelectOverlay';

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
  @StorageLink('userMemberTier') userMemberTier: string = 'free';
  @State routeDistanceKm: number = 0;
  
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
  
  onStartFlight?: (minutes?: number, dest?: Airport) => void;
  onShowTopToast?: (msg: string) => void;

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
    // ✈️ 从停机坪进入地图：底部向上平滑滑入 + 柔和通透遮罩过渡
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
      const defaultDest = findAirportByCode('PEK');
      if (defaultDest) {
        this.selectedDestination = defaultDest;
        this.calculateRouteDistance(defaultDest);
      }
    }
  }

  private onDestinationChange(): void {
    if (this.selectedDestination) {
      this.calculateRouteDistance(this.selectedDestination);
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

  build() {
    Column() {
      // 1. Start Flight 主按钮 (经典纯粹暖珊瑚红，100% 契合温暖机坪氛围)
      Button() {
        Row({ space: 8 }) {
          Text(this.isFlightInProgress ? '飞行中...' : '开始飞行')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(1)
        }
      }
      .width('86%')
      .height(52)
      .backgroundColor('#FA6B56')
      .borderRadius(26)
      .shadow({ radius: 16, color: 'rgba(250, 107, 86, 0.35)', offsetY: 6 })
      .onClick(() => {
        this.handleStartFlightClick();
      })

      // 2. 次级轻量化航线指示器
      Row({ space: 6 }) {
        Text('成都')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#475569')

        Image($r('app.media.ic_airport'))
          .width(12)
          .height(12)
          .fillColor('#FA6B56')

        Text(this.selectedDestination ? this.selectedDestination.city : '选择目的地')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedDestination ? '#1E293B' : '#FA6B56')

        if (this.selectedDestination) {
          Text('•')
            .fontSize(12)
            .fontColor('#CBD5E1')

          Text(`${this.routeDistanceKm}km`)
            .fontSize(12)
            .fontColor('#64748B')
        }

        Image($r('app.media.ic_chevron'))
          .width(10)
          .height(10)
          .fillColor(this.selectedDestination ? '#94A3B8' : '#FA6B56')
          .margin({ left: 1 })
      }
      .height(34)
      .padding({ left: 14, right: 12, top: 6, bottom: 6 })
      .backgroundColor('rgba(255, 255, 255, 0.65)')
      .border({
        width: 1,
        color: this.selectedDestination ? 'rgba(0, 0, 0, 0.06)' : 'rgba(250, 107, 86, 0.22)',
        radius: 17
      })
      .borderRadius(17)
      .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.05)', offsetY: 2 })
      .margin({ top: 12, bottom: 18 })
      .onClick(() => {
        this.destinationDialogController.open();
      })

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

  private handleStartFlightClick(): void {
    if (!this.selectedDestination) {
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
      AppStorage.setOrCreate('selectedDestinationAirport', this.selectedDestination);
      AppStorage.setOrCreate('selectedDestinationCode', this.selectedDestination.code);
      this.onStartFlight(this.timerMinutes, this.selectedDestination);
    }
  }
}
