import { FlightSessionService } from '../services/FlightSessionService';
import { MapCameraEngine } from '../engines/MapCameraEngine';
import { PhysicsAnimEngine } from '../engines/PhysicsAnimEngine';
import { UIContext } from '@kit.ArkUI';
import { IndexHangarHudLayer } from '../components/IndexHangarHudLayer';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { display, promptAction, router, window } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { image } from '@kit.ImageKit';
import { displaySync } from '@kit.ArkGraphics2D';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { CyberMapHudControl } from '../components/CyberMapHudControl';
import { MapRenderHelper } from '../utils/MapRenderHelper';
import { SoundEffectHelper } from '../utils/SoundEffectHelper';
import { PlaneMarkerIconHelper } from '../utils/PlaneMarkerIconHelper';
import { FlightRouteEngine, RouteDistanceProfile } from '../utils/FlightRouteEngine';
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

// 🌃 暗夜纯净航图自定义样式 JSON (彻底关闭地面 POI、地名、路名等文字注记，防止遮挡高空航线与彩虹)
const CLEAN_DARK_AVIATION_STYLE_JSON: string = '[{"mapFeature":"poi","options":"all","visibility":"off"},{"mapFeature":"road","featureName":"label","visibility":"off"},{"mapFeature":"administrative","featureName":"label","visibility":"off"},{"mapFeature":"transportation","featureName":"label","visibility":"off"}]';

// ✈️ 默认飞行终点：北京首都国际机场 (PEK) 跑道数据（用于三阶段航线无缝连接）
function getPekRunwayStart(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.start || { latitude: 40.079857, longitude: 116.603114 };
}

function getPekRunwayEnd(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.end || { latitude: 40.091200, longitude: 116.615000 };
}


export class IndexController {
  public vm: FlightViewModel;
  public context?: UIContext;
  constructor(vm: FlightViewModel) {
    this.vm = vm;
  }
  public flightSessionService = new FlightSessionService(this);
  public mapCameraEngine = new MapCameraEngine(this);
  public physicsAnimEngine = new PhysicsAnimEngine(this);

  public setContext(ctx: UIContext) {
    this.context = ctx;
  }
  get isFullReportVisible(): boolean { return AppStorage.get<boolean>('isFullReportVisible') || false; }
  set isFullReportVisible(val: boolean) { AppStorage.setOrCreate('isFullReportVisible', val); }
  get isStatsSheetVisible(): boolean { return AppStorage.get<boolean>('isStatsSheetVisible') || false; }
  set isStatsSheetVisible(val: boolean) { AppStorage.setOrCreate('isStatsSheetVisible', val); }
  // === 沉浸式物理刹停与停靠动画状态 ===
  public currentZoomLevel: number = 17.2;        // 当前地图缩放级别 Zoom
  public currentMapBearing: number = CTU_RUNWAY_BEARING; // 当前地图方位角度 Bearing
  public planeMarkerRotation: number = CTU_RUNWAY_BEARING; // 地图 Marker 飞机图标旋转角 (非 State 避免高频重绘)
  public huaweiMapController?: map.MapComponentController;
  public currentPlaneMarker?: map.Marker;
  public currentPlaneMarkerHD?: map.Marker;
  public rainbowPolyline?: map.MapPolyline; // 🌈 纯正单向 6 色无缝彩虹光带实例 (紫 -> 蓝 -> 绿 -> 黄 -> 橙 -> 红)
  public rainbowPixelMap?: image.PixelMap; // 🌈 6 色光谱纯净纹理
  public rainbowPolylines: Array<map.MapPolyline> = []; // 旧多色带兼容备份
  public rainbowTraversedPoints: Array<mapCommon.LatLng> = []; // 已飞过的历史航线点集合
  public lastTraversedPointIndex: number = 0;
  public flightDisplaySync: displaySync.DisplaySync | undefined = undefined;
  public animTimer: number = -1;
  get currentDestinationAirport(): Airport | undefined { return AppStorage.get<Airport>('selectedDestinationAirport'); }
  set currentDestinationAirport(val: Airport | undefined) { AppStorage.setOrCreate('selectedDestinationAirport', val); }
  get selectedRouteStyle(): string { return AppStorage.get<string>('selectedRouteStyle') || 'classic'; }
  set selectedRouteStyle(val: string) { AppStorage.setOrCreate('selectedRouteStyle', val); }
  get selectedTrailEffect(): string { return AppStorage.get<string>('selectedTrailEffect') || 'none'; }
  set selectedTrailEffect(val: string) { AppStorage.setOrCreate('selectedTrailEffect', val); }
  public screenVpWidth: number = 360;
  public screenVpHeight: number = 780;
  public isCameraFlyingBack: boolean = false; // 镜头平滑飞回过渡中标志
  public mapTouchStartX: number = 0; // 触摸起始 X（用于位移阈值判断真实拖拽）
  public mapTouchStartY: number = 0; // 触摸起始 Y
  public lastFlightInterpPos: mapCommon.LatLng = { latitude: 30.5828, longitude: 103.9467 }; // 飞行中最后已知实时位置（用于切换 Marker 图标时定位）
  public flybackStartTime: number = 0;
  public readonly FLYBACK_DURATION_MS: number = 750;
  public flybackStartLat: number = 0;
  public flybackStartLon: number = 0;
  public flybackStartZoom: number = 17.2;
  public flybackStartBearing: number = 158;
  public groundFlybackTimerSync?: displaySync.DisplaySync; // 地面精修机场状态下的平滑 60FPS 帧动画
  // 🌪️ 万米高空高仿真巡航气流扰动仿真系统 (Realistic Atmospheric Turbulence Simulation)
  public turbulenceCooldownFrames: number = 220; // 气流状态机冷却倒计时 (帧)
  public targetTurbulenceYaw: number = 0;        // 目标迎风偏航微角 (度, ±2.8°)
  public curTurbulenceYaw: number = 0;           // 当前偏航角 (指数衰减阻尼插值)
  public targetTurbulenceLateral: number = 0;    // 目标侧向横漂移 (米, ±15m)
  public curTurbulenceLateral: number = 0;       // 当前平滑侧向漂移
  public flightTickFrameCount: number = 0;       // 飞行帧计数器
  public readonly turbulenceQuotes: string[] = [
    '遭遇巡航微气流，航向平稳修正中',
    '穿越高空风切变层，自动驾驶姿态稳定中',
    '遇轻度气流颠簸，请系好安全带保持专注',
    '巡航微气流扰动，航程保持平稳前行'
  ];
  public flightPauseElapsedMs: number = 0;      // 暂停前已消耗的累计毫秒数
  public flightPauseSegmentStartTime: number = 0; // 本段连续运行的起始时间戳

