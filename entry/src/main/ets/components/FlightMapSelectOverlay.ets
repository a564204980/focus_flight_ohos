import { promptAction } from '@kit.ArkUI';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { vibrator } from '@kit.SensorServiceKit';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import { image } from '@kit.ImageKit';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { AirportMarkerHelper } from '../utils/AirportMarkerHelper';
import {
  ScreenVpPoint,
  AirportMarkerEntry,
  RULER_FIVE_MIN_UNITS,
  RULER_STEP_WIDTH,
  getMaxFlightDistanceKm,
  getContinuousZoomLevel,
  getCenteredCameraLatitude,
  getBearingDeg,
  filterAndSampleCandidateAirports,
  calculateBezierCurve
} from '../utils/FlightMapMathHelper';
import { CustomAirportMarkerBuilder } from './flight_map/CustomAirportMarkerBuilder';
import { RadarScanOverlay } from './flight_map/RadarScanOverlay';
import { FlightMapTopBar } from './flight_map/FlightMapTopBar';
import { FlightMapZoomControls } from './flight_map/FlightMapZoomControls';
import { FlightMapBottomPanel } from './flight_map/FlightMapBottomPanel';

export interface RadarPingWave {
  id: string;
  x: number;
  y: number;
  code: string;
}

export interface ScanTargetMarker {
  marker: map.Marker;
  code: string;
  lat: number;
  lon: number;
  bearing: number;
}

// 兼容旧导入，保持对外接口 100% 不变
export type { ScreenVpPoint, AirportMarkerEntry };
export { RULER_FIVE_MIN_UNITS, RULER_STEP_WIDTH };

@CustomDialog
export struct FlightMapSelectOverlay {
  controller?: CustomDialogController;
  @Prop selectedCode: string = '';
  @Prop initialMinutes: number = 15;
  onDestinationSelected?: (airport: Airport, minutes?: number) => void;

  // ── 地图状态 ──────────────────────────────────
  @State currentMinutes: number = 15;
  @State currentSelectedCode: string = '';
  @State routeDistanceKm: number = 0;
  @State candidateAirports: Airport[] = [];
  @State currentZoomLevel: number = 6.2;
  @State rulerContainerWidth: number = 360;
  @State ctuScreenX: number = 189;
  @State ctuScreenY: number = 339;
  @State dynamicRadarRadius: number = 155;
  @State isMapReady: boolean = false;
  @State mapOpacity: number = 0.0;
  @State scanAngle: number = 0;
  @State scanBeamOpacity: number = 1.0;
  @State activePingWaves: RadarPingWave[] = [];

  // ── 终点激活态覆盖层 ──────────────────────────
  @State destScreenX: number = 0;
  @State destScreenY: number = 0;
  @State destActiveOverlayVisible: boolean = false;
  @State destActiveOpacity: number = 0.0;
  @State activeDestCode: string = '';
  @State activeDestName: string = '';
  @State activeDestDist: number = 0;

  // ── 领航小飞机 ────────────────────────────────
  @State flightPlaneX: number = 0;
  @State flightPlaneY: number = 0;
  @State flightPlaneAngle: number = 0;
  @State isFlightPlaneVisible: boolean = false;
  @State flightPlaneScale: number = 1.0;
  @State flightPlaneOpacity: number = 1.0;

  // ── 私有字段 ──────────────────────────────────
  private huaweiMapController?: map.MapComponentController;
  private originMarker?: map.Marker;
  private airportMarkers: AirportMarkerEntry[] = [];
  private pendingScanTargets: ScanTargetMarker[] = [];
  private activeScanTimerIds: number[] = [];
  private currentPolyline?: Object;
  private rulerScroller: Scroller = new Scroller();
  private lastVibrateTime: number = 0;
  private lastSnappedMinutes: number = 15;
  private markerPixelMapCache: Map<string, image.PixelMap> = new Map();
  private scanStartTime: number = 0;

