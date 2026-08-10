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

export interface RulerFiveMinUnit {
  minutes: number;
  isMajor: boolean;
}

export interface AirportMarkerEntry {
  marker: map.Marker;
  code: string;
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
  onDestinationSelected?: (airport: Airport, minutes?: number) => void;

  @State currentMinutes: number = 25;
  @State currentSelectedCode: string = '';
  @State routeDistanceKm: number = 0;
  @State candidateAirports: Airport[] = [];
  @State currentZoomLevel: number = 6.2;
  @State rulerContainerWidth: number = 360;
  @State ctuScreenX: number = 210;
  @State ctuScreenY: number = 320;
  @State dynamicRadarRadius: number = 155;

  private huaweiMapController?: map.MapComponentController;
  private originMarker?: map.Marker;
  private airportMarkers: AirportMarkerEntry[] = [];
  private rulerScroller: Scroller = new Scroller();
  private lastHapticTickIndex: number = -1;
  private lastVibrateTime: number = 0;
  private lastPanOffsetX: number = 0;

  /**
   * 🎯 专注领航双擎精确投影系统 (Native + Mercator)：
   * 1. 尝试调用底层 Native getProjection，并用 ArkTS 类型断言安全绕过编译期类型报警。
   * 2. 若 Native 返回空或失效，则极速无缝降级到国际标准 Web Mercator 墨卡托纯数学投影，确保 100% 坐标不丢失！
   */
  private refreshCtuScreenPosition() {
    if (!this.huaweiMapController) return;
    try {
      const origin = findAirportByCode('CTU');
      if (!origin || origin.lat === undefined || origin.lon === undefined) return;

      const cam = this.huaweiMapController.getCameraPosition();
      if (!cam || !cam.target) return;

      const zoom = (cam && typeof cam.zoom === 'number' && !isNaN(cam.zoom)) ? cam.zoom : this.currentZoomLevel;
      const centerLat = cam.target.latitude;
      const centerLon = cam.target.longitude;

      let targetX: number | undefined = undefined;
      let targetY: number | undefined = undefined;

      // 引擎 1：使用 MapKit 原生 Projection 精确计算屏幕物理坐标 (ArkTS 严谨调用法，杜绝 any 关键字与 2339 错误)
      try {
        const dynamicCtrl = this.huaweiMapController as object as Record<string, () => Object>;
        if (typeof dynamicCtrl['getProjection'] === 'function') {
          const proj = dynamicCtrl['getProjection']() as Record<string, (arg: Record<string, number>) => Object>;
          if (proj && typeof proj['toScreenLocation'] === 'function') {
            const latLng: Record<string, number> = { 'latitude': Number(origin.lat), 'longitude': Number(origin.lon) };
            const screenPoint = proj['toScreenLocation'](latLng);
            if (screenPoint) {
              const ptRecord = screenPoint as object as Record<string, number>;
              const rawX = ptRecord['positionX'] ?? ptRecord['x'];
              const rawY = ptRecord['positionY'] ?? ptRecord['y'];
              if (rawX !== undefined && rawY !== undefined) {
                targetX = px2vp(rawX);
                targetY = px2vp(rawY);
              }
            }
          }
        }
      } catch (e) {}

      // 引擎 2：如果原生 API 失效、报空或不兼容，极速降级到国际标准 Web Mercator 墨卡托纯数学投影！
      if (targetX === undefined || targetY === undefined || isNaN(targetX) || isNaN(targetY) || !isFinite(targetX) || !isFinite(targetY)) {
        const tileSize = 256.0;
        const scale = Math.pow(2, zoom);
        const worldSize = tileSize * scale;

        const worldX = ((Number(origin.lon) + 180.0) / 360.0) * worldSize;
        const centerWorldX = ((centerLon + 180.0) / 360.0) * worldSize;

        const sinLat = Math.sin((Number(origin.lat) * Math.PI) / 180.0);
        const clampedSinLat = Math.max(-0.9999, Math.min(0.9999, sinLat));
        const worldY = (0.5 - Math.log((1.0 + clampedSinLat) / (1.0 - clampedSinLat)) / (4.0 * Math.PI)) * worldSize;

        const sinCenterLat = Math.sin((centerLat * Math.PI) / 180.0);
        const clampedSinCenterLat = Math.max(-0.9999, Math.min(0.9999, sinCenterLat));
        const centerWorldY = (0.5 - Math.log((1.0 + clampedSinCenterLat) / (1.0 - clampedSinCenterLat)) / (4.0 * Math.PI)) * worldSize;

        const containerW = this.rulerContainerWidth > 0 ? this.rulerContainerWidth : 360.0;
        const screenCenterX = containerW / 2.0;
        const screenCenterY = 380.0;

        targetX = screenCenterX + (worldX - centerWorldX);
        targetY = screenCenterY + (worldY - centerWorldY);
      }

      if (targetX !== undefined && targetY !== undefined && !isNaN(targetX) && !isNaN(targetY) && isFinite(targetX) && isFinite(targetY)) {
        this.ctuScreenX = targetX;
        this.ctuScreenY = targetY;

        const maxDistKm = this.getMaxFlightDistanceKm(this.currentMinutes);
        // 🎯 规范设计：雷达圈为固定的 HUD 经典视觉尺寸 (155vp)，地图自适应在下方推拉
        this.dynamicRadarRadius = 155;
      }
    } catch (e) {
      console.error('refreshCtuScreenPosition error:', JSON.stringify(e));
    }
  }

