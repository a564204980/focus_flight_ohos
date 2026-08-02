import { router } from '@kit.ArkUI';
import animator, { AnimatorResult } from '@ohos.animator';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { generateGreatCirclePoints, calculateBearing, interpolateAngle } from '../utils/GeodesicUtils';

interface MapPageParams {
  flightNo?: string;
  seatId?: string;
  taskTitle?: string;
  durationMin?: number;
  originCode?: string;
  destCode?: string;
}

/**
 * MapPage.ets
 * 华为原生花瓣地图 (Petal Maps) 专属极简深邃巡航视界
 * 1. 默认高清卫星视图 (SATELLITE)
 * 2. 默认缩放倍数严格为 17 倍 (zoom: 17)
 * 3. 默认方向严格对准正北方 (bearing: 0)，同时支持手势自由旋转
 * 4. 实时显示地图缩放倍数 (Zoom Level Indicator) 与 🧭 正北复位按键
 * 5. 使用 Slerp 大圆测地线算法 (Great Circle Route) 绘制弧形航线
 * 6. B737-800 真实战机沿大圆航线平滑巡航飞行，机头自动切线对齐
 */
@Entry
@Component
struct MapPage {
  @State originCode: string = 'CTU';
  @State destCode: string = 'PEK';
  @State durationMin: number = 25;
  @State currentMapType: mapCommon.MapType = mapCommon.MapType.SATELLITE;
  @State currentZoom: number = 16.5;
  @State currentBearing: number = 0;
  private baseZoom: number = 16.5;
  @State mapIntroOpacity: number = 0;
  @State mapScale: number = 1.06;
  @State isTrackingPlane: boolean = true;
  @State planeRotation: number = 0;

  private originAirport: Airport = { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5785, lon: 103.9471 };
  private destAirport: Airport = { code: 'PEK', name: '北京首都国际机场', city: '北京', lat: 40.0801, lon: 116.5846 };
  private huaweiMapController?: map.MapComponentController;
  private planeMarker?: map.Marker;
  private lastAppliedRotation: number = -999;
  private flightAnimationTimer: number = -1;
  private cameraTrackTimer: number = -1;
  private flightAnimator?: AnimatorResult;
  private isUserInteracting: boolean = false;

