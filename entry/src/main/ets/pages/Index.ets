import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { image } from '@kit.ImageKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { HomeFocusPanel } from '../components/HomeFocusPanel';
import { CabinInteriorOverlay } from '../components/CabinInteriorOverlay';
import { CyberMapHudControl } from '../components/CyberMapHudControl';
import { HeaderGreetingBar } from '../components/HeaderGreetingBar';
import { GroundServiceVehiclesOverlay } from '../components/GroundServiceVehiclesOverlay';
import { PlaneCabinShellOverlay } from '../components/PlaneCabinShellOverlay';
import { MapRenderHelper } from '../utils/MapRenderHelper';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';
import {
  LatLngPoint,
  interpolateLatLng
} from '../utils/GeodesicUtils';
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
  @State honkToastText: string = '';             // 提示文本
  @State isHonkToastVisible: boolean = false;    // 提示框显隐
  @State currentZoomLevel: number = 17.2;        // 当前地图缩放级别 Zoom
  @State currentMapBearing: number = CTU_RUNWAY_BEARING; // 当前地图方位角度 Bearing
  private planeMarkerRotation: number = CTU_RUNWAY_BEARING; // 地图 Marker 飞机图标旋转角 (非 State 避免高频重绘)
  private huaweiMapController?: map.MapComponentController;
  private currentPlaneMarker?: map.Marker;
  private currentPlaneMarkerHD?: map.Marker;
  private flightAnimationTimerId: number = -1;
  @State flightCurrentIndex: number = 0;
  @State isFlightInProgress: boolean = false;
  @State selectedFocusDurationMinutes: number = 45; // 用户在图2刻度尺选定的专注飞行时长 (默认45分钟)
  private animTimer: number = -1;

  @State isCameraFollowLocked: boolean = true; // 飞行跟随锁定状态 (true: 自动跟拍居中, false: 用户自由拖拽地图)
  @State currentMapType: mapCommon.MapType = mapCommon.MapType.STANDARD; // 默认使用纯净战术矢量地图
  @State isFlightPaused: boolean = false;        // 飞行暂停标志位
  private flightPauseElapsedMs: number = 0;      // 暂停前已消耗的累计毫秒数
  private flightPauseSegmentStartTime: number = 0; // 本段连续运行的起始时间戳

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
    mapType: mapCommon.MapType.STANDARD,
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
    this.currentMapBearing = Math.round((this.currentMapBearing + 90) % 360);
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
    this.currentMapBearing = Math.round((this.currentMapBearing + deltaDeg + 360) % 360);
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
    this.planeMarkerRotation = Math.round((this.planeMarkerRotation + deltaDeg + 360) % 360);
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
    if (this.currentMapType === mapCommon.MapType.STANDARD) {
      this.currentMapType = mapCommon.MapType.SATELLITE;
      this.honkToastText = '🛰️ 地图视角: 切换为卫星遥感照片';
    } else {
      this.currentMapType = mapCommon.MapType.STANDARD;
      this.honkToastText = '🗺️ 地图视角: 切换为纯净战术矢量';
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
          const cam = controller.getCameraPosition();
          if (cam) {
            if (cam.zoom !== undefined) {
              this.currentZoomLevel = parseFloat(cam.zoom.toFixed(1));
              const baseZoom = 17.2;
              this.currentZoomScale = Math.pow(2, cam.zoom - baseZoom);
            }
            if (cam.bearing !== undefined) {
              this.currentMapBearing = Math.round(cam.bearing);
            }
          }
        });
      } catch (e) { }

      // 1. 模块化加载跑道、滑行道网络及三阶段战术航线发光线条
      await MapRenderHelper.setupRunwaysAndRoutes(controller);

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

      this.planeMarkerRotation = 202.5;

      this.currentPlaneMarker = await controller.addMarker({
        position: getCtuRunwayStart(),
        icon: planePixelMap || $r('app.media.b737_800_top_3_medium'),
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: 202.5,
        clickable: false
      });
      this.currentPlaneMarker.setAlpha(1.0);
    } catch (e) {
      console.error('Index Petal Map setup error:', JSON.stringify(e));
    }
  }

  /**
   * ✈️ 使用鸿蒙 PixelMap 原生 API 对飞机主高清原图进行代码级动态缩放
   * @param targetWidthPx 目标屏幕宽度像素 (如 140/175/220)，控制飞机 Marker 的大小
   */
  private async getScaledPlaneMarkerIcon(targetWidthPx: number): Promise<image.PixelMap | undefined> {
    try {
      const resourceMgr = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceMgr) {
        return undefined;
      }
      const fileData = await resourceMgr.getMediaContent($r('app.media.b737_800_top_3').id);
      const imageSource = image.createImageSource(fileData.buffer);
      const targetHeightPx = Math.round(targetWidthPx * 1.43);
      const pixelMap = await imageSource.createPixelMap({
        desiredSize: { width: targetWidthPx, height: targetHeightPx }
      });

      // 🔴 在 PixelMap 的机头顶端位置写入鲜艳的红色准星圆点
      try {
        const buffer = new ArrayBuffer(targetWidthPx * targetHeightPx * 4);
        await pixelMap.readPixelsToBuffer(buffer);
        const uint8Arr = new Uint8Array(buffer);

        const cX = Math.floor(targetWidthPx / 2);
        const cY = Math.floor(targetHeightPx * 0.04);
        const radiusOuter = 10;
        const radiusInner = 6;

        for (let y = cY - radiusOuter; y <= cY + radiusOuter; y++) {
          for (let x = cX - radiusOuter; x <= cX + radiusOuter; x++) {
            if (x >= 0 && x < targetWidthPx && y >= 0 && y < targetHeightPx) {
              const distSq = (x - cX) * (x - cX) + (y - cY) * (y - cY);
              if (distSq <= radiusOuter * radiusOuter) {
                const idx = (y * targetWidthPx + x) * 4;
                if (distSq <= radiusInner * radiusInner) {
                  // 🔴 内部纯鲜红色
                  uint8Arr[idx] = 255;     // R
                  uint8Arr[idx + 1] = 0;   // G
                  uint8Arr[idx + 2] = 0;   // B
                  uint8Arr[idx + 3] = 255; // A
                } else {
                  // ⚪ 外圈高亮白边
                  uint8Arr[idx] = 255;
                  uint8Arr[idx + 1] = 255;
                  uint8Arr[idx + 2] = 255;
                  uint8Arr[idx + 3] = 255;
                }
              }
            }
          }
        }
        await pixelMap.writeBufferToPixels(buffer);
      } catch (err) {
        console.error('Error drawing red dot on pixelMap:', JSON.stringify(err));
      }

      return pixelMap;
    } catch (e) {
      console.error('Failed to create scaled plane PixelMap:', JSON.stringify(e));
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

  private async checkAndRestoreActiveSession(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params.startFlight) {
        this.isCabinExposed = false;
        this.isFullFocusMode = false;
        this.isMapBackgroundVisible = true;
        this.planeScale = 0.45;
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
   * 当用户在首页放大的机舱中点击任意座椅时：
   * 彻底取消页面跳转！在当前页面内实现纯 3D 无缝缩小退场与背后华为 Petal Maps 地图的平滑浮现
   */
  private onSeatSelectedInIndex(seatId: string) {
    this.honkToastText = `✨ 已选择座位 ${seatId} · 战术航线与地图无缝就绪`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3000);

    // 1. 400ms 平滑缝合剖开的机身外壳
    this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.shellSplitOffset = 0;
    });

    // 2. 0.35 秒后隐藏机舱透视，飞机平滑 3D 缩小至 1/3 (0.33)，背后的华为 Petal Maps 地图无缝淡入浮现！
    setTimeout(() => {
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
          }), 1200);
        } catch (e) { }
      }

      // 飞机在当前页面平滑 3D 缩小至 0.45 比例（与适中 Marker 100% 尺寸对齐）
      this.getUIContext()?.animateTo({ duration: 1600, curve: Curve.FastOutSlowIn }, () => {
        this.planeScale = 0.45;
        this.planeY = 0;
        this.planeX = 0;
      });

      // 恢复周围地勤设备与 HUD 界面
      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
      });

      // 3. 1600ms 物理缩小动效落定瞬间：无缝交接给双地图原生 3D Marker 交叉渐变渲染！
      setTimeout(async () => {
        if (this.huaweiMapController) {
          try {
            if (this.currentPlaneMarker) { try { this.currentPlaneMarker.remove(); } catch (e) { } }
            if (this.currentPlaneMarkerHD) { try { this.currentPlaneMarkerHD.remove(); } catch (e) { } }

            const planePixelMap = await this.getScaledPlaneMarkerIcon(175);

            this.planeMarkerRotation = 202.5;

            this.currentPlaneMarker = await this.huaweiMapController.addMarker({
              position: getCtuRunwayStart(),
              icon: planePixelMap || $r('app.media.b737_800_top_3_medium'),
              anchorU: 0.5,
              anchorV: 0.5,
              flat: true,
              rotation: 202.5,
              clickable: false
            });
            this.currentPlaneMarker.setAlpha(1.0);
          } catch (e) { }
        }
        this.getUIContext()?.animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
          this.isPlaneMarkerActive = true;
        });

        // 🚀 选座完成后，平滑缩小落定后，触发 2 秒跑道等待与自动沿线起飞引擎！
        this.startFlightAnimationAfterPause();
      }, 1600);
    }, 350);
  }

  /**
   * ✈️ 选座落定后，停靠 2 秒自动触发【60 FPS 物理级极尽丝滑平滑插值起飞引擎】
   */
  private startFlightAnimationAfterPause(): void {
    // 1. 机头角绑定双流跑道西南至东北实际绝对方位角 202.5 度 (顺时针旋转 180 度正对起飞前方)
    const rStart = getCtuRunwayStart();
    this.planeMarkerRotation = 202.5;
    if (this.currentPlaneMarker) {
      try {
        this.currentPlaneMarker.setPosition(rStart);
        this.currentPlaneMarker.setRotation(202.5);
      } catch (e) { }
    }

    const durationMinutes = this.selectedFocusDurationMinutes > 0 ? this.selectedFocusDurationMinutes : 45;

    // 2. 在跑道起点静止停靠等待 2 秒（显示沉浸战术广播）
    this.honkToastText = `✈️ 跑道对正就绪 · 选定专注 ${durationMinutes} 分钟 (2秒后起飞)...`;
    this.isHonkToastVisible = true;

    setTimeout(() => {
      this.honkToastText = `🚀 动力全推，离开成都双流 (CTU)！专注时长 ${durationMinutes} 分钟，开启漫游巡航...`;
      this.isHonkToastVisible = true;
      setTimeout(() => { this.isHonkToastVisible = false; }, 4000);

      // 3. 2 秒等待倒计时结束，获取全程三阶段高密度航线点集
      const points: mapCommon.LatLng[] = MapRenderHelper.getFullFlightPathPoints();
      if (!points || points.length < 2) {
        return;
      }

      this.flightCurrentIndex = 0;
      this.isFlightInProgress = true;

      if (this.flightAnimationTimerId !== -1) {
        clearInterval(this.flightAnimationTimerId);
      }

      // 4. 动态计算飞行总时长：100% 严格对应用户选定的专注分钟数 (如 45 分钟 = 45 * 60 * 1000 ms)
      const totalFlightDurationMs = durationMinutes * 60 * 1000;
      const startTime = Date.now();

      let lastCameraMoveTime = 0;
      this.flightPauseElapsedMs = 0;
      this.flightPauseSegmentStartTime = Date.now();
      this.isFlightPaused = false;

      let firstTickFired = false; // 跳过 interval 首次 tick 的 Marker API 调用，消除 2s 边界闪烁
      this.flightAnimationTimerId = setInterval(() => {
        if (this.isFlightPaused) {
          return;
        }

        const now = Date.now();
        const segmentElapsed = now - this.flightPauseSegmentStartTime;
        const totalElapsed = this.flightPauseElapsedMs + segmentElapsed;
        const overallProgress = Math.min(1.0, totalElapsed / totalFlightDurationMs);

        // 终点到达逻辑
        if (overallProgress >= 1.0) {
          clearInterval(this.flightAnimationTimerId);
          this.flightAnimationTimerId = -1;
          this.isFlightInProgress = false;
          this.honkToastText = `🛬 专注 ${durationMinutes} 分钟完成！成功降落抵达北京首都国际机场 (PEK)`;
          this.isHonkToastVisible = true;
          return;
        }

        // 基于系统物理时间戳解算当前坐标段
        const rawIndex = overallProgress * (points.length - 1);
        const segIndex = Math.floor(rawIndex);
        const segProgress = rawIndex - segIndex;

        const pStart = points[segIndex];
        const pEnd = points[Math.min(points.length - 1, segIndex + 1)];

        // 经纬度双向线性插值
        const currentLat = pStart.latitude + (pEnd.latitude - pStart.latitude) * segProgress;
        const currentLng = pStart.longitude + (pEnd.longitude - pStart.longitude) * segProgress;
        const interpPos: mapCommon.LatLng = { latitude: currentLat, longitude: currentLng };

        // 🧲 40ms (25 FPS) 脉冲 zero-stutter 精确镜头跟随（受 isCameraFollowLocked 控制）
        // 🧭 航向朝上 Heading-Up 模式：bearing 跟随飞机实时航向，marker 永远指向屏幕正上方
        if (this.huaweiMapController && this.isCameraFollowLocked && (now - lastCameraMoveTime >= 40)) {
          lastCameraMoveTime = now;
          try {
            const zoomLevel = (this.currentZoomLevel && this.currentZoomLevel > 3.0) ? this.currentZoomLevel : (segIndex < 20 ? 16.5 : (segIndex > points.length - 20 ? 16.5 : 15.2));
            // 航向朝上：Petal Maps bearing 是地图顺时针旋转量，屏幕正上方 = 360° - bearing
            // 故让飞机航向 H 朝上需：bearing = (360 - H) % 360
            const headingUpBearing = (360 - this.planeMarkerRotation + 360) % 360;
            this.currentMapBearing = Math.round(headingUpBearing);
            this.huaweiMapController.moveCamera(map.newCameraPosition({
              target: interpPos,
              zoom: zoomLevel,
              bearing: headingUpBearing,
              tilt: 0
            }));
          } catch (e) { }
        }

        // 算目标角度：起飞直线跑道段 (segIndex < 20) 100% 坚如磐石锁死 202.5 度 (彻底消灭差值缓动引起的 200ms 抖动)，巡航弯道段启用平滑 Lerp
        if (segIndex < 20) {
          this.planeMarkerRotation = 202.5;
        } else {
          const targetRotation = MapRenderHelper.calculateBearing(pStart, pEnd);
          let angleDiff = targetRotation - this.planeMarkerRotation;
          while (angleDiff < -180) angleDiff += 360;
          while (angleDiff > 180) angleDiff -= 360;
          this.planeMarkerRotation = this.planeMarkerRotation + angleDiff * 0.15;
        }

        // 🚀 零 State 刷新开销！直接调用原生 Marker API，极尽丝滑！
        // 首次 tick 跳过 setPosition/setRotation（marker 已静止在起点），避免 SDK 内部重建触发闪烁
        if (!firstTickFired) {
          firstTickFired = true;
        } else if (this.currentPlaneMarker) {
          try {
            this.currentPlaneMarker.setPosition(interpPos);
            this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
          } catch (e) { }
        }
      }, 16); // 60 FPS 物理满帧刷新
    }, 2000);
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
    this.honkToastText = '⛽ 航油已加满！加油车打火启动，从翼下驶离停机坪...';
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3200);

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
      this.honkToastText = '⛽ 勤务加油车已完成任务并驶离停机坪';
      this.isHonkToastVisible = true;
      setTimeout(() => {
        this.isHonkToastVisible = false;
      }, 2500);
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
        // 底层：停机坪地面
        Image($r('app.media.bg_1'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.05, y: 1.05 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : 1)
          .animation({ duration: 800, curve: Curve.EaseInOut })

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
        planeScale: this.planeScale,
        currentZoomScale: this.currentZoomScale,
        planeX: this.planeX,
        planeY: this.planeY,
        planeRotate: this.planeRotate,
        shellSplitOffset: this.shellSplitOffset,
        onSeatClick: (seatId: string): void => {
          this.onSeatSelectedInIndex(seatId);
        }
      })

      // 5. 底部专注控制面板
      HomeFocusPanel({
        onStartFlight: (minutes?: number) => {
          if (minutes && minutes > 0) {
            this.selectedFocusDurationMinutes = minutes;
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

      // 6. 客舱透视或纯净地图模式下的左上角返回按钮
      if (this.isCabinExposed || (this.isMapBackgroundVisible && !this.isCabinExposed)) {
        Row() {
          Image($r('app.media.ic_back_btn'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.25)', radius: 21 })
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.4)', offsetY: 2 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .position({ x: 18, y: 44 })
        .zIndex(200)
        .onClick(() => {
          this.triggerPureScaleAnimation();
        })
      }

      // 7. 地图模式下的右上角 Cyber HUD 双维度控制组
      if (this.isMapBackgroundVisible && !this.isCabinExposed) {
        CyberMapHudControl({
          currentZoomLevel: this.currentZoomLevel,
          currentMapBearing: this.currentMapBearing,
          planeMarkerRotation: this.planeMarkerRotation,
          currentMapType: this.currentMapType,
          onTweakMapBearing: (delta: number) => this.tweakMapBearing(delta),
          onRotateMapNextAngle: () => this.rotateMapNextAngle(),
          onTweakMarkerRotation: (delta: number) => this.tweakMarkerRotation(delta),
          onToggleMapTypeMode: () => this.toggleMapTypeMode()
        })
          .position({ x: '100%', y: 44 })
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
      this.isFullFocusMode = true;
      this.isMapBackgroundVisible = false;

      // 阶段一：2.5 秒内飞机原位平滑放大到 11.8 倍
      this.getUIContext()?.animateTo({ duration: 2500, curve: Curve.EaseInOut }, () => {
        this.planeScale = 11.8;
        this.planeY = 1200;
      });

      // 阶段二：放大完毕后，剖开机舱
      setTimeout(() => {
        if (this.isFullFocusMode) {
          this.getUIContext()?.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
            this.isCabinExposed = true;
            this.isMapBackgroundVisible = true;
          });
          this.getUIContext()?.animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
            this.shellSplitOffset = 160;
          });
        }
      }, 2400);

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