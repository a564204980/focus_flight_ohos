import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { vibrator } from '@kit.SensorServiceKit';
import {
  Airport,
  POPULAR_AIRPORTS,
  findAirportByCode,
  getDistanceKm
} from '../models/AirportModel';

/**
 * 对应 ArkTS 规范：显式定义地图节点接口
 */
export interface MapAirportNode {
  airport: Airport;
  xPct: number;
  yPct: number;
  isUnlocked?: boolean;
}

export interface RulerTick {
  minutes: number;
  isMajor: boolean;
  label?: string;
}

export interface MapControllerEventSubscriber {
  on(event: string, callback: (pos: mapCommon.CameraPosition) => void): void;
}

// 自动生成 15 ~ 240 分钟，按 5 分钟步进的精细刻度列表 (每 15 分钟为一个数字大刻度，中间带两个小短竖条)
export const RULER_MINUTES_TICKS: RulerTick[] = [];
for (let m = 15; m <= 240; m += 5) {
  RULER_MINUTES_TICKS.push({
    minutes: m,
    isMajor: m % 15 === 0,
    label: m % 15 === 0 ? `${m}` : undefined
  });
}

interface MapElement {
  remove(): void;
}

@CustomDialog
export struct FlightMapSelectOverlay {
  controller?: CustomDialogController;
  @Prop selectedCode: string = '';
  onDestinationSelected?: (airport: Airport, minutes?: number) => void;

  @State currentMinutes: number = 25;
  @State currentSelectedCode: string = 'XIY';
  @State routeDistanceKm: number = 624;
  @State candidateAirports: Airport[] = [];
  @State currentZoomLevel: number = 9.0;
  @State rulerContainerWidth: number = 360;

