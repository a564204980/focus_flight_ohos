/**
 * HomeFocusPanel.ets
 * 首页底部专注沉浸面板 (包含专注时间交互刻度尺、Start Flight 暖珊瑚红按钮、行程信息与底部导航)
 */

import { router, promptAction } from '@kit.ArkUI';
import { TimeRulerPicker } from './TimeRulerPicker';
import { findAirportByCode, getDistanceKm } from '../models/AirportModel';

@Component
export struct HomeFocusPanel {
  @State selectedTab: number = 0;
  @State timerMinutes: number = 45;
  @State isRunning: boolean = false;
  @State routeDistanceKm: number = 1650; // 绝对安全的默认航程状态 (成都➔上海 1650 公里)
  
  onStartFlight?: () => void;

  aboutToAppear() {
    this.calculateRouteDistance();
  }

  // 使用项目真实机场经纬度数据库计算出来的实际大圆航线里程 (KM)
  private calculateRouteDistance() {
    try {
      const origin = findAirportByCode('CTU');
      const dest = findAirportByCode('SHA');
      if (origin && dest && origin.lat !== undefined && dest.lat !== undefined) {
        const lat1 = Number(origin.lat);
        const lon1 = Number(origin.lon);
        const lat2 = Number(dest.lat);
        const lon2 = Number(dest.lon);
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
    this.routeDistanceKm = 1650;
  }

  build() {
    Column() {
      // 1. 专注时间交互刻度尺 (绝对居中中轴线指针 + 36vp 醒目大数字)
      TimeRulerPicker({ timerMinutes: this.timerMinutes })

      // 2. 专注时间（分钟）子标题
      Text('专注时间（分钟）')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#64748B')
        .letterSpacing(1)
        .margin({ top: 6, bottom: 14 })

      // 3. Start Flight 暖珊瑚红胶囊按钮
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
      .shadow({ radius: 16, color: 'rgba(250, 107, 86, 0.38)', offsetY: 6 })
      .onClick(() => {
        this.isRunning = !this.isRunning;
        if (this.onStartFlight) {
          this.onStartFlight();
        } else {
          promptAction.showToast({
            message: this.isRunning ? '🛫 航班起飞，进入巡航专注！' : '🛬 专注结束，回到停机坪！',
            duration: 1500
          });
        }
      })

      // 4. 航线与时长路线指示
      Row({ space: 8 }) {
        Text('成都')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#475569')

        Text('➔')
          .fontSize(12)
          .fontColor('#94A3B8')

        Text('上海')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#475569')

        Text('•')
          .fontSize(13)
          .fontColor('#CBD5E1')

        Text(`${this.routeDistanceKm} 公里`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#64748B')
      }
      .margin({ top: 14, bottom: 22 })

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
        ['rgba(225, 215, 207, 0.0)', 0.0],
        ['rgba(225, 215, 207, 0.95)', 0.08],
        ['rgba(225, 215, 207, 0.98)', 0.22],
        ['rgba(232, 225, 218, 1.0)', 1.0]
      ]
    })
  }
}
