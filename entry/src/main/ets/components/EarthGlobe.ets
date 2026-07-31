import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';

/**
 * EarthGlobe.ets
 * 鸿蒙 ArkTS 3D 旋转地球组件
 * 支持 3D 矩阵旋转、经纬网描绘、陆地板块矢量轮廓、大气光晕、立体光影与手势拖拽自转
 */

export interface Point2D {
  x: number;
  y: number;
}

export interface Point3D {
  x: number;
  y: number;
  z: number;
}

// 陆地板块经纬度点集数据（经度: -180~180, 纬度: -90~90）
const LAND_POLYGONS: number[][][] = [
  // 北美洲 (North America)
  [
    [-168, 65], [-140, 70], [-120, 75], [-80, 73], [-60, 60], [-55, 48],
    [-65, 44], [-80, 25], [-90, 16], [-105, 20], [-120, 34], [-124, 48], [-160, 56], [-168, 65]
  ],
  // 南美洲 (South America)
  [
    [-80, 10], [-65, 10], [-35, -5], [-38, -18], [-52, -33], [-68, -55],
    [-75, -45], [-72, -18], [-80, 2], [-80, 10]
  ],
  // 欧洲 (Europe)
  [
    [-10, 36], [0, 43], [10, 44], [15, 38], [28, 41], [40, 50],
    [30, 60], [25, 71], [15, 58], [5, 52], [-5, 48], [-10, 36]
  ],
  // 非洲 (Africa)
  [
    [-17, 32], [10, 37], [25, 32], [32, 31], [43, 12], [51, 11],
    [40, -10], [33, -27], [18, -34], [12, -15], [8, 5], [-15, 12], [-17, 32]
  ],
  // 亚洲 (Asia)
  [
    [40, 50], [60, 55], [80, 65], [100, 75], [140, 70], [170, 60],
    [140, 50], [130, 35], [120, 23], [108, 12], [100, 4], [96, 16],
    [88, 22], [68, 23], [58, 25], [45, 12], [35, 30], [40, 50]
  ],
  // 澳大利亚 / 大洋洲 (Australia)
  [
    [114, -22], [130, -12], [142, -11], [153, -28], [148, -38],
    [136, -35], [115, -34], [114, -22]
  ],
  // 格陵兰岛 (Greenland)
  [
    [-55, 60], [-40, 65], [-20, 75], [-30, 83], [-60, 80], [-55, 60]
  ],
  // 南极洲 (Antarctica)
  [
    [-180, -75], [-120, -70], [-60, -65], [0, -70], [60, -68], [120, -72], [180, -75]
  ]
];

@Component
export struct EarthGlobe {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 基础渲染参数
  @Prop isAutoRotate: boolean = true;
  @Prop showGraticule: boolean = true;
  @Prop showAtmosphere: boolean = true;
  @Prop rotateSpeed: number = 0.5;
  @Prop invertGesture: boolean = false; // 是否反转手势拖拽方向
  @Prop isTextureMode: boolean = true; // 是否开启真实地图纹理贴图模式

  // 缩放控制（0.5 ~ 3.0 倍）
  @State globeScale: number = 1.0;
  private pinchStartScale: number = 1.0;

  // 真实 4K 地球贴图资源 (PixelMap)
  @State texturePixelMap: PixelMap | null = null;
  private imageWidth: number = 2048;
  private imageHeight: number = 1024;

  // 旋转状态（角度 degree）
  @State rotationX: number = 15; // Pitch 俯仰角
  @State rotationY: number = 0;  // Yaw 偏航角

  private animationTimer: number = -1;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private isTouching: boolean = false;
  private canvasWidth: number = 300;
  private canvasHeight: number = 300;

  aboutToAppear() {
    this.loadTexture();
    this.startAnimation();
  }

