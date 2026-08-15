import { display, promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { image } from '@kit.ImageKit';
import { displaySync } from '@kit.ArkGraphics2D';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { HomeFocusPanel } from '../components/HomeFocusPanel';
import { CabinInteriorOverlay } from '../components/CabinInteriorOverlay';
import { CyberMapHudControl } from '../components/CyberMapHudControl';
import { HeaderGreetingBar } from '../components/HeaderGreetingBar';
import { GroundServiceVehiclesOverlay } from '../components/GroundServiceVehiclesOverlay';
import { CyberThemeSelector } from '../components/CyberThemeSelector';
import { PlaneCabinShellOverlay } from '../components/PlaneCabinShellOverlay';
import { MapRenderHelper } from '../utils/MapRenderHelper';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';
import {
  LatLngPoint,
  interpolateLatLng
} from '../utils/GeodesicUtils';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';

// ✈️ 动态从 ctuAirportConfig 直接读取起飞跑道起点与终点，100% 实时响应 ctu.ets 的任何修改！
function getCtuRunwayStart(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
}

function getCtuRunwayEnd(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };
}

const CTU_RUNWAY_BEARING: number = ctuAirportConfig.runwayAngle ?? 158;

// ✈️ 默认飞行终点：北京首都国际机场 (PEK) 跑道数据（用于三阶段航线无缝连接）
function getPekRunwayStart(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.start || { latitude: 40.079857, longitude: 116.603114 };
}

function getPekRunwayEnd(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.end || { latitude: 40.091200, longitude: 116.615000 };
}


@Entry
@Component
struct Index {
  // === 沉浸式物理刹停与停靠动画状态 ===
  @State planeY: number = -45;                   // 飞机及阴影纵向位置（固定原位）
  @State planeX: number = 0;                     // 飞机及阴影横向对齐偏移（地图模式对齐跑道红点）
  @State planeScale: number = 1.0;               // 飞机与阴影原位 3D 缩放比例
  @State planeOpacity: number = 1.0;             // 缩小后重合时透明度渐变为 0
  @State planeRotate: number = 0;                // 飞机偏航旋转角度
  @State isPlaneMarkerActive: boolean = false;   // 动画完成后是否交接给地图原生 Marker
  @State currentZoomScale: number = 1.0;         // 随地图 Zoom 级别动态计算的物理比例 (2^(zoom - 17.2))
  @State isFullFocusMode: boolean = false;       // 11.8倍极简沉浸专注模式（隐藏所有UI）
  @State isCabinExposed: boolean = false;        // 飞机放大后机身外壳剖开状态
  @State shellSplitOffset: number = 0;           // 机壳剖开向两侧滑移偏移量
  @State isMapBackgroundVisible: boolean = false; // 只有当飞机放大完毕后，底部才无缝切为花瓣地图精修机场
  @State isVehiclesDocked: boolean = false;      // 勤务车辆与廊桥对接状态
  @State fuelTruckX: number = -350;              // 加油车 X 坐标
  @State fuelTruckY: number = 220;               // 加油车 Y 坐标
  @State fuelTruckRotate: number = 90;           // 加油车车头角度
  @State isHudVisible: boolean = true;           // Cyber HUD 界面可见状态 (默认开启展示图2主页)
  @State isFuelTruckParked: boolean = false;     // 加油车已完成驶入并停稳标志
  @State isFuelTruckDeparting: boolean = false;  // 加油车正在驶离标志
  @State isFuelTruckMessageVisible: boolean = false; // 加油车左侧标牌提示显隐
  @State fuelTruckMessageText: string = '';          // 加油车左侧标牌提示文本
  @State honkToastText: string = '';             // 提示文本
  @State isHonkToastVisible: boolean = false;    // 提示框显隐
  private currentZoomLevel: number = 17.2;        // 当前地图缩放级别 Zoom
  private currentMapBearing: number = CTU_RUNWAY_BEARING; // 当前地图方位角度 Bearing
  private planeMarkerRotation: number = CTU_RUNWAY_BEARING; // 地图 Marker 飞机图标旋转角 (非 State 避免高频重绘)
  private huaweiMapController?: map.MapComponentController;
  private currentPlaneMarker?: map.Marker;
  private currentPlaneMarkerHD?: map.Marker;
  private rainbowPolyline?: map.MapPolyline; // 🌈 纯正单向 6 色彩虹光带实例 (紫 -> 蓝 -> 绿 -> 黄 -> 橙 -> 红)
  private rainbowPolylines: Array<map.MapPolyline> = []; // 6 条单向平行彩虹 Polyline 实例
  private rainbowTraversedPoints: Array<mapCommon.LatLng> = []; // 已飞过的历史航线点集合
  private lastTraversedPointIndex: number = 0;
  private flightDisplaySync: displaySync.DisplaySync | undefined = undefined;
  @State flightCurrentIndex: number = 0;
  @State isFlightInProgress: boolean = false;
  @State selectedFocusDurationMinutes: number = 45; // 用户在图2刻度尺选定的专注飞行时长 (默认45分钟)
  private animTimer: number = -1;

  @StorageLink('selectedDestinationAirport') currentDestinationAirport?: Airport = undefined;
  @State isCameraFollowLocked: boolean = true; // 飞行跟随锁定状态 (true: 自动跟拍居中, false: 用户自由拖拽地图)
  @State currentMapType: mapCommon.MapType = mapCommon.MapType.SATELLITE; // 默认使用卫星遥感地图
  @State isFlightPaused: boolean = false;        // 飞行暂停标志位
  private flightPauseElapsedMs: number = 0;      // 暂停前已消耗的累计毫秒数
  private flightPauseSegmentStartTime: number = 0; // 本段连续运行的起始时间戳

  @State currentThemeIndex: number = 0;          // 停机坪主题索引
  private readonly bgThemes: Resource[] = [
    $r('app.media.bg_1'),
    $r('app.media.skytrace'),
    $r('app.media.skywhale'),
    $r('app.media.theme_doraemon'),
    $r('app.media.theme_skyreverie'),
    $r('app.media.skymechacrev'),
    $r('app.media.starportvanguard'),
    $r('app.media.skyframe')
  ];

