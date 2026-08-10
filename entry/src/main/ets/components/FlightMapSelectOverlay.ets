import { promptAction } from '@kit.ArkUI';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { vibrator } from '@kit.SensorServiceKit';
import {
  Airport,
  POPULAR_AIRPORTS,
  findAirportByCode,
  getDistanceKm
} from '../models/AirportModel';
import { AirportMarkerHelper } from '../utils/AirportMarkerHelper';

/**
 * 对应 ArkTS 规范：显式定义地图节点接口
 */
export interface MapAirportNode {
  airport: Airport;
  xPct: number;
  yPct: number;
  isUnlocked?: boolean;
}

export interface ScreenVpPoint {
  x: number;
  y: number;
}

export interface RulerFiveMinUnit {
  minutes: number;
  isMajor: boolean;
}

export interface AirportMarkerEntry {
  marker: map.Marker;
  code: string;
  isTemporary?: boolean;
}

export interface MapControllerEventSubscriber {
  on(event: string, callback: (pos: mapCommon.CameraPosition) => void): void;
}

// 每个小刻度格子的宽度 (vp) 与 每个 5 分钟步进的总宽度 (vp) (1 主刻度 + 3 紧凑小刻度 = 4 * 8 = 32vp)
export const RULER_SUB_WIDTH: number = 8;
export const RULER_STEP_WIDTH: number = 32;

// 自动生成 15 ~ 240 分钟，按 5 分钟步进的刻度列表 (每 15 分钟为数字大刻度，每 5 分钟为中刻度)
export const RULER_FIVE_MIN_UNITS: RulerFiveMinUnit[] = [];
for (let m = 15; m <= 240; m += 5) {
  RULER_FIVE_MIN_UNITS.push({
    minutes: m,
    isMajor: m % 15 === 0
  });
}

/**
 * 🎯 航空空管雷达扫描与声纳脉冲动效组件 (以红框中心为圆心，硬件加速渲染，完全穿透手势)
 */
@Component
struct RadarScanOverlay {
  @Prop radius: number = 155;
  @Prop currentMinutes: number = 25;
  @State radarAngle: number = 0;
  @State pulseRatio1: number = 0.0;
  @State pulseRatio2: number = 0.5;
  private timerId: number = -1;

  aboutToAppear() {
    this.timerId = setInterval(() => {
      this.radarAngle = (this.radarAngle + 2.2) % 360;
      this.pulseRatio1 = (this.pulseRatio1 + 0.015) % 1.0;
      this.pulseRatio2 = (this.pulseRatio2 + 0.015) % 1.0;
    }, 33);
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 360° 顺时针扇形微光扫光 (SweepGradient 硬件加速)
      Stack()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .borderRadius(this.radius)
        .clip(true)
        .sweepGradient({
          center: ['50%', '50%'],
          start: 0,
          end: 360,
          colors: [
            ['rgba(240, 101, 83, 0.0)', 0.0],
            ['rgba(240, 101, 83, 0.0)', 0.78],
            ['rgba(240, 101, 83, 0.06)', 0.88],
            ['rgba(240, 101, 83, 0.22)', 0.98],
            ['rgba(255, 230, 220, 0.75)', 1.0]
          ]
        })
        .rotate({ angle: this.radarAngle })

      // 2. 声纳向外扩散波纹 1
      Stack()
        .width(this.radius * 2 * this.pulseRatio1)
        .height(this.radius * 2 * this.pulseRatio1)
        .borderRadius(this.radius * this.pulseRatio1)
        .border({
          width: 1.8,
          color: `rgba(240, 101, 83, ${((1.0 - this.pulseRatio1) * 0.35).toFixed(2)})`,
          style: BorderStyle.Solid
        })

      // 3. 声纳向外扩散波纹 2
      Stack()
        .width(this.radius * 2 * this.pulseRatio2)
        .height(this.radius * 2 * this.pulseRatio2)
        .borderRadius(this.radius * this.pulseRatio2)
        .border({
          width: 1.8,
          color: `rgba(240, 101, 83, ${((1.0 - this.pulseRatio2) * 0.35).toFixed(2)})`,
          style: BorderStyle.Solid
        })

      // 4. 十字准星横纵刻度线
      Row().width(this.radius * 2).height(1).backgroundColor('rgba(255, 255, 255, 0.08)')
      Column().width(1).height(this.radius * 2).backgroundColor('rgba(255, 255, 255, 0.08)')

      // 5. 内层同心距离刻度圈 (1/3 与 2/3)
      Stack()
        .width(this.radius * 2 * 0.36)
        .height(this.radius * 2 * 0.36)
        .borderRadius(this.radius * 0.36)
        .border({
          width: 1,
          color: 'rgba(255, 255, 255, 0.12)',
          style: BorderStyle.Solid
        })

      Stack()
        .width(this.radius * 2 * 0.70)
        .height(this.radius * 2 * 0.70)
        .borderRadius(this.radius * 0.70)
        .border({
          width: 1,
          color: 'rgba(255, 255, 255, 0.12)',
          style: BorderStyle.Solid
        })

      // 6. 外层主测距范围圈 (半透明珊瑚红虚线)
      Stack()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .borderRadius(this.radius)
        .border({
          width: 1.5,
          color: 'rgba(240, 101, 83, 0.45)',
          style: BorderStyle.Dashed
        })


    }
    .width(this.radius * 2)
    .height(this.radius * 2)
    .hitTestBehavior(HitTestMode.None)
  }
}