  public readonly bgThemes: Resource[] = [
    $r('app.media.bg_1'),
    $r('app.media.skytrace'),
    $r('app.media.skywhale'),
    $r('app.media.theme_doraemon'),
    $r('app.media.theme_skyreverie'),
    $r('app.media.skymechacrev'),
    $r('app.media.starportvanguard'),
    $r('app.media.skyframe')
  ];

  public topToastTimer: number = -1;
  public showTopToast(message: string, duration: number = 3500) {
    this.flightSessionService.showTopToast(message, duration);
  }

  // 华为花瓣地图初始配置：默认纯净战术矢量图 STANDARD + 精修 CTU 跑道垂直朝上对齐视角
  public huaweiMapOptions: mapCommon.MapOptions = {
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
  public applyRunwayCameraOrientation(controller?: map.MapComponentController) {
    this.mapCameraEngine.applyRunwayCameraOrientation(controller);
  }

  public huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
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
  public rotateMapNextAngle(): void {
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
        this.vm.honkToastText = `🧭 地图视角已旋转至 ${this.currentMapBearing}°`;
        this.vm.isHonkToastVisible = true;
        setTimeout(() => {
          this.vm.isHonkToastVisible = false;
        }, 2000);
      } catch (e) {
        console.error('rotateMapNextAngle error:', JSON.stringify(e));
      }
    }
  }

  /**
   * 📐 微调地图视角 Bearing 角度 (±1°)
   */
  public tweakMapBearing(deltaDeg: number) {
    this.mapCameraEngine.tweakMapBearing(deltaDeg);
  }

  /**
   * ✈️ 微调飞机 Marker 点标记角度 (±1° 或 ±90°)
   */
  public tweakMarkerRotation(deltaDeg: number): void {
    this.triggerHapticFeedback();
    this.planeMarkerRotation = Math.round((this.planeMarkerRotation + deltaDeg + 360) % 360); AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
    if (this.currentPlaneMarker) {
      try {
        this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
      } catch (e) {
        console.error('setRotation error:', JSON.stringify(e));
      }
    }
    this.vm.honkToastText = `✈️ 飞机 Marker 角度已调整至 ${this.planeMarkerRotation}°`;
    this.vm.isHonkToastVisible = true;
    setTimeout(() => {
      this.vm.isHonkToastVisible = false;
    }, 1200);
  }

  /**
   * 🗺️ 循环切换地图图层视角：卫星遥感 ➔ 地貌地形 ➔ 暗夜深色航图 (无干扰静默切换)
   */
  public toggleMapTypeMode() {
    this.mapCameraEngine.toggleMapTypeMode();
  }
  public getPlaneMarkerIconResource() {
    return this.mapCameraEngine.getPlaneMarkerIconResource();
  }

  public async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 0a. 立即强制将地图镜头平移与旋转至跑道垂直朝上对齐视角！
      this.applyRunwayCameraOrientation(controller);

      // 0a-2. 禁用地面多余3D建筑，使高空飞行航线与彩虹光带纯净呈现
      try {
        controller.setBuildingEnabled(false);
      } catch (e) { }

      // 0b. 监听地图点击事件，实时输出并弹窗提示经纬度坐标点
      controller.on('mapClick', (data: Object) => {
        const latLng = data as mapCommon.LatLng;
        if (latLng && latLng.latitude !== undefined && latLng.longitude !== undefined) {
          const latStr = latLng.latitude.toFixed(6);
          const lonStr = latLng.longitude.toFixed(6);
          console.info(`[MapClick] Lat: ${latStr}, Lon: ${lonStr}`);
          try {
            promptAction.showToast({
              message: `📍 选点坐标: ${latStr}, ${lonStr}`,
              duration: 3500
            });
          } catch (e) { }
        }
      });

      // 0c. 监听地图缩放与镜头变换（由 flat: true 原生 C++ GPU 引擎处理手势旋转）
      try {
        controller.on('cameraChange', (_data: Object) => {
          // 🚀 核心性能修复：如果处于跟随锁定模式或平滑飞回动画期间，
          // 坚决忽略底层异步抛回的 cameraChange 事件！
          // 防止其因浮点数精度微小变动频繁触发 @State 重绘与 Polyline 重设导致掉帧卡顿。
          if (this.isCameraFlyingBack || this.vm.isCameraFollowLocked) {
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
              if (this.vm.currentZoomScale !== newScale) {
                this.vm.currentZoomScale = newScale;
              }
            }
            if (cam.target) {
              this.vm.currentCameraLat = cam.target.latitude;
              this.vm.currentCameraLng = cam.target.longitude;
            }
            if (cam.zoom !== undefined) {
              this.vm.currentCameraZoom = cam.zoom;
            }
            if (cam.bearing !== undefined) {
              this.vm.currentCameraBearing = cam.bearing;
            }
            // 🎯 用户自由拖拽/缩放地图时，实时重新投影计算飞机当前屏幕坐标
            this.updatePlaneScreenPosition();
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
      const planePixelMap = await this.getScaledPlaneMarkerIcon(175, this.vm.currentMapType === mapCommon.MapType.TERRAIN);

      this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);

      this.currentPlaneMarker = await controller.addMarker({
        position: getCtuRunwayStart(),
        icon: this.getPlaneMarkerIconResource(),
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: 202.5,
        zIndex: 2000,
        clickable: false
      });
      this.currentPlaneMarker.setAlpha(1.0);

      // 3. 🌈 若处于飞行中或断点恢复中，确保挂载 6 色无缝平行彩虹色带并同步轨迹
      if (this.vm.isFlightInProgress) {
        await this.initRainbowPolylinesIfNeeded();
        this.refreshRainbowPolylines();
      }
    } catch (e) {
      console.error('Index Petal Map setup error:', JSON.stringify(e));
    }
  }

  public getFocusTargetTitle(): string {
    const dest = this.currentDestinationAirport || findAirportByCode('PEK');
    const destCity = dest ? dest.city : '北京';
    return `专注巡航 · 飞往${destCity}`;
  }

  public getFocusTargetSubtitle(): string {
    const dest = this.currentDestinationAirport || findAirportByCode('PEK');
    const destName = dest ? dest.name : '北京首都国际机场';
    const destCode = dest ? dest.code : 'PEK';
    return `CTU 成都双流 ➔ ${destCode} ${destName}`;
  }

  /**
   * Delegates PixelMap plane marker composition to PlaneMarkerIconHelper.
   * See utils/PlaneMarkerIconHelper.ets for the full implementation.
   */
  public async getScaledPlaneMarkerIcon(targetWidthPx: number, withStroke: boolean = false): Promise<image.PixelMap | undefined> {
    return PlaneMarkerIconHelper.create(this.context!, targetWidthPx, withStroke);
  }

  public isInitialAppeared: boolean = false;
  public hasColdLaunchAnimationPlayed: boolean = false; // 首次冷启动开场动画完成标记

  aboutToAppear() {
    this.isInitialAppeared = true;
    this.checkAndRestoreActiveSession();
  }

  onPageShow() {
    // 🛡️ 核心修复：如果当前已经在精修地图模式或处于飞行中，坚决不重置页面，保护当前地图界面
    if (this.vm.isMapBackgroundVisible || this.vm.isFlightInProgress) {
      this.handleForegroundResume();
      return;
    }
    this.checkAndRestoreActiveSession();
  }

  onPageHide() {
    // 当页面隐藏（例如切出应用到后台）时，记录偏离航线事件
    if (this.vm.isFlightInProgress && !this.vm.isFlightPaused) {
      this.vm.backgroundStartTime = Date.now();
      this.recordFlightEvent('deviation', '系统休眠或切换应用');
    }
  }

  /**
   * 记录事件到飞行日志并持久化
   */
  public recordFlightEvent(type: 'gate_departure' | 'takeoff' | 'cruise' | 'deviation' | 'recovery' | 'turbulence' | 'descent_prep' | 'landing', note: string) {
    this.flightSessionService.recordFlightEvent(type, note);
  }


  /**
   * 💡 动态控制屏幕常亮 (飞行专注中阻止自动熄屏休眠，返回停机坪后恢复系统默认息屏管理)
   */
  public setKeepScreenOn(enable: boolean): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        if (win) {
          win.setWindowKeepScreenOn(enable);
        }
      }).catch((_e: Error) => { });
    } catch (_e) { }
  }

  aboutToDisappear() {
    this.setKeepScreenOn(false);
    if (this.flightDisplaySync) {
      this.flightDisplaySync.stop();
      this.flightDisplaySync = undefined;
    }
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
  }

  /**
   * 前台唤醒时检查并确保飞行引擎保持运行
   */
  public handleForegroundResume(): void {
    if (!this.vm.isFlightInProgress || this.vm.isFlightPaused) {
      return;
    }
    
    // 如果之前有切出后台的记录，则记录一次航线修正
    if (this.vm.backgroundStartTime > 0) {
      const durationMs = Date.now() - this.vm.backgroundStartTime;
      const durationMins = Math.max(1, Math.round(durationMs / 60000));
      this.recordFlightEvent('recovery', `切出应用 ${durationMins} 分钟`);
      this.vm.backgroundStartTime = 0;
    }

    if (!this.flightDisplaySync) {
      const now = Date.now();
      const currentElapsed = this.flightPauseElapsedMs + (now - this.flightPauseSegmentStartTime);
      this.startFlightAnimationDirectly(currentElapsed);
    }
  }

  /**
   * ✈️ 计算与精修机场地图原生 Marker (targetWidthPx = 175) 1:1 绝对一致的 planeScale 尺寸
   * 确保点击“开始专注”后，机身 3D 缩小落定的尺寸与地图上的飞机 Marker 像素级严格对齐！
   */
  public getTargetMarkerPlaneScale() {
    return this.physicsAnimEngine.getTargetMarkerPlaneScale();
  }

  public async checkAndRestoreActiveSession(): Promise<void> {
    try {
      // 1. 检查路由传参
      const params = router.getParams() as Record<string, Object>;
      if (params && params.startFlight) {
        this.vm.isCabinExposed = false;
        this.vm.isFullFocusMode = false;
        this.vm.isMapBackgroundVisible = true;
        this.vm.planeScale = this.getTargetMarkerPlaneScale();
        this.vm.planeY = 0;
        this.vm.planeX = 0;
        this.vm.isVehiclesDocked = true;
        this.vm.isHudVisible = true;
        return;
      }

      // 2. 检查持久化 FlightSessionStore 中的活跃专注会话
      const session = await FlightSessionStore.getSession();
      if (session && session.isFlightActive) {
        const now = Date.now();
        const elapsedMs = now - session.startTimeMs;
        const totalDurationMs = session.durationMin * 60 * 1000;

        if (elapsedMs < totalDurationMs) {
          // 恢复活跃飞行会话并进入精修地图
          if (session.destCode) {
            const dest = findAirportByCode(session.destCode);
            if (dest) {
              this.currentDestinationAirport = dest;
            }
          }
          this.vm.selectedFocusDurationMinutes = session.durationMin;
          this.vm.isCabinExposed = false;
          this.vm.isFullFocusMode = false;
          this.vm.isMapBackgroundVisible = true;
          this.vm.planeScale = this.getTargetMarkerPlaneScale();
          this.vm.planeOpacity = 0;
          this.vm.planeY = 0;
          this.vm.planeX = 0;
          this.vm.isPlaneMarkerActive = true;
          this.vm.isVehiclesDocked = true;
          this.vm.isHudVisible = true;

          // 恢复断点续飞
          if (session.isWindowViewMode) {
            this.vm.isWindowViewMode = true;
          }
          this.startFlightAnimationDirectly(elapsedMs);
          return;
        } else {
          // 专注时长已在后台自然完成
          this.vm.isWindowViewMode = false;
          await FlightSessionStore.clearSession();
          SoundEffectHelper.playCabinArrivalChime();
          this.triggerHapticFeedback();
          this.vm.honkToastText = '🛬 专注已在后台完成！成功降落目的地';
          this.vm.isHonkToastVisible = true;
          setTimeout(() => { this.vm.isHonkToastVisible = false; }, 3000);
          setTimeout(() => {
            this.vm.isArrivalBoardingPassVisible = true;
          }, 800);
        }
      }

      // 3. 停机坪主页：区分首次冷启动与后台切回前台
      this.vm.isCabinExposed = false;
      this.vm.isFullFocusMode = false;
      this.vm.isMapBackgroundVisible = false;
      this.vm.planeScale = 1.0;
      this.vm.planeY = -45;
      this.vm.planeX = 0;
      this.vm.isVehiclesDocked = true;
      this.vm.isHudVisible = true;

      if (!this.hasColdLaunchAnimationPlayed) {
        this.hasColdLaunchAnimationPlayed = true;
        this.startAnimationSequence();
      } else {
        // 后台切回前台：保持加油车已就位停靠，飞机保持机位不动，零重复动画
        this.vm.fuelTruckX = 120;
        this.vm.fuelTruckY = -85;
        this.vm.fuelTruckRotate = -38.66;
        this.vm.isFuelTruckParked = true;
      }
    } catch (e) {
      // ignore
    }
  }

  /**
   * 当用户在首页放大的机舱中点击任意座椅或确认就座起飞时：
   * 彻底取消页面跳转！在当前页面内实现纯 3D 无缝缩小退场与背后华为 Petal Maps 地图的平滑浮现
   */
  public onSeatSelectedInIndex(seatId: string, tagId: string = 'study', durationMinutes?: number) {
    this.flightSessionService.onSeatSelectedInIndex(seatId, tagId, durationMinutes);
  }

  /**
   * ✈️ 直接动力全推起飞并进入 60 FPS 巡航 (支持 resumeElapsedMs 断点续飞)
   */
  public async startFlightAnimationDirectly(resumeElapsedMs: number = 0): Promise<void> {
    this.setKeepScreenOn(true); // 🚀 开启专注飞行：阻止手机自动休眠熄屏，保持桌面仪表盘常亮
    if (resumeElapsedMs === 0) {
      // 🔔 动力全推起飞：播放经典民航客舱“叮咚～”提示音与触感反馈
      SoundEffectHelper.playCabinArrivalChime();
      this.triggerHapticFeedback();
    }
    this.turbulenceCooldownFrames = 5400 + Math.floor(Math.random() * 3600); // 起飞后前 90~150 秒保持绝对平静稳定巡航
    this.targetTurbulenceYaw = 0;
    this.curTurbulenceYaw = 0;
    this.targetTurbulenceLateral = 0;
    this.curTurbulenceLateral = 0;
    this.vm.isTurbulenceAlertVisible = false;
    const durationMinutes = this.vm.selectedFocusDurationMinutes > 0 ? this.vm.selectedFocusDurationMinutes : 45;
    const totalFlightDurationMs = durationMinutes * 60 * 1000;

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

    if (resumeElapsedMs <= 0) {
      const rStart = getCtuRunwayStart();
      this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
      if (this.currentPlaneMarker) {
        try {
          this.currentPlaneMarker.setPosition(rStart);
          this.currentPlaneMarker.setRotation(202.5);
        } catch (e) { }
      }
      this.vm.honkToastText = `🚀 动力全推，离开成都双流 (CTU)！专注 ${durationMinutes} 分钟，飞往 ${destCity} · ${destName} (${destCode})...`;
      this.vm.isHonkToastVisible = true;
      setTimeout(() => { this.vm.isHonkToastVisible = false; }, 4000);
    } else {
      this.vm.honkToastText = `✈️ 专注飞行继续巡航中 · 飞往 ${destCity} (${destCode})`;
      this.vm.isHonkToastVisible = true;
      setTimeout(() => { this.vm.isHonkToastVisible = false; }, 2500);
    }

    const initRemainingMs = Math.max(0, totalFlightDurationMs - (resumeElapsedMs > 0 ? resumeElapsedMs : 0));
    const initSec = Math.ceil(initRemainingMs / 1000);
    const initMm = Math.floor(initSec / 60).toString().padStart(2, '0');
    const initSs = (initSec % 60).toString().padStart(2, '0');
    this.vm.remainingTimeString = `${initMm}:${initSs}`;

    // 2. 获取全程三阶段高密度航线点集 (动态适配目标目的地)
    const points: mapCommon.LatLng[] = MapRenderHelper.getFullFlightPathPoints(this.currentDestinationAirport);
    if (!points || points.length < 2) {
      return;
    }
    this.vm.currentFlightPoints = points;

    // 初始化单向 6 色无缝平行彩虹光带 (紫->蓝->绿->黄->橙->红)
    if (this.rainbowTraversedPoints.length === 0) {
      this.rainbowTraversedPoints = [points[0]];
    }
    await this.initRainbowPolylinesIfNeeded();

    // 3b. 预计算物理距离数组 (Cumulative Distance)，让飞机保持真实的地理巡航速度
    const profile: RouteDistanceProfile = FlightRouteEngine.buildDistanceProfile(points);
    const physicalDistances = profile.physicalDistances;
    const rawTotalPhysicalDist = profile.rawTotalPhysicalDist;
    const cumulativeDistances = profile.cumulativeDistances;
    const totalRouteDistance = profile.totalRouteDistance;

    const initProgress = totalFlightDurationMs > 0 ? (resumeElapsedMs > 0 ? resumeElapsedMs : 0) / totalFlightDurationMs : 0;
    this.vm.remainingDistanceKm = Math.max(0, Math.round((1.0 - initProgress) * rawTotalPhysicalDist));

    this.vm.flightCurrentIndex = 0;
    this.vm.isFlightInProgress = true;

    if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }

    this.flightPauseElapsedMs = resumeElapsedMs > 0 ? resumeElapsedMs : 0;
    this.flightPauseSegmentStartTime = Date.now();
    this.vm.isFlightPaused = false;

    // Catmull-Rom 样条插值函数
    const getSmoothPos = (idx: number): mapCommon.LatLng => {
      return FlightRouteEngine.getSmoothPosition(points, idx);
    };

    // 若恢复断点，预先填充 rainbowTraversedPoints 历史点
    if (resumeElapsedMs > 0) {
      const initialProgress = Math.min(1.0, resumeElapsedMs / totalFlightDurationMs);
      const initialTargetDist = initialProgress * totalRouteDistance;
      let initSeg = 0;
      for (let i = 0; i < points.length - 1; i++) {
        if (initialTargetDist >= cumulativeDistances[i] && initialTargetDist <= cumulativeDistances[i + 1]) {
          initSeg = i;
          break;
        }
      }
      if (initSeg >= points.length - 1) {
        initSeg = points.length - 2;
      }
      const dStart = cumulativeDistances[initSeg];
      const dEnd = cumulativeDistances[initSeg + 1];
      const sLen = dEnd - dStart;
      const sProg = sLen > 0 ? (initialTargetDist - dStart) / sLen : 0;
      const rawInitIdx = initSeg + sProg;
      const initIntIdx = Math.floor(rawInitIdx);
      this.rainbowTraversedPoints = [];
      for (let ptIdx = 0; ptIdx <= initIntIdx; ptIdx++) {
        this.rainbowTraversedPoints.push(points[ptIdx]);
      }
      this.lastTraversedPointIndex = initIntIdx;
    }

    let firstTickFired = (resumeElapsedMs > 0);
    this.flightDisplaySync = displaySync.create();
    this.flightDisplaySync.on('frame', () => {
      if (this.vm.isFlightPaused) {
        return;
      }

      const now = Date.now();
      const segmentElapsed = now - this.flightPauseSegmentStartTime;
      const totalElapsed = this.flightPauseElapsedMs + segmentElapsed;
      const overallProgress = Math.min(1.0, totalElapsed / totalFlightDurationMs);

      // 实时计算专注倒计时剩余时间
      const remainingMs = Math.max(0, totalFlightDurationMs - totalElapsed);
      const remainingSec = Math.ceil(remainingMs / 1000);
      const mm = Math.floor(remainingSec / 60).toString().padStart(2, '0');
      const ss = (remainingSec % 60).toString().padStart(2, '0');
      const newTimeStr = `${mm}:${ss}`;
      if (this.vm.remainingTimeString !== newTimeStr) {
        this.vm.remainingTimeString = newTimeStr;
      }

      // 实时计算剩余飞行公里数
      const remainingKm = Math.max(0, Math.round((1.0 - overallProgress) * rawTotalPhysicalDist));
      if (this.vm.remainingDistanceKm !== remainingKm) {
        this.vm.remainingDistanceKm = remainingKm;
      }

      // 终点到达逻辑
      if (overallProgress >= 1.0) {
        if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }
        this.vm.isFlightInProgress = false;
        this.vm.isWindowViewMode = false;
        FlightSessionStore.clearSession();

        // 🔔 播放经典民航客舱“叮咚～”落地提示音与触感反馈
        SoundEffectHelper.playCabinArrivalChime();
        this.triggerHapticFeedback();

        // 🎯 保证飞机 100% 绝对死锁在跑道 80% 最终停止点
        const finalPos = points[points.length - 1];
        this.currentPlaneGeoPos = finalPos;
        this.vm.currentPlaneLat = finalPos.latitude;
        this.vm.currentPlaneLng = finalPos.longitude;
        this.lastFlightInterpPos = finalPos;

        // 🧭 终点姿态计算：精确获取降落跑道最终方向角并设置 Heading-Up 机头朝上
        const pPrev = points[Math.max(0, points.length - 2)];
        const finalRunwayBearing = MapRenderHelper.calculateBearing(pPrev, finalPos);
        this.planeMarkerRotation = finalRunwayBearing;
        AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);

        const headingUpBearing = (360 - this.planeMarkerRotation + 360) % 360;
        this.currentMapBearing = headingUpBearing;
        AppStorage.setOrCreate('hudMapBearing', Math.round(headingUpBearing));

        if (this.currentPlaneMarker) {
          try {
            this.currentPlaneMarker.setPosition(finalPos);
            this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
            this.currentPlaneMarker.setAlpha(1.0);
          } catch (e) { }
        }
        if (this.huaweiMapController && this.vm.isCameraFollowLocked) {
          try {
            this.huaweiMapController.moveCamera(map.newCameraPosition({
              target: { latitude: finalPos.latitude, longitude: finalPos.longitude },
              zoom: 17.2,
              bearing: headingUpBearing,
              tilt: 0
            }));
          } catch (e) { }
        }
        this.updatePlaneScreenPosition(finalPos);

        const destApt = this.currentDestinationAirport || findAirportByCode('PEK');
        const destCity = destApt ? destApt.city : '北京';
        const destName = destApt ? destApt.name : '北京首都国际机场';
        const destCode = destApt ? destApt.code : 'PEK';
        this.vm.honkToastText = `🛬 专注 ${durationMinutes} 分钟完成！成功降落抵达 ${destCity} · ${destName} (${destCode})`;
        this.vm.isHonkToastVisible = true;
        setTimeout(() => {
          this.vm.isArrivalBoardingPassVisible = true;
        }, 800);
        return;
      }

      // 基于真实物理距离重映射当前的真实数组进度 (rawIndex)
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
      this.vm.currentFlightRawIndex = rawIndex;

      const interpPos = getSmoothPos(rawIndex);
      this.lastFlightInterpPos = interpPos; // 实时记录最新飞机坐标，供切换 Marker 图标时定位

      // 🌈 60 FPS 连续平滑拉伸 6 色同心彩虹色带
      const currentIntIdx = Math.floor(rawIndex);
      if (currentIntIdx > this.lastTraversedPointIndex) {
        for (let ptIdx = this.lastTraversedPointIndex + 1; ptIdx <= currentIntIdx; ptIdx++) {
          if (ptIdx < points.length) {
            this.rainbowTraversedPoints.push(points[ptIdx]);
          }
        }
        this.lastTraversedPointIndex = currentIntIdx;
      }

      // 🎬 电影级视距伸缩（绝对时间 + 速度自适应巡航 zoom）
      // 起飞阶段固定 90s，落地阶段固定 120s，与总时长无关，消除长时间专注初期贴地低空视觉飞速问题
      const TAKEOFF_MS = 90000;
      const LANDING_MS = 120000;
      // 速度自适应巡航 zoom：速度慢→镜头拉近，速度快→镜头拉远，视觉划行速度始终保持民航感
      // 基准：800 km/h 对应 zoom 13，每倍速度差±1 zoom（因 zoom 是 log2 尺度）
      const speedKmh = (rawTotalPhysicalDist / totalFlightDurationMs) * 3600000; // km/h
      const cruiseZoom = Math.min(15.5, Math.max(10.5, 13.0 + Math.log2(800 / Math.max(speedKmh, 1))));
      let cinematicZoom = cruiseZoom;
      if (totalElapsed < TAKEOFF_MS) {
        // 起飞 90s：zoom 17.2 → cruiseZoom（三次缓出）
        const t = totalElapsed / TAKEOFF_MS;
        const easeT = 1 - Math.pow(1 - t, 3);
        cinematicZoom = 17.2 - (17.2 - cruiseZoom) * easeT;
      } else if (remainingMs < LANDING_MS && remainingMs >= 0) {
        // 落地前 120s：zoom cruiseZoom → 17.2（余弦缓入缓出）
        const t = 1.0 - remainingMs / LANDING_MS;
        const easeT = (1 - Math.cos(Math.PI * t)) / 2;
        cinematicZoom = cruiseZoom + (17.2 - cruiseZoom) * easeT;
      }
      this.vm.currentTargetCinematicZoom = cinematicZoom;

      const displayPoints = this.rainbowTraversedPoints.slice();
      displayPoints.push(interpPos);

      // 🌈 航线光带实时更新 (两两饱满重叠，绝对零间隙)
      if (this.rainbowPolylines.length > 0) {
        const currentCam = this.huaweiMapController?.getCameraPosition();
        const realZoom = (currentCam && currentCam.zoom) ? currentCam.zoom : (this.vm.isCameraFollowLocked ? cinematicZoom : this.currentZoomLevel);
        const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom, this.selectedRouteStyle);
        for (let k = 0; k < this.rainbowPolylines.length; k++) {
          const poly = this.rainbowPolylines[k];
          if (poly && parallelStripes[k] && parallelStripes[k].length > 0) {
            try {
              poly.setPoints(parallelStripes[k]);
            } catch (e) { }
          }
        }
      }

      this.flightTickFrameCount++;

      // 🌪️ 万米高空高仿真巡航气流微扰系统 (跑道与起飞爬升段严格锁定为 0，高空巡航细腻微扰)
      // segIndex >= 30 且起飞超过 15 秒且未进入最后 30 秒降落区时，才进入高空气流环境
      const isHighAltitudeCruise = segIndex >= 30 && totalElapsed >= 15000 && remainingMs >= 30000;
      if (isHighAltitudeCruise) {
        if (this.turbulenceCooldownFrames > 0) {
          this.turbulenceCooldownFrames--;
        } else {
          if (Math.abs(this.targetTurbulenceYaw) < 0.03) {
            // 触发一次偶发的高空气流微迎风修正与微颤抖 (细腻真实：偏航角 ±0.9°~±1.6°, 侧向横漂 ±1.8~3.8米)
            const sign = Math.random() > 0.5 ? 1 : -1;
            this.targetTurbulenceYaw = sign * (0.9 + Math.random() * 0.7);
            this.targetTurbulenceLateral = sign * (1.8 + Math.random() * 2.0);
            this.turbulenceCooldownFrames = 180 + Math.floor(Math.random() * 60); // 扰动仅持续 3.0~4.0 秒
            const q = this.turbulenceQuotes[Math.floor(Math.random() * this.turbulenceQuotes.length)];
            this.vm.turbulenceMessageText = q;
            this.vm.isTurbulenceAlertVisible = true;
            this.recordFlightEvent('turbulence', q);
          } else {
            // 自动驾驶阻尼系统平稳修正回中心基准航线，进入长达 2.5~5.0 分钟的宁静平稳巡航
            this.targetTurbulenceYaw = 0;
            this.targetTurbulenceLateral = 0;
            this.turbulenceCooldownFrames = 9000 + Math.floor(Math.random() * 9000); // 平稳巡航 150.0~300.0 秒 (2.5~5分钟)
            this.vm.isTurbulenceAlertVisible = false;
          }
        }
        // 极平滑的指数阻尼滤波器 (60FPS 柔和过渡，绝无瞬移生硬感)
        this.curTurbulenceYaw += (this.targetTurbulenceYaw - this.curTurbulenceYaw) * 0.025;
        this.curTurbulenceLateral += (this.targetTurbulenceLateral - this.curTurbulenceLateral) * 0.02;
      } else {
        // 地面停靠、跑道滑跑及初始爬升阶段严格锁定为 0，绝对保持在跑道中线
        this.targetTurbulenceYaw = 0;
        this.curTurbulenceYaw = 0;
        this.targetTurbulenceLateral = 0;
        this.curTurbulenceLateral = 0;
        this.vm.isTurbulenceAlertVisible = false;
      }

      // 极轻微的高空呼吸感微颤动 (High-frequency atmospheric breathing jitter: ±0.20°)
      const jitter = isHighAltitudeCruise ? (Math.sin(this.flightTickFrameCount * 0.28) * 0.20 * (Math.abs(this.curTurbulenceYaw) > 0.2 ? 1.0 : 0.35)) : 0;
      const effectiveTurbulenceAngle = isHighAltitudeCruise ? (this.curTurbulenceYaw + jitter) : 0;

      // 角度计算
      if (segIndex < 20) {
        this.planeMarkerRotation = 202.5;
      } else {
        const lookAheadPos = getSmoothPos(rawIndex + 1.2);
        const targetRotation = MapRenderHelper.calculateBearing(interpPos, lookAheadPos);
        
        let angleDiff = targetRotation - this.planeMarkerRotation;
        while (angleDiff < -180) angleDiff += 360;
        while (angleDiff > 180) angleDiff -= 360;
        
        this.planeMarkerRotation = this.planeMarkerRotation + angleDiff * 0.08;
      }

      // ✈️ 叠加气流偏航角后的最终视觉呈现角度
      const finalVisualRotation = (this.planeMarkerRotation + effectiveTurbulenceAngle + 360) % 360;
      AppStorage.setOrCreate('hudPlaneRotation', Math.round(finalVisualRotation));

      // ✈️ 叠加气流扰动后的微小侧向经纬度平滑位移
      let turbInterpPos = interpPos;
      if (Math.abs(this.curTurbulenceLateral) > 0.1) {
        const headingRad = this.planeMarkerRotation * (Math.PI / 180.0);
        const normalLat = Math.cos(headingRad + Math.PI / 2);
        const normalLon = Math.sin(headingRad + Math.PI / 2);
        const latOffsetDeg = (this.curTurbulenceLateral * normalLat) / 111132.0;
        const lonOffsetDeg = (this.curTurbulenceLateral * normalLon) / (111132.0 * Math.max(0.01, Math.cos(interpPos.latitude * Math.PI / 180.0)));
        turbInterpPos = {
          latitude: interpPos.latitude + latOffsetDeg,
          longitude: interpPos.longitude + lonOffsetDeg
        };
      }

      // 🧭 航向朝上 Heading-Up 跟随与平滑飞回机制 (60 FPS 逐帧动态追踪移动目标，零卡顿零瞬移)
      if (this.huaweiMapController && this.vm.isCameraFollowLocked) {
        try {
          let curTargetLat = interpPos.latitude;
          let curTargetLon = interpPos.longitude;
          let curTargetZoom = cinematicZoom;
          const headingUpBearing = (360 - this.planeMarkerRotation + 360) % 360;
          let curTargetBearing = headingUpBearing;

          if (this.isCameraFlyingBack) {
            const elapsed = Date.now() - this.flybackStartTime;
            const rawProgress = Math.min(1.0, elapsed / this.FLYBACK_DURATION_MS);
            const ease = 1.0 - Math.pow(1.0 - rawProgress, 3);

            // 经纬度从起始位置平滑过渡到【当前实时飞机最新位置】
            curTargetLat = this.flybackStartLat + (interpPos.latitude - this.flybackStartLat) * ease;
            curTargetLon = this.flybackStartLon + (interpPos.longitude - this.flybackStartLon) * ease;
            // 视距平滑过渡
            curTargetZoom = this.flybackStartZoom + (cinematicZoom - this.flybackStartZoom) * ease;

            // 航向角度最短路径平滑过渡
            let angleDiff = headingUpBearing - this.flybackStartBearing;
            while (angleDiff < -180) angleDiff += 360;
            while (angleDiff > 180) angleDiff -= 360;
            curTargetBearing = (this.flybackStartBearing + angleDiff * ease + 360) % 360;

            if (rawProgress >= 1.0) {
              this.isCameraFlyingBack = false;
            }
          }

          this.currentZoomLevel = curTargetZoom;
          AppStorage.setOrCreate('hudZoomLevel', parseFloat(curTargetZoom.toFixed(1)));
          
          this.currentMapBearing = curTargetBearing;
          AppStorage.setOrCreate('hudMapBearing', Math.round(curTargetBearing));

          this.huaweiMapController.moveCamera(map.newCameraPosition({
            target: { latitude: curTargetLat, longitude: curTargetLon },
            zoom: curTargetZoom,
            bearing: curTargetBearing,
            tilt: 0
          }));
        } catch (e) { }
      }

      // Marker
      if (!firstTickFired) {
        firstTickFired = true;
      } else if (this.currentPlaneMarker) {
        try {
          this.currentPlaneMarker.setPosition(turbInterpPos);
          this.currentPlaneMarker.setRotation(finalVisualRotation);
          this.currentPlaneMarker.setAlpha(1.0);
        } catch (e) { }
      }

      this.currentPlaneGeoPos = turbInterpPos;
      this.vm.currentPlaneLat = turbInterpPos.latitude;
      this.vm.currentPlaneLng = turbInterpPos.longitude;

      if (this.huaweiMapController) {
        try {
          const cam = this.huaweiMapController.getCameraPosition();
          if (cam && cam.target) {
            this.vm.currentCameraLat = cam.target.latitude;
            this.vm.currentCameraLng = cam.target.longitude;
            this.vm.currentCameraZoom = cam.zoom ?? 17.2;
            this.vm.currentCameraBearing = cam.bearing ?? this.currentMapBearing;
          }
        } catch (e) { }
      }

      // 🎯 60FPS 实时精准计算飞机 Marker 在屏幕上的物理坐标，确保粒子发射源 100% 跟随飞机
      this.updatePlaneScreenPosition(turbInterpPos, finalVisualRotation);
    });
    this.flightDisplaySync.start();
  }

  public currentPlaneGeoPos: mapCommon.LatLng = getCtuRunwayStart(); // 飞机在地图上的绝对真实地理经纬度坐标

  /**
   * 🎯 将飞机经纬度坐标转换为屏幕视口中的相对中心偏移 (vp)，实现粒子发射源 100% 精确跟随飞机 Marker
   */
  public updatePlaneScreenPosition(targetPos?: mapCommon.LatLng, visualRotation?: number) {
    this.physicsAnimEngine.updatePlaneScreenPosition(targetPos, visualRotation);
  }

  /**
   * 🌈 确保当前所选尾迹（彩虹/星光/泡泡/极光/尾迹云）的 6 色平行原生地图 Polyline 实例在地图上成功挂载并就绪 (100% 原生地理坐标吸附，永无任何延迟与视差)
   */
  /**
   * 🌈 确保仅在选择“缤纷彩虹光带 (rainbow)”时挂载 6 色平行彩虹光带；
   *    当选择其他粒子特效（星光、泡泡、云雾、极光）时，彻底隐藏并清除彩虹实线，留出纯净画布给灵动粒子。
   */
  /**
   * 🌈 确保当前所选航线风格（彩虹/极光/蔚蓝/炽热/经典）的原生地图 Polyline 实例在地图上成功挂载并就绪
   */
  public async initRainbowPolylinesIfNeeded(forceRecreate: boolean = false): Promise<void> {
    if (!this.huaweiMapController) {
      return;
    }

    // 🌟 经典航线模式下无需绘制额外平行彩色光带，彻底清理底层多余 Polyline
    if (this.selectedRouteStyle === 'classic') {
      if (this.rainbowPolylines.length > 0) {
        for (const p of this.rainbowPolylines) {
          try { p.remove(); } catch (e) { }
        }
        this.rainbowPolylines = [];
      }
      return;
    }

    const config = MapRenderHelper.getRouteConfig(this.selectedRouteStyle);
    const validColors: number[] = [];
    const validWidths: number[] = [];
    for (let i = 0; i < config.colors.length; i++) {
      if (config.widths[i] > 0 && config.colors[i] !== 0) {
        validColors.push(config.colors[i]);
        validWidths.push(config.widths[i]);
      }
    }

    if (this.rainbowPolylines.length === validColors.length && !forceRecreate) {
      return;
    }

    if (this.rainbowPolylines.length > 0) {
      for (const p of this.rainbowPolylines) {
        try { p.remove(); } catch (e) { }
      }
      this.rainbowPolylines = [];
    }

    const p0 = (this.rainbowTraversedPoints.length > 0) ? this.rainbowTraversedPoints[0] : getCtuRunwayStart();
    const polyPromises: Promise<object>[] = [];
    for (let k = 0; k < validColors.length; k++) {
      const color = validColors[k];
      polyPromises.push(this.huaweiMapController.addPolyline({
        points: [p0, p0],
        width: validWidths[k],
        color: color,
        zIndex: 1000 + k
      }));
    }
    try {
      const createdPolys = await Promise.all(polyPromises);
      this.rainbowPolylines = createdPolys as object as map.MapPolyline[];
      this.refreshRainbowPolylines();
    } catch (e) { }
  }

  /**
   * ✈️ 实时切换航线风格（二选一互斥：选航线风格时自动切换为纯净无尾）
   */
  public onRouteStyleChanged(newRouteId: string) {
    this.mapCameraEngine.onRouteStyleChanged(newRouteId);
  }

  /**
   * 💫 实时切换机尾物理喷气粒子特效（二选一互斥：选尾迹特效时自动切换为经典航线）
   */
  public onTrailEffectChanged(newTrailId: string) {
    this.mapCameraEngine.onTrailEffectChanged(newTrailId);
  }

  /**
   * 🌈 用户在任何缩放倍率下，即时刷新航线各色带地理坐标
   */
  public refreshRainbowPolylines(): void {
    if (this.rainbowTraversedPoints.length === 0) {
      return;
    }
    if (this.rainbowPolylines.length === 0) {
      this.initRainbowPolylinesIfNeeded();
      return;
    }
    const displayPoints = this.rainbowTraversedPoints.slice();
    const currentCam = this.huaweiMapController?.getCameraPosition();
    const realZoom = (currentCam && currentCam.zoom) ? currentCam.zoom : this.currentZoomLevel;
    const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom, this.selectedRouteStyle);
    for (let k = 0; k < this.rainbowPolylines.length; k++) {
      const poly = this.rainbowPolylines[k];
      if (poly && parallelStripes[k] && parallelStripes[k].length > 0) {
        try {
          poly.setPoints(parallelStripes[k]);
        } catch (e) { }
      }
    }
  }

  /**
   * ⏸️ 切换飞行暂停 / 恢复状态
   */
  public togglePauseFlight(): void {
    this.triggerHapticFeedback();
    if (this.vm.isFlightPaused) {
      this.vm.isFlightPaused = false;
      this.flightPauseSegmentStartTime = Date.now();
      this.vm.honkToastText = '▶️ 专注飞行已恢复，继续巡航...';
    } else {
      this.vm.isFlightPaused = true;
      const now = Date.now();
      this.flightPauseElapsedMs += (now - this.flightPauseSegmentStartTime);
      this.vm.honkToastText = '⏸️ 专注飞行已暂停';
    }
    this.vm.isHonkToastVisible = true;
    setTimeout(() => { this.vm.isHonkToastVisible = false; }, 2000);
  }
  public triggerHapticFeedback() {
    this.flightSessionService.triggerHapticFeedback();
  }
  public runFuelTruckDepartureAnimation() {
    this.physicsAnimEngine.runFuelTruckDepartureAnimation();
  }
  public onFuelTruckClick() {
    this.physicsAnimEngine.onFuelTruckClick();
  }
  public onTractorClick() {
    this.physicsAnimEngine.onTractorClick();
  }

  /**
   * 启动开场动画
   */
  public startAnimationSequence() {
    this.vm.planeY = -45;
    this.vm.planeX = 0;
    this.vm.planeScale = 1.0;
    this.vm.isPlaneMarkerActive = false;
    this.vm.isVehiclesDocked = true;
    this.vm.fuelTruckX = -350;
    this.vm.fuelTruckY = 220;
    this.vm.fuelTruckRotate = 90;
    this.vm.isHudVisible = true;
    this.vm.isFuelTruckParked = false;
    this.vm.isFuelTruckDeparting = false;
    this.vm.isHonkToastVisible = false;
    this.vm.isMapBackgroundVisible = false;
    this.vm.isCabinExposed = false;

    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }

    setTimeout(() => {
      this.context?.animateTo({ duration: 1700, curve: Curve.Friction }, () => {
        this.vm.planeY = -48;
      });

      setTimeout(() => {
        this.context?.animateTo({ duration: 350, curve: Curve.FastOutSlowIn }, () => {
          this.vm.planeY = -45;
        });
      }, 1700);

      setTimeout(() => {
        this.vm.isVehiclesDocked = true;
        this.runRealTruckPhysicsAnimation();
      }, 2050);

      setTimeout(() => {
        this.vm.isHudVisible = true;
      }, 3000);
    }, 50);
  }
  public runRealTruckPhysicsAnimation() {
    this.physicsAnimEngine.runRealTruckPhysicsAnimation();
  }

  /**
   * 🛡️ 拦截系统返回手势/按键，确保专注飞行体验
   */
  onBackPress(): boolean {
    if (this.vm.isAbortDialogVisible) {
      this.vm.isAbortDialogVisible = false;
      return true;
    }
    if (this.vm.isFlightInProgress && this.vm.isMapBackgroundVisible) {
      this.vm.isAbortDialogVisible = true;
      return true;
    }
    if (this.vm.isMapBackgroundVisible) {
      this.returnFromMapToHangar(false);
      return true;
    }
    if (this.vm.isCabinExposed || this.vm.isFullFocusMode) {
      this.returnFromCabinToHangar();
      return true;
    }
    return false;
  }

  public getCurrentCinematicZoom(): number {
    return this.vm.currentTargetCinematicZoom > 0 ? this.vm.currentTargetCinematicZoom : 13.0;
  }

  /**
   * ✈️ 电影级相机平滑飞回引擎 (逐帧 60FPS 阻尼插值，动态追踪目标，最短圆弧角度旋转，零卡顿零瞬移)
   */
  public startCameraFlyback() {
    this.mapCameraEngine.startCameraFlyback();
  }

  /**
   * 🧭 切换视角跟随锁定状态 (从自由拖拽与自定义缩放视角丝滑飞回并平滑缩放至巡航/跑道视角，彻底消除卡顿)
   */
  public toggleCameraFollowMode() {
    this.mapCameraEngine.toggleCameraFollowMode();
  }

  /**
   * 1. 停机坪 -> 放大机身并剖开机壳，进入机舱选座
   */
  public enterCabinSelectionFromHangar() {
    this.flightSessionService.enterCabinSelectionFromHangar();
  }

  /**
   * 2. 机舱选座界面 -> 合拢机壳并缩小飞机，返回停机坪
   */
  public returnFromCabinToHangar() {
    this.flightSessionService.returnFromCabinToHangar();
  }

  /**
   * 3. 精修地图飞行/完成界面 -> 直接干净返回停机坪
   */
  public returnFromMapToHangar(isAborted: boolean = false) {
    this.flightSessionService.returnFromMapToHangar(isAborted);
  }

  /**
   * 4. 终止飞行并安全备降返回停机坪
   */
  public abortFlightAndReturnToHangar() {
    this.flightSessionService.abortFlightAndReturnToHangar();
  }
}