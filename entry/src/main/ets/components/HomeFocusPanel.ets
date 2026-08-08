/**
 * HomeFocusPanel.ets
 * 首页底部专注沉浸面板 (包含专注时间交互刻度尺、Start Flight 暖珊瑚红按钮、行程信息与底部导航)
 */

import { router, promptAction } from '@kit.ArkUI';
import { TimeRulerPicker } from './TimeRulerPicker';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { DestinationSelectDialog } from './DestinationSelectDialog';
import { FlightMapSelectOverlay } from './FlightMapSelectOverlay';

@Component
export struct HomeFocusPanel {
  @State selectedTab: number = 0;
  @State timerMinutes: number = 45;
  @State isRunning: boolean = false;
  @State selectedDestination?: Airport = undefined; // 默认不指定目的地，等待用户自主选择
  @State routeDistanceKm: number = 0;
  
  onStartFlight?: (minutes: number) => void;

  destinationDialogController: CustomDialogController = new CustomDialogController({
    builder: FlightMapSelectOverlay({
      selectedCode: this.selectedDestination ? this.selectedDestination.code : '',
      onDestinationSelected: (airport: Airport) => {
        this.selectedDestination = airport;
        this.calculateRouteDistance(airport);
      }
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private calculateRouteDistance(destAirport?: Airport) {
    if (!destAirport) return;
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
  }

  build() {
    Column() {
      // 1. 专注时间交互刻度尺 (绝对居中中轴线指针 + 36vp 醒目大数字)
      TimeRulerPicker({
        timerMinutes: this.timerMinutes,
        onTimeChange: (min: number) => {
          this.timerMinutes = min;
        }
      })

      // 2. 专注时间（分钟）子标题
      Text('专注时间（分钟）')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#64748B')
        .letterSpacing(1)
        .margin({ top: 6, bottom: 14 })

      // 3. Start Flight 暖珊瑚红主按钮 (绝对核心 CTA)
      Button() {
        Row({ space: 8 }) {
          Text(this.isRunning ? '飞行中...' : '开始飞行')
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
          promptAction.showToast({
            message: '✈️ 请先选择您的飞行目的地',
            duration: 2000
          });
          this.destinationDialogController.open();
          return;
        }
        this.isRunning = !this.isRunning;
        if (this.onStartFlight) {
          this.onStartFlight(this.timerMinutes);
        } else {
          promptAction.showToast({
            message: this.isRunning ? '🛫 航班起飞，进入巡航专注！' : '🛬 专注结束，回到停机坪！',
            duration: 1500
          });
        }
      })

      // 4. 次级轻量化航线指示器 (低调半透明温润胶囊，不与主按钮争夺焦点)
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

      // 5. 底部三图标导航栏
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
    .padding({ top: 45, bottom: 20 })
    .linearGradient({
      angle: 180,
      colors: [
        ['rgba(232, 225, 218, 0.0)', 0.0],
        ['rgba(232, 225, 218, 0.0)', 0.18], // 顶部透明区域向下延伸至刻度尺下方
        ['rgba(232, 225, 218, 0.65)', 0.38], // 柔和自然地向下过渡
        ['rgba(232, 225, 218, 0.95)', 0.58], // 按钮区域开始提供清晰的温和背景
        ['rgba(232, 225, 218, 1.0)', 1.0]
      ]
    })
  }
}