@CustomDialog
export struct FlightMapSelectOverlay {
  controller?: CustomDialogController;
  @Prop selectedCode: string = '';
  @Prop initialMinutes: number = 15;
  onDestinationSelected?: (airport: Airport, minutes?: number) => void;

  @State currentMinutes: number = 15;
  @State currentSelectedCode: string = '';
  @State routeDistanceKm: number = 0;
  @State candidateAirports: Airport[] = [];
  @State currentZoomLevel: number = 6.2;
  @State rulerContainerWidth: number = 360;
  @State ctuScreenX: number = 210;
  @State ctuScreenY: number = 320;
  @State dynamicRadarRadius: number = 155;
  @State destScreenX: number = 0;
  @State destScreenY: number = 0;
  @State destPulseRadius: number = 0;
  @State destPulseOpacity: number = 0.0;
  @State flightPlaneX: number = 0;
  @State flightPlaneY: number = 0;
  @State flightPlaneAngle: number = 0;
  @State isFlightPlaneVisible: boolean = false;
  @State flightPlaneScale: number = 1.0;
  @State flightPlaneOpacity: number = 1.0;

  private huaweiMapController?: map.MapComponentController;
  private originMarker?: map.Marker;
  private airportMarkers: AirportMarkerEntry[] = [];
  private currentPolyline?: Object;
  private rulerScroller: Scroller = new Scroller();
  private lastHapticTickIndex: number = -1;
  private lastVibrateTime: number = 0;
  private lastPanOffsetX: number = 0;
  private destPulseTimer: number = -1;

  /**
   * 🎯 经纬度转屏幕 vp 物理坐标转换引擎 (支持 Native MapKit Projection 与 Mercator 双引擎)
   */
  private latLngToScreenVp(lat: number, lon: number): ScreenVpPoint | null {
    if (!this.huaweiMapController) return null;
    // 1. 优先使用 Native Projection
    try {
      const dynamicCtrl = this.huaweiMapController as object as Record<string, () => Object>;
      if (typeof dynamicCtrl['getProjection'] === 'function') {
        const proj = dynamicCtrl['getProjection']() as Record<string, (arg: Record<string, number>) => Object>;
        if (proj && typeof proj['toScreenLocation'] === 'function') {
          const latLng: Record<string, number> = { 'latitude': lat, 'longitude': lon };
          const screenPoint = proj['toScreenLocation'](latLng);
          if (screenPoint) {
            const ptRecord = screenPoint as object as Record<string, number>;
            const rawX = ptRecord['positionX'] ?? ptRecord['x'];
            const rawY = ptRecord['positionY'] ?? ptRecord['y'];
            if (rawX !== undefined && rawY !== undefined && !isNaN(rawX) && !isNaN(rawY)) {
              const pt: ScreenVpPoint = { x: px2vp(rawX), y: px2vp(rawY) };
              return pt;
            }
          }
        }
      }
    } catch (e) {}

    // 2. 备用 Mercator 数学投影
    try {
      const cam = this.huaweiMapController.getCameraPosition();
      if (!cam || !cam.target) return null;
      const zoom = (typeof cam.zoom === 'number' && !isNaN(cam.zoom)) ? cam.zoom : this.currentZoomLevel;
      const centerLat = cam.target.latitude;
      const centerLon = cam.target.longitude;

      const tileSize = 256.0;
      const scale = Math.pow(2, zoom);
      const worldSize = tileSize * scale;

      const worldX = ((lon + 180.0) / 360.0) * worldSize;
      const centerWorldX = ((centerLon + 180.0) / 360.0) * worldSize;

      const sinLat = Math.sin((lat * Math.PI) / 180.0);
      const clampedSinLat = Math.max(-0.9999, Math.min(0.9999, sinLat));
      const worldY = (0.5 - Math.log((1.0 + clampedSinLat) / (1.0 - clampedSinLat)) / (4.0 * Math.PI)) * worldSize;

      const sinCenterLat = Math.sin((centerLat * Math.PI) / 180.0);
      const clampedSinCenterLat = Math.max(-0.9999, Math.min(0.9999, sinCenterLat));
      const centerWorldY = (0.5 - Math.log((1.0 + clampedSinCenterLat) / (1.0 - clampedSinCenterLat)) / (4.0 * Math.PI)) * worldSize;

      const containerW = this.rulerContainerWidth > 0 ? this.rulerContainerWidth : 360.0;
      const screenCenterX = containerW / 2.0;
      const screenCenterY = 305.0; // 🎯 精准回降定格在 Y ≈ 305vp 黄金中轴线

      const targetX = screenCenterX + (worldX - centerWorldX);
      const targetY = screenCenterY + (worldY - centerWorldY);

      if (!isNaN(targetX) && !isNaN(targetY) && isFinite(targetX) && isFinite(targetY)) {
        const pt: ScreenVpPoint = { x: targetX, y: targetY };
        return pt;
      }
    } catch (e) {}
    return null;
  }

  /**
   * 🎯 专注领航精确投影系统 (Web Mercator)：
   * 直接通过相机 target 坐标计算起点在红框中心区域 (screenCenterY = 305vp) 的物理 vp 坐标。
   */
  private refreshCtuScreenPosition() {
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;
    const pt = this.latLngToScreenVp(Number(origin.lat), Number(origin.lon));
    if (pt) {
      this.ctuScreenX = pt.x;
      this.ctuScreenY = pt.y;

      // 🎯 真实地理雷达半径：根据当前专注航程的实际公里数与当前地图缩放倍率，实时计算屏幕真实像素半径
      const maxDistKm = this.getMaxFlightDistanceKm(this.currentMinutes);
      const cosLat = Math.cos(Number(origin.lat) * Math.PI / 180.0);
      const dLon = maxDistKm / (111.32 * (cosLat > 0.01 ? cosLat : 1.0));
      const edgePt = this.latLngToScreenVp(Number(origin.lat), Number(origin.lon) + dLon);
      if (edgePt) {
        const r = Math.hypot(edgePt.x - pt.x, edgePt.y - pt.y);
        if (!isNaN(r) && r > 20) {
          this.dynamicRadarRadius = r;
        }
      }
    }
  }