  private async loadTexture() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const fileData = await context.resourceManager.getRawFileContent('earth_texture.jpg');
      const buffer = fileData.buffer.slice(fileData.byteOffset, fileData.byteOffset + fileData.byteLength);
      const imageSource = image.createImageSource(buffer);
      const pm = await imageSource.createPixelMap();
      const imageInfo = await pm.getImageInfo();
      this.imageWidth = imageInfo.size.width;
      this.imageHeight = imageInfo.size.height;
      this.texturePixelMap = pm;
      this.drawEarth();
    } catch (err) {
      console.error('Failed to load earth_texture.jpg: ' + JSON.stringify(err));
    }
  }

  aboutToDisappear() {
    this.stopAnimation();
  }

  private startAnimation() {
    if (this.animationTimer !== -1) {
      return;
    }
    this.animationTimer = setInterval(() => {
      if (this.isAutoRotate && !this.isTouching) {
        this.rotationY = (this.rotationY + this.rotateSpeed) % 360;
      }
      this.drawEarth();
    }, 16); // 约 60 FPS
  }

  private stopAnimation() {
    if (this.animationTimer !== -1) {
      clearInterval(this.animationTimer);
      this.animationTimer = -1;
    }
  }

  /**
   * 将 3D 空间坐标投影变换至 2D 屏幕坐标
   */
  private project3D(x: number, y: number, z: number, radius: number, cx: number, cy: number): Point3D {
    const radX = (this.rotationX * Math.PI) / 180;
    const radY = (this.rotationY * Math.PI) / 180;

    // 绕 Y 轴旋转 (Yaw)
    const x1 = x * Math.cos(radY) + z * Math.sin(radY);
    const z1 = -x * Math.sin(radY) + z * Math.cos(radY);

    // 绕 X 轴旋转 (Pitch)
    const y2 = y * Math.cos(radX) - z1 * Math.sin(radX);
    const z2 = y * Math.sin(radX) + z1 * Math.cos(radX);

    // 屏幕 2D 坐标系统
    const screenX = cx + x1;
    const screenY = cy - y2;

    return { x: screenX, y: screenY, z: z2 };
  }

  /**
   * 经纬度 (lon, lat) 转 3D 投影坐标
   */
  private latLonToScreen(lon: number, lat: number, radius: number, cx: number, cy: number): Point3D {
    const radLon = (lon * Math.PI) / 180;
    const radLat = (lat * Math.PI) / 180;

    const x = radius * Math.cos(radLat) * Math.sin(radLon);
    const y = radius * Math.sin(radLat);
    const z = radius * Math.cos(radLat) * Math.cos(radLon);

    return this.project3D(x, y, z, radius, cx, cy);
  }

  /**
   * Canvas 主渲染逻辑
   */
  private drawEarth() {
    const ctx = this.context;
    if (!ctx) return;

    const w = this.canvasWidth;
    const h = this.canvasHeight;
    const cx = w / 2;
    const cy = h / 2;
    const radius = Math.min(w, h) * 0.38 * this.globeScale;

    ctx.clearRect(0, 0, w, h);

    // 1. 绘制深空背景渐变
    const bgGradient = ctx.createRadialGradient(cx, cy, radius * 0.5, cx, cy, Math.max(w, h) * 0.7);
    bgGradient.addColorStop(0, '#0d1b2a');
    bgGradient.addColorStop(1, '#020617');
    ctx.fillStyle = bgGradient;
    ctx.fillRect(0, 0, w, h);

    // 2. 绘制星空微粒散点
    ctx.fillStyle = '#ffffff';
    for (let i = 0; i < 30; i++) {
      const sx = (Math.sin(i * 99 + this.rotationY * 0.05) * 0.5 + 0.5) * w;
      const sy = (Math.cos(i * 33 + this.rotationX * 0.05) * 0.5 + 0.5) * h;
      const size = (i % 3 === 0) ? 1.5 : 0.8;
      ctx.globalAlpha = 0.3 + 0.7 * Math.abs(Math.sin(i + this.rotationY * 0.1));
      ctx.beginPath();
      ctx.arc(sx, sy, size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1.0;

    // 3. 绘制外围大气发光层 (Atmosphere Glow)
    if (this.showAtmosphere) {
      const atmosphereGlow = ctx.createRadialGradient(cx, cy, radius * 0.95, cx, cy, radius * 1.25);
      atmosphereGlow.addColorStop(0, 'rgba(56, 189, 248, 0.45)');
      atmosphereGlow.addColorStop(0.5, 'rgba(14, 165, 233, 0.2)');
      atmosphereGlow.addColorStop(1, 'rgba(14, 165, 233, 0.0)');

      ctx.fillStyle = atmosphereGlow;
      ctx.beginPath();
      ctx.arc(cx, cy, radius * 1.25, 0, Math.PI * 2);
      ctx.fill();
    }

    // 4. 绘制海洋球底体与立体渐变球底
    const oceanGradient = ctx.createRadialGradient(
      cx - radius * 0.3,
      cy - radius * 0.3,
      radius * 0.1,
      cx,
      cy,
      radius
    );
    oceanGradient.addColorStop(0, '#1e3a8a');   // 深海湛蓝
    oceanGradient.addColorStop(0.7, '#0f172a'); // 边缘深色
    oceanGradient.addColorStop(1, '#020617');   // 最外围阴影

    ctx.fillStyle = oceanGradient;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    // 5. 绘制经纬网格线 (Graticules)
    if (this.showGraticule) {
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
      ctx.lineWidth = 1;

      // 5.1 纬线 (Parallels: -60° to 60°, 间隔 30°)
      for (let lat = -60; lat <= 60; lat += 30) {
        ctx.beginPath();
        let isFirst = true;
        for (let lon = -180; lon <= 180; lon += 5) {
          const pt = this.latLonToScreen(lon, lat, radius, cx, cy);
          if (pt.z > 0) { // 正面可见
            if (isFirst) {
              ctx.moveTo(pt.x, pt.y);
              isFirst = false;
            } else {
              ctx.lineTo(pt.x, pt.y);
            }
          } else {
            isFirst = true;
          }
        }
        ctx.stroke();
      }

      // 5.2 经线 (Meridians: -180° to 180°, 间隔 30°)
      for (let lon = -180; lon < 180; lon += 30) {
        ctx.beginPath();
        let isFirst = true;
        for (let lat = -90; lat <= 90; lat += 5) {
          const pt = this.latLonToScreen(lon, lat, radius, cx, cy);
          if (pt.z > 0) { // 正面可见
            if (isFirst) {
              ctx.moveTo(pt.x, pt.y);
              isFirst = false;
            } else {
              ctx.lineTo(pt.x, pt.y);
            }
          } else {
            isFirst = true;
          }
        }
        ctx.stroke();
      }
    }

    // 6. 绘制陆地与真实 4K 高清炫彩地球贴图纹理（360°x180° 全球无缝包裹）
    if (this.isTextureMode && this.texturePixelMap) {
      const img = this.texturePixelMap;
      const step = 8; // 8 度经纬网格切片，实现顺滑全覆盖

      for (let lat = 90; lat > -90; lat -= step) {
        for (let lon = -180; lon < 180; lon += step) {
          // 四个顶点的 3D 屏幕坐标
          const p1 = this.latLonToScreen(lon, lat, radius, cx, cy);
          const p2 = this.latLonToScreen(lon + step, lat, radius, cx, cy);
          const p3 = this.latLonToScreen(lon + step, lat - step, radius, cx, cy);
          const p4 = this.latLonToScreen(lon, lat - step, radius, cx, cy);

          // 计算切片网格中心点的 3D 深度 z
          const centerLon = lon + step / 2;
          const centerLat = lat - step / 2;
          const centerPt = this.latLonToScreen(centerLon, centerLat, radius, cx, cy);

          // 仅当切片在 3D 视线正面 (centerPt.z > 0) 时渲染
          if (centerPt.z > 0) {
            const sx = ((lon + 180) / 360) * this.imageWidth;
            const sy = ((90 - lat) / 180) * this.imageHeight;
            const sw = (step / 360) * this.imageWidth;
            const sh = (step / 180) * this.imageHeight;

            const minX = Math.min(p1.x, p2.x, p3.x, p4.x);
            const maxX = Math.max(p1.x, p2.x, p3.x, p4.x);
            const minY = Math.min(p1.y, p2.y, p3.y, p4.y);
            const maxY = Math.max(p1.y, p2.y, p3.y, p4.y);
            const w = Math.max(1, maxX - minX);
            const h = Math.max(1, maxY - minY);

            ctx.save();
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.lineTo(p3.x, p3.y);
            ctx.lineTo(p4.x, p4.y);
            ctx.closePath();
            ctx.clip();

            ctx.drawImage(img, sx, sy, sw, sh, minX, minY, w, h);
            ctx.restore();
          }
        }
      }
    } else if (this.isTextureMode) {
      // 降级使用地理色彩贴图
      for (let polyIndex = 0; polyIndex < LAND_POLYGONS.length; polyIndex++) {
        const polygon = LAND_POLYGONS[polyIndex];
        ctx.beginPath();
        let visibleCount = 0;
        let isFirst = true;

        for (let i = 0; i < polygon.length; i++) {
          const lon = polygon[i][0];
          const lat = polygon[i][1];
          const pt = this.latLonToScreen(lon, lat, radius, cx, cy);

          if (pt.z > 0) {
            visibleCount++;
            if (isFirst) {
              ctx.moveTo(pt.x, pt.y);
              isFirst = false;
            } else {
              ctx.lineTo(pt.x, pt.y);
            }
          } else {
            isFirst = true;
          }
        }

        if (visibleCount > 2) {
          ctx.closePath();
          let fillColor = '#388e3c';
          if (polyIndex === 3) fillColor = '#fbc02d';
          else if (polyIndex === 4) fillColor = '#43a047';
          else if (polyIndex === 6 || polyIndex === 7) fillColor = '#e0f7fa';
          else if (polyIndex === 0) fillColor = '#2e7d32';
          else if (polyIndex === 1) fillColor = '#1b5e20';

          ctx.fillStyle = fillColor;
          ctx.fill();
          ctx.strokeStyle = 'rgba(255, 235, 59, 0.6)';
          ctx.lineWidth = 1.0;
          ctx.stroke();
        }
      }
    } else {
      // --- 矢量模式：翡翠绿科技感点阵 ---
      ctx.fillStyle = 'rgba(34, 197, 94, 0.75)';
      ctx.strokeStyle = 'rgba(74, 222, 128, 0.9)';
      ctx.lineWidth = 1.2;

      for (let polyIndex = 0; polyIndex < LAND_POLYGONS.length; polyIndex++) {
        const polygon = LAND_POLYGONS[polyIndex];
        ctx.beginPath();
        let visiblePoints = 0;
        let isFirst = true;

        for (let i = 0; i < polygon.length; i++) {
          const lon = polygon[i][0];
          const lat = polygon[i][1];
          const pt = this.latLonToScreen(lon, lat, radius, cx, cy);

          if (pt.z > 0) {
            visiblePoints++;
            if (isFirst) {
              ctx.moveTo(pt.x, pt.y);
              isFirst = false;
            } else {
              ctx.lineTo(pt.x, pt.y);
            }
          } else {
            isFirst = true;
          }
        }

        if (visiblePoints > 2) {
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
        }
      }
    }

    // 7. 绘制球体表面立体阴影与边缘高光 (Specular Highlight & Shadow Overlay)
    const shadowOverlay = ctx.createRadialGradient(
      cx - radius * 0.4,
      cy - radius * 0.4,
      radius * 0.2,
      cx,
      cy,
      radius
    );
    shadowOverlay.addColorStop(0, 'rgba(255, 255, 255, 0.15)'); // 左上方微弱高光
    shadowOverlay.addColorStop(0.5, 'rgba(0, 0, 0, 0.0)');
    shadowOverlay.addColorStop(0.85, 'rgba(2, 6, 23, 0.4)');
    shadowOverlay.addColorStop(1, 'rgba(2, 6, 23, 0.85)');     // 右下方球体阴影

    ctx.fillStyle = shadowOverlay;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    // 8. 外边缘精细弧圈
    ctx.strokeStyle = 'rgba(56, 189, 248, 0.6)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();
  }

  /**
   * 2D Canvas 3D 仿射变换三角形贴图渲染
   */
  private drawAffineTriangle(
    ctx: CanvasRenderingContext2D,
    img: PixelMap,
    sx: number, sy: number, sw: number, sh: number,
    p0: Point3D, p1: Point3D, p2: Point3D,
    u0: number, v0: number, u1: number, v1: number, u2: number, v2: number
  ) {
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.closePath();
    ctx.clip();

    const deltaU1 = u1 - u0;
    const deltaV1 = v1 - v0;
    const deltaU2 = u2 - u0;
    const deltaV2 = v2 - v0;
    const det = deltaU1 * deltaV2 - deltaU2 * deltaV1;

    if (Math.abs(det) > 0.0001) {
      const dx1 = p1.x - p0.x;
      const dy1 = p1.y - p0.y;
      const dx2 = p2.x - p0.x;
      const dy2 = p2.y - p0.y;

      const a = (dx1 * deltaV2 - dx2 * deltaV1) / det;
      const b = (dy1 * deltaV2 - dy2 * deltaV1) / det;
      const c = (dx2 * deltaU1 - dx1 * deltaU2) / det;
      const d = (dy2 * deltaU1 - dy1 * deltaU2) / det;
      const e = p0.x - a * u0 - c * v0;
      const f = p0.y - b * u0 - d * v0;

      ctx.transform(a, b, c, d, e, f);
      ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
    }
    ctx.restore();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.drawEarth();
        })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.canvasWidth = Number(newValue.width);
          this.canvasHeight = Number(newValue.height);
          this.drawEarth();
        })
    }
    .width('100%')
    .height('100%')
    .priorityGesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture()
          .onActionStart((event: GestureEvent) => {
            this.isTouching = true;
            this.lastTouchX = event.offsetX;
            this.lastTouchY = event.offsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            const dx = event.offsetX - this.lastTouchX;
            const dy = event.offsetY - this.lastTouchY;

            this.lastTouchX = event.offsetX;
            this.lastTouchY = event.offsetY;

            // 拖拽映射为 3D 旋转角度
            const factor = this.invertGesture ? -1 : 1;
            this.rotationY = (this.rotationY + dx * 0.6 * factor) % 360;
            this.rotationX = Math.max(-80, Math.min(80, this.rotationX + dy * 0.6 * factor));

            this.drawEarth();
          })
          .onActionEnd(() => {
            this.isTouching = false;
          })
          .onActionCancel(() => {
            this.isTouching = false;
          }),
        PinchGesture()
          .onActionStart(() => {
            this.pinchStartScale = this.globeScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event) {
              const newScale = this.pinchStartScale * event.scale;
              this.globeScale = Math.max(0.5, Math.min(3.0, newScale));
              this.drawEarth();
            }
          })
      )
    )
  }
}
