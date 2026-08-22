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

export class MapCameraEngine {
  private ctrl: IndexController;
  constructor(ctrl: IndexController) {
    this.ctrl = ctrl;
  }

  public toggleMapTypeMode(): void {
    this.ctrl.triggerHapticFeedback();
    if (this.ctrl.vm.currentMapType === mapCommon.MapType.SATELLITE) {
      this.ctrl.vm.currentMapType = mapCommon.MapType.TERRAIN;
      if (this.ctrl.huaweiMapController) {
        try {
          this.ctrl.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.DAY);
          this.ctrl.huaweiMapController.setCustomMapStyle({ styleContent: '' });
          this.ctrl.huaweiMapController.setMapType(this.ctrl.vm.currentMapType);
        } catch (e) { }
      }
    } else if (this.ctrl.vm.currentMapType === mapCommon.MapType.TERRAIN) {
      // 🌃 切换至暗夜深色夜间航图模式 (加载纯净无注记自定义航图样式)
      this.ctrl.vm.currentMapType = mapCommon.MapType.STANDARD;
      if (this.ctrl.huaweiMapController) {
        try {
          this.ctrl.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.NIGHT);
          this.ctrl.huaweiMapController.setCustomMapStyle({ styleContent: CLEAN_DARK_AVIATION_STYLE_JSON });
          this.ctrl.huaweiMapController.setMapType(this.ctrl.vm.currentMapType);
        } catch (e) { }
      }
    } else {
      // 🛰️ 切换回卫星遥感实景模式
      this.ctrl.vm.currentMapType = mapCommon.MapType.SATELLITE;
      if (this.ctrl.huaweiMapController) {
        try {
          this.ctrl.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.DAY);
          this.ctrl.huaweiMapController.setCustomMapStyle({ styleContent: '' });
          this.ctrl.huaweiMapController.setMapType(this.ctrl.vm.currentMapType);
        } catch (e) { }
      }
    }
    // ✈️ 切换地图模式后刷新飞机 Marker 图标（地形图加深色描边，其他模式无描边）
    const targetIcon = this.ctrl.getPlaneMarkerIconResource();
    const pos = this.ctrl.lastFlightInterpPos || getCtuRunwayStart();
    const rot = this.ctrl.planeMarkerRotation;
    if (this.ctrl.currentPlaneMarker) {
      try { this.ctrl.currentPlaneMarker.remove(); } catch (e) { }
      this.ctrl.currentPlaneMarker = undefined;
    }
    if (this.ctrl.huaweiMapController) {
      this.ctrl.huaweiMapController.addMarker({
        position: pos,
        icon: targetIcon,
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: rot,
        zIndex: 2000,
        clickable: false
      }).then((marker) => {
        this.ctrl.currentPlaneMarker = marker;
        this.ctrl.currentPlaneMarker.setAlpha(1.0);
      }).catch((e: Error) => { });
    }
  }

  public toggleCameraFollowMode(): void {
    this.ctrl.triggerHapticFeedback();
    if (!this.ctrl.vm.isCameraFollowLocked) {
      this.ctrl.startCameraFlyback();
    } else {
      this.ctrl.vm.isCameraFollowLocked = false;
      this.ctrl.isCameraFlyingBack = false;
      if (this.ctrl.groundFlybackTimerSync) {
        this.ctrl.groundFlybackTimerSync?.stop();
        this.ctrl.groundFlybackTimerSync = undefined;
      }
    }
  }

  public onRouteStyleChanged(newRouteId: string): void {
    this.ctrl.triggerHapticFeedback();
    this.ctrl.selectedRouteStyle = newRouteId;
    AppStorage.setOrCreate('selectedRouteStyle', newRouteId);
    if (newRouteId !== 'classic') {
      this.ctrl.selectedTrailEffect = 'none';
      AppStorage.setOrCreate('selectedTrailEffect', 'none');
    }
    if (this.ctrl.huaweiMapController) {
      this.ctrl.initRainbowPolylinesIfNeeded(true);
    }
  }

  public onTrailEffectChanged(newTrailId: string): void {
    this.ctrl.triggerHapticFeedback();
    this.ctrl.selectedTrailEffect = newTrailId;
    AppStorage.setOrCreate('selectedTrailEffect', newTrailId);
    if (newTrailId !== 'none') {
      this.ctrl.selectedRouteStyle = 'classic';
      AppStorage.setOrCreate('selectedRouteStyle', 'classic');
      if (this.ctrl.huaweiMapController) {
        this.ctrl.initRainbowPolylinesIfNeeded(true);
      }
    }
  }

  public startCameraFlyback(): void {
    if (!this.ctrl.huaweiMapController) {
      return;
    }
    this.ctrl.vm.isCameraFollowLocked = true;
    this.ctrl.isCameraFlyingBack = true;
    this.ctrl.flybackStartTime = Date.now();

    try {
      const currentCam = this.ctrl.huaweiMapController.getCameraPosition();
      if (currentCam && currentCam.target) {
        this.ctrl.flybackStartLat = currentCam.target.latitude;
        this.ctrl.flybackStartLon = currentCam.target.longitude;
        this.ctrl.flybackStartZoom = currentCam.zoom ?? 17.2;
        this.ctrl.flybackStartBearing = currentCam.bearing ?? CTU_RUNWAY_BEARING;
      } else {
        const rStart = getCtuRunwayStart();
        this.ctrl.flybackStartLat = rStart.latitude;
        this.ctrl.flybackStartLon = rStart.longitude;
        this.ctrl.flybackStartZoom = 17.2;
        this.ctrl.flybackStartBearing = CTU_RUNWAY_BEARING;
      }
    } catch (e) {
      const rStart = getCtuRunwayStart();
      this.ctrl.flybackStartLat = rStart.latitude;
      this.ctrl.flybackStartLon = rStart.longitude;
      this.ctrl.flybackStartZoom = 17.2;
      this.ctrl.flybackStartBearing = CTU_RUNWAY_BEARING;
    }

    // 地面精修机场状态：启动地面专用 60FPS 平滑帧插值
    if (!this.ctrl.vm.isFlightInProgress) {
      if (this.ctrl.groundFlybackTimerSync) {
        this.ctrl.groundFlybackTimerSync?.stop();
        this.ctrl.groundFlybackTimerSync = undefined;
      }

      this.ctrl.groundFlybackTimerSync = displaySync.create();
      this.ctrl.groundFlybackTimerSync?.on('frame', () => {
        const now = Date.now();
        const elapsed = now - this.ctrl.flybackStartTime;
        const rawProgress = Math.min(1.0, elapsed / this.ctrl.FLYBACK_DURATION_MS);
        // 采用极致平滑的 Cubic EaseOut 阻尼缓动
        const ease = 1.0 - Math.pow(1.0 - rawProgress, 3);

        const targetPos = this.ctrl.currentPlaneGeoPos || getCtuRunwayStart();
        const targetZoom = 17.2;
        const targetBearing = (360 - this.ctrl.planeMarkerRotation + 360) % 360;

        // 1. 经纬度位置平滑插值
        const curLat = this.ctrl.flybackStartLat + (targetPos.latitude - this.ctrl.flybackStartLat) * ease;
        const curLon = this.ctrl.flybackStartLon + (targetPos.longitude - this.ctrl.flybackStartLon) * ease;
        // 2. 视距平滑插值
        const curZoom = this.ctrl.flybackStartZoom + (targetZoom - this.ctrl.flybackStartZoom) * ease;

        // 3. 航向角度最短路径平滑插值 (Shortest Path Slerp)
        let angleDiff = targetBearing - this.ctrl.flybackStartBearing;
        while (angleDiff < -180) angleDiff += 360;
        while (angleDiff > 180) angleDiff -= 360;
        const curBearing = (this.ctrl.flybackStartBearing + angleDiff * ease + 360) % 360;

        const zoomFixed = parseFloat(curZoom.toFixed(1));
        if (this.ctrl.currentZoomLevel !== zoomFixed) {
          this.ctrl.currentZoomLevel = zoomFixed;
          AppStorage.setOrCreate('hudZoomLevel', this.ctrl.currentZoomLevel);
        }
        const newCompassBearing = Math.round(curBearing);
        if (this.ctrl.currentMapBearing !== newCompassBearing) {
          this.ctrl.currentMapBearing = newCompassBearing;
          AppStorage.setOrCreate('hudMapBearing', this.ctrl.currentMapBearing);
        }

        if (this.ctrl.huaweiMapController) {
          try {
            this.ctrl.huaweiMapController.moveCamera(map.newCameraPosition({
              target: { latitude: curLat, longitude: curLon },
              zoom: curZoom,
              bearing: curBearing,
              tilt: 0
            }));
          } catch (e) { }
        }

        if (rawProgress >= 1.0) {
          if (this.ctrl.groundFlybackTimerSync) {
            this.ctrl.groundFlybackTimerSync?.stop();
            this.ctrl.groundFlybackTimerSync = undefined;
          }
          this.ctrl.isCameraFlyingBack = false;
          this.ctrl.currentZoomLevel = 17.2;
          AppStorage.setOrCreate('hudZoomLevel', 17.2);
          this.ctrl.currentMapBearing = CTU_RUNWAY_BEARING;
          AppStorage.setOrCreate('hudMapBearing', CTU_RUNWAY_BEARING);
        }
      });
      this.ctrl.groundFlybackTimerSync?.start();
    }
  }


  public applyRunwayCameraOrientation(controller?: map.MapComponentController): void {
    const mapCtrl = controller || this.ctrl.huaweiMapController;
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

  public tweakMapBearing(deltaDeg: number): void {
    this.ctrl.triggerHapticFeedback();
    this.ctrl.currentMapBearing = Math.round((this.ctrl.currentMapBearing + deltaDeg + 360) % 360); AppStorage.setOrCreate('hudMapBearing', this.ctrl.currentMapBearing);
    if (this.ctrl.huaweiMapController) {
      try {
        const currentCam = this.ctrl.huaweiMapController.getCameraPosition();
        this.ctrl.huaweiMapController.moveCamera(map.newCameraPosition({
          target: currentCam?.target || getCtuRunwayStart(),
          zoom: currentCam?.zoom || 17.2,
          bearing: this.ctrl.currentMapBearing,
          tilt: 0
        }));
      } catch (e) {
        console.error('tweakMapBearing error:', JSON.stringify(e));
      }
    }
    this.ctrl.vm.honkToastText = `📐 地图视角已微调至 ${this.ctrl.currentMapBearing}°`;
    this.ctrl.vm.isHonkToastVisible = true;
    setTimeout(() => {
      this.ctrl.vm.isHonkToastVisible = false;
    }, 1200);
  }


  public getPlaneMarkerIconResource(): Resource {
    if (this.ctrl.vm.currentMapType === mapCommon.MapType.TERRAIN) {
      return $r('app.media.b737_800_top_3_stroked_medium');
    }
    return $r('app.media.b737_800_top_3_medium');
  }
}
