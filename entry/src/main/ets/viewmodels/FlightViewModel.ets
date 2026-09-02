import { map, mapCommon } from '@kit.MapKit';
import { Airport } from '../models/AirportModel';

@Observed
export class FlightViewModel {
  planeY: number = -45;                   // 飞机及阴影纵向位置（固定原位）;
  planeX: number = 0;                     // 飞机及阴影横向对齐偏移（地图模式对齐跑道红点）;
  planeScale: number = 1.0;               // 飞机与阴影原位 3D 缩放比例;
  planeOpacity: number = 1.0;             // 缩小后重合时透明度渐变为 0;
  planeRotate: number = 0;                // 飞机偏航旋转角度;
  isPlaneMarkerActive: boolean = false;   // 动画完成后是否交接给地图原生 Marker;
  currentZoomScale: number = 1.0;         // 随地图 Zoom 级别动态计算的物理比例 (2^(zoom - 17.2));
  isFullFocusMode: boolean = false;       // 11.8倍极简沉浸专注模式（隐藏所有UI）;
  isCabinExposed: boolean = false;        // 飞机放大后机身外壳剖开状态;
  shellSplitOffset: number = 0;           // 机壳剖开向两侧滑移偏移量;
  isMapBackgroundVisible: boolean = false; // 只有当飞机放大完毕后，底部才无缝切为花瓣地图精修机场;
  isVehiclesDocked: boolean = false;      // 勤务车辆与廊桥对接状态;
  fuelTruckX: number = -350;              // 加油车 X 坐标;
  fuelTruckY: number = 220;               // 加油车 Y 坐标;
  fuelTruckRotate: number = 90;           // 加油车车头角度;
  isHudVisible: boolean = true;           // Cyber HUD 界面可见状态 (默认开启展示图2主页);
  isFuelTruckParked: boolean = false;     // 加油车已完成驶入并停稳标志;
  isFuelTruckDeparting: boolean = false;  // 加油车正在驶离标志;
  isFuelTruckMessageVisible: boolean = false; // 加油车左侧标牌提示显隐;
  fuelTruckMessageText: string = '';          // 加油车左侧标牌提示文本;
  honkToastText: string = '';             // 提示文本;
  isHonkToastVisible: boolean = false;    // 提示框显隐;
  flightCurrentIndex: number = 0;
  isFlightInProgress: boolean = false;
  currentTargetCinematicZoom: number = 13.0; // 当前飞行巡航阶段的目标视距Zoom;
  selectedFocusDurationMinutes: number = 15; // 用户选定的专注飞行时长 (默认15分钟);
  remainingTimeString: string = '15:00';     // 专注倒计时剩余时间文本;
  remainingDistanceKm: number = 0;           // 剩余飞行里程 (公里);
  currentFocusTagId: string = 'study';       // 当前专注标签ID;
  currentFocusTagTitle: string = '深度学习';  // 当前专注类型/任务名称;
  currentFocusTagIcon: string = '📚';        // 当前专注图标;
  currentFocusTagColor: string = '#F06553';   // 当前专注主题色;
  isAbortDialogVisible: boolean = false; // 飞行终止备降二次确认弹窗显隐;
  isTrailSettingsVisible: boolean = false; // 视觉个性化设置抽屉显隐;
  isCameraFollowLocked: boolean = true; // 飞行跟随锁定状态 (true: 自动跟拍居中, false: 用户自由拖拽地图);
  currentPlaneLat: number = 30.5828; // 飞机当前真实地理纬度;
  currentPlaneLng: number = 103.9467; // 飞机当前真实地理经度;
  currentCameraLat: number = 30.5828; // 当前相机视口中心纬度;
  currentCameraLng: number = 103.9467; // 当前相机视口中心经度;
  currentCameraZoom: number = 17.2; // 当前相机视口缩放倍率;
  currentCameraBearing: number = 157.5; // 当前相机方位角;
  planeScreenOffsetX: number = 0; // 飞机当前屏幕中心 X 偏移 (vp);
  planeScreenOffsetY: number = 0; // 飞机当前屏幕中心 Y 偏移 (vp);
  planeScreenDynamicRotation: number = 0; // 飞机在屏幕上的实际渲染朝向角;
  currentFlightRawIndex: number = 0; // 飞机当前在航线中的平滑浮点索引 (用于尾迹弯曲跟随);
  currentFlightPoints: Array<mapCommon.LatLng> = []; // 全量平滑航线点集合 (供粒子系统进行曲率插值);
  currentMapType: mapCommon.MapType = mapCommon.MapType.SATELLITE; // 默认使用卫星遥感地图;
  isFlightPaused: boolean = false;        // 飞行暂停标志位;
  isTurbulenceAlertVisible: boolean = false; // 气流扰动左下角提示显隐;
  isWindowViewMode: boolean = false;         // 🪟 机舱舷窗沉浸专注视角;
  isArrivalBoardingPassVisible: boolean = false; // 🎫 专属落地通关登机牌;
  turbulenceMessageText: string = '遭遇巡航微气流，航向平稳修正中';
  isDistractionReportVisible: boolean = false; // 新增分心报告页状态;
  isLiveLogVisible: boolean = false; // 实时飞行日志抽屉状态;
  isPreFlightBoardingPassVisible: boolean = false; // ✈️ 拟物电影级起飞登机牌掉落过场状态;
  isPreFlightPosterPreviewOnly: boolean = false; // 🧪 是否仅为测试预览模式 (不触发起飞);
  isRoamingMode: boolean = false; // ☁️ 记录是否为正向计时的漫游探索模式
  currentWeatherType: 'clear' | 'thunderstorm' | 'snow' = 'clear'; // 当前俯视与机舱沉浸天气状态
  isTopToastVisible: boolean = false;
  topToastMessage: string = '';
  backgroundStartTime: number = 0;
  lastTurbulenceLogTime: number = 0;
}
