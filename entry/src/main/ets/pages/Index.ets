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
import { FlightMapHudOverlay } from '../components/FlightMapHudOverlay';
import { FlightAbortConfirmDialog } from '../components/FlightAbortConfirmDialog';
import { FlightTrailSettingsOverlay } from '../components/FlightTrailSettingsOverlay';
import { FlightTrailParticleOverlay } from '../components/FlightTrailParticleOverlay';
import { MapRenderHelper } from '../utils/MapRenderHelper';
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
  private rainbowPolyline?: map.MapPolyline; // 🌈 纯正单向 6 色无缝彩虹光带实例 (紫 -> 蓝 -> 绿 -> 黄 -> 橙 -> 红)
  private rainbowPixelMap?: image.PixelMap; // 🌈 6 色光谱纯净纹理
  private rainbowPolylines: Array<map.MapPolyline> = []; // 旧多色带兼容备份
  private rainbowTraversedPoints: Array<mapCommon.LatLng> = []; // 已飞过的历史航线点集合
  private lastTraversedPointIndex: number = 0;
  private flightDisplaySync: displaySync.DisplaySync | undefined = undefined;
  @State flightCurrentIndex: number = 0;
  @State isFlightInProgress: boolean = false;
  @State currentTargetCinematicZoom: number = 13.0; // 当前飞行巡航阶段的目标视距Zoom
  @State selectedFocusDurationMinutes: number = 15; // 用户选定的专注飞行时长 (默认15分钟)
  @State remainingTimeString: string = '15:00';     // 专注倒计时剩余时间文本
  @State remainingDistanceKm: number = 0;           // 剩余飞行里程 (公里)
  @State currentFocusTagTitle: string = '深度学习';  // 当前专注类型/任务名称
  private animTimer: number = -1;

  @StorageLink('selectedDestinationAirport') currentDestinationAirport?: Airport = undefined;
  @State isAbortDialogVisible: boolean = false; // 飞行终止备降二次确认弹窗显隐
  @StorageLink('selectedTrailEffect') selectedTrailEffect: string = 'rainbow'; // 当前所选巡航尾迹特效
  @State isTrailSettingsVisible: boolean = false; // 尾迹个性化设置抽屉显隐
  @State isCameraFollowLocked: boolean = true; // 飞行跟随锁定状态 (true: 自动跟拍居中, false: 用户自由拖拽地图)
  @State currentPlaneLat: number = 30.5828; // 飞机当前真实地理纬度
  @State currentPlaneLng: number = 103.9467; // 飞机当前真实地理经度
  @State currentCameraLat: number = 30.5828; // 当前相机视口中心纬度
  @State currentCameraLng: number = 103.9467; // 当前相机视口中心经度
  @State currentCameraZoom: number = 17.2; // 当前相机视口缩放倍率
  @State currentCameraBearing: number = 157.5; // 当前相机方位角
  @State planeScreenOffsetX: number = 0; // 飞机当前屏幕中心 X 偏移 (vp)
  @State planeScreenOffsetY: number = 0; // 飞机当前屏幕中心 Y 偏移 (vp)
  @State planeScreenDynamicRotation: number = 0; // 飞机在屏幕上的实际渲染朝向角
  @State currentFlightRawIndex: number = 0; // 飞机当前在航线中的平滑浮点索引 (用于尾迹弯曲跟随)
  @State currentFlightPoints: Array<mapCommon.LatLng> = []; // 全量平滑航线点集合 (供粒子系统进行曲率插值)
  private screenVpWidth: number = 360;
  private screenVpHeight: number = 780;
  private isCameraFlyingBack: boolean = false; // 镜头平滑飞回过渡中标志
  private mapTouchStartX: number = 0; // 触摸起始 X（用于位移阈值判断真实拖拽）
  private mapTouchStartY: number = 0; // 触摸起始 Y
  private lastFlightInterpPos: mapCommon.LatLng = { latitude: 30.5828, longitude: 103.9467 }; // 飞行中最后已知实时位置（用于切换 Marker 图标时定位）
  private flybackStartTime: number = 0;
  private readonly FLYBACK_DURATION_MS: number = 750;
  private flybackStartLat: number = 0;
  private flybackStartLon: number = 0;
  private flybackStartZoom: number = 17.2;
  private flybackStartBearing: number = 158;
  private groundFlybackTimerSync?: displaySync.DisplaySync; // 地面精修机场状态下的平滑 60FPS 帧动画
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

  @State isTopToastVisible: boolean = false;
  @State topToastMessage: string = '';
  private topToastTimer: number = -1;

  public showTopToast(message: string, duration: number = 3500): void {
    if (this.topToastTimer !== -1) {
      clearTimeout(this.topToastTimer);
      this.topToastTimer = -1;
    }
    this.topToastMessage = message;
    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.isTopToastVisible = true;
    });
    this.topToastTimer = setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
        this.isTopToastVisible = false;
      });
      this.topToastTimer = -1;
    }, duration);
  }

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
   * 🗺️ 循环切换地图图层视角：卫星遥感 ➔ 地貌地形 ➔ 暗夜深色航图 (无干扰静默切换)
   */
  private toggleMapTypeMode(): void {
    this.triggerHapticFeedback();
    if (this.currentMapType === mapCommon.MapType.SATELLITE) {
      this.currentMapType = mapCommon.MapType.TERRAIN;
      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.DAY);
          this.huaweiMapController.setCustomMapStyle({ styleContent: '' });
          this.huaweiMapController.setMapType(this.currentMapType);
        } catch (e) { }
      }
    } else if (this.currentMapType === mapCommon.MapType.TERRAIN) {
      // 🌃 切换至暗夜深色夜间航图模式 (加载纯净无注记自定义航图样式)
      this.currentMapType = mapCommon.MapType.STANDARD;
      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.NIGHT);
          this.huaweiMapController.setCustomMapStyle({ styleContent: CLEAN_DARK_AVIATION_STYLE_JSON });
          this.huaweiMapController.setMapType(this.currentMapType);
        } catch (e) { }
      }
    } else {
      // 🛰️ 切换回卫星遥感实景模式
      this.currentMapType = mapCommon.MapType.SATELLITE;
      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.DAY);
          this.huaweiMapController.setCustomMapStyle({ styleContent: '' });
          this.huaweiMapController.setMapType(this.currentMapType);
        } catch (e) { }
      }
    }
    // ✈️ 切换地图模式后刷新飞机 Marker 图标（地形图加深色描边，其他模式无描边）
    const targetIcon = this.getPlaneMarkerIconResource();
    const pos = this.lastFlightInterpPos || getCtuRunwayStart();
    const rot = this.planeMarkerRotation;
    if (this.currentPlaneMarker) {
      try { this.currentPlaneMarker.remove(); } catch (e) { }
      this.currentPlaneMarker = undefined;
    }
    if (this.huaweiMapController) {
      this.huaweiMapController.addMarker({
        position: pos,
        icon: targetIcon,
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: rot,
        zIndex: 2000,
        clickable: false
      }).then((marker) => {
        this.currentPlaneMarker = marker;
        this.currentPlaneMarker.setAlpha(1.0);
      }).catch((e: Error) => { });
    }
  }

  private getPlaneMarkerIconResource(): Resource {
    if (this.currentMapType === mapCommon.MapType.TERRAIN) {
      return $r('app.media.b737_800_top_3_stroked_medium');
    }
    return $r('app.media.b737_800_top_3_medium');
  }

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
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
          if (this.isCameraFlyingBack || this.isCameraFollowLocked) {
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
            if (cam.target) {
              this.currentCameraLat = cam.target.latitude;
              this.currentCameraLng = cam.target.longitude;
            }
            if (cam.zoom !== undefined) {
              this.currentCameraZoom = cam.zoom;
            }
            if (cam.bearing !== undefined) {
              this.currentCameraBearing = cam.bearing;
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
      const planePixelMap = await this.getScaledPlaneMarkerIcon(175, this.currentMapType === mapCommon.MapType.TERRAIN);

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
      if (this.isFlightInProgress) {
        await this.initRainbowPolylinesIfNeeded();
        this.refreshRainbowPolylines();
      }
    } catch (e) {
      console.error('Index Petal Map setup error:', JSON.stringify(e));
    }
  }

  private getFocusTargetTitle(): string {
    const dest = this.currentDestinationAirport || findAirportByCode('PEK');
    const destCity = dest ? dest.city : '北京';
    return `专注巡航 · 飞往${destCity}`;
  }

  private getFocusTargetSubtitle(): string {
    const dest = this.currentDestinationAirport || findAirportByCode('PEK');
    const destName = dest ? dest.name : '北京首都国际机场';
    const destCode = dest ? dest.code : 'PEK';
    return `CTU 成都双流 ➔ ${destCode} ${destName}`;
  }

  /**
   * ✈️ 使用鸿蒙 PixelMap 原生 API 对飞机高清原图与机身阴影进行代码级高质感融合
   * 采用对称画布设计，确保 Marker 的中心 (0.5, 0.5) 与飞机机身中轴线 100% 绝对同轴对齐！
   * @param targetWidthPx 目标屏幕宽度像素 (如 175)
   */
  private async getScaledPlaneMarkerIcon(targetWidthPx: number, withStroke: boolean = false): Promise<image.PixelMap | undefined> {
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

      // 5a. 地形图模式：在绘制机身前先向外扩散像素生成深色描边轮廓
      if (withStroke) {
        const strokeWidth = 8;
        const sR = 18, sG = 22, sB = 42, sA = 220;
        for (let y = 0; y < targetHeightPx; y++) {
          for (let x = 0; x < targetWidthPx; x++) {
            if (planePixels[(y * targetWidthPx + x) * 4 + 3] > 30) {
              for (let dy = -strokeWidth; dy <= strokeWidth; dy++) {
                for (let dx = -strokeWidth; dx <= strokeWidth; dx++) {
                  if (dx * dx + dy * dy > strokeWidth * strokeWidth) { continue; }
                  const nx = x + planeOffsetX + dx;
                  const ny = y + planeOffsetY + dy;
                  if (nx >= 0 && nx < canvasW && ny >= 0 && ny < canvasH) {
                    const nIdx = (ny * canvasW + nx) * 4;
                    if (canvasPixels[nIdx + 3] < sA) {
                      canvasPixels[nIdx] = sR;
                      canvasPixels[nIdx + 1] = sG;
                      canvasPixels[nIdx + 2] = sB;
                      canvasPixels[nIdx + 3] = sA;
                    }
                  }
                }
              }
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

  private isInitialAppeared: boolean = false;
  private hasColdLaunchAnimationPlayed: boolean = false; // 首次冷启动开场动画完成标记

  aboutToAppear() {
    this.isInitialAppeared = true;
    this.checkAndRestoreActiveSession();
  }

  onPageShow() {
    // 🛡️ 核心修复：如果当前已经在精修地图模式或处于飞行中，坚决不重置页面，保护当前地图界面
    if (this.isMapBackgroundVisible || this.isFlightInProgress) {
      this.handleForegroundResume();
      return;
    }
    this.checkAndRestoreActiveSession();
  }

  aboutToDisappear() {
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
  private handleForegroundResume(): void {
    if (!this.isFlightInProgress || this.isFlightPaused) {
      return;
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
      // 1. 检查路由传参
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
          this.selectedFocusDurationMinutes = session.durationMin;
          this.isCabinExposed = false;
          this.isFullFocusMode = false;
          this.isMapBackgroundVisible = true;
          this.planeScale = this.getTargetMarkerPlaneScale();
          this.planeOpacity = 0;
          this.planeY = 0;
          this.planeX = 0;
          this.isPlaneMarkerActive = true;
          this.isVehiclesDocked = true;
          this.isHudVisible = true;

          // 恢复断点续飞
          this.startFlightAnimationDirectly(elapsedMs);
          return;
        } else {
          // 专注时长已在后台自然完成
          await FlightSessionStore.clearSession();
          this.honkToastText = '🛬 专注已在后台完成！成功降落目的地';
          this.isHonkToastVisible = true;
          setTimeout(() => { this.isHonkToastVisible = false; }, 3000);
        }
      }

      // 3. 停机坪主页：区分首次冷启动与后台切回前台
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.isMapBackgroundVisible = false;
      this.planeScale = 1.0;
      this.planeY = -45;
      this.planeX = 0;
      this.isVehiclesDocked = true;
      this.isHudVisible = true;

      if (!this.hasColdLaunchAnimationPlayed) {
        this.hasColdLaunchAnimationPlayed = true;
        this.startAnimationSequence();
      } else {
        // 后台切回前台：保持加油车已就位停靠，飞机保持机位不动，零重复动画
        this.fuelTruckX = 120;
        this.fuelTruckY = -85;
        this.fuelTruckRotate = -38.66;
        this.isFuelTruckParked = true;
      }
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
    this.currentFocusTagTitle = tagName;
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

          this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
          if (this.currentPlaneMarker) {
            try {
              this.currentPlaneMarker.setPosition(getCtuRunwayStart());
              this.currentPlaneMarker.setRotation(202.5);
              this.currentPlaneMarker.setAlpha(1.0);
            } catch (e) { }
          } else {
            const planePixelMap = await this.getScaledPlaneMarkerIcon(175, this.currentMapType === mapCommon.MapType.TERRAIN);
            this.currentPlaneMarker = await this.huaweiMapController.addMarker({
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
          }
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
   * ✈️ 直接动力全推起飞并进入 60 FPS 巡航 (支持 resumeElapsedMs 断点续飞)
   */
  private async startFlightAnimationDirectly(resumeElapsedMs: number = 0): Promise<void> {
    const durationMinutes = this.selectedFocusDurationMinutes > 0 ? this.selectedFocusDurationMinutes : 45;
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
      this.honkToastText = `🚀 动力全推，离开成都双流 (CTU)！专注 ${durationMinutes} 分钟，飞往 ${destCity} · ${destName} (${destCode})...`;
      this.isHonkToastVisible = true;
      setTimeout(() => { this.isHonkToastVisible = false; }, 4000);
    } else {
      this.honkToastText = `✈️ 专注飞行继续巡航中 · 飞往 ${destCity} (${destCode})`;
      this.isHonkToastVisible = true;
      setTimeout(() => { this.isHonkToastVisible = false; }, 2500);
    }

    const initRemainingMs = Math.max(0, totalFlightDurationMs - (resumeElapsedMs > 0 ? resumeElapsedMs : 0));
    const initSec = Math.ceil(initRemainingMs / 1000);
    const initMm = Math.floor(initSec / 60).toString().padStart(2, '0');
    const initSs = (initSec % 60).toString().padStart(2, '0');
    this.remainingTimeString = `${initMm}:${initSs}`;

    // 2. 获取全程三阶段高密度航线点集 (动态适配目标目的地)
    const points: mapCommon.LatLng[] = MapRenderHelper.getFullFlightPathPoints(this.currentDestinationAirport);
    if (!points || points.length < 2) {
      return;
    }
    this.currentFlightPoints = points;

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
    this.remainingDistanceKm = Math.max(0, Math.round((1.0 - initProgress) * rawTotalPhysicalDist));

    this.flightCurrentIndex = 0;
    this.isFlightInProgress = true;

    if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }

    this.flightPauseElapsedMs = resumeElapsedMs > 0 ? resumeElapsedMs : 0;
    this.flightPauseSegmentStartTime = Date.now();
    this.isFlightPaused = false;

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
      if (this.isFlightPaused) {
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
      if (this.remainingTimeString !== newTimeStr) {
        this.remainingTimeString = newTimeStr;
      }

      // 实时计算剩余飞行公里数
      const remainingKm = Math.max(0, Math.round((1.0 - overallProgress) * rawTotalPhysicalDist));
      if (this.remainingDistanceKm !== remainingKm) {
        this.remainingDistanceKm = remainingKm;
      }

      // 终点到达逻辑
      if (overallProgress >= 1.0) {
        if (this.flightDisplaySync) { this.flightDisplaySync.stop(); this.flightDisplaySync = undefined; }
        this.isFlightInProgress = false;
        FlightSessionStore.clearSession();

        // 🎯 保证飞机 100% 绝对死锁在跑道 80% 最终停止点
        const finalPos = points[points.length - 1];
        this.currentPlaneGeoPos = finalPos;
        this.currentPlaneLat = finalPos.latitude;
        this.currentPlaneLng = finalPos.longitude;
        this.lastFlightInterpPos = finalPos;
        if (this.currentPlaneMarker) {
          try {
            this.currentPlaneMarker.setPosition(finalPos);
            this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
          } catch (e) { }
        }
        if (this.huaweiMapController && this.isCameraFollowLocked) {
          try {
            this.huaweiMapController.moveCamera(map.newCameraPosition({
              target: { latitude: finalPos.latitude, longitude: finalPos.longitude },
              zoom: 17.2,
              bearing: this.currentMapBearing,
              tilt: 0
            }));
          } catch (e) { }
        }
        this.updatePlaneScreenPosition(finalPos);

        const destApt = this.currentDestinationAirport || findAirportByCode('PEK');
        const destCity = destApt ? destApt.city : '北京';
        const destName = destApt ? destApt.name : '北京首都国际机场';
        const destCode = destApt ? destApt.code : 'PEK';
        this.honkToastText = `🛬 专注 ${durationMinutes} 分钟完成！成功降落抵达 ${destCity} · ${destName} (${destCode})`;
        this.isHonkToastVisible = true;
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
      this.currentFlightRawIndex = rawIndex;

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
      this.currentTargetCinematicZoom = cinematicZoom;

      const displayPoints = this.rainbowTraversedPoints.slice();
      displayPoints.push(interpPos);

      // 🌈 6 色无缝平行彩虹光带实时更新 (两两 6px 饱满重叠，绝对零间隙)
      if (this.rainbowPolylines.length > 0) {
        const currentCam = this.huaweiMapController?.getCameraPosition();
        const realZoom = (currentCam && currentCam.zoom) ? currentCam.zoom : (this.isCameraFollowLocked ? cinematicZoom : this.currentZoomLevel);
        const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom, this.selectedTrailEffect);
        for (let k = 0; k < this.rainbowPolylines.length; k++) {
          const poly = this.rainbowPolylines[k];
          if (poly && parallelStripes[k] && parallelStripes[k].length > 0) {
            try {
              poly.setPoints(parallelStripes[k]);
            } catch (e) { }
          }
        }
      }

      // 角度计算
      if (segIndex < 20) {
        this.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
      } else {
        const lookAheadPos = getSmoothPos(rawIndex + 1.2);
        const targetRotation = MapRenderHelper.calculateBearing(interpPos, lookAheadPos);
        
        let angleDiff = targetRotation - this.planeMarkerRotation;
        while (angleDiff < -180) angleDiff += 360;
        while (angleDiff > 180) angleDiff -= 360;
        
        this.planeMarkerRotation = this.planeMarkerRotation + angleDiff * 0.08; AppStorage.setOrCreate('hudPlaneRotation', this.planeMarkerRotation);
      }

      // 🧭 航向朝上 Heading-Up 跟随与平滑飞回机制 (60 FPS 逐帧动态追踪移动目标，零卡顿零瞬移)
      if (this.huaweiMapController && this.isCameraFollowLocked) {
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
          this.currentPlaneMarker.setPosition(interpPos);
          this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
          this.currentPlaneMarker.setAlpha(1.0);
        } catch (e) { }
      }

      this.currentPlaneGeoPos = interpPos;
      this.currentPlaneLat = interpPos.latitude;
      this.currentPlaneLng = interpPos.longitude;

      if (this.huaweiMapController) {
        try {
          const cam = this.huaweiMapController.getCameraPosition();
          if (cam && cam.target) {
            this.currentCameraLat = cam.target.latitude;
            this.currentCameraLng = cam.target.longitude;
            this.currentCameraZoom = cam.zoom ?? 17.2;
            this.currentCameraBearing = cam.bearing ?? this.currentMapBearing;
          }
        } catch (e) { }
      }

      // 🎯 60FPS 实时精准计算飞机 Marker 在屏幕上的物理坐标，确保粒子发射源 100% 跟随飞机
      this.updatePlaneScreenPosition(interpPos);
    });
    this.flightDisplaySync.start();
  }

  private currentPlaneGeoPos: mapCommon.LatLng = getCtuRunwayStart(); // 飞机在地图上的绝对真实地理经纬度坐标

  /**
   * 🎯 将飞机经纬度坐标转换为屏幕视口中的相对中心偏移 (vp)，实现粒子发射源 100% 精确跟随飞机 Marker
   */
  private updatePlaneScreenPosition(targetPos?: mapCommon.LatLng): void {
    if (!this.huaweiMapController) {
      return;
    }
    const pos = targetPos || this.currentPlaneGeoPos;
    if (!pos) {
      return;
    }

    try {
      // 🎯 相机跟随模式：飞机始终在屏幕正中，offset 强制为 (0,0)，跳过 toScreenLocation
      // 原因：moveCamera 是异步的，调用后立刻 toScreenLocation 会拿到旧相机状态，
      // 返回偏离屏幕中心几像素的抖动值，在起飞期 zoom 快速变化时尤为显著 → 尾迹"一抽一抽"
      if (this.isCameraFollowLocked) {
        this.planeScreenOffsetX = 0;
        this.planeScreenOffsetY = 0;
        const cam = this.huaweiMapController.getCameraPosition();
        const bearing = (cam && typeof cam.bearing === 'number') ? cam.bearing : this.currentMapBearing;
        this.planeScreenDynamicRotation = (this.planeMarkerRotation + bearing) % 360;
        return;
      }

      // 自由拖拽模式：使用 Projection API 计算飞机偏离屏幕中心的精确坐标
      const projection = this.huaweiMapController.getProjection();
      if (projection && typeof projection.toScreenLocation === 'function') {
        const pt = projection.toScreenLocation(pos);
        if (pt && typeof pt.positionX === 'number' && typeof pt.positionY === 'number') {
          const planeVpX = px2vp(pt.positionX);
          const planeVpY = px2vp(pt.positionY);
          const screenCenterX = (this.screenVpWidth > 0 ? this.screenVpWidth : 360) / 2;
          const screenCenterY = (this.screenVpHeight > 0 ? this.screenVpHeight : 780) / 2;

          this.planeScreenOffsetX = planeVpX - screenCenterX;
          this.planeScreenOffsetY = planeVpY - screenCenterY;

          const cam = this.huaweiMapController.getCameraPosition();
          const bearing = (cam && typeof cam.bearing === 'number') ? cam.bearing : this.currentMapBearing;
          this.planeScreenDynamicRotation = (this.planeMarkerRotation + bearing) % 360;
          return;
        }
      }

      // Fallback
      const cam = this.huaweiMapController.getCameraPosition();
      if (cam && cam.target) {
        const bearing = (typeof cam.bearing === 'number' && !isNaN(cam.bearing)) ? cam.bearing : this.currentMapBearing;
        this.planeScreenDynamicRotation = (this.planeMarkerRotation + bearing) % 360;
      }
    } catch (e) { }

    this.planeScreenOffsetX = 0;
    this.planeScreenOffsetY = 0;
  }

  /**
   * 🌈 确保当前所选尾迹（彩虹/星光/泡泡/极光/尾迹云）的 6 色平行原生地图 Polyline 实例在地图上成功挂载并就绪 (100% 原生地理坐标吸附，永无任何延迟与视差)
   */
  /**
   * 🌈 确保仅在选择“缤纷彩虹光带 (rainbow)”时挂载 6 色平行彩虹光带；
   *    当选择其他粒子特效（星光、泡泡、云雾、极光）时，彻底隐藏并清除彩虹实线，留出纯净画布给灵动粒子。
   */
  private async initRainbowPolylinesIfNeeded(forceRecreate: boolean = false): Promise<void> {
    if (!this.huaweiMapController) {
      return;
    }

    // 🌟 核心：非彩虹特效时，清理并隐藏所有底层 Polyline 实线
    if (this.selectedTrailEffect !== 'rainbow') {
      if (this.rainbowPolylines.length > 0) {
        for (const p of this.rainbowPolylines) {
          try { p.remove(); } catch (e) { }
        }
        this.rainbowPolylines = [];
      }
      return;
    }

    const config = MapRenderHelper.getTrailConfig('rainbow');
    const polyWidths: number[] = config.widths;
    const polyColors: number[] = config.colors;

    if (this.rainbowPolylines.length === polyColors.length && !forceRecreate) {
      return;
    }

    if (this.rainbowPolylines.length > 0) {
      for (const p of this.rainbowPolylines) {
        try { p.remove(); } catch (e) { }
      }
      this.rainbowPolylines = [];
    }

    const p0 = (this.rainbowTraversedPoints.length > 0) ? this.rainbowTraversedPoints[0] : getCtuRunwayStart();
    const polyPromises: Promise<map.MapPolyline>[] = [];
    for (let k = 0; k < polyColors.length; k++) {
      const color = polyColors[k];
      polyPromises.push(this.huaweiMapController.addPolyline({
        points: [p0, p0],
        width: polyWidths[k],
        color: color,
        zIndex: 1000 + k
      }));
    }
    try {
      const createdPolys = await Promise.all(polyPromises);
      this.rainbowPolylines = createdPolys;
      this.refreshRainbowPolylines();
    } catch (e) { }
  }

  /**
   * ✨ 实时切换巡航尾迹特效（毫秒级热更新光带与机尾粒子）
   */
  private onTrailEffectChanged(newTrailId: string): void {
    this.triggerHapticFeedback();
    this.selectedTrailEffect = newTrailId;
    AppStorage.setOrCreate('selectedTrailEffect', newTrailId);
    if (this.huaweiMapController) {
      this.initRainbowPolylinesIfNeeded(true);
    }
  }

  /**
   * 🌈 用户在任何缩放倍率下，即时刷新彩虹各色带地理坐标
   */
  private refreshRainbowPolylines(): void {
    if (this.selectedTrailEffect !== 'rainbow') {
      if (this.rainbowPolylines.length > 0) {
        for (const p of this.rainbowPolylines) {
          try { p.remove(); } catch (e) { }
        }
        this.rainbowPolylines = [];
      }
      return;
    }

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
    const parallelStripes = MapRenderHelper.generateParallelRainbowStripes(displayPoints, realZoom, 'rainbow');
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
    if (!this.isFuelTruckParked || this.isFuelTruckDeparting) return;
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
    if (!this.isFuelTruckParked) {
      if (this.isFuelTruckDeparting) {
        this.triggerHapticFeedback();
        this.fuelTruckMessageText = '加油车驾驶员：已完成任务驶离中';
        this.isFuelTruckMessageVisible = true;
        setTimeout(() => {
          this.isFuelTruckMessageVisible = false;
        }, 3000);
      } else {
        this.triggerHapticFeedback();
        this.fuelTruckMessageText = '加油车正在驶入停靠机位中...';
        this.isFuelTruckMessageVisible = true;
        setTimeout(() => {
          this.isFuelTruckMessageVisible = false;
        }, 2500);
      }
      return;
    }
    this.runFuelTruckDepartureAnimation();
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
              // 🛡️ 位移阈值判断真实拖拽：记录按下坐标，仅当位移 > 8vp 才认定为地图拖拽并取消跟随
              // 纯点击（含 HUD 按钮穿透的 Down）与轻微抖动不超阈值，绝不误取消镜头跟随
              if (event.type === TouchType.Down) {
                this.mapTouchStartX = event.touches[0].x;
                this.mapTouchStartY = event.touches[0].y;
              } else if (event.type === TouchType.Move && (this.isCameraFollowLocked || this.isCameraFlyingBack)) {
                const dx = event.touches[0].x - this.mapTouchStartX;
                const dy = event.touches[0].y - this.mapTouchStartY;
                if (Math.sqrt(dx * dx + dy * dy) > 8) {
                  this.isCameraFollowLocked = false;
                  this.isCameraFlyingBack = false;
                  if (this.groundFlybackTimerSync) {
                    this.groundFlybackTimerSync.stop();
                    this.groundFlybackTimerSync = undefined;
                  }
                }
              }

              if (event.type === TouchType.Move || event.type === TouchType.Up) {
                if (!this.isCameraFollowLocked) {
                  this.updatePlaneScreenPosition();
                }
              }

              // 🎯 用户松手后启动 2 秒无操作自动平滑飞回飞机
              if (event.type === TouchType.Up && !this.isCameraFollowLocked && this.isFlightInProgress) {
                if (this.groundFlybackTimerSync) {
                  this.groundFlybackTimerSync.stop();
                }
                this.groundFlybackTimerSync = displaySync.create();
                let waitFrames = 0;
                this.groundFlybackTimerSync.on('frame', () => {
                  waitFrames++;
                  if (waitFrames >= 120) { // 约 2 秒
                    if (this.groundFlybackTimerSync) {
                      this.groundFlybackTimerSync.stop();
                      this.groundFlybackTimerSync = undefined;
                    }
                    this.startCameraFlyback();
                  }
                });
                this.groundFlybackTimerSync.start();
              }
            })

          // 🎨 60FPS 极简唯美尾迹粒子与流光浮层 (梦幻泡泡/星光粉尘/凝结尾迹云/极光/彩虹)
          if (this.isFlightInProgress) {
            FlightTrailParticleOverlay({
              isFlightActive: this.isFlightInProgress && !this.isFlightPaused,
              trailId: this.selectedTrailEffect,
              planeScreenOffsetX: this.planeScreenOffsetX,
              planeScreenOffsetY: this.planeScreenOffsetY,
              planeScreenRotation: this.planeScreenDynamicRotation,
              currentMapBearing: this.currentMapBearing,
              currentZoomLevel: this.currentZoomLevel,
              currentFlightRawIndex: this.currentFlightRawIndex,
              flightPoints: this.currentFlightPoints
            })
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.None)
              .zIndex(150)
          }
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.screenVpWidth = newArea.width as number;
        this.screenVpHeight = newArea.height as number;
      })


      HeaderGreetingBar({
        isHudVisible: this.isHudVisible,
        isFullFocusMode: this.isFullFocusMode,
        isMapBackgroundVisible: this.isMapBackgroundVisible
      })

      // 2.1 顶部沉浸式通知胶囊 (图2指定红框区域)
      if (this.isTopToastVisible) {
        Row({ space: 6 }) {
          Text(this.topToastMessage)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E293B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor('rgba(255, 255, 255, 0.95)')
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(226, 232, 240, 0.8)' })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.08)', offsetY: 3 })
        .position({ x: '50%', y: 56 })
        .markAnchor({ x: '50%', y: 0 })
        .zIndex(999)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: -16 }))
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        )
      }

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
        selectedDurationMinutes: this.selectedFocusDurationMinutes,
        onSeatClick: (seatId: string): void => {
          this.onSeatSelectedInIndex(seatId, 'study', this.selectedFocusDurationMinutes);
        },
        onConfirmFlight: (seatId: string, tagId: string, durationMinutes: number): void => {
          this.onSeatSelectedInIndex(seatId, tagId, durationMinutes);
        }
      })
        .hitTestBehavior(HitTestMode.Transparent)

      // 5. 底部专注控制面板
      HomeFocusPanel({
        isFlightInProgress: this.isFlightInProgress,
        onShowTopToast: (msg: string) => {
          this.showTopToast(msg);
        },
        onStartFlight: (minutes?: number, dest?: Airport) => {
          if (minutes && minutes > 0) {
            this.selectedFocusDurationMinutes = minutes;
          }
          if (dest) {
            this.currentDestinationAirport = dest;
          }
          this.enterCabinSelectionFromHangar();
        }
      })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .opacity((this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 1 : 0)
        .translate({ y: (this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 0 : 260 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .zIndex(100)

      // 6. 飞行地图 HUD 悬浮控制层 (仅在机舱展开或地图飞行模式下挂载渲染，绝不干扰停机坪首页交互)
      if (this.isCabinExposed || (this.isMapBackgroundVisible && !this.isCabinExposed)) {
        FlightMapHudOverlay({
          isMapBackgroundVisible: this.isMapBackgroundVisible,
          isCabinExposed: this.isCabinExposed,
          isCameraFollowLocked: this.isCameraFollowLocked,
          currentMapType: this.currentMapType,
          currentFocusTagTitle: this.currentFocusTagTitle,
          remainingTimeString: this.remainingTimeString,
          onOpenSettings: () => {
            this.triggerHapticFeedback();
            this.isTrailSettingsVisible = true;
          },
          onToggleMapType: () => this.toggleMapTypeMode(),
          onToggleCameraFollow: () => this.toggleCameraFollowMode(),
          onExitFlight: () => {
            this.triggerHapticFeedback();
            if (this.isFlightInProgress) {
              this.isAbortDialogVisible = true;
            } else if (this.isMapBackgroundVisible) {
              this.returnFromMapToHangar(false);
            } else {
              this.returnFromCabinToHangar();
            }
          }
        })
          .hitTestBehavior(HitTestMode.Transparent)
          .zIndex(250)
      }

      // 7. 专注飞行终止备降二次确认弹窗 (优雅航空沉浸式提示)
      FlightAbortConfirmDialog({
        isVisible: this.isAbortDialogVisible,
        onCancel: () => {
          this.triggerHapticFeedback();
          this.isAbortDialogVisible = false;
        },
        onConfirmAbort: () => {
          this.triggerHapticFeedback();
          this.abortFlightAndReturnToHangar();
        }
      })

      // 8. 巡航尾迹与个性化设置底部抽屉面板 (严格用 if 控制挂载，不可见时绝不阻挡底层任何点击！)
      if (this.isTrailSettingsVisible) {
        FlightTrailSettingsOverlay({
          isVisible: this.isTrailSettingsVisible,
          currentTrailId: $selectedTrailEffect,
          onSelectTrail: (trailId: string) => {
            this.onTrailEffectChanged(trailId);
          },
          onClose: () => {
            this.triggerHapticFeedback();
            this.isTrailSettingsVisible = false;
          }
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(300)
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // 🛡️ 只有在机舱展开选座模式下才响应全屏点击收起逻辑
      if (this.isCabinExposed && !this.isMapBackgroundVisible) {
        this.returnFromCabinToHangar();
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 🛡️ 拦截系统返回手势/按键，确保专注飞行体验
   */
  onBackPress(): boolean {
    if (this.isAbortDialogVisible) {
      this.isAbortDialogVisible = false;
      return true;
    }
    if (this.isFlightInProgress && this.isMapBackgroundVisible) {
      this.isAbortDialogVisible = true;
      return true;
    }
    if (this.isMapBackgroundVisible) {
      this.returnFromMapToHangar(false);
      return true;
    }
    if (this.isCabinExposed || this.isFullFocusMode) {
      this.returnFromCabinToHangar();
      return true;
    }
    return false;
  }

  private getCurrentCinematicZoom(): number {
    return this.currentTargetCinematicZoom > 0 ? this.currentTargetCinematicZoom : 13.0;
  }

  /**
   * ✈️ 电影级相机平滑飞回引擎 (逐帧 60FPS 阻尼插值，动态追踪目标，最短圆弧角度旋转，零卡顿零瞬移)
   */
  private startCameraFlyback(): void {
    if (!this.huaweiMapController) {
      return;
    }
    this.isCameraFollowLocked = true;
    this.isCameraFlyingBack = true;
    this.flybackStartTime = Date.now();

    try {
      const currentCam = this.huaweiMapController.getCameraPosition();
      if (currentCam && currentCam.target) {
        this.flybackStartLat = currentCam.target.latitude;
        this.flybackStartLon = currentCam.target.longitude;
        this.flybackStartZoom = currentCam.zoom ?? 17.2;
        this.flybackStartBearing = currentCam.bearing ?? CTU_RUNWAY_BEARING;
      } else {
        const rStart = getCtuRunwayStart();
        this.flybackStartLat = rStart.latitude;
        this.flybackStartLon = rStart.longitude;
        this.flybackStartZoom = 17.2;
        this.flybackStartBearing = CTU_RUNWAY_BEARING;
      }
    } catch (e) {
      const rStart = getCtuRunwayStart();
      this.flybackStartLat = rStart.latitude;
      this.flybackStartLon = rStart.longitude;
      this.flybackStartZoom = 17.2;
      this.flybackStartBearing = CTU_RUNWAY_BEARING;
    }

    // 地面精修机场状态：启动地面专用 60FPS 平滑帧插值
    if (!this.isFlightInProgress) {
      if (this.groundFlybackTimerSync) {
        this.groundFlybackTimerSync.stop();
        this.groundFlybackTimerSync = undefined;
      }

      this.groundFlybackTimerSync = displaySync.create();
      this.groundFlybackTimerSync.on('frame', () => {
        const now = Date.now();
        const elapsed = now - this.flybackStartTime;
        const rawProgress = Math.min(1.0, elapsed / this.FLYBACK_DURATION_MS);
        // 采用极致平滑的 Cubic EaseOut 阻尼缓动
        const ease = 1.0 - Math.pow(1.0 - rawProgress, 3);

        const targetPos = getCtuRunwayStart();
        const targetZoom = 17.2;
        const targetBearing = CTU_RUNWAY_BEARING;

        // 1. 经纬度位置平滑插值
        const curLat = this.flybackStartLat + (targetPos.latitude - this.flybackStartLat) * ease;
        const curLon = this.flybackStartLon + (targetPos.longitude - this.flybackStartLon) * ease;
        // 2. 视距平滑插值
        const curZoom = this.flybackStartZoom + (targetZoom - this.flybackStartZoom) * ease;

        // 3. 航向角度最短路径平滑插值 (Shortest Path Slerp)
        let angleDiff = targetBearing - this.flybackStartBearing;
        while (angleDiff < -180) angleDiff += 360;
        while (angleDiff > 180) angleDiff -= 360;
        const curBearing = (this.flybackStartBearing + angleDiff * ease + 360) % 360;

        const zoomFixed = parseFloat(curZoom.toFixed(1));
        if (this.currentZoomLevel !== zoomFixed) {
          this.currentZoomLevel = zoomFixed;
          AppStorage.setOrCreate('hudZoomLevel', this.currentZoomLevel);
        }
        const newCompassBearing = Math.round(curBearing);
        if (this.currentMapBearing !== newCompassBearing) {
          this.currentMapBearing = newCompassBearing;
          AppStorage.setOrCreate('hudMapBearing', this.currentMapBearing);
        }

        if (this.huaweiMapController) {
          try {
            this.huaweiMapController.moveCamera(map.newCameraPosition({
              target: { latitude: curLat, longitude: curLon },
              zoom: curZoom,
              bearing: curBearing,
              tilt: 0
            }));
          } catch (e) { }
        }

        if (rawProgress >= 1.0) {
          if (this.groundFlybackTimerSync) {
            this.groundFlybackTimerSync.stop();
            this.groundFlybackTimerSync = undefined;
          }
          this.isCameraFlyingBack = false;
          this.currentZoomLevel = 17.2;
          AppStorage.setOrCreate('hudZoomLevel', 17.2);
          this.currentMapBearing = CTU_RUNWAY_BEARING;
          AppStorage.setOrCreate('hudMapBearing', CTU_RUNWAY_BEARING);
        }
      });
      this.groundFlybackTimerSync.start();
    }
  }

  /**
   * 🧭 切换视角跟随锁定状态 (从自由拖拽与自定义缩放视角丝滑飞回并平滑缩放至巡航/跑道视角，彻底消除卡顿)
   */
  private toggleCameraFollowMode(): void {
    this.triggerHapticFeedback();
    if (!this.isCameraFollowLocked) {
      this.startCameraFlyback();
    } else {
      this.isCameraFollowLocked = false;
      this.isCameraFlyingBack = false;
      if (this.groundFlybackTimerSync) {
        this.groundFlybackTimerSync.stop();
        this.groundFlybackTimerSync = undefined;
      }
    }
  }

  /**
   * 1. 停机坪 -> 放大机身并剖开机壳，进入机舱选座
   */
  private enterCabinSelectionFromHangar() {
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
      if (this.isFullFocusMode && !this.isMapBackgroundVisible) {
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
  }

  /**
   * 2. 机舱选座界面 -> 合拢机壳并缩小飞机，返回停机坪
   */
  private returnFromCabinToHangar() {
    this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.shellSplitOffset = 0;
    });

    setTimeout(() => {
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.planeOpacity = 1.0;

      this.getUIContext()?.animateTo({ duration: 1500, curve: Curve.EaseInOut }, () => {
        this.planeScale = 1.0;
        this.planeY = -45;
      });

      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
      });
    }, 300);
  }

  /**
   * 3. 精修地图飞行/完成界面 -> 直接干净返回停机坪
   */
  private returnFromMapToHangar(isAborted: boolean = false) {
    // 1. 清理本地持久化飞行会话与定时器
    FlightSessionStore.clearSession();
    if (this.flightDisplaySync) {
      this.flightDisplaySync.stop();
      this.flightDisplaySync = undefined;
    }
    if (this.groundFlybackTimerSync) {
      this.groundFlybackTimerSync.stop();
      this.groundFlybackTimerSync = undefined;
    }

    // 2. 重置飞行状态标记与目的地
    this.isFlightInProgress = false;
    this.isFlightPaused = false;
    this.isPlaneMarkerActive = false;
    AppStorage.setOrCreate('selectedDestinationAirport', undefined);
    AppStorage.setOrCreate('selectedDestinationCode', '');
    this.currentDestinationAirport = undefined;

    // 3. 清理彩虹轨迹航线
    if (this.rainbowPolylines.length > 0) {
      for (const p of this.rainbowPolylines) {
        try { p.remove(); } catch (e) { }
      }
      this.rainbowPolylines = [];
    }
    this.rainbowTraversedPoints = [];
    this.lastTraversedPointIndex = 0;

    // 4. 平滑关闭地图，确保机壳合拢并隐藏机舱
    this.getUIContext()?.animateTo({ duration: 350, curve: Curve.EaseIn }, () => {
      this.shellSplitOffset = 0;
      this.isMapBackgroundVisible = false;
    });

    // 5. 重置飞机机位、尺寸与服务保障车辆
    setTimeout(() => {
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.planeOpacity = 1.0;

      this.getUIContext()?.animateTo({ duration: 1200, curve: Curve.EaseInOut }, () => {
        this.planeScale = 1.0;
        this.planeY = -45;
      });

      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
      });
    }, 250);

    // 6. 顶部通知胶囊
    if (isAborted) {
      this.showTopToast('✈️ 航班已就近紧急备降，已安全返回停机坪', 3500);
    } else {
      this.showTopToast('✈️ 航班已安全抵达，已返回停机坪', 3000);
    }
  }

  /**
   * 4. 终止飞行并安全备降返回停机坪
   */
  private abortFlightAndReturnToHangar() {
    this.isAbortDialogVisible = false;
    this.returnFromMapToHangar(true);
  }
}