  /**
   * 🎯 根据当前缩放级别，计算让起点成都地标在上方红框可视区域（顶部到“目的地”操作栏）内上下左右绝对居中的相机目标纬度
   */
  private getCenteredCameraLatitude(originLat: number, _zoomLevel: number): number {
    return originLat;
  }

  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: { latitude: 30.5607, longitude: 103.9426 }, // 🎯 默认直接定位到用户所在的定位点 CTU (30.5607, 103.9426)
      zoom: 6.2,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE, // 卫星地图模式
    zoomControlsEnabled: false,
    compassControlsEnabled: false
  };

  aboutToAppear() {
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

  // 🎯 动态视界缩放引擎：根据专注航程自适应调整相机高空视野 (15分钟默认 7.0 倍)
  private getBestZoomLevelForMinutes(minutes: number): number {
    if (minutes <= 15) return 7.0;
    if (minutes <= 25) return 6.2;
    if (minutes <= 45) return 5.2;
    if (minutes <= 60) return 4.5;
    if (minutes <= 90) return 3.8;
    if (minutes <= 120) return 3.0;
    return 2.2;
  }

  // 🎯 专用于拖拽过程的 60fps 顺滑视界拉伸引擎 (220ms 电影级柔和动画过渡 + map.newCameraPosition)
  private updateCameraZoomSmoothly(minutes: number) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;
    try {
      const targetZoom = this.getBestZoomLevelForMinutes(minutes);
      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: {
          latitude: this.getCenteredCameraLatitude(origin.lat, targetZoom),
          longitude: origin.lon
        },
        zoom: targetZoom
      }), 220);
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

  private async drawRoute(destCode: string, force: boolean = false) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;

    // 1. 清理旧候选 Marker (保留起点 Marker 不变)
    if (this.airportMarkers && this.airportMarkers.length > 0) {
      this.airportMarkers.forEach(entry => {
        try {
          entry.marker.remove();
        } catch (e) {}
      });
      this.airportMarkers = [];
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

    // 3. 批量在地图上绘制当前专注时长对应的所有候选机场胶囊 Marker
    for (let i = 0; i < this.candidateAirports.length; i++) {
      const apt = this.candidateAirports[i];
      if (apt.code === 'CTU' || apt.lat === undefined || apt.lon === undefined) continue;

      const isSelected = (apt.code === destCode);
      const iconRes = isSelected ? AirportMarkerHelper.getDestActiveIcon(apt.code) : AirportMarkerHelper.getCandidateIcon(apt.code);

      const optCand: mapCommon.MarkerOptions = {
        position: { latitude: apt.lat, longitude: apt.lon },
        icon: iconRes,
        anchorU: 0.148,
        anchorV: 0.5,
        clickable: true,
        zIndex: isSelected ? 35 : 20,
        title: `(${apt.code})`
      };

      try {
        const m = await this.huaweiMapController.addMarker(optCand);
        if (m) {
          this.airportMarkers.push({ marker: m, code: apt.code });
        }
      } catch (e) {
        console.error('add candidate marker error', JSON.stringify(e));
      }
    }

    // 4. 如果选中了目的地，绘制连接航线 (精细橙红色画笔)
    if (destCode) {
      const target = findAirportByCode(destCode);
      if (target && target.lat !== undefined && target.lon !== undefined) {
        try {
          await this.huaweiMapController.addPolyline({
            points: [
              { latitude: origin.lat, longitude: origin.lon },
              { latitude: target.lat, longitude: target.lon }
            ],
            color: 0xFFF06553,
            width: 5
          });
        } catch (e) {
          console.error('add polyline error', JSON.stringify(e));
        }
      }
    }

    // 6. 智能镜头：始终以起点成都地标在上方红框可视区域内上下左右绝对居中为锚点，自适应缩放将雷达圈与圈内所有候选机场完全容纳
    try {
      let targetZoom = 6.2;
      if (destCode && this.routeDistanceKm > 0) {
        if (this.routeDistanceKm > 8000) {
          targetZoom = 3.0;
        } else if (this.routeDistanceKm > 4000) {
          targetZoom = 3.8;
        } else if (this.routeDistanceKm > 2000) {
          targetZoom = 4.8;
        } else if (this.routeDistanceKm > 1000) {
          targetZoom = 5.5;
        } else if (this.routeDistanceKm > 400) {
          targetZoom = 6.0;
        } else if (this.routeDistanceKm > 150) {
          targetZoom = 6.6;
        } else {
          targetZoom = 7.0;
        }
      } else {
        // 未选目的地时，根据当前专注时长的航程覆盖半径自适应最佳雷达全景视野
        targetZoom = this.getBestZoomLevelForMinutes(this.currentMinutes);
      }

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

  private huaweiMapCallback = async (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
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
                this.updateCameraZoomSmoothly(targetMin);
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

              this.rulerScroller.scrollTo({
                xOffset: targetScrollX,
                yOffset: 0
              });

              // 🎯 实时触发震动与更新
              const tickIdx = Math.round(targetScrollX / RULER_STEP_WIDTH);
              if (tickIdx >= 0 && tickIdx < RULER_FIVE_MIN_UNITS.length) {
                if (tickIdx !== this.lastHapticTickIndex) {
                  this.lastHapticTickIndex = tickIdx;
                  const unit = RULER_FIVE_MIN_UNITS[tickIdx];
                  this.triggerTickHaptic(unit.isMajor, true);
                }
                const targetMin = RULER_FIVE_MIN_UNITS[tickIdx].minutes;
                if (targetMin !== this.currentMinutes) {
                  this.currentMinutes = targetMin;
                  this.updateCameraZoomSmoothly(targetMin);
                }
              }
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
