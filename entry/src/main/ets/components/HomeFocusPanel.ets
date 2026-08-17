/**
 * HomeFocusPanel.ets
 * 首页底部专注沉浸面板 (Start Flight 暖珊瑚红按钮、行程信息与底部导航)
 */

import { router, promptAction } from '@kit.ArkUI';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { DestinationSelectDialog } from './DestinationSelectDialog';
import { FlightMapSelectOverlay } from './FlightMapSelectOverlay';

@Component
export struct HomeFocusPanel {
  @State selectedTab: number = 0;
  @State timerMinutes: number = 15;
  @Prop isFlightInProgress: boolean = false;
  @Watch('onDestinationChange') @StorageLink('selectedDestinationAirport') selectedDestination?: Airport = undefined;
  @State routeDistanceKm: number = 0;
  
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
    maskColor: 'rgba(26, 38, 59, 0.90)',
    customStyle: true
  });

  aboutToAppear() {
    this.calculateRouteDistance(this.selectedDestination);
  }

  onDestinationChange() {
    this.calculateRouteDistance(this.selectedDestination);
  }

  private calculateRouteDistance(destAirport?: Airport) {
    if (!destAirport) {
      this.routeDistanceKm = 0;
      return;
    }
    try {
      const origin = findAirportByCode('CTU');
      if (origin && destAirport.lat !== undefined && destAirport.lon !== undefined) {
        const lat1 = Number(origin.lat);
        const lon1 = Number(origin.lon);
        const lat2 = Number(destAirport.lat);
        const lon2 = Number(destAirport.lon);
        if (!isNaN(lat1) && !isNaN(lon1) && !isNaN(lat2) && !isNaN(lon2)) {
          const dist = getDistanceKm(lat1, lon1, lat2, lon2);
          if (!isNaN(dist) && dist > 0) {
            this.routeDistanceKm = dist;
            return;
          }
        }
      }
    } catch (e) {
      // fallback
    }
    this.routeDistanceKm = 0;
  }

  build() {
    Column() {
      // 1. Start Flight 暖珊瑚红主按钮 (绝对核心 CTA)
      Button() {
        Row({ space: 8 }) {
          Text(this.isFlightInProgress ? '飞行中...' : '开始飞行')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .width('82%')
      .height(52)
      .backgroundColor('#FA6B56')
      .borderRadius(26)
      .shadow({ radius: 16, color: 'rgba(250, 107, 86, 0.35)', offsetY: 6 })
      .onClick(() => {
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
      })

      // 2. 次级轻量化航线指示器 (低调半透明温润胶囊，不与主按钮争夺焦点)
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
      .border({ width: 1, color: this.selectedDestination ? 'rgba(0, 0, 0, 0.06)' : 'rgba(250, 107, 86, 0.22)', radius: 17 })
      .borderRadius(17)
      .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.03)', offsetY: 2 })
      .margin({ top: 12, bottom: 18 })
      .onClick(() => {
        this.destinationDialogController.open();
      })

      // 3. 底部三图标导航栏
      Row() {
        // Tab 0: 首页 (Home)
        Column({ space: 4 }) {
          Image($r('app.media.ic_airport'))
            .width(22)
            .height(22)
            .fillColor(this.selectedTab === 0 ? '#1E293B' : '#94A3B8')
          
          Circle({ width: 5, height: 5 })
            .fill('#FA6B56')
            .opacity(this.selectedTab === 0 ? 1 : 0)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.selectedTab = 0; })

        // Tab 1: 历史 / 日志 (Clock)
        Column({ space: 4 }) {
          Image($r('app.media.ic_logbook'))
            .width(22)
            .height(22)
            .fillColor(this.selectedTab === 1 ? '#1E293B' : '#94A3B8')

          Circle({ width: 5, height: 5 })
            .fill('#FA6B56')
            .opacity(this.selectedTab === 1 ? 1 : 0)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.selectedTab = 1; })

        // Tab 2: 个人 / 机库 (Profile)
        Column({ space: 4 }) {
          Image($r('app.media.ic_hangar'))
            .width(22)
            .height(22)
            .fillColor(this.selectedTab === 2 ? '#1E293B' : '#94A3B8')

          Circle({ width: 5, height: 5 })
            .fill('#FA6B56')
            .opacity(this.selectedTab === 2 ? 1 : 0)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.selectedTab = 2; })
      }
      .width('100%')
      .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .padding({ top: 20, bottom: 20 })
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
}
