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
  private radarZoom: number = 6.2;     // 专用于雷达半径视觉大小计算（目标预期缩放）
  private rulerAnimatingUntil: number = 0;
  private isRulerDragging: boolean = false;
  private rulerDraggingTimeout: number = 0;
  @State rulerContainerWidth: number = 360;
  @State ctuScreenX: number = 189;
  @State ctuScreenY: number = 339;
  @State dynamicRadarRadius: number = 155;
  @State isMapReady: boolean = false;
  @State mapOpacity: number = 0.0;
  @State scanAngle: number = 0;
  @State scanBeamOpacity: number = 1.0;
  @State activePingWaves: RadarPingWave[] = [];

  // ── 终点激活态覆盖层与平滑渐变 ────────────────
  @State destScreenX: number = 0;
  @State destScreenY: number = 0;
  @State destActiveOverlayVisible: boolean = false;
  @State destActiveOpacity: number = 1.0;
  @State destActiveScale: number = 1.0;
  @State activeDestCode: string = '';
  @State activeDestName: string = '';
  @State activeDestDist: number = 0;
  
  // 🎨 动态颜色渐变状态 (从候选蓝灰平滑渐变到激活珊瑚红)
  @State destCapsuleBg: string = '#0B1726';
  @State destCapsuleBorder: string = '#317393';
  @State destCapsuleShadow: string = 'rgba(11, 23, 38, 0.5)';
  @State destCodeColor: string = '#FFFFFF';
  @State destTagColor: string = 'rgba(255, 255, 255, 0.72)';
  @State destPlaneFill: string = '#FFFFFF';
  @State destTagText: string = '候选航线';

  // ── 领航小飞机 ────────────────────────────────
  @State flightPlaneX: number = 0;
  @State flightPlaneY: number = 0;
  @State flightPlaneAngle: number = 0;
  @State isFlightPlaneVisible: boolean = false;
  @State flightPlaneScale: number = 1.0;
  @State flightPlaneOpacity: number = 1.0;

  // ── 主动退场动画控制 (杜绝系统 Dialog 默认中心缩放) ──────
  @State overlayOffsetY: number = 0;
  private isClosing: boolean = false;

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
    this.radarZoom = getContinuousZoomLevel(this.currentMinutes); // 初始化雷达缩放基准，确保首次渲染半径正确
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

    // 1. 实时将雷达中心磁吸贴合在 CTU 机场的屏幕真实投影点上
    const ptCenter = this.latLngToScreenVp(Number(origin.lat), Number(origin.lon));
    if (ptCenter && !isNaN(ptCenter.x) && !isNaN(ptCenter.y)) {
      this.ctuScreenX = ptCenter.x;
      this.ctuScreenY = ptCenter.y;
    } else {
      const containerW = this.rulerContainerWidth > 0 ? this.rulerContainerWidth : 360.0;
      this.ctuScreenX = containerW / 2.0;
      this.ctuScreenY = 305.0;
    }

    // 防御性清理超时的拖动状态
    if (this.isRulerDragging && Date.now() > this.rulerDraggingTimeout) {
      this.isRulerDragging = false;
    }

    // 以"刻度尺目标 zoom"或真实 zoom 为基准计算半径
    let renderZoom = this.radarZoom > 0 ? this.radarZoom : this.currentZoomLevel;
    if (!this.isRulerDragging && Date.now() > this.rulerAnimatingUntil) {
      try {
        if (this.huaweiMapController) {
          const cam = this.huaweiMapController.getCameraPosition();
          if (cam && typeof cam.zoom === 'number' && !isNaN(cam.zoom)) {
            renderZoom = cam.zoom;
          }
        }
      } catch(e) {}
    }

    const maxDistKm = getMaxFlightDistanceKm(this.currentMinutes);
    const latRad = Number(origin.lat) * Math.PI / 180.0;
    const cosLat = Math.cos(latRad);
    const dLonDeg = maxDistKm / (111.32 * (cosLat > 0.01 ? cosLat : 1.0));

    // 优先尝试基于起点 CTU 的真实屏幕投影采样测距 (正东边缘点)
    let calculatedRadius: number = -1;
    const ptEdge = this.latLngToScreenVp(Number(origin.lat), Number(origin.lon) + dLonDeg);
    if (ptCenter && ptEdge && !isNaN(ptCenter.x) && !isNaN(ptEdge.x)) {
      const projDist = Math.abs(ptEdge.x - ptCenter.x);
      if (projDist > 10 && projDist < 3000) {
        calculatedRadius = projDist;
      }
    }

    // 若投影采样点超出视口或尚未准备就绪，使用第一性原理推导的标准墨卡托降级公式:
    // radius_vp = maxDistKm * (256 * 2^zoom) / 40075.16
    if (calculatedRadius <= 0) {
      calculatedRadius = (maxDistKm * 256.0 * Math.pow(2, renderZoom)) / 40075.16;
    }

    // 🌟 自适应雷达包络 (Adaptive Radar Envelope)：
    // 在墨卡托高纬度拉伸影响下，遍历当前候选机场在屏幕上的 VP 距离。
    // 取所有候选机场最大的屏幕 VP 距离 * 1.05 作为半径包络上限，
    // 确保如圣彼得堡（LED）等高纬度机场被刚好包覆在雷达圈内边缘。
    if (ptCenter && !isNaN(ptCenter.x) && !isNaN(ptCenter.y) && this.candidateAirports && this.candidateAirports.length > 0) {
      let maxCandidateVpDist = 0;
      this.candidateAirports.forEach(apt => {
        if (apt.lat !== undefined && apt.lon !== undefined && apt.code !== 'CTU') {
          const aptPt = this.latLngToScreenVp(Number(apt.lat), Number(apt.lon));
          if (aptPt && !isNaN(aptPt.x) && !isNaN(aptPt.y)) {
            const dx = aptPt.x - ptCenter.x;
            const dy = aptPt.y - ptCenter.y;
            const vpDist = Math.sqrt(dx * dx + dy * dy);
            if (!isNaN(vpDist) && vpDist > maxCandidateVpDist) {
              maxCandidateVpDist = vpDist;
            }
          }
        }
      });

      if (maxCandidateVpDist > 0) {
        const envelopeRadius = maxCandidateVpDist * 1.05;
        if (envelopeRadius > calculatedRadius) {
          calculatedRadius = envelopeRadius;
        }
      }
    }

    if (!isNaN(calculatedRadius) && calculatedRadius > 20) {
      this.dynamicRadarRadius = calculatedRadius;
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
      this.updateCameraZoomSmoothly(targetMin);  // 同时更新 radarZoom（在内部完成）
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
      this.radarZoom = targetZoom;  // ← 立即锁定雷达半径到目标值，不受后续动画帧影响
      this.rulerAnimatingUntil = Date.now() + 950;
      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: { latitude: getCenteredCameraLatitude(origin.lat, targetZoom), longitude: origin.lon },
        zoom: targetZoom
      }), 850);

      // 当 SDK 最小 zoom（约 2.0）小于目标 zoom 时，animateCamera 被拒绝，地图不动，
      // 因此 cameraChange 事件不会触发，rulerAnimatingUntil 到期后圆圈不会自动更新。
      // 这里补一个 970ms 的延迟刷新，确保动画窗口结束后雷达圈能自动放大到正确尺寸，
      // 无需用户手动触碰地图触发 cameraChange。
      setTimeout(() => {
        this.refreshCtuScreenPosition();
      }, 970);
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
  // 候选机场管理与取消选中
  // ─────────────────────────────────────────────

  /** 清除当前选中的目的机场、航线与顶层悬浮高亮 */
  private clearSelection() {
    this.currentSelectedCode = '';
    this.routeDistanceKm = 0;
    this.activeDestCode = '';
    this.activeDestName = '';
    this.activeDestDist = 0;
    this.destActiveOverlayVisible = false;
    this.destActiveOpacity = 0.0;

    // 清除 Polyline 航线
    if (this.currentPolyline) {
      try {
        const p = this.currentPolyline as object as Record<string, () => void>;
        if (typeof p['remove'] === 'function') p['remove']();
      } catch (e) {}
      this.currentPolyline = undefined;
    }

    // 恢复所有 Marker 为可见普通态
    if (this.airportMarkers) {
      this.airportMarkers.forEach(entry => {
        try { entry.marker.setAlpha(1.0); } catch (e) {}
      });
    }
  }

  private updateCandidateAirports(minutes: number) {
    this.candidateAirports = filterAndSampleCandidateAirports(minutes, getBearingDeg);
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
    if (minutes !== this.currentMinutes) {
      this.clearSelection();
    }
    this.currentMinutes = minutes;
    this.lastSnappedMinutes = minutes;
    this.triggerTickHaptic(true);
    this.updateCandidateAirports(minutes);
    this.drawRoute('', true);
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
    // 立即重置上一个机场的悬浮层，杜绝旧文字残留到新机场上
    this.destActiveOverlayVisible = false;
    this.destActiveOpacity = 0.0;
    if (this.airportMarkers) {
      this.airportMarkers.forEach(entry => {
        try { entry.marker.setAlpha(1.0); } catch (e) {}
      });
    }

    this.currentSelectedCode = code;
    this.updateRouteDistance(code);
    this.drawRoute(code);
    this.focusCameraBetweenOriginAndDest(code);
  }

  /**
   * 智能相机聚焦：自动计算起点 CTU 与选中的目的地中点及自适应 Zoom，
   * 确保起点和目的地全览同屏呈现在上半部分视口中。
   */
  private focusCameraBetweenOriginAndDest(destCode: string) {
    if (!destCode || !this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    const dest = findAirportByCode(destCode);
    if (!origin || !dest || origin.lat === undefined || origin.lon === undefined || dest.lat === undefined || dest.lon === undefined) return;

    try {
      const lat1 = Number(origin.lat);
      const lon1 = Number(origin.lon);
      const lat2 = Number(dest.lat);
      const lon2 = Number(dest.lon);

      let dLon = lon2 - lon1;
      if (dLon > 180) dLon -= 360;
      else if (dLon < -180) dLon += 360;

      const centerLat = (lat1 + lat2) / 2.0;
      let centerLon = lon1 + dLon / 2.0;
      while (centerLon > 180) centerLon -= 360;
      while (centerLon < -180) centerLon += 360;

      const distKm = getDistanceKm(lat1, lon1, lat2, lon2);

      // 计算恰好将起终点全览并留出边距的视口 Zoom
      let fitZoom = Math.log2(18000.0 / Math.max(100, distKm));
      fitZoom = Math.max(1.8, Math.min(6.2, fitZoom));

      // 考虑屏幕下半部 BottomPanel 遮挡，将中心点 Latitude 稍微向上避让（减去度数偏移）
      const degPerPixel = 360.0 / (256.0 * Math.pow(2, fitZoom));
      const adjustedLat = centerLat - (35.0 * degPerPixel);

      this.currentZoomLevel = parseFloat(fitZoom.toFixed(1));
      this.radarZoom = fitZoom;
      this.rulerAnimatingUntil = Date.now() + 850;

      this.huaweiMapController.animateCamera(map.newCameraPosition({
        target: { latitude: adjustedLat, longitude: centerLon },
        zoom: fitZoom
      }), 750);

      setTimeout(() => {
        this.refreshCtuScreenPosition();
      }, 800);
    } catch (e) {}
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

  /** 优雅向下滑出并安全关闭 Dialog (消除系统缩放干扰) */
  private handleClose() {
    if (this.isClosing) return;
    this.isClosing = true;
    this.getUIContext()?.animateTo({
      duration: 320,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        if (this.controller) {
          this.controller.close();
        }
      }
    }, () => {
      this.overlayOffsetY = 1000;
    });
  }

  private confirmSelection() {
    if (!this.currentSelectedCode) {
      try { promptAction.showToast({ message: '请先选择目的地机场 🛫', duration: 2000 }); } catch (e) {}
      return;
    }
    const selected = findAirportByCode(this.currentSelectedCode);
    if (selected && this.onDestinationSelected) this.onDestinationSelected(selected, this.currentMinutes);
    this.handleClose();
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

  /** 刷新选中的目的地机场在屏幕上的物理 vp 坐标 */
  private refreshDestScreenPosition() {
    if (this.currentSelectedCode && this.destActiveOverlayVisible && this.activeDestCode === this.currentSelectedCode) {
      const dest = findAirportByCode(this.currentSelectedCode);
      if (dest && dest.lat !== undefined && dest.lon !== undefined) {
        const pt = this.latLngToScreenVp(Number(dest.lat), Number(dest.lon));
        if (pt && !isNaN(pt.x) && !isNaN(pt.y)) {
          this.destScreenX = pt.x;
          this.destScreenY = pt.y;
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // 终点地标激活动效 (弹性浮跃 + 脉冲扩散 + 触感反馈)
  // ─────────────────────────────────────────────

  private async activateDestMarker(destCode: string) {
    if (!destCode || !this.huaweiMapController) return;
    const origin = findAirportByCode('CTU');
    const targetApt = findAirportByCode(destCode);
    if (!targetApt || targetApt.lat === undefined || targetApt.lon === undefined) return;

    this.activeDestCode = destCode;
    this.activeDestName = targetApt.city || targetApt.name;
    const targetDist = (origin && origin.lat !== undefined && origin.lon !== undefined)
      ? getDistanceKm(Number(origin.lat), Number(origin.lon), Number(targetApt.lat), Number(targetApt.lon)) : 0;
    this.activeDestDist = targetDist;

    // 1. 计算屏幕投影坐标并启动无缝接管与平滑色彩渐变动效
    const screenPt = this.latLngToScreenVp(Number(targetApt.lat), Number(targetApt.lon));
    if (screenPt && !isNaN(screenPt.x) && !isNaN(screenPt.y)) {
      this.destScreenX = screenPt.x;
      this.destScreenY = screenPt.y;

      // 阶段一：初始以 100% 候选蓝灰原色无缝覆盖底层 Marker
      this.destCapsuleBg = '#0B1726';
      this.destCapsuleBorder = '#317393';
      this.destCapsuleShadow = 'rgba(11, 23, 38, 0.5)';
      this.destCodeColor = '#FFFFFF';
      this.destTagColor = 'rgba(255, 255, 255, 0.72)';
      this.destPlaneFill = '#FFFFFF';
      this.destTagText = '候选航线';
      this.destActiveScale = 1.0;
      this.destActiveOpacity = 1.0;
      this.destActiveOverlayVisible = true;

      // 瞬间隐藏底层目标 Marker，由悬浮层无缝接管
      if (this.airportMarkers) {
        const currentEntry = this.airportMarkers.find(e => e.code === destCode);
        if (currentEntry) {
          try { currentEntry.marker.setAlpha(0.0); } catch (e) {}
        }
      }

      // 阶段二：启动 320ms 平滑色彩渗透与微弹性跃升 (蓝灰 -> 珊瑚红)
      this.getUIContext()?.animateTo({
        duration: 320,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.destCapsuleBg = '#451717';
        this.destCapsuleBorder = '#E05A47';
        this.destCapsuleShadow = 'rgba(224, 90, 71, 0.6)';
        this.destCodeColor = '#F06553';
        this.destTagColor = '#FFB4A9';
        this.destPlaneFill = '#FFB4A9';
        this.destTagText = '目的地';
        this.destActiveScale = 1.12;
      });

      // 阶段三：微弹跳回弹收敛至 1.0
      setTimeout(() => {
        this.getUIContext()?.animateTo({
          duration: 180,
          curve: Curve.EaseOut
        }, () => {
          this.destActiveScale = 1.0;
        });
      }, 320);
    }

    // 3. 伴随触感振动反馈
    this.triggerTickHaptic(true, false);

    // 4. 同步恢复其他非目标 Marker 的普通候选态
    if (this.airportMarkers && this.airportMarkers.length > 0) {
      for (const entry of this.airportMarkers) {
        const isTarget = entry.code === destCode;
        const apt = findAirportByCode(entry.code);
        if (!apt || apt.lat === undefined || apt.lon === undefined) continue;

        if (!isTarget) {
          const dist = (origin && origin.lat !== undefined && origin.lon !== undefined)
            ? getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon)) : 0;

          try {
            const pix = await this.generateMarkerPixelMap(entry.code, apt.city || apt.name, dist, false, false);
            if (entry.marker) {
              if (pix) {
                const dm = entry.marker as object as Record<string, (icon: image.PixelMap) => void>;
                if (typeof dm['setIcon'] === 'function') dm['setIcon'](pix);
              }
              const dmZ = entry.marker as object as Record<string, (z: number) => void>;
              if (typeof dmZ['setZIndex'] === 'function') dmZ['setZIndex'](5);
              entry.marker.setAlpha(1.0);
            }
          } catch (e) {}
        }
      }
    }
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

    // 增量重用与平滑 Fade-In / Fade-Out 候选 Marker
    let renderList = this.candidateAirports.filter(apt =>
      apt.code !== 'CTU' && apt.lat !== undefined && apt.lon !== undefined
    ).slice(0, 8);

    const targetCodes = renderList.map(a => a.code);
    const oldMarkers = this.airportMarkers.slice();
    const keptMarkers: AirportMarkerEntry[] = [];
    const removedMarkers: AirportMarkerEntry[] = [];

    // 1. 分离保留与退场的旧 Marker
    oldMarkers.forEach(entry => {
      if (targetCodes.includes(entry.code)) {
        keptMarkers.push(entry);
      } else {
        removedMarkers.push(entry);
      }
    });

    // 2. 超出航程退场的 Marker 优雅淡出 (Fade-Out)
    removedMarkers.forEach(entry => {
      try { entry.marker.setAlpha(0.0); } catch (e) {}
      setTimeout(() => {
        try { entry.marker.remove(); } catch (e) {}
      }, 300);
    });

    // 3. 找出完全新增的机场
    const keptCodes = keptMarkers.map(m => m.code);
    const newAirports = renderList.filter(apt => !keptCodes.includes(apt.code));

    this.airportMarkers = keptMarkers;

    // 4. 为新机场并发生成离屏快照与挂载
    if (newAirports.length > 0 && this.huaweiMapController) {
      const pixmapPromises = newAirports.map(apt => {
        const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
        return this.generateMarkerPixelMap(apt.code, apt.city || apt.name, dist, false, false);
      });
      const pixmaps = await Promise.all(pixmapPromises);
      const ctrl = this.huaweiMapController;

      for (let i = 0; i < newAirports.length; i++) {
        const apt = newAirports[i];
        const markerPix = pixmaps[i];
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

            // 柔和 Fade-In 渐变入场（如果初始扫频已过，按阶梯优雅错开淡入）
            if (this.scanStartTime > 0) {
              setTimeout(() => {
                try {
                  m.setAlpha(1.0);
                  this.triggerTickHaptic(false, true);
                } catch (e) {}
              }, 120 + i * 80);
            }
          }
        } catch (e) {}
      }
    }

    // 5. 重新配置待扫描目标列表并进行柔和显现
    this.pendingScanTargets = [];
    this.airportMarkers.forEach(entry => {
      const apt = renderList.find(a => a.code === entry.code);
      if (apt && apt.lat !== undefined && apt.lon !== undefined && origin && origin.lat !== undefined && origin.lon !== undefined) {
        const bearing = getBearingDeg(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
        this.pendingScanTargets.push({
          marker: entry.marker,
          code: entry.code,
          lat: Number(apt.lat),
          lon: Number(apt.lon),
          bearing: bearing
        });
      }
    });

    if (this.scanStartTime <= 0) {
      this.startRadarScanSequence();
    } else {
      this.schedulePendingScanPings();
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

    // 智能镜头：force=true 时的相机缩放由外部 updateCameraZoomSmoothly() 统一负责，
    // 此处不再重复调用 animateCamera，避免与外部动画相互打断产生雷达跳变
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

      // ⚡⚡⚡ 地图就绪后延迟淡入，等待界面进场动画先行完成
      setTimeout(() => {
        this.mapOpacity = 1.0;
        this.isMapReady = true;
      }, 200);

      // 🎯 绘制航线与底册 Marker，Marker 批量就绪后精准同步启动雷达扫频
      await this.drawRoute(this.currentSelectedCode);
      this.refreshCtuScreenPosition();

      try {
        controller.on('markerClick', (markerObj: Object) => {
          try {
            if (!markerObj) return;
            const m = markerObj as object as Record<string, Function>;
            let clickedCode: string = '';

            // 1. 优先尝试从 title 了解机场代码 (如 "(BNE)")
            if (typeof m['getTitle'] === 'function') {
              const titleStr = String(m['getTitle']());
              const match = titleStr.match(/\(([A-Z]{3})\)/);
              if (match && match[1]) clickedCode = match[1];
            }

            // 2. 若 title 未解析出，通过 getId() 或对象映射二次比对
            if (!clickedCode && this.airportMarkers && this.airportMarkers.length > 0) {
              const entry = this.airportMarkers.find(item => {
                if (item.marker === (markerObj as map.Marker)) return true;
                try {
                  const itemM = item.marker as object as Record<string, Function>;
                  if (typeof itemM['getId'] === 'function' && typeof m['getId'] === 'function') {
                    return itemM['getId']() === m['getId']();
                  }
                } catch (e) {}
                return false;
              });
              if (entry) clickedCode = entry.code;
            }

            // 3. 成功识别点击的机场并触发全套连线、缩放与选中联动
            if (clickedCode && clickedCode !== 'CTU') {
              this.selectCity(clickedCode);
            }
          } catch (_e) {}
        });
      } catch (e) {}

      try {
        controller.on('cameraChange', (_data: Object) => {
          try {
            const cam = controller.getCameraPosition();
            if (cam && typeof cam.zoom === 'number' && !isNaN(cam.zoom)) {
              const newZoom = parseFloat(cam.zoom.toFixed(2));
              if (this.currentZoomLevel !== newZoom) this.currentZoomLevel = newZoom;
              // 如果刻度尺动画锁已过期，说明是用户在手动操作（平移或捏合缩放）
              // 实时同步 radarZoom 为实际 zoom，确保雷达圈自然跟随地图缩放
              if (Date.now() > this.rulerAnimatingUntil) {
                this.radarZoom = newZoom;
              }
            }
            this.refreshCtuScreenPosition();
            this.refreshDestScreenPosition();
          } catch (_e) {}
        });
        const ctrlAny = controller as object as Record<string, Function>;
        if (typeof ctrlAny.on === 'function') {
          ctrlAny.on('cameraMove', (_data: Object) => {
            try { 
              this.refreshCtuScreenPosition(); 
              this.refreshDestScreenPosition();
            } catch (_e) {}
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
        .borderRadius({ topLeft: 24, topRight: 24 })
        .opacity(this.mapOpacity)
        .animation({ duration: 350, curve: Curve.EaseOut })

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

      // 3. 终点机场到达平滑渐变与弹性浮跃层
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
              .fillColor(this.destPlaneFill)
              .animation({ duration: 320, curve: Curve.FastOutSlowIn })
          }
          .width(18).height(42)
          .backgroundColor(this.destCapsuleBg)
          .borderRadius(9)
          .border({ width: 1.5, color: this.destCapsuleBorder })
          .shadow({ radius: 10, color: this.destCapsuleShadow, offsetY: 1 })
          .animation({ duration: 320, curve: Curve.FastOutSlowIn })

          Column({ space: 0.5 }) {
            Text(this.activeDestCode)
              .fontSize(14).fontWeight(FontWeight.Bolder).fontColor(this.destCodeColor)
              .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })
              .animation({ duration: 320, curve: Curve.FastOutSlowIn })

            Text(this.activeDestName.endsWith('机场') ? this.activeDestName : `${this.activeDestName}机场`)
              .fontSize(11.5).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })

            Text(this.activeDestDist > 0 ? `${this.destTagText} · ${Math.round(this.activeDestDist)}km` : this.destTagText)
              .fontSize(9.5).fontWeight(FontWeight.Regular).fontColor(this.destTagColor)
              .textShadow({ radius: 2, color: '#000000', offsetX: 1, offsetY: 1 })
              .animation({ duration: 320, curve: Curve.FastOutSlowIn })
          }
          .width(105)
          .alignItems(HorizontalAlign.Start)
        }
        .width(238).height(46)
        .justifyContent(FlexAlign.Center)
        .position({ x: this.destScreenX, y: this.destScreenY })
        .markAnchor({ x: 119, y: 23 })
        .scale({ x: this.destActiveScale, y: this.destActiveScale })
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

      // 5. 顶部状态条 (含左上角 HUD 水晶返回按钮)
      FlightMapTopBar({
        selectedCode: this.currentSelectedCode,
        currentMinutes: this.currentMinutes,
        routeDistanceKm: this.routeDistanceKm,
        ctuScreenX: this.ctuScreenX,
        ctuScreenY: this.ctuScreenY,
        currentZoomLevel: this.currentZoomLevel,
        onClose: () => { this.handleClose(); }
      })
      .position({ x: 0, y: 52 })


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
            this.clearSelection();
            this.isRulerDragging = true;
            this.rulerDraggingTimeout = Date.now() + 1500;
            this.currentMinutes = minutes;
            this.radarZoom = getContinuousZoomLevel(minutes); // 与 currentMinutes 同步更新，防止半径计算失真
            this.updateCandidateAirports(minutes);
            this.drawRoute('', true);
            this.refreshCtuScreenPosition();
          }
        },
        onScrollStop: () => { 
          this.isRulerDragging = false;
          this.snapToNearestTick(); 
        },
        onConfirm: () => { this.confirmSelection(); },
        onRulerWidthChange: (w: number) => { this.rulerContainerWidth = w; }
      })
    }
    .width('100%')
    .height('100%')
    .borderRadius({ topLeft: 24, topRight: 24 })
    .linearGradient({
      angle: 180,
      colors: [
        ['#1E293B', 0.0],
        ['#0F172A', 1.0]
      ]
    })
    .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.45)', offsetY: -6 })
    .translate({ y: this.overlayOffsetY })
    // ✈️ Dialog 内容本体的进场空间动画：从屏幕底部平滑推入
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 800 }))
        .animation({ duration: 360, curve: Curve.FastOutSlowIn })
    )
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