  private huaweiMapController?: map.MapComponentController;
  private currentPolyline?: MapElement;
  private currentMarkers: Object[] = [];
  private rulerScroller: Scroller = new Scroller();
  private lastHapticTickIndex: number = -1;
  private lastVibrateTime: number = 0;
  private lastPanOffsetX: number = 0;

  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: { latitude: 30.48, longitude: 103.95 }, // 🎯 默认精准定位到起点 (成都: 30.56N, 103.95E)，如图 2 所示
      zoom: 7.5,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE, // 卫星地图模式
    zoomControlsEnabled: false,
    compassControlsEnabled: false
  };

  aboutToAppear() {
    if (this.selectedCode) {
      this.currentSelectedCode = this.selectedCode;
    }
    this.updateCandidateAirports(this.currentMinutes);
    this.updateRouteDistance(this.currentSelectedCode);
    this.initRulerScroll();
  }

  /**
   * 🎯 对标 BackButton 标准系统的 25~40ms 触控微脉冲引擎 (100% 稳定响应)
   */
  private triggerTickHaptic(isMajor: boolean = false) {
    const now = Date.now();
    if (now - this.lastVibrateTime < 25) {
      return;
    }
    this.lastVibrateTime = now;

    try {
      vibrator.startVibration({
        type: 'time',
        duration: isMajor ? 40 : 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      console.error('vibrator startVibration error:', JSON.stringify(e));
    }
  }

  private initRulerScroll() {
    const idx = RULER_MINUTES_TICKS.findIndex(t => t.minutes === this.currentMinutes);
    if (idx >= 0) {
      setTimeout(() => {
        this.rulerScroller.scrollTo({
          xOffset: idx * 36,
          yOffset: 0,
          animation: { duration: 300, curve: Curve.Smooth }
        });
      }, 200);
    }
  }

  private snapToNearestTick() {
    const xOffset = this.rulerScroller.currentOffset().xOffset;
    let tickIdx = Math.round(xOffset / 36);
    if (tickIdx < 0) tickIdx = 0;
    if (tickIdx >= RULER_MINUTES_TICKS.length) tickIdx = RULER_MINUTES_TICKS.length - 1;

    const snapX = tickIdx * 36;
    // 移除松手时的二次重复震动，保证单次滚动过程触感干净利落
    this.rulerScroller.scrollTo({
      xOffset: snapX,
      yOffset: 0,
      animation: { duration: 180, curve: Curve.FastOutSlowIn }
    });

    const targetMin = RULER_MINUTES_TICKS[tickIdx].minutes;
    if (targetMin !== this.currentMinutes) {
      this.currentMinutes = targetMin;
      this.updateCandidateAirports(targetMin);
      this.drawRoute(this.currentSelectedCode);
    }
  }

  private updateCandidateAirports(minutes: number) {
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) {
      this.candidateAirports = POPULAR_AIRPORTS.slice(0, 5);
      return;
    }

    const filtered = POPULAR_AIRPORTS.filter(apt => {
      if (apt.code === 'CTU' || apt.lat === undefined || apt.lon === undefined) return false;
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
      if (minutes <= 25) {
        return dist < 800; // 绵阳 / 重庆 / 西安
      } else if (minutes <= 45) {
        return dist < 2200; // 包含 624km 的西安、320km 的重庆、1200km 的广州、1558km 的北京
      } else if (minutes <= 90) {
        return dist >= 1200 && dist < 4200;
      } else {
        return dist >= 3500;
      }
    });

    this.candidateAirports = filtered.length > 0 ? filtered : POPULAR_AIRPORTS.slice(0, 6);
    
    // 🎯 防止默认切到北京：优先保持当前选中，若不在列表中优先取近途机场 (如 XIY 西安 / CKG 重庆)
    const exists = this.candidateAirports.some(apt => apt.code === this.currentSelectedCode);
    if (!exists && this.candidateAirports.length > 0) {
      const preferred = this.candidateAirports.find(a => a.code === 'XIY' || a.code === 'CKG') || this.candidateAirports[0];
      this.currentSelectedCode = preferred.code;
      this.updateRouteDistance(this.currentSelectedCode);
    }
  }

  private selectMinutes(minutes: number, index?: number) {
    this.currentMinutes = minutes;
    this.triggerTickHaptic(true);
    this.updateCandidateAirports(minutes);
    this.drawRoute(this.currentSelectedCode);

    if (index !== undefined) {
      this.rulerScroller.scrollTo({
        xOffset: index * 36,
        yOffset: 0,
        animation: { duration: 300, curve: Curve.Smooth }
      });
    }
  }

  private selectCity(code: string) {
    this.triggerTickHaptic(true);
    this.currentSelectedCode = code;
    this.updateRouteDistance(code);
    this.drawRoute(code);
  }

  private updateRouteDistance(targetCode: string) {
    const origin = findAirportByCode('CTU');
    const target = findAirportByCode(targetCode);
    if (origin && target && origin.lat !== undefined && origin.lon !== undefined && target.lat !== undefined && target.lon !== undefined) {
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(target.lat), Number(target.lon));
      if (!isNaN(dist) && dist > 0) {
        this.routeDistanceKm = dist;
      }
    }
  }

  private async drawRoute(destCode: string) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    const target = findAirportByCode(destCode);
    
    if (!origin || !target || origin.lat === undefined || origin.lon === undefined || target.lat === undefined || target.lon === undefined) return;

    // 清理旧航线
    if (this.currentPolyline) {
      this.currentPolyline.remove();
      this.currentPolyline = undefined;
    }

    // 清理旧 Marker 标注
    if (this.currentMarkers.length > 0) {
      this.currentMarkers.forEach((m: Object) => {
        try {
          (m as map.Marker).remove();
        } catch (e) {}
      });
      this.currentMarkers = [];
    }

    // 绘制航线 (精细橙红色画笔)
    try {
      this.currentPolyline = (await this.huaweiMapController.addPolyline({
        points: [
          { latitude: origin.lat, longitude: origin.lon },
          { latitude: target.lat, longitude: target.lon }
        ],
        color: 0xFFF06553,
        width: 5
      })) as MapElement;
    } catch (e) {
      console.error('add polyline error', JSON.stringify(e));
    }

    // 🎯 绘制定位点机场 Marker (起点 + 终点)
    try {
      const opt1: mapCommon.MarkerOptions = {
        position: { latitude: origin.lat, longitude: origin.lon }
      };
      const m1 = await this.huaweiMapController.addMarker(opt1);
      if (m1) {
        try {
          const markerObj = m1 as Object as Record<string, Function>;
          if (typeof markerObj['setTitle'] === 'function') {
            markerObj['setTitle'](`📍 ${origin.name} (${origin.code})`);
          }
        } catch (err) {}
        this.currentMarkers.push(m1);
      }

      const opt2: mapCommon.MarkerOptions = {
        position: { latitude: target.lat, longitude: target.lon }
      };
      const m2 = await this.huaweiMapController.addMarker(opt2);
      if (m2) {
        try {
          const markerObj = m2 as Object as Record<string, Function>;
          if (typeof markerObj['setTitle'] === 'function') {
            markerObj['setTitle'](`📍 ${target.name} (${target.code})`);
          }
        } catch (err) {}
        this.currentMarkers.push(m2);
      }
    } catch (e) {
      console.error('addMarker error', JSON.stringify(e));
    }

    // 智能镜头：以起点 (成都: 30.56N, 103.95E) 为基准视角（如图 2 所示），顺着航线延伸 15% 并扣除抽屉遮挡！
    try {
      let targetZoom = 7.5;
      if (this.routeDistanceKm > 8000) {
        targetZoom = 3.2;
      } else if (this.routeDistanceKm > 3000) {
        targetZoom = 4.5;
      } else if (this.routeDistanceKm > 1500) {
        targetZoom = 6.0;
      } else if (this.routeDistanceKm > 800) {
        targetZoom = 6.8;
      } else {
        targetZoom = 7.5;
      }

      this.currentZoomLevel = targetZoom;

      // 镜头焦点精准打在起点成都 (30.56N, 103.95E) 偏南 0.08°，100% 呈现图 2 效果！
      const anchorLat = origin.lat + (target.lat - origin.lat) * 0.15 - 0.08;
      const anchorLon = origin.lon + (target.lon - origin.lon) * 0.15;

      this.huaweiMapController.animateCamera({
         target: {
           latitude: anchorLat,
           longitude: anchorLon
         },
         zoom: targetZoom
      }, 800);
    } catch (e) {
      console.error('animate camera error', JSON.stringify(e));
    }
  }

  private huaweiMapCallback = async (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.drawRoute(this.currentSelectedCode);

      // 🎯 动态兼容监听两指 Pinch 放大缩小地图手势，实时同步更新右侧 7.5x 倍率数字！
      try {
        const ctrl = controller as Object as MapControllerEventSubscriber;
        if (ctrl && typeof ctrl.on === 'function') {
          ctrl.on('cameraChange', (position: mapCommon.CameraPosition) => {
            if (position && typeof position.zoom === 'number') {
              this.currentZoomLevel = position.zoom;
            }
          });
          ctrl.on('cameraMove', (position: mapCommon.CameraPosition) => {
            if (position && typeof position.zoom === 'number') {
              this.currentZoomLevel = position.zoom;
            }
          });
        }
      } catch (e) {
        console.error('camera listener error', JSON.stringify(e));
      }
    }
  };

  private zoomIn() {
    if (!this.huaweiMapController) return;
    this.currentZoomLevel = Math.min(this.currentZoomLevel + 0.5, 12.0);
    try {
      this.huaweiMapController.animateCamera({ zoom: this.currentZoomLevel }, 300);
    } catch (e) {
      console.error('zoom in error', JSON.stringify(e));
    }
  }

  private zoomOut() {
    if (!this.huaweiMapController) return;
    this.currentZoomLevel = Math.max(this.currentZoomLevel - 0.5, 1.5);
    try {
      this.huaweiMapController.animateCamera({ zoom: this.currentZoomLevel }, 300);
    } catch (e) {
      console.error('zoom out error', JSON.stringify(e));
    }
  }

  private confirmSelection() {
    const selected = findAirportByCode(this.currentSelectedCode);
    if (selected && this.onDestinationSelected) {
      this.onDestinationSelected(selected, this.currentMinutes);
    }
    if (this.controller) {
      this.controller.close();
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 1. 原生花瓣卫星地图底图
      MapComponent({ mapOptions: this.huaweiMapOptions, mapCallback: this.huaweiMapCallback })
        .width('100%')
        .height('100%')

      // 2. 顶部高级暗黑玻璃 Header (Route Pill & Close)
      Row() {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Text('成都')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
            Text('✈️')
              .fontSize(11)
            Text(findAirportByCode(this.currentSelectedCode)?.city || this.currentSelectedCode)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F06553')
          }

          Divider()
            .vertical(true)
            .height(12)
            .color('rgba(255, 255, 255, 0.2)')

          Text(`${Math.round(this.routeDistanceKm)} km · ${this.currentMinutes}min`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#94A3B8')
        }
        .padding({ left: 16, right: 16, top: 9, bottom: 9 })
        .backgroundColor('rgba(15, 23, 42, 0.88)')
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.35)', offsetY: 3 })

        Blank()

        // 右侧关闭 ✕
        Row() {
          Text('✕')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#94A3B8')
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(15, 23, 42, 0.88)')
        .borderRadius(18)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .position({ x: 0, y: 44 })
      .hitTestBehavior(HitTestMode.Transparent)

      // 3. 右侧极简地图缩放倍率悬浮面板 (+ / - Controls)
      Column({ space: 4 }) {
        Row() {
          Text('+')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .width(34)
        .height(34)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(15, 23, 42, 0.85)')
        .borderRadius(17)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
        .onClick(() => {
          this.zoomIn();
        })

        Column({ space: 1 }) {
          Text(`${this.currentZoomLevel.toFixed(1)}x`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F06553')
        }
        .padding({ top: 2, bottom: 2 })

        Row() {
          Text('−')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .width(34)
        .height(34)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(15, 23, 42, 0.85)')
        .borderRadius(17)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
        .onClick(() => {
          this.zoomOut();
        })
      }
      .position({ x: '86%', y: 105 })
      .hitTestBehavior(HitTestMode.Transparent)

      // 4. 底部一体化暗黑玻璃导航控制面板 (宽幅防遮挡 + 绝无重叠截断的精致刻度尺)
      Column({ space: 12 }) {
        // (1) 候选城市名牌横向滑块
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.candidateAirports, (apt: Airport) => {
              Row({ space: 6 }) {
                Text(apt.city || apt.name)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.currentSelectedCode === apt.code ? '#FFFFFF' : '#CBD5E1')
                Text(apt.code)
                  .fontSize(10)
                  .fontColor(this.currentSelectedCode === apt.code ? 'rgba(255,255,255,0.85)' : '#64748B')
              }
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor(this.currentSelectedCode === apt.code ? '#F06553' : 'rgba(255, 255, 255, 0.08)')
              .borderRadius(16)
              .border({ width: 1, color: this.currentSelectedCode === apt.code ? 'transparent' : 'rgba(255, 255, 255, 0.12)' })
              .onClick(() => {
                this.selectCity(apt.code);
              })
            })
          }
          .padding({ left: 4, right: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // (2) 36px 宽幅呼吸排版刻度尺 (100% 绝无重叠、绝无截断)
        Column({ space: 4 }) {
          // 顶层指针 ▲
          Text('▲')
            .fontSize(11)
            .fontColor('#F06553')
            .margin({ bottom: 2 })

          // 横向自由滑动卷轴刻度尺
          Scroll(this.rulerScroller) {
            Row({ space: 0 }) {
              // 动态精确中点垫片 (根据 36px 宽幅刻度计算中点)
              Blank()
                .width(Math.max(0, this.rulerContainerWidth / 2.0 - 18.0))

              ForEach(RULER_MINUTES_TICKS, (tick: RulerTick, index: number) => {
                Column({ space: 6 }) {
                  // 数字在刻度线正上方 (主刻度显示数字，次刻度若被选中也高亮显示数字)
                  if (tick.isMajor || tick.minutes === this.currentMinutes) {
                    Text(`${tick.minutes}`)
                      .fontSize(tick.minutes === this.currentMinutes ? 13 : 11)
                      .fontWeight(tick.minutes === this.currentMinutes ? FontWeight.Bold : FontWeight.Medium)
                      .fontColor(tick.minutes === this.currentMinutes ? '#F06553' : 'rgba(255, 255, 255, 0.65)')
                  } else {
                    Text(' ')
                      .fontSize(11)
                  }

                  // 刻度线 (底部对齐，主刻度长，次刻度小短竖条)
                  Line()
                    .width(tick.minutes === this.currentMinutes ? 3.5 : (tick.isMajor ? 1.5 : 1))
                    .height(tick.minutes === this.currentMinutes ? 22 : (tick.isMajor ? 14 : 7))
                    .backgroundColor(tick.minutes === this.currentMinutes ? '#F06553' : (tick.isMajor ? 'rgba(255, 255, 255, 0.65)' : 'rgba(255, 255, 255, 0.28)'))
                    .borderRadius(1)
                }
                .width(36)
                .alignItems(HorizontalAlign.Center)
                .justifyContent(FlexAlign.End)
                .onClick(() => {
                  this.selectMinutes(tick.minutes, index);
                })
              })

              Blank()
                .width(Math.max(0, this.rulerContainerWidth / 2.0 - 18.0))
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .onAreaChange((oldArea, newArea) => {
            this.rulerContainerWidth = Number(newArea.width);
          })
          .onScroll(() => {
            const xOffset = this.rulerScroller.currentOffset().xOffset;
            const tickIdx = Math.round(xOffset / 36);
            if (tickIdx >= 0 && tickIdx < RULER_MINUTES_TICKS.length) {
              if (tickIdx !== this.lastHapticTickIndex) {
                this.lastHapticTickIndex = tickIdx;
                const isMajor = RULER_MINUTES_TICKS[tickIdx].isMajor;
                this.triggerTickHaptic(isMajor);
              }
              const targetMin = RULER_MINUTES_TICKS[tickIdx].minutes;
              if (targetMin !== this.currentMinutes) {
                this.currentMinutes = targetMin;
                this.updateCandidateAirports(targetMin);
                this.drawRoute(this.currentSelectedCode);
              }
            }
          })
          .onScrollStop(() => {
            this.snapToNearestTick();
          })

          // 刻度尺下方标题提示
          Text('专注时间（分钟）')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255, 255, 255, 0.45)')
            .margin({ top: 6, bottom: 2 })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
        .backgroundColor('rgba(255, 255, 255, 0.05)')
        .borderRadius(18)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart(() => {
              this.lastPanOffsetX = 0;
            })
            .onActionUpdate((event: GestureEvent) => {
              if (!event) return;
              const deltaX = event.offsetX - this.lastPanOffsetX;
              this.lastPanOffsetX = event.offsetX;

              const currentScrollX = this.rulerScroller.currentOffset().xOffset;
              // 0.40 粘性手势抗力阻尼感
              const targetScrollX = Math.max(0, currentScrollX - deltaX * 0.40);

              this.rulerScroller.scrollTo({
                xOffset: targetScrollX,
                yOffset: 0
              });

              // 🎯 解决 scrollTo 不触发 onScroll 的鸿蒙底层机制：在 PanGesture 手势中实时触发震动！
              const tickIdx = Math.round(targetScrollX / 36);
              if (tickIdx >= 0 && tickIdx < RULER_MINUTES_TICKS.length) {
                if (tickIdx !== this.lastHapticTickIndex) {
                  this.lastHapticTickIndex = tickIdx;
                  const isMajor = RULER_MINUTES_TICKS[tickIdx].isMajor;
                  this.triggerTickHaptic(isMajor);
                }
                const targetMin = RULER_MINUTES_TICKS[tickIdx].minutes;
                if (targetMin !== this.currentMinutes) {
                  this.currentMinutes = targetMin;
                  this.updateCandidateAirports(targetMin);
                  this.drawRoute(this.currentSelectedCode);
                }
              }
            })
            .onActionEnd(() => {
              this.snapToNearestTick();
            })
        )

        // (3) 主行动按钮
        Button() {
          Row({ space: 8 }) {
            Text(`开启 ${this.currentMinutes} 分钟专注航程 · 准备起飞 🛫`)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#F06553')
        .borderRadius(24)
        .shadow({ radius: 12, color: 'rgba(240, 101, 83, 0.45)', offsetY: 4 })
        .onClick(() => {
          this.confirmSelection();
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 32 })
      .backgroundColor('rgba(15, 23, 42, 0.95)')
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.6)', offsetY: -4 })
      .margin({ left: 0, bottom: 0 })
    }
    .width('100%')
    .height('100%')
  }
}
