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

export class PhysicsAnimEngine {
  private ctrl: IndexController;
  constructor(ctrl: IndexController) {
    this.ctrl = ctrl;
  }


  public runRealTruckPhysicsAnimation() {
    const duration = 4600;
    const startTime = Date.now();

    if (this.ctrl.animTimer !== -1) {
      clearInterval(this.ctrl.animTimer);
    }

    this.ctrl.animTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      let rawT = elapsed / duration;

      if (rawT >= 1.0) {
        rawT = 1.0;
        clearInterval(this.ctrl.animTimer);
        this.ctrl.animTimer = -1;
        this.ctrl.vm.isFuelTruckParked = true;
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

      this.ctrl.vm.fuelTruckX = x;
      this.ctrl.vm.fuelTruckY = y;
      this.ctrl.vm.fuelTruckRotate = angleDeg;
    }, 16);
  }


  public runFuelTruckDepartureAnimation() {
    if (!this.ctrl.vm.isFuelTruckParked || this.ctrl.vm.isFuelTruckDeparting) return;
    this.ctrl.vm.isFuelTruckDeparting = true;
    this.ctrl.vm.isFuelTruckParked = false;

    this.ctrl.triggerHapticFeedback();
    this.ctrl.vm.fuelTruckMessageText = '加油车驾驶员：航油已加满！';
    this.ctrl.vm.isFuelTruckMessageVisible = true;
    setTimeout(() => {
      this.ctrl.vm.isFuelTruckMessageVisible = false;
    }, 4000);

    const duration = 3500;
    const startTime = Date.now();

    const startX = this.ctrl.vm.fuelTruckX;
    const startY = this.ctrl.vm.fuelTruckY;

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

      this.ctrl.vm.fuelTruckX = x;
      this.ctrl.vm.fuelTruckY = y;
      this.ctrl.vm.fuelTruckRotate = angleDeg;
    }, 16);
  }


  public onTractorClick(): void {
    if (this.ctrl.vm.isMapBackgroundVisible || this.ctrl.vm.isFullFocusMode) return;
    this.ctrl.triggerHapticFeedback();
    this.ctrl.vm.honkToastText = '🚜 勤务牵引车就绪 · 轮档已撤除，随时准备离港后推！';
    this.ctrl.vm.isHonkToastVisible = true;
    setTimeout(() => {
      this.ctrl.vm.isHonkToastVisible = false;
    }, 3000);
  }


  public onFuelTruckClick(): void {
    if (this.ctrl.vm.isMapBackgroundVisible || this.ctrl.vm.isFullFocusMode) return;
    if (!this.ctrl.vm.isFuelTruckParked) {
      if (this.ctrl.vm.isFuelTruckDeparting) {
        this.ctrl.triggerHapticFeedback();
        this.ctrl.vm.fuelTruckMessageText = '加油车驾驶员：已完成任务驶离中';
        this.ctrl.vm.isFuelTruckMessageVisible = true;
        setTimeout(() => {
          this.ctrl.vm.isFuelTruckMessageVisible = false;
        }, 3000);
      } else {
        this.ctrl.triggerHapticFeedback();
        this.ctrl.vm.fuelTruckMessageText = '加油车正在驶入停靠机位中...';
        this.ctrl.vm.isFuelTruckMessageVisible = true;
        setTimeout(() => {
          this.ctrl.vm.isFuelTruckMessageVisible = false;
        }, 2500);
      }
      return;
    }
    this.ctrl.runFuelTruckDepartureAnimation();
  }

  public updatePlaneScreenPosition(targetPos?: mapCommon.LatLng, visualRotation?: number): void {
    if (!this.ctrl.huaweiMapController) {
      return;
    }
    const pos = targetPos || this.ctrl.currentPlaneGeoPos;
    if (!pos) {
      return;
    }

    const effectiveRot = visualRotation !== undefined ? visualRotation : this.ctrl.planeMarkerRotation;

    try {
      // 🎯 相机跟随模式：飞机始终在屏幕正中，offset 强制为 (0,0)，跳过 toScreenLocation
      // 原因：moveCamera 是异步的，调用后立刻 toScreenLocation 会拿到旧相机状态，
      // 返回偏离屏幕中心几像素的抖动值，在起飞期 zoom 快速变化时尤为显著 → 尾迹"一抽一抽"
      if (this.ctrl.vm.isCameraFollowLocked) {
        this.ctrl.vm.planeScreenOffsetX = 0;
        this.ctrl.vm.planeScreenOffsetY = 0;
        const cam = this.ctrl.huaweiMapController.getCameraPosition();
        const bearing = (cam && typeof cam.bearing === 'number') ? cam.bearing : this.ctrl.currentMapBearing;
        this.ctrl.vm.planeScreenDynamicRotation = (effectiveRot + bearing) % 360;
        return;
      }

      // 自由拖拽模式：使用 Projection API 计算飞机偏离屏幕中心的精确坐标
      const projection = this.ctrl.huaweiMapController.getProjection();
      if (projection && typeof projection.toScreenLocation === 'function') {
        const pt = projection.toScreenLocation(pos);
        if (pt && typeof pt.positionX === 'number' && typeof pt.positionY === 'number') {
          const planeVpX = px2vp(pt.positionX);
          const planeVpY = px2vp(pt.positionY);
          const screenCenterX = (this.ctrl.screenVpWidth > 0 ? this.ctrl.screenVpWidth : 360) / 2;
          const screenCenterY = (this.ctrl.screenVpHeight > 0 ? this.ctrl.screenVpHeight : 780) / 2;

          this.ctrl.vm.planeScreenOffsetX = planeVpX - screenCenterX;
          this.ctrl.vm.planeScreenOffsetY = planeVpY - screenCenterY;

          const cam = this.ctrl.huaweiMapController.getCameraPosition();
          const bearing = (cam && typeof cam.bearing === 'number') ? cam.bearing : this.ctrl.currentMapBearing;
          this.ctrl.vm.planeScreenDynamicRotation = (effectiveRot + bearing) % 360;
          return;
        }
      }

      // Fallback
      const cam = this.ctrl.huaweiMapController.getCameraPosition();
      if (cam && cam.target) {
        const bearing = (typeof cam.bearing === 'number' && !isNaN(cam.bearing)) ? cam.bearing : this.ctrl.currentMapBearing;
        this.ctrl.vm.planeScreenDynamicRotation = (effectiveRot + bearing) % 360;
      }
    } catch (e) { }

    this.ctrl.vm.planeScreenOffsetX = 0;
    this.ctrl.vm.planeScreenOffsetY = 0;
  }

  public getTargetMarkerPlaneScale(): number {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const density = displayInfo.densityPixels || 3.5;
      const targetMarkerVp = 175 / density; // 175px 在当前屏幕的真实 vp 宽度 (约 49.2vp)
      return targetMarkerVp / 315; // 对应 315vp 飞机原图的精确缩放比 (约 0.156)
    } catch (e) {
      return 0.156;
    }
  }
}