  /**
   * 🎯 将相机 Target 纬度固定偏南 1.82°，把 CTU 地标、雷达圈与缩放轴心精准回降定格在完美黄金中轴 (Y ≈ 305vp)
   */
  private getCenteredCameraLatitude(originLat: number, _zoomLevel: number): number {
    return originLat - 1.82;
  }

  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: { latitude: 30.5607 - 1.82, longitude: 103.9426 }, // 🎯 精准回降至 Y ≈ 305vp 黄金中轴
      zoom: 5.54,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE, // 卫星地图模式
    zoomControlsEnabled: false,
    compassControlsEnabled: false
  };

  aboutToAppear() {
    if (this.initialMinutes && this.initialMinutes > 0) {
      this.currentMinutes = this.initialMinutes;
    } else {
      this.currentMinutes = 15;
    }
    if (this.selectedCode) {
      this.currentSelectedCode = this.selectedCode;
      this.updateRouteDistance(this.currentSelectedCode);
    } else {
      this.currentSelectedCode = '';
    }
    this.updateCandidateAirports(this.currentMinutes);
    this.initRulerScroll();
  }

  aboutToDisappear() {
    if (this.destPulseTimer !== -1) {
      clearInterval(this.destPulseTimer);
      this.destPulseTimer = -1;
    }
    if (this.currentPolyline) {
      try {
        const p = this.currentPolyline as object as Record<string, () => void>;
        if (typeof p['remove'] === 'function') {
          p['remove']();
        }
      } catch (e) {}
      this.currentPolyline = undefined;
    }
    if (this.airportMarkers && this.airportMarkers.length > 0) {
      this.airportMarkers.forEach(entry => {
        try { entry.marker.remove(); } catch (e) {}
      });
      this.airportMarkers = [];
    }
    if (this.originMarker) {
      try { this.originMarker.remove(); } catch (e) {}
      this.originMarker = undefined;
    }
  }

  /**
   * 🎯 对标 BackButton 标准系统的触控微脉冲引擎 (分级机械触感)
   */
  private triggerTickHaptic(isMajor: boolean = false, isMedium: boolean = false) {
    const now = Date.now();
    if (now - this.lastVibrateTime < 25) {
      return;
    }
    this.lastVibrateTime = now;

    try {
      vibrator.startVibration({
        type: 'time',
        duration: isMajor ? 35 : (isMedium ? 20 : 10)
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      console.error('vibrator startVibration error:', JSON.stringify(e));
    }
  }

  private initRulerScroll() {
    const idx = RULER_FIVE_MIN_UNITS.findIndex(t => t.minutes === this.currentMinutes);
    if (idx >= 0) {
      setTimeout(() => {
        this.rulerScroller.scrollTo({
          xOffset: idx * RULER_STEP_WIDTH,
          yOffset: 0,
          animation: { duration: 300, curve: Curve.Smooth }
        });
      }, 200);
    }
  }

  private snapToNearestTick() {
    const xOffset = this.rulerScroller.currentOffset().xOffset;
    let tickIdx = Math.round(xOffset / RULER_STEP_WIDTH);
    if (tickIdx < 0) tickIdx = 0;
    if (tickIdx >= RULER_FIVE_MIN_UNITS.length) tickIdx = RULER_FIVE_MIN_UNITS.length - 1;

    const snapX = tickIdx * RULER_STEP_WIDTH;
    // 移除松手时的二次重复震动，保证单次滚动过程触感干净利落
    this.rulerScroller.scrollTo({
      xOffset: snapX,
      yOffset: 0,
      animation: { duration: 180, curve: Curve.FastOutSlowIn }
    });

    const targetMin = RULER_FIVE_MIN_UNITS[tickIdx].minutes;
    this.currentMinutes = targetMin;
    this.updateCandidateAirports(targetMin);
    this.drawRoute(this.currentSelectedCode);
    this.updateCameraZoomSmoothly(targetMin);
  }

  private getMaxFlightDistanceKm(minutes: number): number {
    if (minutes <= 15) return 420;
    if (minutes <= 25) return 850;
    if (minutes <= 45) return 1450;
    if (minutes <= 60) return 2000;
    if (minutes <= 90) return 3500;
    if (minutes <= 120) return 5500;
    return 10000;
  }

  // 🎯 连续视界缩放算法：自适应对齐 155vp 稳定雷达圈，确保对应分钟数的候选目的地 100% 全员容纳在雷达圈内
  private getContinuousZoomLevel(minutes: number): number {
    const maxDist = this.getMaxFlightDistanceKm(minutes);
    const targetZoom = Math.log2(20893.5 / maxDist);
    return Math.max(1.8, Math.min(5.6, targetZoom));
  }

  // 🎯 动态视界缩放引擎 (自适应获取当前最佳 Zoom)
  private getBestZoomLevelForMinutes(minutes: number): number {
    return this.getContinuousZoomLevel(minutes);
  }

  // 🎯 专用于高频拖拽过程的 60fps 实时跟手视界拉伸引擎
  private updateCameraZoomDirectly(minutes: number) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;
    try {
      const targetZoom = this.getContinuousZoomLevel(minutes);
      this.currentZoomLevel = targetZoom;
      this.huaweiMapController.moveCamera(map.newCameraPosition({
        target: {
          latitude: this.getCenteredCameraLatitude(origin.lat, targetZoom),
          longitude: origin.lon
        },
        zoom: targetZoom
      }));
    } catch (e) {
      console.error('updateCameraZoomDirectly error:', JSON.stringify(e));
    }
  }

  // 🎯 专用于松手吸附与点选的 850ms 电影级超长柔和推拉引擎 (EaseInOut 缓入缓出，呼吸感拉满)
  private updateCameraZoomSmoothly(minutes: number) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;
    try {
      const targetZoom = this.getContinuousZoomLevel(minutes);
      this.currentZoomLevel = targetZoom;
      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: {
          latitude: this.getCenteredCameraLatitude(origin.lat, targetZoom),
          longitude: origin.lon
        },
        zoom: targetZoom
      }), 850);
    } catch (e) {
      console.error('updateCameraZoomSmoothly error:', JSON.stringify(e));
    }
  }

  private updateCandidateAirports(minutes: number) {
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) {
      this.candidateAirports = POPULAR_AIRPORTS.slice(0, 5);
      return;
    }

    // 🎯 科学专注航程阶梯算法体系 (1分钟 ≈ 15km，划分专属航段等级)
    const maxDist = this.getMaxFlightDistanceKm(minutes);
    const filtered = POPULAR_AIRPORTS.filter(apt => {
      if (apt.code === 'CTU' || apt.code === 'TFU' || apt.lat === undefined || apt.lon === undefined) return false;
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
      
      // 过滤掉低于最小航程的，同时保证最大航程严格小于等于 maxDist (即被雷达圈完美包裹)
      if (minutes <= 15) return dist >= 80 && dist <= maxDist;
      if (minutes <= 25) return dist > 380 && dist <= maxDist;
      if (minutes <= 45) return dist > 800 && dist <= maxDist;
      if (minutes <= 60) return dist > 1200 && dist <= maxDist;
      if (minutes <= 90) return dist > 1800 && dist <= maxDist;
      if (minutes <= 120) return dist > 2800 && dist <= maxDist;
      return dist > 5000;
    });

    // 按照与出发地的实际飞行距离由近及远优雅排序
    filtered.sort((a, b) => {
      const d1 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(a.lat), Number(a.lon));
      const d2 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(b.lat), Number(b.lon));
      return d1 - d2;
    });

    this.candidateAirports = filtered.length > 0 ? filtered : POPULAR_AIRPORTS.slice(0, 6);

    // 如果当前选中的机场不在候选列表内，清空选中
    if (this.currentSelectedCode) {
      const exists = this.candidateAirports.some(apt => apt.code === this.currentSelectedCode);
      if (!exists) {
        this.currentSelectedCode = '';
        this.routeDistanceKm = 0;
      }
    }
  }

  private selectMinutes(minutes: number, index?: number) {
    this.currentMinutes = minutes;
    this.triggerTickHaptic(true);
    this.updateCandidateAirports(minutes);
    this.drawRoute(this.currentSelectedCode);
    this.updateCameraZoomSmoothly(minutes);

    if (index !== undefined) {
      this.rulerScroller.scrollTo({
        xOffset: index * RULER_STEP_WIDTH,
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
    if (!targetCode) {
      this.routeDistanceKm = 0;
      return;
    }
    const origin = findAirportByCode('CTU');
    const target = findAirportByCode(targetCode);
    if (origin && target && origin.lat !== undefined && origin.lon !== undefined && target.lat !== undefined && target.lon !== undefined) {
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(target.lat), Number(target.lon));
      if (!isNaN(dist) && dist > 0) {
        this.routeDistanceKm = dist;
      }
    }
  }

  /**
   * 🎯 航线飞抵终点时，点亮目标机场地标 (通过带精确锚点的 addMarker 替换，100% 杜绝 setIcon 导致的锚点丢失偏移)
   */
  private async activateDestMarker(destCode: string) {
    if (!destCode || !this.huaweiMapController || !this.airportMarkers || this.airportMarkers.length === 0) return;
    const entryIdx = this.airportMarkers.findIndex(item => item.code === destCode);
    if (entryIdx !== -1) {
      const entry = this.airportMarkers[entryIdx];
      const targetApt = findAirportByCode(destCode);
      if (targetApt && targetApt.lat !== undefined && targetApt.lon !== undefined) {
        try {
          // 1. 安全清理旧 Marker
          if (entry.marker) {
            try { entry.marker.remove(); } catch (e) {}
          }
          // 2. 使用显式 anchorU: 0.148, anchorV: 0.5 重新创建红色到达 Marker，绝对零偏移
          const optDest: mapCommon.MarkerOptions = {
            position: { latitude: targetApt.lat, longitude: targetApt.lon },
            icon: AirportMarkerHelper.getDestActiveIcon(destCode),
            anchorU: 0.148,
            anchorV: 0.5,
            clickable: true,
            zIndex: 35,
            title: `(${destCode})`
          };
          const newMarker = await this.huaweiMapController.addMarker(optDest);
          if (newMarker) {
            this.airportMarkers[entryIdx] = {
              marker: newMarker,
              code: destCode,
              isTemporary: entry.isTemporary
            };
          }
          this.triggerTickHaptic(true, false);
        } catch (e) {
          console.error('activateDestMarker error:', JSON.stringify(e));
        }
      }
    }
  }

  private async drawRoute(destCode: string, force: boolean = false) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;

    // 1. 清理旧 Polyline 航线
    if (this.currentPolyline) {
      try {
        const p = this.currentPolyline as object as Record<string, () => void>;
        if (typeof p['remove'] === 'function') {
          p['remove']();
        }
      } catch (e) {}
      this.currentPolyline = undefined;
    }

    // 2. 确保起点 CTU 跑道胶囊航空地标 Marker 仅初始化一次
    if (!this.originMarker) {
      try {
        const optOrigin: mapCommon.MarkerOptions = {
          position: { latitude: origin.lat, longitude: origin.lon },
          icon: $rawfile('textures/markers/mk_CTU_orig.png'),
          anchorU: 0.148,
          anchorV: 0.5,
          clickable: false,
          zIndex: 10,
          title: '(CTU)'
        };
        this.originMarker = await this.huaweiMapController.addMarker(optOrigin);
      } catch (e) {
        console.error('add origin marker error', JSON.stringify(e));
      }
    }

    // 3. 🎯 0 闪烁与 0 偏移核心：切换城市时，通过显式 anchor 重置所有候选 Marker
    if (this.airportMarkers && this.airportMarkers.length > 0) {
      this.airportMarkers.forEach(entry => {
        try { entry.marker.remove(); } catch (e) {}
      });
      this.airportMarkers = [];
    }

    let renderList = this.candidateAirports.filter(apt => apt.code !== 'CTU' && apt.lat !== undefined && apt.lon !== undefined);
    if (!destCode && renderList.length > 7) {
      renderList = renderList.slice(0, 7);
    } else if (destCode) {
      const hasDest = renderList.some(apt => apt.code === destCode);
      if (!hasDest) {
        const destApt = findAirportByCode(destCode);
        if (destApt) renderList.push(destApt);
      }
      if (renderList.length > 8) {
        const selectedApt = renderList.find(apt => apt.code === destCode);
        const others = renderList.filter(apt => apt.code !== destCode).slice(0, 7);
        renderList = selectedApt ? [selectedApt, ...others] : others;
      }
    }

    for (let i = 0; i < renderList.length; i++) {
      const apt = renderList[i];
      const isSelected = (apt.code === destCode);
      const iconRes = AirportMarkerHelper.getCandidateIcon(apt.code);

      const optCand: mapCommon.MarkerOptions = {
        position: { latitude: apt.lat, longitude: apt.lon },
        icon: iconRes,
        anchorU: 0.148,
        anchorV: 0.5,
        clickable: true,
        zIndex: isSelected ? 25 : 5,
        title: `(${apt.code})`
      };

      try {
        const m = await this.huaweiMapController.addMarker(optCand);
        if (m) {
          if (destCode && !isSelected) {
            try {
              const dm = m as object as Record<string, (a: number) => void>;
              if (typeof dm['setAlpha'] === 'function') {
                dm['setAlpha'](0.65);
              }
            } catch (e) {}
          }
          this.airportMarkers.push({ marker: m, code: apt.code });
        }
      } catch (e) {
        console.error('add candidate marker error', JSON.stringify(e));
      }
    }

    // 4. 🎯 绘制原生抗锯齿贝塞尔航线 (具有生长展开动效，航线飞抵终点时瞬间点亮目标 Marker)
    if (destCode) {
      const target = findAirportByCode(destCode);
      if (target && target.lat !== undefined && target.lon !== undefined) {
        try {
          const originLat = Number(origin.lat);
          const originLon = Number(origin.lon);
          const targetLat = Number(target.lat);
          const targetLon = Number(target.lon);

          const midLat = (originLat + targetLat) / 2;
          const midLon = (originLon + targetLon) / 2;
          const dLat = targetLat - originLat;
          const dLon = targetLon - originLon;
          // 偏移控制点制造优雅弧度 (绝不生硬折角)
          const ctrlLat = midLat - dLon * 0.15;
          const ctrlLon = midLon + dLat * 0.15;

          const totalSteps = 45;
          const fullCurve: mapCommon.LatLng[] = [];
          for (let i = 0; i <= totalSteps; i++) {
            const t = i / totalSteps;
            const lat = (1 - t) * (1 - t) * originLat + 2 * (1 - t) * t * ctrlLat + t * t * targetLat;
            const lon = (1 - t) * (1 - t) * originLon + 2 * (1 - t) * t * ctrlLon + t * t * targetLon;
            const curvePt: mapCommon.LatLng = { latitude: lat, longitude: lon };
            fullCurve.push(curvePt);
          }

          const firstPt: mapCommon.LatLng = { latitude: originLat, longitude: originLon };
          this.currentPolyline = await this.huaweiMapController.addPolyline({
            points: [firstPt],
            color: 0xFFF06553,
            width: 6,
            zIndex: 20
          }) as Object;

          const currentPolylineRef = this.currentPolyline;
          const polyObj = currentPolylineRef as object as Record<string, (points: mapCommon.LatLng[]) => void>;

          if (typeof polyObj['setPoints'] === 'function') {
            let frame = 1;
            const totalFrames = 22; // 约 350ms 平滑飞行流光
            const timerId = setInterval(() => {
              // 航线被切换或销毁时立即停止当前动画
              if (frame >= totalFrames || this.currentPolyline !== currentPolylineRef) {
                if (this.currentPolyline === currentPolylineRef) {
                  polyObj['setPoints'](fullCurve); // 确保最后完整画完
                  // 🎯 航线飞抵终点！点亮目标 Marker 并震动反馈！
                  this.activateDestMarker(destCode);
                  // 🎯 飞抵终点后小飞机瞬间优雅淡出隐藏，绝不残留
                  this.isFlightPlaneVisible = false;
                } else {
                  this.isFlightPlaneVisible = false;
                }
                clearInterval(timerId);
                return;
              }

              // Cubic Ease-Out 缓动算法，使连线呈现“快出慢落”的丝滑感
              const progress = frame / totalFrames;
              const easeOut = 1 - Math.pow(1 - progress, 3);
              const targetIndex = Math.max(1, Math.floor(easeOut * totalSteps));

              polyObj['setPoints'](fullCurve.slice(0, targetIndex + 1));

              // ✈️ 实时驱动前导领航小飞机沿航线切线极速飞行
              const headGeo = fullCurve[targetIndex];
              const prevGeo = fullCurve[Math.max(0, targetIndex - 1)];
              const dLatDeg = headGeo.latitude - prevGeo.latitude;
              const dLonDeg = headGeo.longitude - prevGeo.longitude;
              const bearing = (Math.atan2(dLonDeg, dLatDeg) * 180 / Math.PI + 360) % 360;

              const pt = this.latLngToScreenVp(headGeo.latitude, headGeo.longitude);
              if (pt) {
                this.flightPlaneX = pt.x;
                this.flightPlaneY = pt.y;
                this.flightPlaneAngle = bearing;
                this.flightPlaneScale = 1.0;
                this.flightPlaneOpacity = 1.0;
                this.isFlightPlaneVisible = true;
              }

              frame++;
            }, 16);
          }
        } catch (e) {
          console.error('add polyline error', JSON.stringify(e));
        }
      }
    }

    // 6. 智能镜头：只有在 force 为 true 时（切换时长或首次加载）才平移镜头，普通选城市时绝对保持静止，彻底消除地标抖动与位移！
    if (force) {
      try {
        const targetZoom = this.getBestZoomLevelForMinutes(this.currentMinutes);
        this.currentZoomLevel = targetZoom;

        this.huaweiMapController.animateCamera(map.newCameraPosition({
           target: {
             latitude: this.getCenteredCameraLatitude(origin.lat, targetZoom),
             longitude: origin.lon
           },
           zoom: targetZoom
        }), 700);
      } catch (e) {
        console.error('animate camera error', JSON.stringify(e));
      }
    }
  }

  private huaweiMapCallback = async (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;

      // 🎯 设置地图控件内边距遮挡 (88vp top, 420vp bottom)，把地图相机视角中心与雷达缩放轴心整体向上平移至 Y ≈ 280vp 黄金位置
      try {
        const ctrlAny = controller as object as Record<string, Function>;
        if (typeof ctrlAny['setPadding'] === 'function') {
          ctrlAny['setPadding'](88, 0, 420, 0);
        }
      } catch (e) {}

      this.drawRoute(this.currentSelectedCode);
      this.refreshCtuScreenPosition();

      // 🎯 动态监听 Marker 点击事件，支持直接在地图上点击候选机场胶囊切换目的地！
      try {
        controller.on('markerClick', (markerObj: Object) => {
          try {
            const m = markerObj as map.Marker;
            if (m && this.airportMarkers && this.airportMarkers.length > 0) {
              const entry = this.airportMarkers.find(item => item.marker === m);
              if (entry && entry.code && entry.code !== 'CTU') {
                this.selectCity(entry.code);
              }
            }
          } catch (err) {}
        });
      } catch (e) {}

      // 🎯 动态监听地图拖拽平移与 Pinch 缩放，采用花瓣 Native Projection 实时极速刷新雷达物理 vp 坐标！
      try {
        controller.on('cameraChange', (_data: Object) => {
          try {
            const cam = controller.getCameraPosition();
            if (cam && typeof cam.zoom === 'number' && !isNaN(cam.zoom)) {
              const newZoom = parseFloat(cam.zoom.toFixed(1));
              if (this.currentZoomLevel !== newZoom) {
                this.currentZoomLevel = newZoom;
              }
            }
            this.refreshCtuScreenPosition();
          } catch (err) { }
        });

        // 🎯 额外监听 cameraMove 实现拖拽时的 60帧丝滑跟随，解决松开才复位的问题
        try {
          // 使用类型断言绕过 TypeScript 对字面量类型的过严检查
          const ctrlAny = controller as object as Record<string, Function>;
          if (typeof ctrlAny.on === 'function') {
            ctrlAny.on('cameraMove', (_data: Object) => {
              try {
                this.refreshCtuScreenPosition();
              } catch (err) { }
            });
          }
        } catch (e) {}
      } catch (e) {
        console.error('camera listener error', JSON.stringify(e));
      }
    }
  };

  private zoomIn() {
    if (this.huaweiMapController) {
      const target = Math.min(18, this.currentZoomLevel + 0.5);
      this.currentZoomLevel = target;
      const cam = this.huaweiMapController.getCameraPosition();
      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: cam?.target || { latitude: 30.5607, longitude: 103.9426 },
        zoom: target
      }), 300);
    }
  }

  private zoomOut() {
    if (!this.huaweiMapController) return;
    try {
      const cam = this.huaweiMapController.getCameraPosition();
      const current = (cam && typeof cam.zoom === 'number') ? cam.zoom : this.currentZoomLevel;
      const target = Math.max(current - 0.5, 1.5);
      this.currentZoomLevel = parseFloat(target.toFixed(1));
      this.huaweiMapController.animateCamera({ zoom: target }, 300);
    } catch (e) {
      console.error('zoom out error', JSON.stringify(e));
    }
  }

  private confirmSelection() {
    if (!this.currentSelectedCode) {
      try {
        promptAction.showToast({ message: '请先选择目的地机场 🛫', duration: 2000 });
      } catch (e) { }
      return;
    }
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

      // 1.5 🎯 专注领航辐射圈动效层 (圆心 100% 锁死 CTU 出发机场，半径随地图缩放与专注分钟数绝对地理锁定)
      RadarScanOverlay({ radius: this.dynamicRadarRadius, currentMinutes: this.currentMinutes })
        .position({ x: this.ctuScreenX, y: this.ctuScreenY })
        .markAnchor({ x: this.dynamicRadarRadius, y: this.dynamicRadarRadius })
        .zIndex(10)
        .hitTestBehavior(HitTestMode.None)

      // 1.6 🎯 终点机场到达雷达声纳光晕脉冲层 (扩散高光)
      // 1.6 🎯 终点雷达脉冲微光晕 (抵达时声纳扩散)
      if (this.destPulseOpacity > 0.01) {
        Stack()
          .width(this.destPulseRadius * 2)
          .height(this.destPulseRadius * 2)
          .borderRadius(this.destPulseRadius)
          .border({ width: 2, color: `rgba(240, 101, 83, ${this.destPulseOpacity.toFixed(2)})` })
          .backgroundColor(`rgba(240, 101, 83, ${(this.destPulseOpacity * 0.25).toFixed(2)})`)
          .position({ x: this.destScreenX, y: this.destScreenY })
          .markAnchor({ x: this.destPulseRadius, y: this.destPulseRadius })
          .zIndex(15)
          .hitTestBehavior(HitTestMode.None)
      }
      // 1.7 ✈️ 航线前导领航小飞机 (纯净纯白矢量剪影，零方块阴影，沿航线切线极速飞行)
      if (this.isFlightPlaneVisible) {
        Image($r('app.media.ic_plane_topview'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .fillColor('#FFFFFF')
          .position({ x: this.flightPlaneX, y: this.flightPlaneY })
          .markAnchor({ x: 11, y: 11 })
          .rotate({ angle: this.flightPlaneAngle })
          .scale({ x: this.flightPlaneScale, y: this.flightPlaneScale })
          .opacity(this.flightPlaneOpacity)
          .zIndex(28)
          .hitTestBehavior(HitTestMode.None)
      }

      Row() {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Text('成都')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
            Text('✈️')
              .fontSize(11)
            Text(this.currentSelectedCode ? (findAirportByCode(this.currentSelectedCode)?.city || this.currentSelectedCode) : '选择目的地')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentSelectedCode ? '#F06553' : 'rgba(255, 255, 255, 0.55)')
            Text(`[X:${Math.round(this.ctuScreenX)} Y:${Math.round(this.ctuScreenY)} Z:${this.currentZoomLevel}]`)
              .fontSize(9)
              .fontColor('#FFD700')
          }

          Divider()
            .vertical(true)
            .height(12)
            .color('rgba(255, 255, 255, 0.2)')

          Text(this.currentSelectedCode ? `${Math.round(this.routeDistanceKm)} km · ${this.currentMinutes}min` : `待选择 · ${this.currentMinutes}min`)
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

      // 4. 底部渐变半透明导航控制面板 (电影级暗角渐变 + 图2专属排版)
      Column({ space: 12 }) {
        // (1) 目的地分区标题
        Text('目的地')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.75)')
          .width('100%')
          .textAlign(TextAlign.Start)

        // (2) 候选城市名牌横向滑块 (微磨砂透光胶囊)
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.candidateAirports, (apt: Airport) => {
              Row({ space: 6 }) {
                Text(apt.city || apt.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.currentSelectedCode === apt.code ? '#FFFFFF' : '#F1F5F9')
                Text(apt.code)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.currentSelectedCode === apt.code ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.6)')
              }
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(this.currentSelectedCode === apt.code ? '#F06553' : 'rgba(15, 23, 42, 0.48)')
              .borderRadius(18)
              .border({ width: 1, color: this.currentSelectedCode === apt.code ? 'transparent' : 'rgba(255, 255, 255, 0.22)' })
              .onClick(() => {
                this.selectCity(apt.code);
              })
            })
          }
          .padding({ left: 2, right: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // (3) 专注时长与高亮数字行 (超过60分钟自动转换为小时显示)
        Row() {
          Text('专注时长')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255, 255, 255, 0.75)')

          Blank()

          Row({ space: 2 }) {
            if (this.currentMinutes < 60) {
              Text(`${this.currentMinutes}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F06553')
              Text('分钟')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255, 255, 255, 0.85)')
            } else {
              Text(`${Math.floor(this.currentMinutes / 60)}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F06553')
              Text('小时')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255, 255, 255, 0.85)')
              if (this.currentMinutes % 60 > 0) {
                Text(`${this.currentMinutes % 60}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F06553')
                Text('分钟')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('rgba(255, 255, 255, 0.85)')
              }
            }
          }
        }
        .width('100%')
        .margin({ top: 4 })

        // (4) 纯透明悬浮刻度尺 (精密航空仪表级三级细分标尺)
        Column({ space: 2 }) {
          // 横向自由滑动卷轴刻度尺
          Scroll(this.rulerScroller) {
            Row({ space: 0 }) {
              // 动态精确中点垫片 (确保 index=0 的刻度线 100% 居中在屏幕正中央中轴线上)
              // 减去 18vp，是因为包裹 Scroll 的父容器拥有 .padding({ left: 18, right: 18 })
              Blank()
                .width(Math.max(0, this.rulerContainerWidth / 2.0 - (RULER_SUB_WIDTH / 2.0) - 18))

              ForEach(RULER_FIVE_MIN_UNITS, (unit: RulerFiveMinUnit, index: number) => {
                Row({ space: 0 }) {
                  // 1. 5分钟主刻度单元 (可点击选择)
                  Column({ space: 4 }) {
                    // (A) 顶部游标：朝上飞行的纯正红色小飞机矢量图标 (仅在当前选中的刻度线正上方精准显示)
                    if (unit.minutes === this.currentMinutes) {
                      Image($r('app.media.ic_ruler_plane_pointer'))
                        .width(14)
                        .height(14)
                    } else {
                      Row()
                        .width(1)
                        .height(14)
                    }

                    // (B) 刻度数字：当前选中的为大字红字 (如 25)；其他 15 分钟大刻度为白色数字
                    if (unit.minutes === this.currentMinutes) {
                      Text(`${unit.minutes}`)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#F06553')
                        .textAlign(TextAlign.Center)
                        .width(48)
                        .height(16)
                        .margin({ left: -20, right: -20 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.None })
                    } else if (unit.isMajor) {
                      Text(`${unit.minutes}`)
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('rgba(255, 255, 255, 0.85)')
                        .textAlign(TextAlign.Center)
                        .width(48)
                        .height(16)
                        .margin({ left: -20, right: -20 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.None })
                    } else {
                      Row()
                        .width(1)
                        .height(16)
                    }

                    // (C) 底部刻度线：当前选中的高18/加粗红色，主刻度15min高14/纯白，中刻度5min高9.5/清晰白
                    Column()
                      .width(unit.minutes === this.currentMinutes ? 2.5 : (unit.isMajor ? 1.8 : 1.4))
                      .height(unit.minutes === this.currentMinutes ? 18 : (unit.isMajor ? 14 : 9.5))
                      .backgroundColor(
                        unit.minutes === this.currentMinutes 
                          ? '#F06553' 
                          : (unit.isMajor ? '#FFFFFF' : 'rgba(255, 255, 255, 0.75)')
                      )
                      .borderRadius(unit.minutes === this.currentMinutes ? 1.5 : (unit.isMajor ? 1.0 : 0.7))
                  }
                  .width(RULER_SUB_WIDTH)
                  .height(56)
                  .clip(false)
                  .alignItems(HorizontalAlign.Center)
                  .justifyContent(FlexAlign.End)
                  .onClick(() => {
                    this.selectMinutes(unit.minutes, index);
                  })

                  // 2. 5分钟之间的 3 个紧凑小刻度 (不可选，纯精致视觉修饰)
                  if (unit.minutes < 240) {
                    ForEach([1, 2, 3], (_subIdx: number) => {
                      Column({ space: 4 }) {
                        Row()
                          .width(1)
                          .height(14)

                        Row()
                          .width(1)
                          .height(16)

                        Column()
                          .width(1.0)
                          .height(5.5)
                          .backgroundColor('rgba(255, 255, 255, 0.40)')
                          .borderRadius(0.5)
                      }
                      .width(RULER_SUB_WIDTH)
                      .height(56)
                      .alignItems(HorizontalAlign.Center)
                      .justifyContent(FlexAlign.End)
                      .hitTestBehavior(HitTestMode.None)
                    }, (subIdx: number) => `${unit.minutes}_sub_${subIdx}`)
                  }
                }
              }, (unit: RulerFiveMinUnit) => `${unit.minutes}`)

              Blank()
                .width(Math.max(0, this.rulerContainerWidth / 2.0 - (RULER_SUB_WIDTH / 2.0) - 18))
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
            const tickIdx = Math.round(xOffset / RULER_STEP_WIDTH);
            if (tickIdx >= 0 && tickIdx < RULER_FIVE_MIN_UNITS.length) {
              if (tickIdx !== this.lastHapticTickIndex) {
                this.lastHapticTickIndex = tickIdx;
                const unit = RULER_FIVE_MIN_UNITS[tickIdx];
                this.triggerTickHaptic(unit.isMajor, true);
              }
              const targetMin = RULER_FIVE_MIN_UNITS[tickIdx].minutes;
              if (targetMin !== this.currentMinutes) {
                this.currentMinutes = targetMin;
              }
            }
          })
          .onScrollStop(() => {
            this.snapToNearestTick();
          })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
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
              // 0.85 自然平滑拖动手感
              const targetScrollX = Math.max(0, currentScrollX - deltaX * 0.85);

              // 🎯 仅需驱动 Scroll，由 onScroll 统一极速响应 60fps 跟手缩放，避免重复触发
              this.rulerScroller.scrollTo({
                xOffset: targetScrollX,
                yOffset: 0
              });
            })
            .onActionEnd(() => {
              this.snapToNearestTick();
            })
        )

        // (5) 底部主操作按钮
        Button() {
          Row({ space: 6 }) {
            Text('开始专注旅程')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#F06553')
        .borderRadius(24)
        .shadow({ radius: 12, color: 'rgba(240, 101, 83, 0.45)', offsetY: 4 })
        .margin({ top: 6 })
        .onClick(() => {
          this.confirmSelection();
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 32, bottom: 28 })
      .linearGradient({
        angle: 180,
        colors: [
          ['rgba(10, 15, 26, 0.0)', 0.0],
          ['rgba(10, 15, 26, 0.28)', 0.22],
          ['rgba(10, 15, 26, 0.62)', 0.58],
          ['rgba(10, 15, 26, 0.86)', 1.0]
        ]
      })
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea, newArea) => {
      if (newArea.width && Number(newArea.width) > 0) {
        this.rulerContainerWidth = Number(newArea.width);
      }
    })
  }
}