  // 华为花瓣地图初始配置：默认卫星图 + 高清 16.5 倍缩放 + 允许完整原生手势交互
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 30.5785,
        longitude: 103.9471
      },
      zoom: 16.5,
      bearing: 0,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: true,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true
  };

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
      // 开启轮询保持 currentZoom 实时响应
      setInterval(() => {
        try {
          if (this.huaweiMapController) {
            const pos = this.huaweiMapController.getCameraPosition();
            if (pos && typeof pos.zoom === 'number') {
              const newZoom = Number(pos.zoom.toFixed(1));
              if (Math.abs(newZoom - this.currentZoom) >= 0.25) {
                this.currentZoom = newZoom;
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }, 300);
    } else {
      console.error('Petal Map init error:', JSON.stringify(err));
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as MapPageParams;
    if (params) {
      if (params.originCode) this.originCode = params.originCode;
      if (params.destCode) this.destCode = params.destCode;
      if (params.durationMin) this.durationMin = params.durationMin;
    }
    const foundOrigin = findAirportByCode(this.originCode);
    if (foundOrigin) this.originAirport = foundOrigin;
    const foundDest = findAirportByCode(this.destCode);
    if (foundDest) this.destAirport = foundDest;

    // 高空镜头落定动画 (淡入 + 缩放归位)
    this.getUIContext()?.animateTo({
      duration: 600,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.mapIntroOpacity = 1;
      this.mapScale = 1.0;
    });
  }

  aboutToDisappear(): void {
    if (this.flightAnimationTimer !== -1) {
      clearInterval(this.flightAnimationTimer);
      this.flightAnimationTimer = -1;
    }
    if (this.cameraTrackTimer !== -1) {
      clearInterval(this.cameraTrackTimer);
      this.cameraTrackTimer = -1;
    }
    if (this.flightAnimator) {
      this.flightAnimator.finish();
      this.flightAnimator = undefined;
    }
    if (this.planeMarker) {
      try {
        this.planeMarker.remove();
      } catch (e) { }
      this.planeMarker = undefined;
    }
  }

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 1. 计算大圆测地线航线
      const greatCirclePoints = generateGreatCirclePoints(
        { latitude: this.originAirport.lat, longitude: this.originAirport.lon },
        { latitude: this.destAirport.lat, longitude: this.destAirport.lon },
        600
      );

      // 2. 绘制航线
      await controller.addPolyline({
        points: greatCirclePoints,
        width: 8,
        color: 0xFF0284C7
      });

      // 3. 起点 / 终点机场 Marker
      await controller.addMarker({
        position: { latitude: this.originAirport.lat, longitude: this.originAirport.lon },
        title: `🛫 ${this.originAirport.city}`,
        snippet: this.originAirport.name
      });
      await controller.addMarker({
        position: { latitude: this.destAirport.lat, longitude: this.destAirport.lon },
        title: `🛬 ${this.destAirport.city}`,
        snippet: this.destAirport.name
      });

      // 4. 飞机 Marker：使用 flat: true 平贴地面，由 GPU 管线自动随地图旋转对齐航线
      const initBearing = greatCirclePoints.length >= 2 ? calculateBearing(greatCirclePoints[0], greatCirclePoints[1]) : 0;
      this.lastAppliedRotation = initBearing;
      this.planeMarker = await controller.addMarker({
        position: greatCirclePoints[0],
        icon: $r('app.media.b737_800_top_3'),
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: initBearing,
        clickable: false,
        zIndex: 100
      });

      // 5. 初始镜头：定位到起点，zoom=16.5 高清俯瞰
      controller.moveCamera(map.newCameraPosition({
        target: greatCirclePoints[0],
        zoom: 16.5,
        bearing: 0,
        tilt: 0
      }));
      this.currentZoom = 16.5;

      // 6. 启动飞行动画
      if (greatCirclePoints.length >= 2) {
        this.startFlightAnimation(greatCirclePoints);
      }
    } catch (e) {
      console.error('Petal Map setup error:', JSON.stringify(e));
    }
  }

  private currentPlanePos?: mapCommon.LatLng;
  private smoothedCamPos?: mapCommon.LatLng;

  private zoomIn(): void {
    this.triggerHaptic();
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const curZoom = curPos?.zoom || this.currentZoom;
        if (curZoom < 20.0) {
          const targetZoom = Math.min(curZoom + 1.0, 20.0);
          this.currentZoom = Number(targetZoom.toFixed(1));
          const centerTarget = this.currentPlanePos || curPos.target;
          this.huaweiMapController.animateCamera(
            map.newCameraPosition({
              target: centerTarget,
              zoom: targetZoom,
              bearing: 0,
              tilt: 0
            }),
            200
          );
        }
      } catch (e) { }
    }
  }

  private zoomOut(): void {
    this.triggerHaptic();
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const curZoom = curPos?.zoom || this.currentZoom;
        if (curZoom > 3.0) {
          const targetZoom = Math.max(curZoom - 1.0, 3.0);
          this.currentZoom = Number(targetZoom.toFixed(1));
          const centerTarget = this.currentPlanePos || curPos.target;
          this.huaweiMapController.animateCamera(
            map.newCameraPosition({
              target: centerTarget,
              zoom: targetZoom,
              bearing: 0,
              tilt: 0
            }),
            200
          );
        }
      } catch (e) { }
    }
  }

  private startFlightAnimation(points: Array<mapCommon.LatLng>): void {
    if (!points || points.length < 2) return;
    if (this.flightAnimationTimer !== -1) {
      clearInterval(this.flightAnimationTimer);
      this.flightAnimationTimer = -1;
    }
    if (this.flightAnimator) {
      this.flightAnimator.finish();
      this.flightAnimator = undefined;
    }

    const totalDurationMs = Math.max(10000, this.durationMin * 60 * 1000);
    const startTime = Date.now();

    // 🚀 飞机动画：Marker(flat:true) 绑定地图坐标系，animateCamera/animateCameraWithMarker 控制追随
    this.flightAnimationTimer = setInterval(() => {
      if (!this.huaweiMapController) return;

      const elapsed = Date.now() - startTime;
      const progress = Math.min(Math.max(elapsed / totalDurationMs, 0.0), 1.0);

      const exactIndex = progress * (points.length - 1);
      const baseIndex = Math.min(Math.floor(exactIndex), points.length - 2);
      const alpha = exactIndex - baseIndex;
      const p1 = points[baseIndex];
      const p2 = points[baseIndex + 1];
      const p3 = points[Math.min(baseIndex + 2, points.length - 1)];

      const lat = p1.latitude + (p2.latitude - p1.latitude) * alpha;
      const lon = p1.longitude + (p2.longitude - p1.longitude) * alpha;
      const pos: mapCommon.LatLng = { latitude: lat, longitude: lon };
      this.currentPlanePos = pos;

      // 计算当前航向角
      const b1 = calculateBearing(p1, p2);
      const b2 = calculateBearing(p2, p3);
      const geobearing = interpolateAngle(b1, b2, alpha);

      // 1. 实时更新 Marker 航向角与 TranslateAnimation (100ms GPU 底层平滑插值移动)
      if (this.planeMarker) {
        try {
          const transAnim = new map.TranslateAnimation(pos);
          transAnim.setDuration(100);
          this.planeMarker.setAnimation(transAnim);
          this.planeMarker.startAnimation();
        } catch (e) {
          this.planeMarker.setPosition(pos);
        }
        if (Math.abs(geobearing - this.lastAppliedRotation) >= 0.5) {
          this.lastAppliedRotation = geobearing;
          this.planeMarker.setRotation(geobearing);
        }
      }

      // 2. 相机追随：使用与 Marker 相同的 100ms GPU 动画过渡，匹配 100ms 触发周期，零截断零相位差平滑滑动
      if (this.isTrackingPlane && !this.isUserInteracting && this.huaweiMapController) {
        try {
          let currentMapBearing = this.currentBearing;
          let currentMapZoom = this.currentZoom;
          try {
            const curCam = this.huaweiMapController.getCameraPosition();
            if (curCam) {
              if (typeof curCam.bearing === 'number') currentMapBearing = curCam.bearing;
              if (typeof curCam.zoom === 'number') currentMapZoom = curCam.zoom;
            }
          } catch (e) { }

          const cameraUpdate = map.newCameraPosition({
            target: pos,
            zoom: currentMapZoom,
            bearing: currentMapBearing,
            tilt: 0
          });

          this.huaweiMapController.animateCamera(cameraUpdate, 100);
        } catch (e) { }
      }

      if (progress >= 1.0) {
        clearInterval(this.flightAnimationTimer);
        this.flightAnimationTimer = -1;
      }
    }, 100);
  }

  private switchMapType(type: mapCommon.MapType): void {
    this.triggerHaptic();
    this.currentMapType = type;
    if (this.huaweiMapController) {
      try {
        this.huaweiMapController.setMapType(type);
      } catch (e) {
        console.error('setMapType error:', JSON.stringify(e));
      }
    }
  }

  private resetNorth(): void {
    this.triggerHaptic();
    this.currentBearing = 0;
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const cameraUpdate = map.newCameraPosition({
          target: curPos?.target || { latitude: this.originAirport.lat, longitude: this.originAirport.lon },
          zoom: curPos?.zoom || this.currentZoom,
          bearing: 0,
          tilt: 0
        });
        this.huaweiMapController.animateCamera(cameraUpdate, 250);
      } catch (e) {
        console.error('resetNorth error:', JSON.stringify(e));
      }
    }
  }

  private toggleTracking(): void {
    this.triggerHaptic();
    this.isTrackingPlane = !this.isTrackingPlane;
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 25 }, { id: 0, usage: 'touch' });
    } catch (e) {
      // ignore
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 华为花瓣地图 (Petal Maps) 视界
      MapComponent({
        mapOptions: this.huaweiMapOptions,
        mapCallback: this.huaweiMapCallback
      })
        .width('100%')
        .height('100%')
        .scale({ x: this.mapScale, y: this.mapScale })
        .opacity(this.mapIntroOpacity)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down || event.type === TouchType.Move) {
            this.isUserInteracting = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            // 给地图惯性滑动留出 400ms 缓冲，避免手抬起瞬间 animateCamera 暴力打断手势惯性造成跳变位移！
            setTimeout(() => {
              this.isUserInteracting = false;
            }, 400);
          }
        })

      // 顶部操控挂件：返回胶囊 + 地图模式切换 + 缩放倍数 + 🧭 正北复位 + 🎥 视角追随
      Row({ space: 6 }) {
        // 返回按钮
        Row() {
          Text('‹')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#FFFFFF' : '#0F172A')
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 20 })
        .borderRadius(20)
        .backdropBlur(16)
        .onClick(() => {
          this.triggerHaptic();
          router.back();
        })

        // 花瓣地图样式切换胶囊
        Row({ space: 4 }) {
          // ☀️ 标准路线
          Text('☀️ 标准')
            .fontSize(12)
            .fontWeight(this.currentMapType === mapCommon.MapType.STANDARD ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentMapType === mapCommon.MapType.STANDARD ? '#0284C7' : (this.currentMapType === mapCommon.MapType.SATELLITE ? '#94A3B8' : '#64748B'))
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .backgroundColor(this.currentMapType === mapCommon.MapType.STANDARD ? 'rgba(56, 189, 248, 0.18)' : 'transparent')
            .borderRadius(14)
            .onClick(() => this.switchMapType(mapCommon.MapType.STANDARD))

          // 🛰️ 真实卫星 (默认)
          Text('🛰️ 卫星')
            .fontSize(12)
            .fontWeight(this.currentMapType === mapCommon.MapType.SATELLITE ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#38BDF8' : '#64748B')
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(56, 189, 248, 0.25)' : 'transparent')
            .borderRadius(14)
            .onClick(() => this.switchMapType(mapCommon.MapType.SATELLITE))
        }
        .padding(4)
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)

        // 🎥 战机视角追随胶囊按钮
        Row({ space: 4 }) {
          Text('🎥')
            .fontSize(11)
          Text(this.isTrackingPlane ? '追随中' : '追随')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isTrackingPlane ? '#38BDF8' : (this.currentMapType === mapCommon.MapType.SATELLITE ? '#F8FAFC' : '#0F172A'))
        }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.isTrackingPlane ? 'rgba(56, 189, 248, 0.22)' : (this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)'))
        .border({ width: 1, color: this.isTrackingPlane ? '#38BDF8' : (this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)'), radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)
        .onClick(() => this.toggleTracking())

        // 缩放倍数 HUD 实时显示标牌
        Row({ space: 2 }) {
          Text('🔍')
            .fontSize(11)
          Text(`${this.currentZoom}×`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#38BDF8' : '#0284C7')
        }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)

        // 🧭 正北复位按钮
        Row({ space: 2 }) {
          Text('🧭')
            .fontSize(11)
          Text('正北')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#F8FAFC' : '#0F172A')
        }
        .padding({ left: 6, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)
        .onClick(() => this.resetNorth())
      }
      .margin({ top: 48, left: 12, right: 12 })
      .zIndex(100)
      .opacity(this.mapIntroOpacity)

      // 🔍 右下角 Cyber HUD 放大 (+) 与 缩小 (−) 快捷控制按键
      Column({ space: 10 }) {
        // ➕ 放大按键
        Row() {
          Text('+')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#38BDF8' : '#0284C7')
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.88)' : 'rgba(255, 255, 255, 0.95)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(56, 189, 248, 0.4)' : 'rgba(2, 132, 199, 0.3)', radius: 22 })
        .borderRadius(22)
        .backdropBlur(16)
        .shadow({ radius: 10, color: 'rgba(0,0,0,0.35)', offsetY: 3 })
        .onClick(() => this.zoomIn())

        // ➖ 缩小按键
        Row() {
          Text('−')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapType === mapCommon.MapType.SATELLITE ? '#F8FAFC' : '#0F172A')
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(15, 23, 42, 0.88)' : 'rgba(255, 255, 255, 0.95)')
        .border({ width: 1, color: this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 22 })
        .borderRadius(22)
        .backdropBlur(16)
        .shadow({ radius: 10, color: 'rgba(0,0,0,0.35)', offsetY: 3 })
        .onClick(() => this.zoomOut())
      }
      .position({ x: '100%', y: '100%' })
      .markAnchor({ x: '100%', y: '100%' })
      .offset({ x: -16, y: -100 })
      .zIndex(100)
      .opacity(this.mapIntroOpacity)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