  // ── 地图初始化配置 ────────────────────────────
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: { latitude: 30.5607 - 1.82, longitude: 103.9426 },
      zoom: 5.54,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: false,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true,
    scrollGesturesEnabled: true
  };

  // ─────────────────────────────────────────────
  // 生命周期
  // ─────────────────────────────────────────────

  aboutToAppear() {
    this.currentMinutes = (this.initialMinutes && this.initialMinutes > 0) ? this.initialMinutes : 15;
    this.lastSnappedMinutes = this.currentMinutes;
    if (this.selectedCode) {
      this.currentSelectedCode = this.selectedCode;
      this.updateRouteDistance(this.currentSelectedCode);
    }
    this.updateCandidateAirports(this.currentMinutes);
    this.initRulerScroll();
  }

  aboutToDisappear() {
    if (this.currentPolyline) {
      try {
        const p = this.currentPolyline as object as Record<string, () => void>;
        if (typeof p['remove'] === 'function') p['remove']();
      } catch (e) {}
      this.currentPolyline = undefined;
    }
    this.airportMarkers.forEach(entry => {
      try { entry.marker.remove(); } catch (e) {}
    });
    this.airportMarkers = [];
    if (this.originMarker) {
      try { this.originMarker.remove(); } catch (e) {}
      this.originMarker = undefined;
    }
  }

  // ─────────────────────────────────────────────
  // 坐标投影
  // ─────────────────────────────────────────────

  /**
   * 经纬度转屏幕 vp 物理坐标转换引擎
   * 优先 Native Projection，备用 Mercator 数学投影
   */
  private latLngToScreenVp(lat: number, lon: number): ScreenVpPoint | null {
    if (!this.huaweiMapController) return null;
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
              return { x: px2vp(rawX), y: px2vp(rawY) };
            }
          }
        }
      }
    } catch (e) {}

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
      const screenCenterY = 305.0;
      const targetX = screenCenterX + (worldX - centerWorldX);
      const targetY = screenCenterY + (worldY - centerWorldY);
      if (!isNaN(targetX) && !isNaN(targetY) && isFinite(targetX) && isFinite(targetY)) {
        return { x: targetX, y: targetY };
      }
    } catch (e) {}
    return null;
  }

  /** 刷新 CTU 机场在屏幕上的物理 vp 坐标与雷达圈半径 */
  private refreshCtuScreenPosition() {
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;

    // 1. 实实时时将雷达中心 100% 精确磁吸贴合在 CTU 机场的屏幕真实投影点上
    const pt = this.latLngToScreenVp(Number(origin.lat), Number(origin.lon));
    if (pt && !isNaN(pt.x) && !isNaN(pt.y)) {
      this.ctuScreenX = pt.x;
      this.ctuScreenY = pt.y;
    } else {
      const containerW = this.rulerContainerWidth > 0 ? this.rulerContainerWidth : 360.0;
      this.ctuScreenX = containerW / 2.0;
      this.ctuScreenY = 305.0;
    }

    // 2. 墨卡托代数半径计算 (通过目标连贯缩放级别解耦，消除爆大/缩小跳变)
    const maxDistKm = getMaxFlightDistanceKm(this.currentMinutes);
    const latRad = Number(origin.lat) * Math.PI / 180.0;
    const cosLat = Math.cos(latRad);
    const dLonDeg = maxDistKm / (111.32 * (cosLat > 0.01 ? cosLat : 1.0));

    // 使用与 currentMinutes 同步的目标视口 Zoom 级别，消解时序交错造成的屏幕突变失真
    const targetZoom = getContinuousZoomLevel(this.currentMinutes);
    const scale = Math.pow(2, targetZoom);
    const worldSize = 256.0 * scale;
    const targetRadiusVp = dLonDeg * (worldSize / 360.0);

    if (!isNaN(targetRadiusVp) && targetRadiusVp > 20) {
      if (Math.abs(this.dynamicRadarRadius - targetRadiusVp) > 1.0) {
        animateTo({
          duration: 350,
          curve: Curve.EaseOut
        }, () => {
          this.dynamicRadarRadius = targetRadiusVp;
        });
      } else {
        this.dynamicRadarRadius = targetRadiusVp;
      }
    }
  }

  // ─────────────────────────────────────────────
  // 触感反馈
  // ─────────────────────────────────────────────

  private triggerTickHaptic(isMajor: boolean = false, isMedium: boolean = false) {
    const now = Date.now();
    if (now - this.lastVibrateTime < 25) return;
    this.lastVibrateTime = now;
    try {
      vibrator.startVibration({
        type: 'time',
        duration: isMajor ? 35 : (isMedium ? 20 : 10)
      }, { id: 0, usage: 'touch' });
    } catch (e) {}
  }

  // ─────────────────────────────────────────────
  // 刻度尺控制
  // ─────────────────────────────────────────────

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
    this.rulerScroller.scrollTo({
      xOffset: tickIdx * RULER_STEP_WIDTH,
      yOffset: 0,
      animation: { duration: 180, curve: Curve.FastOutSlowIn }
    });
    const targetMin = RULER_FIVE_MIN_UNITS[tickIdx].minutes;
    const isMinChanged = targetMin !== this.lastSnappedMinutes;
    this.currentMinutes = targetMin;
    if (isMinChanged) {
      this.lastSnappedMinutes = targetMin;
      this.updateCandidateAirports(targetMin);
      this.drawRoute(this.currentSelectedCode, true);
      this.updateCameraZoomSmoothly(targetMin);
    } else {
      this.updateCandidateAirports(targetMin);
    }
    this.refreshCtuScreenPosition();
  }

  // ─────────────────────────────────────────────
  // 相机与缩放
  // ─────────────────────────────────────────────

  private updateCameraZoomSmoothly(minutes: number) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;
    try {
      const targetZoom = getContinuousZoomLevel(minutes);
      this.currentZoomLevel = targetZoom;
      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: { latitude: getCenteredCameraLatitude(origin.lat), longitude: origin.lon },
        zoom: targetZoom
      }), 850);
    } catch (e) {}
  }

  private zoomIn() {
    if (!this.huaweiMapController) return;
    const target = Math.min(18, this.currentZoomLevel + 0.5);
    this.currentZoomLevel = target;
    const cam = this.huaweiMapController.getCameraPosition();
    this.huaweiMapController.animateCamera(map.newCameraPosition({
      target: cam?.target || { latitude: 30.5607, longitude: 103.9426 },
      zoom: target
    }), 300);
  }

  private zoomOut() {
    if (!this.huaweiMapController) return;
    try {
      const cam = this.huaweiMapController.getCameraPosition();
      const current = (cam && typeof cam.zoom === 'number') ? cam.zoom : this.currentZoomLevel;
      const target = Math.max(current - 0.5, 1.5);
      this.currentZoomLevel = parseFloat(target.toFixed(1));
      this.huaweiMapController.animateCamera({ zoom: target }, 300);
    } catch (e) {}
  }

  // ─────────────────────────────────────────────
  // 候选机场管理
  // ─────────────────────────────────────────────

  private updateCandidateAirports(minutes: number) {
    this.candidateAirports = filterAndSampleCandidateAirports(minutes, getBearingDeg);
    if (this.currentSelectedCode) {
      const exists = this.candidateAirports.some(apt => apt.code === this.currentSelectedCode);
      if (!exists) {
        this.currentSelectedCode = '';
        this.routeDistanceKm = 0;
      }
    }
    this.prewarmMarkerCache(this.candidateAirports);
  }

  private prewarmMarkerCache(airports: Airport[]) {
    if (!airports || airports.length === 0) return;
    const origin = findAirportByCode('CTU');
    airports.forEach(apt => {
      if (apt.code !== 'CTU' && apt.lat !== undefined && apt.lon !== undefined) {
        const dist = (origin && origin.lat !== undefined && origin.lon !== undefined)
          ? getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon)) : 0;
        this.generateMarkerPixelMap(apt.code, apt.city || apt.name, dist, true, false);
      }
    });
  }

  // ─────────────────────────────────────────────
  // 选择逻辑
  // ─────────────────────────────────────────────

  private selectMinutes(minutes: number, index?: number) {
    this.currentMinutes = minutes;
    this.lastSnappedMinutes = minutes;
    this.triggerTickHaptic(true);
    this.updateCandidateAirports(minutes);
    this.drawRoute(this.currentSelectedCode, true);
    this.updateCameraZoomSmoothly(minutes);
    this.refreshCtuScreenPosition();
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
    if (!targetCode) { this.routeDistanceKm = 0; return; }
    const origin = findAirportByCode('CTU');
    const target = findAirportByCode(targetCode);
    if (origin && target &&
        origin.lat !== undefined && origin.lon !== undefined &&
        target.lat !== undefined && target.lon !== undefined) {
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(target.lat), Number(target.lon));
      if (!isNaN(dist) && dist > 0) this.routeDistanceKm = dist;
    }
  }

  private confirmSelection() {
    if (!this.currentSelectedCode) {
      try { promptAction.showToast({ message: '请先选择目的地机场 🛫', duration: 2000 }); } catch (e) {}
      return;
    }
    const selected = findAirportByCode(this.currentSelectedCode);
    if (selected && this.onDestinationSelected) this.onDestinationSelected(selected, this.currentMinutes);
    if (this.controller) this.controller.close();
  }

  // ─────────────────────────────────────────────
  // 地标快照生成
  // ─────────────────────────────────────────────

  @Builder
  private snapshotMarkerBuilder(code: string, name: string, distanceKm: number, isSelected: boolean, isOrigin: boolean) {
    CustomAirportMarkerBuilder(code, name, distanceKm, isSelected, isOrigin);
  }

  private async generateMarkerPixelMap(
    code: string, name: string, distanceKm: number, isSelected: boolean, isOrigin: boolean = false
  ): Promise<image.PixelMap | undefined> {
    const cacheKey = isOrigin ? `${code}_orig` : (isSelected ? `${code}_dest` : `${code}_cand`);
    if (this.markerPixelMapCache.has(cacheKey)) return this.markerPixelMapCache.get(cacheKey);
    try {
      const pixmap: image.PixelMap = await componentSnapshot.createFromBuilder(() => {
        this.snapshotMarkerBuilder(code, name, distanceKm, isSelected, isOrigin);
      });
      if (pixmap) this.markerPixelMapCache.set(cacheKey, pixmap);
      return pixmap;
    } catch (e) {
      console.error(`generateMarkerPixelMap error for ${code}:`, JSON.stringify(e));
      return undefined;
    }
  }

  // ─────────────────────────────────────────────
  // 终点地标激活动效
  // ─────────────────────────────────────────────

  private async activateDestMarker(destCode: string) {
    if (!destCode || !this.huaweiMapController || !this.airportMarkers || this.airportMarkers.length === 0) return;
    const targetApt = findAirportByCode(destCode);
    if (!targetApt || targetApt.lat === undefined || targetApt.lon === undefined) return;

    const origin = findAirportByCode('CTU');
    const dist = (origin && origin.lat !== undefined && origin.lon !== undefined)
      ? getDistanceKm(Number(origin.lat), Number(origin.lon), Number(targetApt.lat), Number(targetApt.lon)) : 0;

    const pt = this.latLngToScreenVp(targetApt.lat, targetApt.lon);
    if (pt) { this.destScreenX = pt.x; this.destScreenY = pt.y; }

    this.activeDestCode = destCode;
    this.activeDestName = targetApt.city || targetApt.name;
    this.activeDestDist = dist;
    this.triggerTickHaptic(true, false);

    // 纯透明度平滑交叉淡入 (无任何缩放回弹)
    this.destActiveOverlayVisible = true;
    this.destActiveOpacity = 0.0;
    animateTo({
      duration: 250,
      curve: Curve.EaseOut,
      onFinish: () => {
        animateTo({
          duration: 120,
          curve: Curve.EaseOut,
          onFinish: () => { this.destActiveOverlayVisible = false; }
        }, () => { this.destActiveOpacity = 0.0; });
      }
    }, () => { this.destActiveOpacity = 1.0; });

    // 异步更新底层 MapKit Marker 贴图
    try {
      const activePix = await this.generateMarkerPixelMap(destCode, targetApt.city || targetApt.name, dist, true, false);
      const entryIdx = this.airportMarkers.findIndex(item => item.code === destCode);
      if (entryIdx !== -1) {
        const entry = this.airportMarkers[entryIdx];
        if (entry && entry.marker && activePix) {
          const dm = entry.marker as object as Record<string, (icon: image.PixelMap) => void>;
          if (typeof dm['setIcon'] === 'function') dm['setIcon'](activePix);
          const dmZ = entry.marker as object as Record<string, (z: number) => void>;
          if (typeof dmZ['setZIndex'] === 'function') dmZ['setZIndex'](35);
        }
      }
    } catch (e) {}
  }

  // ─────────────────────────────────────────────
  // 航线绘制与小飞机动画
  // ─────────────────────────────────────────────

  private async drawRoute(destCode: string, force: boolean = false) {
    if (!this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    if (!origin || origin.lat === undefined || origin.lon === undefined) return;

    // 清理旧 Polyline
    if (this.currentPolyline) {
      try {
        const p = this.currentPolyline as object as Record<string, () => void>;
        if (typeof p['remove'] === 'function') p['remove']();
      } catch (e) {}
      this.currentPolyline = undefined;
    }

    // CTU 起点地标（仅初始化一次）
    if (!this.originMarker) {
      try {
        const originPix = await this.generateMarkerPixelMap(origin.code, origin.city || origin.name, 0, false, true);
        const optOrigin: mapCommon.MarkerOptions = {
          position: { latitude: origin.lat, longitude: origin.lon },
          icon: originPix || $rawfile('textures/markers/mk_CTU_orig.png'),
          anchorU: 0.5, anchorV: 0.5, clickable: false, zIndex: 10, title: '(CTU)'
        };
        this.originMarker = await this.huaweiMapController.addMarker(optOrigin);
      } catch (e) {}
    }

    // 增量重用候选 Marker（0 闪烁、0 延迟）
    let renderList = this.candidateAirports.filter(apt =>
      apt.code !== 'CTU' && apt.lat !== undefined && apt.lon !== undefined
    ).slice(0, 8);

    const existingCodes = this.airportMarkers.map(m => m.code);
    const targetCodes = renderList.map(a => a.code);
    const isListSame = existingCodes.length === targetCodes.length &&
      existingCodes.every((val, i) => val === targetCodes[i]);

    if (isListSame && this.airportMarkers.length > 0) {
      for (let i = 0; i < renderList.length; i++) {
        const apt = renderList[i];
        const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
        const markerPix = await this.generateMarkerPixelMap(apt.code, apt.city || apt.name, dist, false, false);
        const entry = this.airportMarkers[i];
        if (entry && entry.marker) {
          try {
            if (markerPix) {
              const dm = entry.marker as object as Record<string, (icon: image.PixelMap) => void>;
              if (typeof dm['setIcon'] === 'function') dm['setIcon'](markerPix);
            }
            const dmZ = entry.marker as object as Record<string, (z: number) => void>;
            if (typeof dmZ['setZIndex'] === 'function') dmZ['setZIndex'](5);
          } catch (e) {}
        }
      }
    } else {
      this.airportMarkers.forEach(entry => { try { entry.marker.remove(); } catch (e) {} });
      this.airportMarkers = [];
      this.pendingScanTargets = [];

      // 1. 并发离屏快照生成
      const pixmapPromises = renderList.map(apt => {
        const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
        return this.generateMarkerPixelMap(apt.code, apt.city || apt.name, dist, false, false);
      });
      const pixmaps = await Promise.all(pixmapPromises);

      // 2. 将底册 Marker 写入地图 (初始完全透明 setAlpha(0.0))
      const ctrl = this.huaweiMapController;
      if (ctrl) {
        for (let i = 0; i < renderList.length; i++) {
          const apt = renderList[i];
          const markerPix = pixmaps[i];
          const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
          const optCand: mapCommon.MarkerOptions = {
            position: { latitude: apt.lat, longitude: apt.lon },
            icon: markerPix || AirportMarkerHelper.getCandidateIcon(apt.code),
            anchorU: 0.5, anchorV: 0.5, clickable: true, zIndex: 5, title: `(${apt.code})`
          };
          try {
            const m = await ctrl.addMarker(optCand);
            if (m) {
              try { m.setAlpha(0.0); } catch (e) {}
              const markerItem: AirportMarkerEntry = { marker: m, code: apt.code };
              this.airportMarkers.push(markerItem);
              if (apt.lat !== undefined && apt.lon !== undefined) {
                const bearing = getBearingDeg(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
                const scanItem: ScanTargetMarker = {
                  marker: m,
                  code: apt.code,
                  lat: Number(apt.lat),
                  lon: Number(apt.lon),
                  bearing: bearing
                };
                this.pendingScanTargets.push(scanItem);
              }
            }
          } catch (e) {}
        }
      }

      // 3. 🎯 仅在初始未扫频时启动扫频旋转，避免滑动刻度尺时重复打乱自旋角速度
      if (this.scanStartTime <= 0) {
        this.startRadarScanSequence();
      } else {
        this.schedulePendingScanPings();
      }
    }

    // 绘制贝塞尔航线流光 + 领航小飞机
    if (destCode) {
      const target = findAirportByCode(destCode);
      if (target && target.lat !== undefined && target.lon !== undefined) {
        try {
          const fullCurve = calculateBezierCurve(
            Number(origin.lat), Number(origin.lon),
            Number(target.lat), Number(target.lon)
          );
          const firstPt: mapCommon.LatLng = { latitude: Number(origin.lat), longitude: Number(origin.lon) };
          this.currentPolyline = await this.huaweiMapController.addPolyline({
            points: [firstPt], color: 0xFFF06553, width: 6, zIndex: 20
          }) as Object;

          const currentPolylineRef = this.currentPolyline;
          const polyObj = currentPolylineRef as object as Record<string, (points: mapCommon.LatLng[]) => void>;
          const totalSteps = 45;
          const totalFrames = 22;

          if (typeof polyObj['setPoints'] === 'function') {
            let frame = 1;
            const timerId = setInterval(() => {
              if (frame >= totalFrames || this.currentPolyline !== currentPolylineRef) {
                if (this.currentPolyline === currentPolylineRef) {
                  polyObj['setPoints'](fullCurve);
                  this.activateDestMarker(destCode);
                }
                this.isFlightPlaneVisible = false;
                clearInterval(timerId);
                return;
              }
              const progress = frame / totalFrames;
              const easeOut = 1 - Math.pow(1 - progress, 3);
              const targetIndex = Math.max(1, Math.floor(easeOut * totalSteps));
              polyObj['setPoints'](fullCurve.slice(0, targetIndex + 1));

              const headGeo = fullCurve[targetIndex];
              const prevGeo = fullCurve[Math.max(0, targetIndex - 1)];
              const bearing = (Math.atan2(
                headGeo.longitude - prevGeo.longitude,
                headGeo.latitude - prevGeo.latitude
              ) * 180 / Math.PI + 360) % 360;
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
        } catch (e) {}
      }
    }

    // 智能镜头：force=true 时平移
    if (force) {
      try {
        const targetZoom = getContinuousZoomLevel(this.currentMinutes);
        this.currentZoomLevel = targetZoom;
        this.huaweiMapController.animateCamera(map.newCameraPosition({
          target: { latitude: getCenteredCameraLatitude(origin.lat), longitude: origin.lon },
          zoom: targetZoom
        }), 700);
      } catch (e) {}
    }
  }

  private triggerRadarPingAt(code: string, lat: number, lon: number) {
    const pt = this.latLngToScreenVp(lat, lon);
    if (pt) {
      const pingId = `${code}_${Date.now()}`;
      const ping: RadarPingWave = { id: pingId, x: pt.x, y: pt.y, code: code };
      this.activePingWaves.push(ping);
      this.triggerTickHaptic(false, true);
      setTimeout(() => {
        this.activePingWaves = this.activePingWaves.filter(p => p.id !== pingId);
      }, 650);
    }
  }

  private startRadarScanSequence() {
    this.activeScanTimerIds.forEach(id => clearTimeout(id));
    this.activeScanTimerIds = [];

    if (this.pendingScanTargets) {
      this.pendingScanTargets.forEach(target => {
        const record = target as object as Record<string, boolean>;
        record['_scheduled'] = false;
        try { target.marker.setAlpha(0.0); } catch (e) {}
      });
    }

    this.scanStartTime = Date.now();
    this.scanAngle = 0;
    this.scanBeamOpacity = 1.0;

    // 1. 旋转动画延长至 1.5 圈 (540°)，全程 7800ms 匀速连续旋转，绝无停顿
    animateTo({
      duration: 7800,
      curve: Curve.Linear,
      onFinish: () => {
        this.scanBeamOpacity = 0.0;
      }
    }, () => {
      this.scanAngle = 540;
    });

    // 2. 满 1 圈 (5200ms / 360°) 时，启动半圈 (2600ms / 180°) 在旋转中平滑淡出动画
    const fadeTimerId = setTimeout(() => {
      animateTo({
        duration: 2600,
        curve: Curve.EaseOut
      }, () => {
        this.scanBeamOpacity = 0.0;
      });
    }, 5200);
    this.activeScanTimerIds.push(fadeTimerId);

    this.schedulePendingScanPings();
  }

  private schedulePendingScanPings() {
    if (this.scanStartTime <= 0 || !this.pendingScanTargets || this.pendingScanTargets.length === 0) return;
    const elapsed = Date.now() - this.scanStartTime;
    this.pendingScanTargets.forEach(target => {
      const record = target as object as Record<string, boolean>;
      if (record['_scheduled']) return;
      record['_scheduled'] = true;

      // 🎯 单圈 360° 旋转对应 5200ms，根据极坐标正北方位角精确匹配雷达划过该机场的时间点
      const revealDelay = Math.max(80, Math.min(5000, Math.round((target.bearing / 360.0) * 5200)));
      const remainingDelay = revealDelay - elapsed;

      if (remainingDelay <= 0) {
        try {
          target.marker.setAlpha(1.0);
          const mObj = target.marker as object as Record<string, Function>;
          if (typeof mObj['setVisible'] === 'function') mObj['setVisible'](true);
          this.triggerTickHaptic(false, true);
        } catch (e) {}
      } else {
        const timerId = setTimeout(() => {
          try {
            target.marker.setAlpha(1.0);
            const mObj = target.marker as object as Record<string, Function>;
            if (typeof mObj['setVisible'] === 'function') mObj['setVisible'](true);
            this.triggerTickHaptic(false, true);
          } catch (e) {}
        }, remainingDelay);
        this.activeScanTimerIds.push(timerId);
      }
    });
  }

  // ─────────────────────────────────────────────
  // 地图 Callback
  // ─────────────────────────────────────────────

  private huaweiMapCallback = async (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      try {
        const ctrlAny = controller as object as Record<string, Function>;
        if (typeof ctrlAny['setPadding'] === 'function') ctrlAny['setPadding'](88, 0, 420, 0);
      } catch (e) {}

      // 📍 映射控制器就绪瞬间同步计算 CTU 精确屏幕 VP 坐标，消除定位错位与二次平移动画
      this.refreshCtuScreenPosition();

      // ⚡⚡⚡ 同步挂载 UI 组件并标记地图就绪
      this.mapOpacity = 1.0;
      this.isMapReady = true;

      // 🎯 绘制航线与底册 Marker，Marker 批量就绪后精准同步启动雷达扫频
      await this.drawRoute(this.currentSelectedCode);
      this.refreshCtuScreenPosition();

      try {
        controller.on('markerClick', (markerObj: Object) => {
          try {
            const m = markerObj as map.Marker;
            if (m && this.airportMarkers && this.airportMarkers.length > 0) {
              const entry = this.airportMarkers.find(item => item.marker === m);
              if (entry && entry.code && entry.code !== 'CTU') this.selectCity(entry.code);
            }
          } catch (_e) {}
        });
      } catch (e) {}

      try {
        controller.on('cameraChange', (_data: Object) => {
          try {
            const cam = controller.getCameraPosition();
            if (cam && typeof cam.zoom === 'number' && !isNaN(cam.zoom)) {
              const newZoom = parseFloat(cam.zoom.toFixed(1));
              if (this.currentZoomLevel !== newZoom) this.currentZoomLevel = newZoom;
            }
            this.refreshCtuScreenPosition();
          } catch (_e) {}
        });
        const ctrlAny = controller as object as Record<string, Function>;
        if (typeof ctrlAny.on === 'function') {
          ctrlAny.on('cameraMove', (_data: Object) => {
            try { this.refreshCtuScreenPosition(); } catch (_e) {}
          });
        }
      } catch (e) {}
    }
  };

  // ─────────────────────────────────────────────
  // build()
  // ─────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 1. 原生花瓣卫星地图底图 (平滑 Fade-In 溶入，消除硬切闪烁)
      MapComponent({ mapOptions: this.huaweiMapOptions, mapCallback: this.huaweiMapCallback })
        .width('100%')
        .height('100%')
        .opacity(this.mapOpacity)
        .animation({ duration: 450, curve: Curve.EaseInOut })

      // 2. 专注航程测距指示圈（地图就绪后平滑淡入，包含 360° 单圈扫频与平滑淡出）
      if (this.isMapReady) {
        RadarScanOverlay({
          radius: this.dynamicRadarRadius,
          currentMinutes: this.currentMinutes,
          scanAngle: this.scanAngle,
          scanBeamOpacity: this.scanBeamOpacity
        })
          .position({ x: this.ctuScreenX, y: this.ctuScreenY })
          .markAnchor({ x: this.dynamicRadarRadius, y: this.dynamicRadarRadius })
          .opacity(this.isMapReady ? 1.0 : 0.0)
          .zIndex(10)
          .hitTestBehavior(HitTestMode.None)
      }

      // 3. 终点机场到达平滑渐变层（纯透明度交叉淡入，零回弹零脉冲）
      if (this.destActiveOverlayVisible) {
        Row({ space: 5 }) {
          Row().width(105)

          Stack({ alignContent: Alignment.Center }) {
            Column() {
              Row()
                .width(2).height(6)
                .backgroundColor('#FFFFFF').borderRadius(1).opacity(0.9)
              Blank()
              Row()
                .width(2).height(6)
                .backgroundColor('#FFFFFF').borderRadius(1).opacity(0.9)
            }
            .width(18).height(42)
            .padding({ top: 4, bottom: 4 })
            .alignItems(HorizontalAlign.Center)
            Image($r('app.media.ic_plane_topview'))
              .width(13).height(13)
              .objectFit(ImageFit.Contain)
              .fillColor('#FFFFFF')
          }
          .width(18).height(42)
          .backgroundColor('#451717').borderRadius(9)
          .border({ width: 1.5, color: '#E05A47' })
          .shadow({ radius: 8, color: 'rgba(224, 90, 71, 0.5)', offsetY: 1 })

          Column({ space: 0.5 }) {
            Text(this.activeDestCode)
              .fontSize(14).fontWeight(FontWeight.Bolder).fontColor('#F06553')
              .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })
            Text(this.activeDestName.endsWith('机场') ? this.activeDestName : `${this.activeDestName}机场`)
              .fontSize(11.5).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })
            Text(this.activeDestDist > 0 ? `目的地 · ${Math.round(this.activeDestDist)}km` : '目的地')
              .fontSize(9.5).fontWeight(FontWeight.Regular).fontColor('#FFB4A9')
              .textShadow({ radius: 2, color: '#000000', offsetX: 1, offsetY: 1 })
          }
          .width(105)
          .alignItems(HorizontalAlign.Start)
        }
        .width(238).height(46)
        .justifyContent(FlexAlign.Center)
        .position({ x: this.destScreenX, y: this.destScreenY })
        .markAnchor({ x: 119, y: 23 })
        .opacity(this.destActiveOpacity)
        .zIndex(27)
        .hitTestBehavior(HitTestMode.None)
      }

      // 4. 领航小飞机（沿航线切线极速飞行）
      if (this.isFlightPlaneVisible) {
        Image($r('app.media.ic_plane_topview'))
          .width(22).height(22)
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

      // 5. 顶部状态条
      FlightMapTopBar({
        selectedCode: this.currentSelectedCode,
        currentMinutes: this.currentMinutes,
        routeDistanceKm: this.routeDistanceKm,
        ctuScreenX: this.ctuScreenX,
        ctuScreenY: this.ctuScreenY,
        currentZoomLevel: this.currentZoomLevel,
        onClose: () => { if (this.controller) this.controller.close(); }
      })
      .position({ x: 0, y: 44 })

      // 6. 右侧缩放控制器
      FlightMapZoomControls({
        currentZoomLevel: this.currentZoomLevel,
        onZoomIn: () => { this.zoomIn(); },
        onZoomOut: () => { this.zoomOut(); }
      })
      .position({ x: '86%', y: 105 })

      // 7. 底部控制面板
      FlightMapBottomPanel({
        currentMinutes: this.currentMinutes,
        currentSelectedCode: this.currentSelectedCode,
        candidateAirports: this.candidateAirports,
        rulerContainerWidth: this.rulerContainerWidth,
        rulerScroller: this.rulerScroller,
        onSelectCity: (code: string) => { this.selectCity(code); },
        onSelectMinutes: (minutes: number, index: number) => { this.selectMinutes(minutes, index); },
        onScrollMinutesChange: (minutes: number) => {
          if (minutes !== this.currentMinutes) {
            this.currentMinutes = minutes;
            this.updateCandidateAirports(minutes);
            this.refreshCtuScreenPosition();
          }
        },
        onScrollStop: () => { this.snapToNearestTick(); },
        onConfirm: () => { this.confirmSelection(); },
        onRulerWidthChange: (w: number) => { this.rulerContainerWidth = w; }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1A263B')
    .onAreaChange((_oldArea, newArea) => {
      if (newArea.width && Number(newArea.width) > 0) {
        this.rulerContainerWidth = Number(newArea.width);
        this.refreshCtuScreenPosition();
      }
    })
  }
}

@Component
struct RadarPingWaveItem {
  @State scaleValue: number = 0.2;
  @State opacityValue: number = 0.85;

  aboutToAppear() {
    animateTo({
      duration: 600,
      curve: Curve.EaseOut
    }, () => {
      this.scaleValue = 1.8;
      this.opacityValue = 0.0;
    });
  }

  build() {
    Stack()
      .width(48)
      .height(48)
      .borderRadius(24)
      .border({ width: 1.5, color: '#F06553' })
      .shadow({ radius: 8, color: 'rgba(240, 101, 83, 0.6)', offsetY: 0 })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .opacity(this.opacityValue)
  }
}