  // 华为花瓣地图初始配置：默认纯净战术矢量图 STANDARD + 精修 CTU 跑道垂直朝上对齐视角
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: getCtuRunwayStart().latitude,
        longitude: getCtuRunwayStart().longitude
      },
      zoom: 17.2,
      bearing: CTU_RUNWAY_BEARING,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: false,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true,
    scrollGesturesEnabled: true
  };

  private applyRunwayCameraOrientation(controller?: map.MapComponentController): void {
    const mapCtrl = controller || this.huaweiMapController;
    if (mapCtrl) {
      try {
        const targetPos = getCtuRunwayStart();
        console.info(`[CTU Camera] target=(${targetPos.latitude}, ${targetPos.longitude}) bearing=${CTU_RUNWAY_BEARING}`);
        mapCtrl.moveCamera(map.newCameraPosition({
          target: {
            latitude: targetPos.latitude,
            longitude: targetPos.longitude
          },
          zoom: 17.2,
          bearing: CTU_RUNWAY_BEARING,
          tilt: 0
        }));
      } catch (e) {
        console.error('applyRunwayCameraOrientation error:', JSON.stringify(e));
      }
    }
  }

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
      // 双重保障：在 MapComponent 渲染表面完全稳定后强行平移并旋转地图视角！
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 150);
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 650);
    }
  };



  /**
   * 🧭 旋转地图视角 90° (平滑动画过渡)
   */
  private rotateMapNextAngle(): void {
    this.triggerHapticFeedback();
    this.currentMapBearing = Math.round((this.currentMapBearing + 90) % 360); AppStorage.setOrCreate('hudMapBearing', this.currentMapBearing);
    if (this.huaweiMapController) {
      try {
        const currentCam = this.huaweiMapController.getCameraPosition();
        this.huaweiMapController.animateCamera(map.newCameraPosition({
          target: currentCam?.target || getCtuRunwayStart(),
          zoom: currentCam?.zoom || 17.2,
          bearing: this.currentMapBearing,
          tilt: 0
        }), 500);
        this.honkToastText = `🧭 地图视角已旋转至 ${this.currentMapBearing}°`;
        this.isHonkToastVisible = true;
        setTimeout(() => {
          this.isHonkToastVisible = false;
        }, 2000);
      } catch (e) {
        console.error('rotateMapNextAngle error:', JSON.stringify(e));
      }
    }
  }

  /**
   * 📐 微调地图视角 Bearing 角度 (±1°)
   */
  private tweakMapBearing(deltaDeg: number): void {
    this.triggerHapticFeedback();
    this.currentMapBearing = Math.round((this.currentMapBearing + deltaDeg + 360) % 360); AppStorage.setOrCreate('hudMapBearing', this.currentMapBearing);
    if (this.huaweiMapController) {
      try {
        const currentCam = this.huaweiMapController.getCameraPosition();
        this.huaweiMapController.moveCamera(map.newCameraPosition({
          target: currentCam?.target || getCtuRunwayStart(),
          zoom: currentCam?.zoom || 17.2,
          bearing: this.currentMapBearing,
          tilt: 0
        }));
      } catch (e) {
        console.error('tweakMapBearing error:', JSON.stringify(e));
      }
    }
    this.honkToastText = `📐 地图视角已微调至 ${this.currentMapBearing}°`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 1200);
  }

  /**
   * ✈️ 微调飞机 Marker 点标记角度 (±1° 或 ±90°)
   */
  private tweakMarkerRotation(deltaDeg: number): void {
    this.triggerHapticFeedback();
    this.planeMarkerRotation = Math.round((this.planeMarkerRotation + deltaDeg + 360) % 360); AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
    if (this.currentPlaneMarker) {
      try {
        this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
      } catch (e) {
        console.error('setRotation error:', JSON.stringify(e));
      }
    }
    this.honkToastText = `✈️ 飞机 Marker 角度已调整至 ${this.planeMarkerRotation}°`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 1200);
  }

  /**
   * 🗺️ 切换战术矢量地图与卫星遥感地图模式
   */
  private toggleMapTypeMode(): void {
    this.triggerHapticFeedback();
    if (this.currentMapType === mapCommon.MapType.SATELLITE) {
      this.currentMapType = mapCommon.MapType.TERRAIN;
      this.honkToastText = '⛰️ 地图视角: 切换为地形地貌';
    } else if (this.currentMapType === mapCommon.MapType.TERRAIN) {
      this.currentMapType = mapCommon.MapType.STANDARD;
      this.honkToastText = '🗺️ 地图视角: 切换为纯净战术矢量';
    } else {
      this.currentMapType = mapCommon.MapType.SATELLITE;
      this.honkToastText = '🛰️ 地图视角: 切换为卫星遥感照片';
    }
    if (this.huaweiMapController) {
      try {
        this.huaweiMapController.setMapType(this.currentMapType);
      } catch (e) {
        console.error('setMapType error:', JSON.stringify(e));
      }
    }
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 1800);
  }

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 0a. 立即强制将地图镜头平移与旋转至跑道垂直朝上对齐视角！
      this.applyRunwayCameraOrientation(controller);

      // 0b. 监听地图点击事件，实时输出并弹窗提示经纬度坐标点
      controller.on('mapClick', (data: Object) => {
        const latLng = data as mapCommon.LatLng;
        if (latLng && latLng.latitude !== undefined && latLng.longitude !== undefined) {
          const latStr = latLng.latitude.toFixed(6);
          const lonStr = latLng.longitude.toFixed(6);
          console.info(`[MapClick] Lat: ${latStr}, Lon: ${lonStr}`);
          this.honkToastText = `📍 选点坐标: ${latStr}, ${lonStr}`;
          this.isHonkToastVisible = true;
          setTimeout(() => {
            this.isHonkToastVisible = false;
          }, 4500);
        }
      });

      // 0c. 监听地图缩放与镜头变换（由 flat: true 原生 C++ GPU 引擎处理手势旋转）
      try {
        controller.on('cameraChange', (_data: Object) => {
          // 🚀 核心性能修复：如果处于系统接管的自动跟随模式，
          // 坚决忽略底层异步抛回的 cameraChange 事件！
          // 防止其因浮点数精度微小变动触发 @State 重绘，导致出现几秒一次的“UI抽帧”。
          if (this.isFlightInProgress && this.isCameraFollowLocked) {
            return;
          }

          const cam = controller.getCameraPosition();
          if (cam) {
            if (cam.zoom !== undefined && cam.zoom > 3.0) {
              const newLevel = parseFloat(cam.zoom.toFixed(1));
              if (this.currentZoomLevel !== newLevel) {
                this.currentZoomLevel = newLevel; AppStorage.setOrCreate('hudZoomLevel', this.currentZoomLevel);
                this.refreshRainbowPolylines();
              }
              const baseZoom = 17.2;
              const newScale = parseFloat(Math.pow(2, cam.zoom - baseZoom).toFixed(3));
              if (this.currentZoomScale !== newScale) {
                this.currentZoomScale = newScale;
              }
            }
            if (cam.bearing !== undefined) {
              const newBearing = Math.round(cam.bearing);
              if (this.currentMapBearing !== newBearing) {
                this.currentMapBearing = newBearing; AppStorage.setOrCreate('hudMapBearing', this.currentMapBearing);
              }
            }
          }
        });
      } catch (e) { }

      // 1. 模块化加载跑道、滑行道网络及三阶段战术航线发光线条 (动态匹配用户目的地)
      await MapRenderHelper.setupRunwaysAndRoutes(controller, this.currentDestinationAirport);

      // 2. 清理旧 Marker 并挂载唯一原生地图 Marker 实例 (支持 PixelMap 代码级任意像素动态缩放)
      if (this.currentPlaneMarker) {
        try { this.currentPlaneMarker.remove(); } catch (e) { }
        this.currentPlaneMarker = undefined;
      }
      if (this.currentPlaneMarkerHD) {
        try { this.currentPlaneMarkerHD.remove(); } catch (e) { }
        this.currentPlaneMarkerHD = undefined;
      }

      // 💡 通过代码级动态指定目标像素宽度（如 175px），实现容器级精确放缩！
      const planePixelMap = await this.getScaledPlaneMarkerIcon(175);

      this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);

      this.currentPlaneMarker = await controller.addMarker({
        position: getCtuRunwayStart(),
        icon: planePixelMap || $r('app.media.b737_800_top_3_medium'),
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: 202.5,
        zIndex: 100,
        clickable: false
      });
      this.currentPlaneMarker.setAlpha(1.0);
    } catch (e) {
      console.error('Index Petal Map setup error:', JSON.stringify(e));
    }
  }

  /**
   * ✈️ 使用鸿蒙 PixelMap 原生 API 对飞机高清原图与机身阴影进行代码级高质感融合
   * 采用对称画布设计，确保 Marker 的中心 (0.5, 0.5) 与飞机机身中轴线 100% 绝对同轴对齐！
   * @param targetWidthPx 目标屏幕宽度像素 (如 175)
   */
  private async getScaledPlaneMarkerIcon(targetWidthPx: number): Promise<image.PixelMap | undefined> {
    try {
      const resourceMgr = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceMgr) {
        return undefined;
      }

      const targetHeightPx = Math.round(targetWidthPx * 1.43);
      // 🌟 显著加大阴影偏移距离（右偏 18px，下偏 32px），让机翼与机尾投射出清晰可见的 3D 立体悬浮阴影
      const shadowOffsetX = Math.round(18 * (targetWidthPx / 175));
      const shadowOffsetY = Math.round(32 * (targetWidthPx / 175));

      // 🛡️ 核心对称画布设计：在四周留出完全对称的 padding，
      // 使得飞机的几何中心就是画布的绝对中心 (canvasW/2, canvasH/2)，
      // 进而保证 anchorU: 0.5, anchorV: 0.5 在任意旋转角度下，飞机机身中轴线绝对不发生任何偏移！
      const padX = shadowOffsetX + 12;
      const padY = shadowOffsetY + 12;
      const canvasW = targetWidthPx + padX * 2;
      const canvasH = targetHeightPx + padY * 2;
      const planeOffsetX = padX;
      const planeOffsetY = padY;
      const shadowDstX = padX + shadowOffsetX;
      const shadowDstY = padY + shadowOffsetY;

      // 1. 加载飞机实体
      const planeData = await resourceMgr.getMediaContent($r('app.media.b737_800_top_3').id);
      const planeImgSource = image.createImageSource(planeData.buffer);
      const planePm = await planeImgSource.createPixelMap({
        desiredSize: { width: targetWidthPx, height: targetHeightPx }
      });
      const planeBuf = new ArrayBuffer(targetWidthPx * targetHeightPx * 4);
      await planePm.readPixelsToBuffer(planeBuf);
      const planePixels = new Uint8Array(planeBuf);

      // 2. 加载机身地面柔和阴影
      const shadowData = await resourceMgr.getMediaContent($r('app.media.b737_800_top_3_shadow').id);
      const shadowImgSource = image.createImageSource(shadowData.buffer);
      const shadowPm = await shadowImgSource.createPixelMap({
        desiredSize: { width: targetWidthPx, height: targetHeightPx }
      });
      const shadowBuf = new ArrayBuffer(targetWidthPx * targetHeightPx * 4);
      await shadowPm.readPixelsToBuffer(shadowBuf);
      const shadowPixels = new Uint8Array(shadowBuf);

      // 3. 创建对称合成画布
      const canvasPm = await planeImgSource.createPixelMap({
        desiredSize: { width: canvasW, height: canvasH }
      });
      const canvasBuf = new ArrayBuffer(canvasW * canvasH * 4);
      const canvasPixels = new Uint8Array(canvasBuf);

      // 4. 将高对比度柔和阴影渲染至偏移位置
      for (let y = 0; y < targetHeightPx; y++) {
        for (let x = 0; x < targetWidthPx; x++) {
          const sIdx = (y * targetWidthPx + x) * 4;
          const sA = shadowPixels[sIdx + 3];
          if (sA > 10) {
            const dstX = x + shadowDstX;
            const dstY = y + shadowDstY;
            if (dstX >= 0 && dstX < canvasW && dstY >= 0 && dstY < canvasH) {
              const dIdx = (dstY * canvasW + dstX) * 4;
              // 深度纯黑半透明阴影，在浅色地面和深色跑道均有清晰边界
              canvasPixels[dIdx] = 12;
              canvasPixels[dIdx + 1] = 16;
              canvasPixels[dIdx + 2] = 24;
              canvasPixels[dIdx + 3] = Math.min(220, Math.round(sA * 1.15)); // 增强阴影浓度
            }
          }
        }
      }

      // 5. 将飞机实体叠加上层（机身居于画布绝对中心）
      for (let y = 0; y < targetHeightPx; y++) {
        for (let x = 0; x < targetWidthPx; x++) {
          const pIdx = (y * targetWidthPx + x) * 4;
          const pA = planePixels[pIdx + 3] / 255.0;
          if (pA > 0) {
            const dstX = x + planeOffsetX;
            const dstY = y + planeOffsetY;
            if (dstX >= 0 && dstX < canvasW && dstY >= 0 && dstY < canvasH) {
              const dIdx = (dstY * canvasW + dstX) * 4;
              if (pA >= 0.99) {
                canvasPixels[dIdx] = planePixels[pIdx];
                canvasPixels[dIdx + 1] = planePixels[pIdx + 1];
                canvasPixels[dIdx + 2] = planePixels[pIdx + 2];
                canvasPixels[dIdx + 3] = planePixels[pIdx + 3];
              } else {
                const dstA = canvasPixels[dIdx + 3] / 255.0;
                const outA = pA + dstA * (1.0 - pA);
                if (outA > 0.001) {
                  canvasPixels[dIdx] = Math.round((planePixels[pIdx] * pA + canvasPixels[dIdx] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 1] = Math.round((planePixels[pIdx + 1] * pA + canvasPixels[dIdx + 1] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 2] = Math.round((planePixels[pIdx + 2] * pA + canvasPixels[dIdx + 2] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 3] = Math.round(outA * 255);
                }
              }
            }
          }
        }
      }

      // 6. 🔴 在飞机机头正中写入鲜艳的红色准星圆点
      const cX = planeOffsetX + Math.floor(targetWidthPx / 2);
      const cY = planeOffsetY + Math.floor(targetHeightPx * 0.04);
      const radiusOuter = 10;
      const radiusInner = 6;

      for (let y = cY - radiusOuter; y <= cY + radiusOuter; y++) {
        for (let x = cX - radiusOuter; x <= cX + radiusOuter; x++) {
          if (x >= 0 && x < canvasW && y >= 0 && y < canvasH) {
            const distSq = (x - cX) * (x - cX) + (y - cY) * (y - cY);
            if (distSq <= radiusOuter * radiusOuter) {
              const idx = (y * canvasW + x) * 4;
              if (distSq <= radiusInner * radiusInner) {
                canvasPixels[idx] = 255;
                canvasPixels[idx + 1] = 0;
                canvasPixels[idx + 2] = 0;
                canvasPixels[idx + 3] = 255;
              } else {
                canvasPixels[idx] = 255;
                canvasPixels[idx + 1] = 255;
                canvasPixels[idx + 2] = 255;
                canvasPixels[idx + 3] = 255;
              }
            }
          }
        }
      }

      await canvasPm.writeBufferToPixels(canvasBuf);
      return canvasPm;
    } catch (e) {
      console.error('Failed to create scaled plane PixelMap with shadow:', JSON.stringify(e));
      return undefined;
    }
  }

  aboutToAppear() {
    this.checkAndRestoreActiveSession();
    this.startAnimationSequence();
  }

  onPageShow() {
    this.checkAndRestoreActiveSession();
    this.startAnimationSequence();
  }

  /**
   * ✈️ 计算与精修机场地图原生 Marker (targetWidthPx = 175) 1:1 绝对一致的 planeScale 尺寸
   * 确保点击“开始专注”后，机身 3D 缩小落定的尺寸与地图上的飞机 Marker 像素级严格对齐！
   */
  private getTargetMarkerPlaneScale(): number {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const density = displayInfo.densityPixels || 3.5;
      const targetMarkerVp = 175 / density; // 175px 在当前屏幕的真实 vp 宽度 (约 49.2vp)
      return targetMarkerVp / 315; // 对应 315vp 飞机原图的精确缩放比 (约 0.156)
    } catch (e) {
      return 0.156;
    }
  }

  private async checkAndRestoreActiveSession(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params.startFlight) {
        this.isCabinExposed = false;
        this.isFullFocusMode = false;
        this.isMapBackgroundVisible = true;
        this.planeScale = this.getTargetMarkerPlaneScale();
        this.planeY = 0;
        this.planeX = 0;
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
        return;
      }

      // 默认冷启动：始终优先展示【图2 停机坪即刻专注准备主页】
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.isMapBackgroundVisible = false;
      this.planeScale = 1.0;
      this.planeY = -45;
      this.planeX = 0;
      this.isVehiclesDocked = true;
      this.isHudVisible = true;
    } catch (e) {
      // ignore
    }
  }

  /**
   * 当用户在首页放大的机舱中点击任意座椅或确认就座起飞时：
   * 彻底取消页面跳转！在当前页面内实现纯 3D 无缝缩小退场与背后华为 Petal Maps 地图的平滑浮现
   */
  private onSeatSelectedInIndex(seatId: string, tagId: string = 'study', durationMinutes?: number) {
    if (durationMinutes && durationMinutes > 0) {
      this.selectedFocusDurationMinutes = durationMinutes;
    }
    const tagMap: Record<string, string> = {
      'study': '深度学习',
      'work': '高效工作',
      'create': '创意灵感',
      'relax': '正念冥想',
      'sprint': '极速冲刺'
    };
    const tagName = tagMap[tagId] || '深度专注';
    const destApt = this.currentDestinationAirport || findAirportByCode('PEK');
    const destCode = destApt ? destApt.code : 'PEK';

    // 存储当前飞行专注会话状态
    FlightSessionStore.saveSession({
      isFlightActive: true,
      flightNo: 'FF-2026',
      seatId: seatId,
      taskTitle: tagName,
      durationMin: this.selectedFocusDurationMinutes,
      originCode: 'CTU',
      destCode: destCode,
      startTimeMs: Date.now()
    });

    this.honkToastText = `✨ 座位 ${seatId} · ${tagName} (${this.selectedFocusDurationMinutes}m) 桌板已放下，准备起飞`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3000);

    // 1. 400ms 平滑缝合剖开的机身外壳
    this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.shellSplitOffset = 0;
    });

    // 2. 0.35 秒后隐藏机舱透视，飞机平滑 3D 缩小至与精修地图飞机完全 1:1 的尺寸，背后的华为 Petal Maps 地图无缝淡入浮现！
    setTimeout(async () => {
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.isMapBackgroundVisible = true; // 背后华为花瓣地图无缝出现！

      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.animateCamera(map.newCameraPosition({
            target: getCtuRunwayStart(),
            zoom: 17.2,
            bearing: CTU_RUNWAY_BEARING,
            tilt: 0
          }), 1000);

          // 预先在跑道起点挂载好原生 Marker，准备与上方缩小的 3D 飞机无缝交叉淡入淡出
          if (this.currentPlaneMarker) { try { this.currentPlaneMarker.remove(); } catch (e) { } }
          if (this.currentPlaneMarkerHD) { try { this.currentPlaneMarkerHD.remove(); } catch (e) { } }

          const planePixelMap = await this.getScaledPlaneMarkerIcon(175);
          this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);

          this.currentPlaneMarker = await this.huaweiMapController.addMarker({
            position: getCtuRunwayStart(),
            icon: planePixelMap || $r('app.media.b737_800_top_3_medium'),
            anchorU: 0.5,
            anchorV: 0.5,
            flat: true,
            rotation: 202.5,
            zIndex: 100,
            clickable: false
          });
          this.currentPlaneMarker.setAlpha(1.0);
        } catch (e) { }
      }

      // 飞机在 2 秒内持续平滑 3D 缩小至 1:1，并在这完整的 2 秒内同步平滑将透明度降到 0（绝不在最后停顿才开始变透明！）
      const targetScale = this.getTargetMarkerPlaneScale();
      this.planeOpacity = 1.0;
      this.getUIContext()?.animateTo({ duration: 2000, curve: Curve.FastOutSlowIn }, () => {
        this.planeScale = targetScale;
        this.planeY = 0;
        this.planeX = 0;
      });
      this.getUIContext()?.animateTo({ duration: 2000, curve: Curve.EaseInOut }, () => {
        this.planeOpacity = 0;
      });

      // 恢复周围地勤设备与 HUD 界面
      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
      });

      // 3. 2 秒过渡期满（UI 飞机已完全无缝淡出至 0），由底层地图 Marker 立即接管并直接动力全推起飞！
      setTimeout(() => {
        this.isPlaneMarkerActive = true;
        this.startFlightAnimationDirectly();
      }, 2000);
    }, 350);
  }

  /**
   * ✈️ 2秒无缝过渡淡出结束后，直接动力全推起飞并进入 60 FPS 巡航！
   */
  private async startFlightAnimationDirectly(): Promise<void> {
    // 1. 机头角绑定双流跑道西南至东北实际绝对方位角 202.5 度 (顺时针旋转 180 度正对起飞前方)
    const rStart = getCtuRunwayStart();
    this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
    if (this.currentPlaneMarker) {
      try {
        this.currentPlaneMarker.setPosition(rStart);
        this.currentPlaneMarker.setRotation(202.5);
      } catch (e) { }
    }

    const durationMinutes = this.selectedFocusDurationMinutes > 0 ? this.selectedFocusDurationMinutes : 45;

    // 清理并重置彩虹光带
    if (this.rainbowPolyline) {
      try { this.rainbowPolyline.remove(); } catch (e) { }
      this.rainbowPolyline = undefined;
    }
    if (this.rainbowPolylines.length > 0) {
      for (const p of this.rainbowPolylines) {
        try {
          p.remove();
        } catch (e) { }
      }
      this.rainbowPolylines = [];
    }
    this.rainbowTraversedPoints = [];
    this.lastTraversedPointIndex = 0;

    const destApt = this.currentDestinationAirport || findAirportByCode('PEK');
    const destCity = destApt ? destApt.city : '北京';
    const destName = destApt ? destApt.name : '北京首都国际机场';
    const destCode = destApt ? destApt.code : 'PEK';

    this.honkToastText = `🚀 动力全推，离开成都双流 (CTU)！专注 ${durationMinutes} 分钟，飞往 ${destCity} · ${destName} (${destCode})...`;
    this.isHonkToastVisible = true;
    setTimeout(() => { this.isHonkToastVisible = false; }, 4000);

    // 2. 获取全程三阶段高密度航线点集 (动态适配目标目的地)
    const points: mapCommon.LatLng[] = MapRenderHelper.getFullFlightPathPoints(this.currentDestinationAirport);
    if (!points || points.length < 2) {
      return;
    }

    // 初始化单向 6 色平行彩虹光带 (紫->蓝->绿->黄->橙->红)
    if (this.huaweiMapController) {
      const p0 = points[0];
      this.rainbowTraversedPoints = [p0];

      // 严格按照 k = 0..5 预分配有序数组，消除异步 resolve 乱序导致的色带交叉与黑缝！
      const polyWidths: number[] = [8.0, 10.0, 10.0, 10.0, 10.0, 8.0];
      const polyPromises: Promise<map.MapPolyline>[] = [];
      for (let k = 0; k < MapRenderHelper.RAINBOW_PARALLEL_COLORS.length; k++) {
        const color = MapRenderHelper.RAINBOW_PARALLEL_COLORS[k];
        polyPromises.push(this.huaweiMapController.addPolyline({
          points: [p0, p0],
          width: polyWidths[k],
          color: color,
          zIndex: 60 + k
        }));
      }
      try {
        const createdPolys = await Promise.all(polyPromises);
        this.rainbowPolylines = createdPolys;
      } catch (e) { }
    }

      // 3b. 预计算物理距离数组 (Cumulative Distance)，让飞机保持真实的地理巡航速度，
      // 同时通过“连续平滑速度权重”实现起飞从容、巡航高效、降落稳健，彻底消除任何弯道突发加速缺陷。
      const deg2rad = Math.PI / 180;
      const physicalDistances = new Float64Array(points.length);
      physicalDistances[0] = 0;
      let rawTotalPhysicalDist = 0;
      for (let i = 1; i < points.length; i++) {
        const p1 = points[i - 1];
        const p2 = points[i];
        const dLat = (p2.latitude - p1.latitude) * deg2rad;
        const dLon = (p2.longitude - p1.longitude) * deg2rad;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                  Math.cos(p1.latitude * deg2rad) * Math.cos(p2.latitude * deg2rad) *
                  Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const d = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)); // km
        rawTotalPhysicalDist += d;
        physicalDistances[i] = rawTotalPhysicalDist;
      }

      const cumulativeDistances = new Float64Array(points.length);
      cumulativeDistances[0] = 0;
      let totalRouteDistance = 0;

      for (let i = 1; i < points.length; i++) {
        const segPhysDist = physicalDistances[i] - physicalDistances[i - 1];
        const ratio = rawTotalPhysicalDist > 0 ? physicalDistances[i] / rawTotalPhysicalDist : 0;

        // 基于航程物理比例的平滑余弦过渡调速权重：
        // 0% ~ 4%（起飞滑跑与完整第一弯道）：保持流畅自然的适度速度（weight = 3.2，既不爬行也不暴冲）
        // 4% ~ 8%：平滑余弦加速进入巡航
        // 8% ~ 92%：高空稳定巡航（weight = 1.0）
        // 92% ~ 96%：平滑余弦减速进入降落
        // 96% ~ 100%：稳健慢速降落接地（weight = 3.2）
        let weight = 1.0;
        if (ratio <= 0.04) {
          weight = 3.2;
        } else if (ratio < 0.08) {
          const t = (ratio - 0.04) / 0.04;
          weight = 3.2 - (3.2 - 1.0) * (0.5 - 0.5 * Math.cos(Math.PI * t));
        } else if (ratio <= 0.92) {
          weight = 1.0;
        } else if (ratio < 0.96) {
          const t = (ratio - 0.92) / 0.04;
          weight = 1.0 + (3.2 - 1.0) * (0.5 - 0.5 * Math.cos(Math.PI * t));
        } else {
          weight = 3.2;
        }

        totalRouteDistance += (segPhysDist * weight);
        cumulativeDistances[i] = totalRouteDistance;
      }

      this.flightCurrentIndex = 0;
      this.isFlightInProgress = true;

      if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }

      // 4. 动态计算飞行总时长：100% 严格对应用户选定的专注分钟数 (如 45 分钟 = 45 * 60 * 1000 ms)
      const totalFlightDurationMs = durationMinutes * 60 * 1000;
      const startTime = Date.now();

      this.flightPauseElapsedMs = 0;
      this.flightPauseSegmentStartTime = Date.now();
      this.isFlightPaused = false;

      let firstTickFired = false; // 跳过 interval 首次 tick 的 Marker API 调用，消除 2s 边界闪烁
      this.flightDisplaySync = displaySync.create();
      this.flightDisplaySync.on('frame', () => {
        if (this.isFlightPaused) {
          return;
        }

        const now = Date.now();
        const segmentElapsed = now - this.flightPauseSegmentStartTime;
        const totalElapsed = this.flightPauseElapsedMs + segmentElapsed;
        const overallProgress = Math.min(1.0, totalElapsed / totalFlightDurationMs);

        // 终点到达逻辑
        if (overallProgress >= 1.0) {
          if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }
          this.isFlightInProgress = false;
          const destApt = this.currentDestinationAirport || findAirportByCode('PEK');
          const destCity = destApt ? destApt.city : '北京';
          const destName = destApt ? destApt.name : '北京首都国际机场';
          const destCode = destApt ? destApt.code : 'PEK';
          this.honkToastText = `🛬 专注 ${durationMinutes} 分钟完成！成功降落抵达 ${destCity} · ${destName} (${destCode})`;
          this.isHonkToastVisible = true;
          return;
        }

        // 基于真实物理距离重映射当前的真实数组进度 (rawIndex)，确保飞机恒速飞行
        const targetDist = overallProgress * totalRouteDistance;
        let segIndex = 0;
        for (let i = 0; i < points.length - 1; i++) {
          if (targetDist >= cumulativeDistances[i] && targetDist <= cumulativeDistances[i + 1]) {
            segIndex = i;
            break;
          }
        }
        if (segIndex >= points.length - 1) {
          segIndex = points.length - 2;
        }
        
        const distStart = cumulativeDistances[segIndex];
        const distEnd = cumulativeDistances[segIndex + 1];
        const segmentLen = distEnd - distStart;
        const segProgress = segmentLen > 0 ? (targetDist - distStart) / segmentLen : 0;
        const rawIndex = segIndex + segProgress;
        // 使用 Catmull-Rom 样条曲线进行平滑插值，彻底消除多边形折线感
        const getSmoothPos = (idx: number): mapCommon.LatLng => {
          const maxIdx = points.length - 1;
          if (idx <= 0) return points[0];
          if (idx >= maxIdx) return points[maxIdx];
          
          const i = Math.floor(idx);
          const t = idx - i;
          
          const p0 = points[Math.max(0, i - 1)];
          const p1 = points[i];
          const p2 = points[Math.min(maxIdx, i + 1)];
          const p3 = points[Math.min(maxIdx, i + 2)];
          
          const t2 = t * t;
          const t3 = t2 * t;
          
          const lat = 0.5 * (
            (2 * p1.latitude) +
            (-p0.latitude + p2.latitude) * t +
            (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2 +
            (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3
          );
          
          const lng = 0.5 * (
            (2 * p1.longitude) +
            (-p0.longitude + p2.longitude) * t +
            (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2 +
            (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3
          );
          
          return { latitude: lat, longitude: lng };
        };

        const interpPos = getSmoothPos(rawIndex);

        // 🌈 60 FPS 连续平滑拉伸 6 色同心彩虹色带（红橙黄绿蓝紫完全等宽，飞过的航线 100% 纹丝不动！）
        const currentIntIdx = Math.floor(rawIndex);
        if (currentIntIdx > this.lastTraversedPointIndex) {
          for (let ptIdx = this.lastTraversedPointIndex; ptIdx < currentIntIdx; ptIdx++) {
            this.rainbowTraversedPoints.push(points[ptIdx]);
          }
          this.lastTraversedPointIndex = currentIntIdx;
        }

        // 🎬 电影级视距伸缩：前 10% 17.2 -> 13，后 10% 13 -> 17.2 (连续无级平滑浮点)
        let cinematicZoom = 13.0;
        if (overallProgress <= 0.1) {
          const t = overallProgress / 0.1;
          const easeT = 1 - Math.pow(1 - t, 3);
          cinematicZoom = 17.2 - (17.2 - 13.0) * easeT;
        } else if (overallProgress >= 0.9) {
          const t = (overallProgress - 0.9) / 0.1;
          const easeT = (1 - Math.cos(Math.PI * t)) / 2;
          cinematicZoom = 13.0 + (17.2 - 13.0) * easeT;
        }

        const displayPoints = this.rainbowTraversedPoints.slice();
        displayPoints.push(interpPos);

        if (this.rainbowPolylines.length > 0) {
          const currentCam = this.huaweiMapController?.getCameraPosition();
          const realZoom = (currentCam && currentCam.zoom) ? currentCam.zoom : (this.isCameraFollowLocked ? cinematicZoom : this.currentZoomLevel);
          const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom);
          for (let k = 0; k < this.rainbowPolylines.length; k++) {
            const poly = this.rainbowPolylines[k];
            if (poly && parallelStripes[k]) {
              try {
                poly.setPoints(parallelStripes[k]);
              } catch (e) { }
            }
          }
        }

        // 【先】算目标角度，确保 Camera 与 Marker 同帧使用同一旋转角，消除 1 帧偏差导致的滑行抽帧
        // 起飞直线跑道段锁死 202.5°；其他段使用平滑曲线的前视点作为真实的连续切线
        if (segIndex < 20) {
          this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
        } else {
          // 动态前视 1.2 个点段，完美模拟真实飞行员沿着平滑曲线前视转弯
          const lookAheadPos = getSmoothPos(rawIndex + 1.2);
          const targetRotation = MapRenderHelper.calculateBearing(interpPos, lookAheadPos);
          
          let angleDiff = targetRotation - this.planeMarkerRotation;
          while (angleDiff < -180) angleDiff += 360;
          while (angleDiff > 180) angleDiff -= 360;
          
          // 加入 0.08 的缓动系数，模拟重型客机转弯时的重量惯性与物理阻尼
          this.planeMarkerRotation = this.planeMarkerRotation + angleDiff * 0.08; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
        }

        // 🧭 航向朝上 Heading-Up 同频跟随：与 marker 同为 16ms tick，camera 与飞机零延迟同步
        // currentMapBearing 由 cameraChange 回调更新，此处不重复赋值，避免多余 @State 重绘
        if (this.huaweiMapController && this.isCameraFollowLocked) {
          try {
            
            // 🔥 核心修复：高频的 moveCamera(16ms) 会导致底层 SDK 认为相机一直未停稳，
            // 从而不触发 'cameraChange' 回调。必须在此处手动将解算的 zoom 同步给 @State 刷新 UI 面板！
            const zoomFixed = parseFloat(cinematicZoom.toFixed(1));
            if (this.currentZoomLevel !== zoomFixed) {
              this.currentZoomLevel = zoomFixed; AppStorage.setOrCreate('hudZoomLevel', this.currentZoomLevel);
            }
            
            const headingUpBearing = (360 - this.planeMarkerRotation + 360) % 360;
            // 手动接管罗盘的数值同步，带有严格的值相等检测以避免无意义的全局重绘
            const newCompassBearing = Math.round(headingUpBearing);
            if (this.currentMapBearing !== newCompassBearing) {
              this.currentMapBearing = newCompassBearing; AppStorage.setOrCreate('hudMapBearing', this.currentMapBearing);
            }

            this.huaweiMapController.moveCamera(map.newCameraPosition({
              target: interpPos,
              zoom: cinematicZoom,
              bearing: headingUpBearing,
              tilt: 0
            }));
          } catch (e) { }
        }

        // 🚀 零 State 刷新开销！直接调用原生 Marker API，极尽丝滑！
        // 首次 tick 跳过 setPosition/setRotation（marker 已静止在起点），避免 SDK 内部重建触发闪烁
        if (!firstTickFired) {
          firstTickFired = true;
        } else if (this.currentPlaneMarker) {
          try {
            this.currentPlaneMarker.setPosition(interpPos);
            this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
            this.currentPlaneMarker.setAlpha(1.0);
          } catch (e) { }
        }
      });
      this.flightDisplaySync.start();
  }

  /**
   * 🌈 用户在任何缩放倍率下，即时刷新彩虹各色带地理坐标，确保放大至 20x 仍 100% 严密贴合无黑缝且尾部平整
   */
  private refreshRainbowPolylines(): void {
    if (this.rainbowTraversedPoints.length === 0 || this.rainbowPolylines.length === 0) {
      return;
    }
    const displayPoints = this.rainbowTraversedPoints.slice();
    const currentCam = this.huaweiMapController?.getCameraPosition();
    const realZoom = (currentCam && currentCam.zoom) ? currentCam.zoom : this.currentZoomLevel;
    const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom);
    for (let k = 0; k < this.rainbowPolylines.length; k++) {
      const poly = this.rainbowPolylines[k];
      if (poly && parallelStripes[k]) {
        try {
          poly.setPoints(parallelStripes[k]);
        } catch (e) { }
      }
    }
  }

  /**
   * ⏸️ 切换飞行暂停 / 恢复状态
   */
  private togglePauseFlight(): void {
    this.triggerHapticFeedback();
    if (this.isFlightPaused) {
      this.isFlightPaused = false;
      this.flightPauseSegmentStartTime = Date.now();
      this.honkToastText = '▶️ 专注飞行已恢复，继续巡航...';
    } else {
      this.isFlightPaused = true;
      const now = Date.now();
      this.flightPauseElapsedMs += (now - this.flightPauseSegmentStartTime);
      this.honkToastText = '⏸️ 专注飞行已暂停';
    }
    this.isHonkToastVisible = true;
    setTimeout(() => { this.isHonkToastVisible = false; }, 2000);
  }

  private triggerHapticFeedback(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 30
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private runFuelTruckDepartureAnimation() {
    if (this.isFuelTruckDeparting) return;
    this.isFuelTruckDeparting = true;
    this.isFuelTruckParked = false;

    this.triggerHapticFeedback();
    this.fuelTruckMessageText = '加油车驾驶员：航油已加满！';
    this.isFuelTruckMessageVisible = true;
    setTimeout(() => {
      this.isFuelTruckMessageVisible = false;
    }, 4000);

    const duration = 3500;
    const startTime = Date.now();

    const startX = this.fuelTruckX;
    const startY = this.fuelTruckY;

    // 离场三阶贝塞尔路径：从飞机翼下停靠点转向，从机翼腹部下方滑过并驶离屏幕
    const p0x = startX, p0y = startY;
    const p1x = -10,   p1y = -160;
    const p2x = 180,   p2y = -260;
    const p3x = 480,   p3y = -360;

    let departureTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      let rawT = elapsed / duration;

      if (rawT >= 1.0) {
        rawT = 1.0;
        clearInterval(departureTimer);
      }

      let t = rawT;
      const mt = 1 - t;
      const x = mt * mt * mt * p0x + 3 * mt * mt * t * p1x + 3 * mt * t * t * p2x + t * t * t * p3x;
      const y = mt * mt * mt * p0y + 3 * mt * mt * t * p1y + 3 * mt * t * t * p2y + t * t * t * p3y;

      const dx = 3 * mt * mt * (p1x - p0x) + 6 * mt * t * (p2x - p1x) + 3 * t * t * (p3x - p2x);
      const dy = 3 * mt * mt * (p1y - p0y) + 6 * mt * t * (p2y - p1y) + 3 * t * t * (p3y - p2y);

      const angleRad = Math.atan2(dy, dx);
      const angleDeg = angleRad * (180 / Math.PI) + 90;

      this.fuelTruckX = x;
      this.fuelTruckY = y;
      this.fuelTruckRotate = angleDeg;
    }, 16);
  }

  private onFuelTruckClick(): void {
    if (this.isMapBackgroundVisible || this.isFullFocusMode) return;
    if (!this.isFuelTruckDeparting) {
      this.runFuelTruckDepartureAnimation();
    } else {
      this.triggerHapticFeedback();
      this.fuelTruckMessageText = '加油车驾驶员：已完成任务驶离中';
      this.isFuelTruckMessageVisible = true;
      setTimeout(() => {
        this.isFuelTruckMessageVisible = false;
      }, 3000);
    }
  }

  private onTractorClick(): void {
    if (this.isMapBackgroundVisible || this.isFullFocusMode) return;
    this.triggerHapticFeedback();
    this.honkToastText = '🚜 勤务牵引车就绪 · 轮档已撤除，随时准备离港后推！';
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3000);
  }

  /**
   * 启动开场动画
   */
  private startAnimationSequence() {
    this.planeY = -45;
    this.planeX = 0;
    this.planeScale = 1.0;
    this.isPlaneMarkerActive = false;
    this.isVehiclesDocked = true;
    this.fuelTruckX = -350;
    this.fuelTruckY = 220;
    this.fuelTruckRotate = 90;
    this.isHudVisible = true;
    this.isFuelTruckParked = false;
    this.isFuelTruckDeparting = false;
    this.isHonkToastVisible = false;
    this.isMapBackgroundVisible = false;
    this.isCabinExposed = false;

    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }

    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 1700, curve: Curve.Friction }, () => {
        this.planeY = -48;
      });

      setTimeout(() => {
        this.getUIContext()?.animateTo({ duration: 350, curve: Curve.FastOutSlowIn }, () => {
          this.planeY = -45;
        });
      }, 1700);

      setTimeout(() => {
        this.isVehiclesDocked = true;
        this.runRealTruckPhysicsAnimation();
      }, 2050);

      setTimeout(() => {
        this.isHudVisible = true;
      }, 3000);
    }, 50);
  }

  private runRealTruckPhysicsAnimation() {
    const duration = 4600;
    const startTime = Date.now();

    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
    }

    this.animTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      let rawT = elapsed / duration;

      if (rawT >= 1.0) {
        rawT = 1.0;
        clearInterval(this.animTimer);
        this.animTimer = -1;
        this.isFuelTruckParked = true;
      }

      let t = rawT;
      if (rawT > 0.85) {
        const subT = (rawT - 0.85) / 0.15;
        t = 0.85 + 0.15 * (1 - Math.pow(1 - subT, 2));
      }

      const p0x = -350, p0y = 220;
      const p1x = 180,  p1y = 220;
      const p2x = 220,  p2y = 40;
      const p3x = 120,  p3y = -85;

      const mt = 1 - t;
      const x = mt * mt * mt * p0x + 3 * mt * mt * t * p1x + 3 * mt * t * t * p2x + t * t * t * p3x;
      const y = mt * mt * mt * p0y + 3 * mt * mt * t * p1y + 3 * mt * t * t * p2y + t * t * t * p3y;

      const dx = 3 * mt * mt * (p1x - p0x) + 6 * mt * t * (p2x - p1x) + 3 * t * t * (p3x - p2x);
      const dy = 3 * mt * mt * (p1y - p0y) + 6 * mt * t * (p2y - p1y) + 3 * t * t * (p3y - p2y);

      const angleRad = Math.atan2(dy, dx);
      const angleDeg = angleRad * (180 / Math.PI) + 90;

      this.fuelTruckX = x;
      this.fuelTruckY = y;
      this.fuelTruckRotate = angleDeg;
    }, 16);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 全屏背景层 (未放大时为停机坪 bg_1，仅在【飞机完全放大完毕】或【点击座椅后】无缝切为华为花瓣地图精修机场)
      Stack({ alignContent: Alignment.Center }) {
        // 底层：停机坪地面 (固定底层)
        Image($r('app.media.bg_1'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.05, y: 1.05 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : 1)
          .animation({ duration: 800, curve: Curve.EaseInOut })

        // 主题附加层1：晴空航迹 (Index 1)
        Image(this.bgThemes[1])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 1 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层2：云鲸航线 (Index 2)
        Image(this.bgThemes[2])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 2 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层3：戴竹蜻蜓蓝色胖子 (Index 3)
        Image(this.bgThemes[3])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 3 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层4：空港幻想 (Index 4)
        Image(this.bgThemes[4])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 4 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层5：机修大队 (Index 5)
        Image(this.bgThemes[5])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 5 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层6：星港先锋 (Index 6)
        Image(this.bgThemes[6])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 6 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层7：苍穹机甲 (Index 7)
        Image(this.bgThemes[7])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 7 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 上层：华为原生花瓣地图 (Petal Maps) 精修机场地图
        if (this.isMapBackgroundVisible) {
          MapComponent({ mapOptions: this.huaweiMapOptions, mapCallback: this.huaweiMapCallback })
            .width('100%')
            .height('100%')
            .renderGroup(true)
            .opacity(this.isMapBackgroundVisible ? 1 : 0)
            .animation({ duration: 800, curve: Curve.EaseInOut })
            .onTouch((event: TouchEvent) => {
              if ((event.type === TouchType.Down || event.type === TouchType.Move) && this.isFlightInProgress && this.isCameraFollowLocked) {
                this.isCameraFollowLocked = false;
                this.honkToastText = '🗺️ 已脱离跟随，您可自由拖拽与缩放地图';
                this.isHonkToastVisible = true;
                setTimeout(() => { this.isHonkToastVisible = false; }, 1800);
              }
            })
        }
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 顶部问候栏与航班简报
      HeaderGreetingBar({
        isHudVisible: this.isHudVisible,
        isFullFocusMode: this.isFullFocusMode,
        isMapBackgroundVisible: this.isMapBackgroundVisible
      })

      // 2.5 停机坪机位地面标牌互动 (刻度尺上方右侧)
      if (this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) {
        Column() {
          CyberThemeSelector({ currentThemeIndex: this.currentThemeIndex })
        }
        .position({ x: '100%', y: '67%' })
        .markAnchor({ x: '100%', y: '100%' })
        .margin({ right: 24, bottom: 6 })
        .zIndex(200)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 2.6 加油车状态提示 (用户指定位置：刻度尺上方左侧，纯单行文字)
      if (this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible && this.isFuelTruckMessageVisible) {
        Text(this.fuelTruckMessageText)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#64748B')
          .position({ x: '0%', y: '67%' })
          .markAnchor({ x: '0%', y: '100%' })
          .margin({ left: 24, bottom: 6 })
          .zIndex(200)
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 16 }))
              .animation({ duration: 350, curve: Curve.EaseOut })
          )
      }

      // Toast 战术提示浮标 (启用 renderGroup 离屏硬件合成隔离，废除 DOM 动态销毁，彻底消除 2 秒后 Marker 闪烁)
      Row({ space: 8 }) {
        Text(this.honkToastText)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor('rgba(10, 15, 26, 0.9)')
      .border({ width: 1, color: '#38BDF8', radius: 20 })
      .borderRadius(20)
      .shadow({ radius: 16, color: 'rgba(56, 189, 248, 0.5)', offsetY: 4 })
      .position({ y: 110 })
      .opacity(this.isHonkToastVisible ? 1 : 0)
      .animation({ duration: 250, curve: Curve.EaseInOut })
      .renderGroup(true)
      .hitTestBehavior(HitTestMode.None)
      .zIndex(300)

      // 3. 地面勤务设备与阴影层
      GroundServiceVehiclesOverlay({
        isFullFocusMode: this.isFullFocusMode,
        isMapBackgroundVisible: this.isMapBackgroundVisible,
        isVehiclesDocked: this.isVehiclesDocked,
        fuelTruckX: this.fuelTruckX,
        fuelTruckY: this.fuelTruckY,
        fuelTruckRotate: this.fuelTruckRotate,
        onFuelTruckClick: () => this.onFuelTruckClick(),
        onTractorClick: () => this.onTractorClick()
      })


      // 4. 飞机实体与剖开机舱图层
      PlaneCabinShellOverlay({
        isMapBackgroundVisible: this.isMapBackgroundVisible,
        isCabinExposed: this.isCabinExposed,
        isFullFocusMode: this.isFullFocusMode,
        planeScale: this.planeScale,
        planeOpacity: this.planeOpacity,
        currentZoomScale: this.currentZoomScale,
        planeX: this.planeX,
        planeY: this.planeY,
        planeRotate: this.planeRotate,
        shellSplitOffset: this.shellSplitOffset,
        onSeatClick: (seatId: string): void => {
          this.onSeatSelectedInIndex(seatId);
        },
        onConfirmFlight: (seatId: string, tagId: string, durationMinutes: number): void => {
          this.onSeatSelectedInIndex(seatId, tagId, durationMinutes);
        }
      })
        .hitTestBehavior(HitTestMode.Transparent)

      // 5. 底部专注控制面板
      HomeFocusPanel({
        onStartFlight: (minutes?: number, dest?: Airport) => {
          if (minutes && minutes > 0) {
            this.selectedFocusDurationMinutes = minutes;
          }
          if (dest) {
            this.currentDestinationAirport = dest;
          }
          this.triggerPureScaleAnimation();
        }
      })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .opacity((this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 1 : 0)
        .translate({ y: (this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 0 : 260 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .zIndex(100)

      // 6. 客舱透视或纯净地图模式下的左上角大厂极简圆形返回按钮 (Apple / HarmonyOS Translucent Floating Glass Back Button)
      if (this.isCabinExposed || (this.isMapBackgroundVisible && !this.isCabinExposed)) {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.ic_back_btn_dark'))
            .width(16)
            .height(16)
            .objectFit(ImageFit.Contain)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('rgba(255, 255, 255, 0.92)')
        .border({ width: 1, color: 'rgba(0, 0, 0, 0.06)', radius: 18 })
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.08)', offsetY: 2 })
        .position({ x: 18, y: 48 })
        .zIndex(200)
        .onClick(() => {
          this.triggerPureScaleAnimation();
        })
      }

      // 7. 地图模式下的右上角 Cyber HUD 双维度控制组
      if (this.isMapBackgroundVisible && !this.isCabinExposed) {
        CyberMapHudControl({
          currentMapType: this.currentMapType,
          onTweakMapBearing: (delta: number) => this.tweakMapBearing(delta),
          onRotateMapNextAngle: () => this.rotateMapNextAngle(),
          onTweakMarkerRotation: (delta: number) => this.tweakMarkerRotation(delta),
          onToggleMapTypeMode: () => this.toggleMapTypeMode()
        })
          .position({ x: '100%', y: 60 })
          .markAnchor({ x: '100%', y: 0 })
          .margin({ right: 14 })
          .zIndex(200)
      }

      // 8. 飞行阶段脱离跟随时的右下角经典“🎯 恢复跟随”定位按钮
      if (this.isMapBackgroundVisible && !this.isCabinExposed && this.isFlightInProgress && !this.isCameraFollowLocked) {
        Row({ space: 6 }) {
          Text('🎯 恢复跟随')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#FA6B56')
        .border({ width: 1, color: '#FFFFFF', radius: 20 })
        .borderRadius(20)
        .shadow({ radius: 14, color: 'rgba(250, 107, 86, 0.45)', offsetY: 4 })
        .position({ x: '100%', y: '100%' })
        .markAnchor({ x: '100%', y: '100%' })
        .margin({ right: 18, bottom: 85 })
        .renderGroup(true)
        .zIndex(300)
        .onClick(() => {
          this.triggerHapticFeedback();
          this.isCameraFollowLocked = true;
          this.honkToastText = '🎯 已重新锁定机头跟随视角';
          this.isHonkToastVisible = true;
          setTimeout(() => { this.isHonkToastVisible = false; }, 2000);
        })
      }

      // 9. 飞行阶段暂停/恢复控制按钮
      if (this.isMapBackgroundVisible && !this.isCabinExposed && this.isFlightInProgress) {
        Row({ space: 6 }) {
          Text(this.isFlightPaused ? '▶️ 恢复飞行' : '⏸️ 暂停飞行')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.isFlightPaused ? '#4ADE80' : 'rgba(10, 15, 26, 0.88)')
        .border({ width: 1, color: this.isFlightPaused ? '#FFFFFF' : '#38BDF8', radius: 20 })
        .borderRadius(20)
        .shadow({ radius: 14, color: 'rgba(0, 0, 0, 0.45)', offsetY: 4 })
        .position({ x: 18, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .margin({ bottom: 85 })
        .zIndex(300)
        .onClick(() => {
          this.togglePauseFlight();
        })
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // 🛡️ 只有在非地图模式下才响应全屏点击收起逻辑，防止地图操作被穿透触发模式切换！
      if (this.isFullFocusMode && !this.isMapBackgroundVisible && !this.isCabinExposed) {
        this.triggerPureScaleAnimation();
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 触发飞机原位慢慢放大至 11.8 倍 -> 等飞机放大完毕后，露出华为 Petal Maps 精修机场地图与机舱
   */
  private triggerPureScaleAnimation() {
    if (!this.isFullFocusMode) {
      this.isMapBackgroundVisible = false;
      this.planeOpacity = 1.0;

      // 阶段一：2.5 秒内飞机原位平滑放大到 11.8 倍
      this.getUIContext()?.animateTo({ duration: 2500, curve: Curve.EaseInOut }, () => {
        this.isFullFocusMode = true;
        this.planeScale = 11.8;
        this.planeY = 1200;
      });

      // 阶段二：放大完毕后，露出机舱选座
      setTimeout(() => {
        if (this.isFullFocusMode) {
          this.getUIContext()?.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
            this.isCabinExposed = true;
          });
          this.getUIContext()?.animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
            this.shellSplitOffset = 160;
          });
        }
      }, 1200);

      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = false;
      });
    } else {
      // 退出沉浸专注模式：背景先平滑切回停机坪地面，关合缝合机壳，再缩小飞机
      this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
        this.shellSplitOffset = 0;
        this.isMapBackgroundVisible = false;
      });

      setTimeout(() => {
        this.isCabinExposed = false;
        this.isFullFocusMode = false;
        this.planeOpacity = 1.0;

        this.getUIContext()?.animateTo({ duration: 2000, curve: Curve.EaseInOut }, () => {
          this.planeScale = 1.0;
          this.planeY = -45;
        });

        this.getUIContext()?.animateTo({ duration: 1200, curve: Curve.EaseOut }, () => {
          this.isVehiclesDocked = true;
        });
      }, 400);
    }
  }
}