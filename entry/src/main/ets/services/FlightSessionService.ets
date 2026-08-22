import { getCtuRunwayStart, getCtuRunwayEnd, CTU_RUNWAY_BEARING, CLEAN_DARK_AVIATION_STYLE_JSON } from '../utils/FlightConstants';
import { display } from '@kit.ArkUI';
import { displaySync } from '@kit.ArkGraphics2D';
import { IndexController } from '../controllers/IndexController';
import { common } from '@kit.AbilityKit';
import { UIContext, window, promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { SoundEffectHelper } from '../utils/SoundEffectHelper';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';
import { LatLngPoint, interpolateLatLng } from '../utils/GeodesicUtils';
import { findAirportByCode } from '../models/AirportModel';
import { FlightRecordRepository } from '../database/FlightRecordRepository';

export class FlightSessionService {
  private ctrl: IndexController;
  constructor(ctrl: IndexController) {
    this.ctrl = ctrl;
  }

  public onSeatSelectedInIndex(seatId: string, tagId: string = 'study', durationMinutes?: number) {
    if (durationMinutes && durationMinutes > 0) {
      this.ctrl.vm.selectedFocusDurationMinutes = durationMinutes;
    }
    const tagMap: Record<string, string> = {
      'study': '深度学习',
      'work': '高效工作',
      'create': '创意灵感',
      'relax': '正念冥想',
      'sprint': '极速冲刺'
    };
    const tagName = tagMap[tagId] || '深度专注';
    this.ctrl.vm.currentFocusTagTitle = tagName;
    const destApt = this.ctrl.currentDestinationAirport || findAirportByCode('PEK');
    const destCode = destApt ? destApt.code : 'PEK';

    // 存储当前飞行专注会话状态
    FlightSessionStore.saveSession({
      isFlightActive: true,
      flightNo: 'FF-2026',
      seatId: seatId,
      taskTitle: tagName,
      durationMin: this.ctrl.vm.selectedFocusDurationMinutes,
      originCode: 'CTU',
      destCode: destCode,
      startTimeMs: Date.now(),
      events: [{
        id: 'start_' + Date.now(),
        type: 'gate_departure',
        timestampMs: Date.now(),
        note: '设备锁定，航线开始'
      }]
    });

    this.ctrl.vm.honkToastText = `✨ 座位 ${seatId} · ${tagName} (${this.ctrl.vm.selectedFocusDurationMinutes}m) 桌板已放下，准备起飞`;
    this.ctrl.vm.isHonkToastVisible = true;
    setTimeout(() => {
      this.ctrl.vm.isHonkToastVisible = false;
    }, 3000);

    // 1. 400ms 平滑缝合剖开的机身外壳
    this.ctrl.context?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.ctrl.vm.shellSplitOffset = 0;
    });

    // 2. 0.35 秒后隐藏机舱透视，飞机平滑 3D 缩小至与精修地图飞机完全 1:1 的尺寸，背后的华为 Petal Maps 地图无缝淡入浮现！
    setTimeout(async () => {
      this.ctrl.vm.isCabinExposed = false;
      this.ctrl.vm.isFullFocusMode = false;
      this.ctrl.vm.isMapBackgroundVisible = true; // 背后华为花瓣地图无缝出现！

      if (this.ctrl.huaweiMapController) {
        try {
          this.ctrl.huaweiMapController.animateCamera(map.newCameraPosition({
            target: getCtuRunwayStart(),
            zoom: 17.2,
            bearing: CTU_RUNWAY_BEARING,
            tilt: 0
          }), 1000);

          this.ctrl.planeMarkerRotation = 202.5; AppStorage.setOrCreate('hudPlaneRotation', this.ctrl.planeMarkerRotation);
          if (this.ctrl.currentPlaneMarker) {
            try {
              this.ctrl.currentPlaneMarker.setPosition(getCtuRunwayStart());
              this.ctrl.currentPlaneMarker.setRotation(202.5);
              this.ctrl.currentPlaneMarker.setAlpha(1.0);
            } catch (e) { }
          } else {
            const planePixelMap = await this.ctrl.getScaledPlaneMarkerIcon(175, this.ctrl.vm.currentMapType === mapCommon.MapType.TERRAIN);
            this.ctrl.currentPlaneMarker = await this.ctrl.huaweiMapController.addMarker({
              position: getCtuRunwayStart(),
              icon: this.ctrl.getPlaneMarkerIconResource(),
              anchorU: 0.5,
              anchorV: 0.5,
              flat: true,
              rotation: 202.5,
              zIndex: 2000,
              clickable: false
            });
            this.ctrl.currentPlaneMarker.setAlpha(1.0);
          }
        } catch (e) { }
      }

      // 飞机在 2 秒内持续平滑 3D 缩小至 1:1，并在这完整的 2 秒内同步平滑将透明度降到 0（绝不在最后停顿才开始变透明！）
      const targetScale = this.ctrl.getTargetMarkerPlaneScale();
      this.ctrl.vm.planeOpacity = 1.0;
      this.ctrl.context?.animateTo({ duration: 2000, curve: Curve.FastOutSlowIn }, () => {
        this.ctrl.vm.planeScale = targetScale;
        this.ctrl.vm.planeY = 0;
        this.ctrl.vm.planeX = 0;
      });
      this.ctrl.context?.animateTo({ duration: 2000, curve: Curve.EaseInOut }, () => {
        this.ctrl.vm.planeOpacity = 0;
      });

      // 恢复周围地勤设备与 HUD 界面
      this.ctrl.context?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.ctrl.vm.isVehiclesDocked = true;
        this.ctrl.vm.isHudVisible = true;
      });

      // 3. 2 秒过渡期满（UI 飞机已完全无缝淡出至 0），由底层地图 Marker 立即接管并直接动力全推起飞！
      setTimeout(() => {
        this.ctrl.vm.isPlaneMarkerActive = true;
        this.ctrl.startFlightAnimationDirectly();
      }, 2000);
    }, 350);
  }

  public enterCabinSelectionFromHangar() {
    this.ctrl.vm.isMapBackgroundVisible = false;
    this.ctrl.vm.planeOpacity = 1.0;

    // 阶段一：2.5 秒内飞机原位平滑放大到 11.8 倍
    this.ctrl.context?.animateTo({ duration: 2500, curve: Curve.EaseInOut }, () => {
      this.ctrl.vm.isFullFocusMode = true;
      this.ctrl.vm.planeScale = 11.8;
      this.ctrl.vm.planeY = 1200;
    });

    // 阶段二：放大完毕后，露出机舱选座
    setTimeout(() => {
      if (this.ctrl.vm.isFullFocusMode && !this.ctrl.vm.isMapBackgroundVisible) {
        this.ctrl.context?.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
          this.ctrl.vm.isCabinExposed = true;
        });
        this.ctrl.context?.animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
          this.ctrl.vm.shellSplitOffset = 160;
        });
      }
    }, 1200);

    this.ctrl.context?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
      this.ctrl.vm.isVehiclesDocked = false;
    });
  }

  public returnFromMapToHangar(isAborted: boolean = false) {
    // 0. 保存当前已执飞的航班数据至本地关系型数据库 (RDB)
    const activeSession = AppStorage.get<FlightSessionData>('activeFlightSession');
    if (activeSession) {
      FlightRecordRepository.saveCompletedFlight(activeSession, isAborted);
    }

    // 1. 清理本地持久化飞行会话与定时器
    FlightSessionStore.clearSession();
    if (this.ctrl.flightDisplaySync) {
      this.ctrl.flightDisplaySync.stop();
      this.ctrl.flightDisplaySync = undefined;
    }
    if (this.ctrl.groundFlybackTimerSync) {
      this.ctrl.groundFlybackTimerSync?.stop();
      this.ctrl.groundFlybackTimerSync = undefined;
    }

    // 2. 重置飞行状态标记与目的地
    this.ctrl.vm.isFlightInProgress = false;
    this.ctrl.vm.isFlightPaused = false;
    this.ctrl.vm.isWindowViewMode = false;
    this.ctrl.vm.isArrivalBoardingPassVisible = false;
    this.ctrl.vm.isPlaneMarkerActive = false;
    AppStorage.setOrCreate('selectedDestinationAirport', undefined);
    AppStorage.setOrCreate('selectedDestinationCode', '');
    this.ctrl.currentDestinationAirport = undefined;

    // 3. 清理彩虹轨迹航线
    if (this.ctrl.rainbowPolylines.length > 0) {
      for (const p of this.ctrl.rainbowPolylines) {
        try { p.remove(); } catch (e) { }
      }
      this.ctrl.rainbowPolylines = [];
    }
    this.ctrl.rainbowTraversedPoints = [];
    this.ctrl.lastTraversedPointIndex = 0;

    // 4. 平滑关闭地图，确保机壳合拢并隐藏机舱
    this.ctrl.context?.animateTo({ duration: 350, curve: Curve.EaseIn }, () => {
      this.ctrl.vm.shellSplitOffset = 0;
      this.ctrl.vm.isMapBackgroundVisible = false;
    });

    // 5. 重置飞机机位、尺寸与服务保障车辆
    setTimeout(() => {
      this.ctrl.vm.isCabinExposed = false;
      this.ctrl.vm.isFullFocusMode = false;
      this.ctrl.vm.planeOpacity = 1.0;

      this.ctrl.context?.animateTo({ duration: 1200, curve: Curve.EaseInOut }, () => {
        this.ctrl.vm.planeScale = 1.0;
        this.ctrl.vm.planeY = -45;
      });

      this.ctrl.context?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.ctrl.vm.isVehiclesDocked = true;
      });

      // 航班返航结束，再次呼叫加油车驶入保障机位
      this.ctrl.vm.isFuelTruckDeparting = false;
      this.ctrl.vm.isFuelTruckParked = false;
      this.ctrl.runRealTruckPhysicsAnimation();

    }, 250);

    // 6. 顶部通知胶囊
    if (isAborted) {
      this.ctrl.showTopToast('✈️ 航班已就近紧急备降，已安全返回停机坪', 3500);
    } else {
      this.ctrl.showTopToast('✈️ 航班已安全抵达，已返回停机坪', 3000);
    }
  }

  public returnFromCabinToHangar() {
    this.ctrl.context?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.ctrl.vm.shellSplitOffset = 0;
    });

    setTimeout(() => {
      this.ctrl.vm.isCabinExposed = false;
      this.ctrl.vm.isFullFocusMode = false;
      this.ctrl.vm.planeOpacity = 1.0;

      this.ctrl.context?.animateTo({ duration: 1500, curve: Curve.EaseInOut }, () => {
        this.ctrl.vm.planeScale = 1.0;
        this.ctrl.vm.planeY = -45;
      });

      this.ctrl.context?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.ctrl.vm.isVehiclesDocked = true;
      });
    }, 300);
  }

  public abortFlightAndReturnToHangar() {
    this.ctrl.vm.isAbortDialogVisible = false;
    this.ctrl.returnFromMapToHangar(true);
  }

  public recordFlightEvent(type: 'gate_departure' | 'takeoff' | 'cruise' | 'deviation' | 'recovery' | 'turbulence' | 'descent_prep' | 'landing', note: string): void {
    const session = AppStorage.get<FlightSessionData>('activeFlightSession');
    if (session) {
      if (!session.events) {
        session.events = [];
      }
      session.events.unshift({
        id: Date.now().toString(),
        type: type,
        timestampMs: Date.now(),
        note: note
      });
      FlightSessionStore.saveSession(session);
      AppStorage.setOrCreate('lastFlightEventUpdate', Date.now()); // 触发UI实时更新
    }
  }


  public showTopToast(message: string, duration: number = 3500): void {
    if (this.ctrl.topToastTimer !== -1) {
      clearTimeout(this.ctrl.topToastTimer);
      this.ctrl.topToastTimer = -1;
    }
    this.ctrl.vm.topToastMessage = message;
    this.ctrl.context?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.ctrl.vm.isTopToastVisible = true;
    });
    this.ctrl.topToastTimer = setTimeout(() => {
      this.ctrl.context?.animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
        this.ctrl.vm.isTopToastVisible = false;
      });
      this.ctrl.topToastTimer = -1;
    }, duration);
  }


  public triggerHapticFeedback(): void {
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
}
