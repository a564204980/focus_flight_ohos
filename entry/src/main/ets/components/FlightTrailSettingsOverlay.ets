/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import vibrator from '@ohos.vibrator';
import { displaySync } from '@kit.ArkGraphics2D';
import { TrailParticle, TrailParticleRenderHelper } from '../utils/TrailParticleRenderHelper';

export interface VisualOptionItem {
  id: string;
  name: string;
}

/**
 * ✈️ 飞行视觉个性化抽屉面板（参考图 2 Flighty 高端全景视窗 + 胶囊切换条架构）
 */
@Component
export struct FlightTrailSettingsOverlay {
  @Prop isVisible: boolean = false;
  @Link currentRouteStyle: string;
  @Link currentTrailId: string;

  @State activeTab: string = 'trail'; // 'trail' | 'route' (默认进入巡航尾迹)
  @State planeFloatingOffsetX: number = 0; // ✈️ 巡航随机微气流水平漂移 (vp)
  @State planeFloatingOffsetY: number = 0; // ✈️ 巡航随机微气流垂直漂移 (vp)
  @State planeTiltAngle: number = 0; // ✈️ 巡航微幅俯仰姿态角 (deg)
  @State private topTabWidth: number = 324;
  @State private switcherBarWidth: number = 324;
  @State private previewCardWidth: number = 324;

  public onSelectRoute: (routeId: string) => void = () => {};
  public onSelectTrail: (trailId: string) => void = () => {};
  public onClose: () => void = () => {};

  // ✈️ 4 款航线风格 (纯净由右上角 ✕ 纯净 按钮承载)
  private readonly routeList: VisualOptionItem[] = [
    { id: 'rainbow', name: '彩虹光谱' },
    { id: 'aurora', name: '极光天际' },
    { id: 'ocean', name: '蔚蓝天路' },
    { id: 'blaze', name: '炽热航路' }
  ];

  // 💫 4 款机尾喷气粒子特效 (纯净由右上角 ✕ 纯净 按钮承载)
  private readonly trailList: VisualOptionItem[] = [
    { id: 'bubbles', name: '梦幻气泡' },
    { id: 'stardust', name: '星光粉尘' },
    { id: 'melody', name: '律动音符' },
    { id: 'contrail', name: '凝结尾迹' }
  ];

  /**
   * 触发轻快触觉震动
   */
  private triggerHaptic() {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 15
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) { }
  }

  /**
   * 当前是否选中了 4 款特效中的任意一款
   */
  private isAnyOptionSelected(): boolean {
    const list = this.activeTab === 'route' ? this.routeList : this.trailList;
    const curId = this.activeTab === 'route' ? this.currentRouteStyle : this.currentTrailId;
    return list.some(item => item.id === curId);
  }

  /**
   * 计算飞机在 Hero 视窗中的水平锚点坐标：
   * - 航线效果 Tab：飞机始终水平居中左右展示（贯穿全屏的流光航线更显宏伟对称）
   * - 巡航尾迹 Tab：
   *   - 选中尾迹特效：平滑右移至黄金航行位 (98vp)，留出左侧空间展示尾迹喷涌
   *   - 默认纯净无尾：平滑居中
   */
  private getPlaneAnchorX(): number {
    if (this.activeTab === 'route') {
      const cardW = this.previewCardWidth > 50 ? this.previewCardWidth : (this.switcherBarWidth > 50 ? this.switcherBarWidth : 324);
      return (cardW / 2) - this.planeFloatingOffsetX;
    }

    if (this.currentTrailId !== 'none') {
      return 98 - this.planeFloatingOffsetX;
    } else {
      const cardW = this.previewCardWidth > 50 ? this.previewCardWidth : (this.switcherBarWidth > 50 ? this.switcherBarWidth : 324);
      return (cardW / 2) - this.planeFloatingOffsetX;
    }
  }

  /**
   * 获取当前激活样式的名称（用于 Hero 视窗左下角标签显示）
   */
  private getSelectedName(): string {
    if (this.activeTab === 'route') {
      const found = this.routeList.find(item => item.id === this.currentRouteStyle);
      return found ? found.name : '经典航线';
    } else {
      const found = this.trailList.find(item => item.id === this.currentTrailId);
      return found ? found.name : '纯净无尾';
    }
  }

  private getTopTabWidth(): number {
    return this.topTabWidth > 50 ? this.topTabWidth : 324;
  }

  private getBottomPillWidth(): number {
    const list = this.activeTab === 'route' ? this.routeList : this.trailList;
    const count = list.length;
    if (count <= 0) return 0;
    const w = this.switcherBarWidth > 50 ? this.switcherBarWidth : 324;
    const innerW = Math.max(10, w - 8);
    return innerW / count;
  }

  private getBottomPillOffset(): number {
    const list = this.activeTab === 'route' ? this.routeList : this.trailList;
    const curId = this.activeTab === 'route' ? this.currentRouteStyle : this.currentTrailId;
    let idx = list.findIndex(item => item.id === curId);
    if (idx < 0) idx = 0;
    const pillW = this.getBottomPillWidth();
    return idx * pillW;
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 1. 全屏沉浸式磨砂深色遮罩 (点击空白区域平滑收起)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.40)')
          .backdropBlur(15)
          .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          .onClick(() => {
            this.triggerHaptic();
            this.onClose();
          })

        // 2. 纯白大圆角抽屉面板 (参考图 2 高级 Flighty 质感)
        Column() {
          // 2.1 顶部药丸拖拽指示条
          Row()
            .width(36)
            .height(4)
            .borderRadius(2)
            .backgroundColor('#E2E8F0')
            .margin({ top: 10, bottom: 8 })

          // 2.2 头部信息栏
          Row() {
            Column({ space: 4 }) {
              Text('飞行外观')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')

              Text('定制专属航线光带与机尾喷气粒子，自由组合沉浸心流。')
                .fontSize(12)
                .fontColor('#64748B')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .padding({ right: 12 })

            // 右上角圆形关闭按钮 (顶部与大标题基准线水平对齐)
            Stack({ alignContent: Alignment.Center }) {
              Text('✕')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#64748B')
            }
            .width(30)
            .height(30)
            .borderRadius(15)
            .backgroundColor('#F1F5F9')
            .onClick(() => {
              this.triggerHaptic();
              this.onClose();
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 4, bottom: 12 })
          .alignItems(VerticalAlign.Top)

          // 2.3 顶部双 Tab 分段平滑滑动胶囊 (航线效果 | 巡航尾迹)
          Stack({ alignContent: Alignment.Start }) {
            // 2.3.1 滑动纯白浮雕卡片
            Row()
              .width(Math.max(10, (this.getTopTabWidth() - 6) / 2))
              .height(34)
              .borderRadius(10)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.08)', offsetY: 1 })
              .translate({ x: (this.activeTab === 'route' ? 0 : 1) * Math.max(10, (this.getTopTabWidth() - 6) / 2) })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })

            // 2.3.2 选项文字 Row
            Row() {
              // Tab 1: 航线效果
              Row() {
                Text('航线效果')
                  .fontSize(14)
                  .fontWeight(this.activeTab === 'route' ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.activeTab === 'route' ? '#0F172A' : '#64748B')
                  .animation({ duration: 200, curve: Curve.EaseOut })
              }
              .layoutWeight(1)
              .height(34)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.triggerHaptic();
                this.activeTab = 'route';
              })

              // Tab 2: 巡航尾迹
              Row() {
                Text('巡航尾迹')
                  .fontSize(14)
                  .fontWeight(this.activeTab === 'trail' ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.activeTab === 'trail' ? '#0F172A' : '#64748B')
                  .animation({ duration: 200, curve: Curve.EaseOut })
              }
              .layoutWeight(1)
              .height(34)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.triggerHaptic();
                this.activeTab = 'trail';
              })
            }
            .width('100%')
            .height(34)
          }
          .width('90%')
          .height(40)
          .padding(3)
          .borderRadius(12)
          .backgroundColor('#F1F5F9')
          .onAreaChange((_oldVal: Area, newVal: Area) => {
            const w = newVal.width as number;
            if (w > 0) {
              this.topTabWidth = w;
            }
          })
          .margin({ bottom: 14 })

          // 2.4 🌟 Hero 全景实时大预览视窗 (图2核心：大卡片深蓝视窗 + 实时预览标 + 样式名标签 + 右侧直飞飞机)
          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              // 2.4.1 深色夜空底板
              Row()
                .width('100%')
                .height('100%')
                .backgroundColor('#131C2E')

              // 2.4.2 全景动效 2D Canvas (动态渲染航线流光或尾迹粒子)
              HeroPreviewCanvas({
                activeTab: this.activeTab,
                routeId: this.currentRouteStyle,
                trailId: this.currentTrailId,
                planeOffsetX: $planeFloatingOffsetX,
                planeOffsetY: $planeFloatingOffsetY,
                planeTiltAngle: $planeTiltAngle
              })
                .width('100%')
                .height('100%')

              // 2.4.3 顶部标签与快捷还原栏 (左右对称对齐，高度严格一致为 24vp)
              Row() {
                // 左侧：「实时预览」标签
                Row() {
                  Text('实时预览')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#E2E8F0')
                }
                .height(24)
                .padding({ left: 8, right: 8 })
                .borderRadius(6)
                .backgroundColor('rgba(255, 255, 255, 0.12)')
                .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.20)' })
                .alignItems(VerticalAlign.Center)

                Blank()

                // 右侧：毛玻璃「✕ 默认」快捷还原按钮 (一键去除尾迹/航线光带)
                Row({ space: 4 }) {
                  Text('✕')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(!this.isAnyOptionSelected() ? '#38BDF8' : '#94A3B8')
                  Text('默认')
                    .fontSize(11)
                    .fontWeight(!this.isAnyOptionSelected() ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(!this.isAnyOptionSelected() ? '#38BDF8' : '#E2E8F0')
                }
                .height(24)
                .padding({ left: 8, right: 8 })
                .borderRadius(6)
                .backgroundColor(!this.isAnyOptionSelected() ? 'rgba(56, 189, 248, 0.22)' : 'rgba(255, 255, 255, 0.12)')
                .border({
                  width: 0.8,
                  color: !this.isAnyOptionSelected() ? 'rgba(56, 189, 248, 0.50)' : 'rgba(255, 255, 255, 0.20)'
                })
                .alignItems(VerticalAlign.Center)
                .animation({ duration: 200, curve: Curve.EaseOut })
                .onClick(() => {
                  this.triggerHaptic();
                  if (this.activeTab === 'route') {
                    this.currentRouteStyle = 'classic';
                    this.onSelectRoute('classic');
                    this.currentTrailId = 'none';
                    this.onSelectTrail('none');
                  } else {
                    this.currentTrailId = 'none';
                    this.onSelectTrail('none');
                    this.currentRouteStyle = 'classic';
                    this.onSelectRoute('classic');
                  }
                })
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 12 })
              .alignItems(VerticalAlign.Center)

              // 2.4.4 飞机巡航展示 (默认模式平滑回中，选择样式平滑飞至右侧黄金航行位)
              Image($r('app.media.ic_plane_topview'))
                .width(26)
                .height(26)
                .fillColor('#FFFFFF')
                .objectFit(ImageFit.Contain)
                .rotate({ angle: 90 + this.planeTiltAngle }) // ✈️ 水平巡航 + 间歇性微偏航角
                .position({ x: '100%', y: '50%' })
                .markAnchor({
                  x: this.getPlaneAnchorX(),
                  y: 13 - this.planeFloatingOffsetY
                })
                .animation({ duration: 450, curve: Curve.FastOutSlowIn })
            }
            .width('100%')
            .aspectRatio(2.35)
            .borderRadius(20)
            .clip(true)
            .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.18)', offsetY: 4 })
            .onAreaChange((_oldVal: Area, newVal: Area) => {
              const w = newVal.width as number;
              if (w > 0) {
                this.previewCardWidth = w;
              }
            })
          }
          .width('90%')
          .margin({ bottom: 16 })

          // 2.5 样式选择区小标题 (左对齐)
          Row() {
            Text(this.activeTab === 'route' ? '航线样式' : '尾迹样式')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
          }
          .width('90%')
          .justifyContent(FlexAlign.Start)
          .margin({ bottom: 8 })

          // 2.6 🌟 底部平滑滑动分段胶囊选择条 (如丝般顺滑的水平平移动画)
          Stack({ alignContent: Alignment.Start }) {
            // 2.6.1 智能平滑滑动纯白浮雕卡片
            Row()
              .width(this.getBottomPillWidth())
              .height(36)
              .borderRadius(10)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.08)', offsetY: 1 })
              .opacity(this.isAnyOptionSelected() ? 1 : 0)
              .translate({ x: this.getBottomPillOffset() })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })

            // 2.6.2 各选项文字 Row
            Row() {
              ForEach(this.activeTab === 'route' ? this.routeList : this.trailList, (item: VisualOptionItem) => {
                Row() {
                  Text(item.name)
                    .fontSize(13.5)
                    .fontWeight(this.isItemSelected(item.id) ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.isItemSelected(item.id) ? '#0F172A' : '#64748B')
                    .animation({ duration: 200, curve: Curve.EaseOut })
                }
                .layoutWeight(1)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.triggerHaptic();
                  if (this.activeTab === 'route') {
                    this.currentRouteStyle = item.id;
                    this.onSelectRoute(item.id);
                    // 🌟 严格二选一互斥：选航线风格时，自动将机尾尾迹设为“纯净无尾”
                    this.currentTrailId = 'none';
                    this.onSelectTrail('none');
                  } else {
                    this.currentTrailId = item.id;
                    this.onSelectTrail(item.id);
                    // 🌟 严格二选一互斥：选巡航尾迹时，自动将航线风格设为“经典航线”
                    this.currentRouteStyle = 'classic';
                    this.onSelectRoute('classic');
                  }
                })
              }, (item: VisualOptionItem) => item.id)
            }
            .width('100%')
            .height(36)
          }
          .width('90%')
          .padding(4)
          .borderRadius(14)
          .backgroundColor('#F1F5F9')
          .onAreaChange((_oldVal: Area, newVal: Area) => {
            const w = newVal.width as number;
            if (w > 0) {
              this.switcherBarWidth = w;
            }
          })
          .margin({ bottom: 14 })

          // 2.7 居中操作提示说明
          Text('点击样式即可实时预览')
            .fontSize(12)
            .fontColor('#94A3B8')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 8 })
        }
        .width('100%')
        .padding({ bottom: 24 })
        .backgroundColor('#FFFFFF')
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.16)', offsetY: -4 })
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 280, curve: Curve.FastOutSlowIn }))
      }
      .width('100%')
      .height('100%')
      .zIndex(999)
    }
  }

  private isItemSelected(id: string): boolean {
    if (this.activeTab === 'route') {
      return this.currentRouteStyle === id;
    } else {
      return this.currentTrailId === id;
    }
  }
}

interface CloudPuff {
  dx: number;
  dy: number;
  r: number;
}

interface PreviewCloud {
  x: number;
  y: number;
  scale: number;
  speed: number;
  alpha: number;
  puffs: CloudPuff[];
}

/**
 * 🌟 Hero 全景实时大预览 2D Canvas 画布组件
 * 支持航线流光与尾迹粒子在全景宽屏中流畅流淌消散
 */
@Component
struct HeroPreviewCanvas {
  @Prop activeTab: string = 'trail';
  @Prop @Watch('onStyleChanged') routeId: string = 'classic';
  @Prop @Watch('onStyleChanged') trailId: string = 'none';
  @Link planeOffsetX: number;
  @Link planeOffsetY: number;
  @Link planeTiltAngle: number;

  @State canvasWidth: number = 320;
  @State canvasHeight: number = 140;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private particles: TrailParticle[] = [];
  private frameCount: number = 0;
  private animSync?: displaySync.DisplaySync;
  private scrollOffset: number = 0;

  // ☁️ 动效大气层多层漂浮云朵系统
  private clouds: PreviewCloud[] = [];

  // 🌟 平滑动画过渡控制器
  private melodyStaffAlpha: number = 0.0;
  private currentRenderRouteId: string = 'classic';
  private prevRenderRouteId: string = '';
  private routeCrossFadeProgress: number = 1.0;

  // 🌟 间歇性自然巡航微漂移控制器 (隔一段时间随机忽上忽下忽左忽右微幅摆动)
  private targetDriftX: number = 0;
  private targetDriftY: number = 0;
  private targetDriftAngle: number = 0;
  private curDriftX: number = 0;
  private curDriftY: number = 0;
  private curDriftAngle: number = 0;
  private driftCooldownFrames: number = 180; // 初始平稳飞行 3 秒 (60FPS)
  private lastFrameTime: number = 0;

  aboutToAppear() {
    this.initClouds();
    this.currentRenderRouteId = this.routeId;
    this.reseedParticles();
    this.startLoop();
  }

  aboutToDisappear() {
    this.stopLoop();
  }

  /**
   * ☁️ 初始化天空高空多层流动云朵（真实俯视/卫星航拍视角：全向有机发散积云团 + 卷云丝带）
   */
  private initClouds() {
    // 1. 大型多裂片俯视积云团 (Aerial Cumulus Blob)
    const puffA: CloudPuff[] = [
      { dx: 0, dy: 0, r: 24 },
      { dx: -18, dy: -8, r: 18 }, { dx: 18, dy: -10, r: 17 },
      { dx: -28, dy: 6, r: 13 }, { dx: 28, dy: 4, r: 14 },
      { dx: -12, dy: 14, r: 16 }, { dx: 14, dy: 16, r: 17 },
      { dx: 0, dy: -16, r: 14 }, { dx: 38, dy: -4, r: 9 }, { dx: -38, dy: 2, r: 8 }
    ];

    // 2. 中型多瓣俯视流云 (Mid Aerial Drift Cloud)
    const puffB: CloudPuff[] = [
      { dx: 0, dy: 0, r: 20 },
      { dx: -16, dy: -6, r: 15 }, { dx: 17, dy: 5, r: 16 },
      { dx: -26, dy: 4, r: 11 }, { dx: 26, dy: -3, r: 12 },
      { dx: 6, dy: -12, r: 12 }, { dx: -6, dy: 12, r: 13 }
    ];

    // 3. 拉长羽状高空俯视卷云 (Wispy Cirrus Band)
    const puffC: CloudPuff[] = [
      { dx: 0, dy: 0, r: 16 },
      { dx: -20, dy: -3, r: 12 }, { dx: 20, dy: 2, r: 13 },
      { dx: -36, dy: -2, r: 8 }, { dx: 36, dy: 1, r: 9 },
      { dx: -10, dy: 7, r: 10 }, { dx: 12, dy: -6, r: 9 }
    ];

    // 4. 散落微型碎积云 (Small Fluffy Puff)
    const puffD: CloudPuff[] = [
      { dx: 0, dy: 0, r: 13 },
      { dx: -9, dy: -4, r: 9 }, { dx: 9, dy: 4, r: 10 },
      { dx: -4, dy: 7, r: 8 }, { dx: 5, dy: -6, r: 8 }
    ];

    this.clouds = [
      { x: 30, y: 26, scale: 0.95, speed: 0.35, alpha: 0.11, puffs: puffA },
      { x: 210, y: 32, scale: 0.72, speed: 0.22, alpha: 0.07, puffs: puffC },
      { x: 110, y: 115, scale: 1.10, speed: 0.42, alpha: 0.12, puffs: puffB },
      { x: 280, y: 122, scale: 0.80, speed: 0.28, alpha: 0.08, puffs: puffA },
      { x: 350, y: 22, scale: 0.65, speed: 0.20, alpha: 0.06, puffs: puffD },
      { x: 170, y: 72, scale: 0.60, speed: 0.18, alpha: 0.05, puffs: puffD },
      { x: -15, y: 88, scale: 0.85, speed: 0.30, alpha: 0.09, puffs: puffC }
    ];
  }

  private updateClouds() {
    for (let i = 0; i < this.clouds.length; i++) {
      const c = this.clouds[i];
      c.x -= (c.speed * 0.5); // 60FPS 对应匀速半步位移
      if (c.x < -90) {
        c.x = this.canvasWidth + 70 + (Math.random() * 60);
        if (i % 2 === 0) {
          c.y = 16 + Math.random() * 30;
        } else {
          c.y = 92 + Math.random() * 32;
        }
      }
    }
  }

  private onStyleChanged() {
    // 若当前无粒子且选中了有效尾迹，则快速补齐粒子
    if (this.particles.length === 0 && this.trailId !== 'none') {
      this.reseedParticles();
    }
    // 航线风格切换时触发平滑交叉渐变
    if (this.routeId !== this.currentRenderRouteId) {
      this.prevRenderRouteId = this.currentRenderRouteId;
      this.currentRenderRouteId = this.routeId;
      this.routeCrossFadeProgress = 0.0;
    }
  }

  private getPlaneAnchorOffset(): number {
    if (this.activeTab === 'route') {
      return (this.canvasWidth / 2);
    }
    if (this.trailId !== 'none') {
      return 98;
    }
    return (this.canvasWidth / 2);
  }

  private getPlaneCenterX(): number {
    return this.canvasWidth - this.getPlaneAnchorOffset() + this.curDriftX;
  }

  /**
   * ✈️ 机腹中点坐标：前后航线与尾迹的共同基准起点
   */
  /**
   * ✈️ 机腹中心点坐标：航线效果的起点位置 (位于机身正中腹部)
   */
  private getBellyX(): number {
    return this.getPlaneCenterX();
  }

  /**
   * 💨 机尾后部喷口坐标：巡航尾迹的起点位置 (位于机身尾部)
   */
  private getTailX(): number {
    return this.getPlaneCenterX() - 13;
  }

  /**
   * 🎯 机头前方坐标
   */
  private getNoseX(): number {
    return this.getPlaneCenterX() + 13;
  }

  /**
   * 🌟 预填充历史粒子，使粒子流立即丰满连贯且与大地图 100% 对齐
   */
  private reseedParticles() {
    this.particles = [];
    if (this.activeTab === 'route' || this.trailId === 'none') {
      return;
    }
    const tailX = this.getTailX();
    const centerY = this.canvasHeight / 2 + this.curDriftY;
    for (let f = 110; f >= 0; f--) {
      const newPs = TrailParticleRenderHelper.spawnParticlesForTrail(
        this.trailId,
        tailX,
        centerY,
        f,
        0,
        1
      );
      for (let i = 0; i < newPs.length; i++) {
        const p = newPs[i];
        p.life = Math.max(1, p.maxLife - f);
        this.particles.push(p);
      }
    }
  }

  private startLoop() {
    this.stopLoop();
    this.lastFrameTime = Date.now();
    this.animSync = displaySync.create();
    this.animSync.setExpectedFrameRateRange({
      expected: 60,
      min: 30,
      max: 60
    });
    this.animSync.on('frame', () => {
      const now = Date.now();
      const dt = this.lastFrameTime > 0 ? (now - this.lastFrameTime) : 16;
      this.lastFrameTime = now;

      // 🌟 前后台切换 / 休眠恢复自愈：若间隔大于 200ms，立即重置并补全整条航迹粒子
      if (dt > 200) {
        this.curDriftX = 0;
        this.curDriftY = 0;
        this.targetDriftX = 0;
        this.targetDriftY = 0;
        this.reseedParticles();
      }

      this.frameCount++;
      this.scrollOffset = (this.scrollOffset + 0.6) % 60;

      // ☁️ 更新云朵向左流动位移 (60FPS 丝滑流畅)
      this.updateClouds();

      // 🌟 五线谱平滑淡入淡出动效 (60FPS 柔和过渡)
      if (this.trailId === 'melody') {
        this.melodyStaffAlpha = Math.min(1.0, this.melodyStaffAlpha + 0.03);
      } else {
        this.melodyStaffAlpha = Math.max(0.0, this.melodyStaffAlpha - 0.03);
      }

      // 🌟 航线风格切换平滑交叉渐变 (60FPS 柔和过渡)
      if (this.routeCrossFadeProgress < 1.0) {
        this.routeCrossFadeProgress = Math.min(1.0, this.routeCrossFadeProgress + 0.035);
      }

      // 🌟 间歇性自然巡航微气流扰动漂移（隔一段时间产生随机 X/Y 微偏与仰俯角）
      if (this.driftCooldownFrames > 0) {
        this.driftCooldownFrames--;
      } else {
        if (Math.abs(this.targetDriftX) < 0.1 && Math.abs(this.targetDriftY) < 0.1) {
          // 当前处于平直航线中轴：触发一次随机气流微漂移 (X: ±8vp, Y: ±7vp, Angle: ±2.5°)
          this.targetDriftX = (Math.random() - 0.5) * 16.0;
          this.targetDriftY = (Math.random() - 0.5) * 14.0;
          this.targetDriftAngle = (this.targetDriftY > 0 ? 1 : -1) * (1.2 + Math.random() * 1.8);
          this.driftCooldownFrames = 90 + Math.floor(Math.random() * 70); // 漂移保持 1.5~2.5 秒 (60FPS)
        } else {
          // 当前处于漂移态：平稳返回中心基准航线
          this.targetDriftX = 0;
          this.targetDriftY = 0;
          this.targetDriftAngle = 0;
          this.driftCooldownFrames = 200 + Math.floor(Math.random() * 200); // 平稳巡航 3.5~6.5 秒 (60FPS)
        }
      }

      // 平滑指数插值 (Exponential Lerp at 60FPS)
      this.curDriftX += (this.targetDriftX - this.curDriftX) * 0.025;
      this.curDriftY += (this.targetDriftY - this.curDriftY) * 0.025;
      this.curDriftAngle += (this.targetDriftAngle - this.curDriftAngle) * 0.025;

      this.planeOffsetX = this.curDriftX;
      this.planeOffsetY = this.curDriftY;
      this.planeTiltAngle = this.curDriftAngle;

      this.spawnParticle();
      this.updateParticles();
      this.render();
    });
    this.animSync.start();
  }

  private stopLoop() {
    if (this.animSync) {
      try {
        this.animSync.stop();
      } catch (e) { }
      this.animSync = undefined;
    }
  }

  private spawnParticle() {
    if (this.activeTab === 'route' || this.trailId === 'none') {
      return;
    }
    const tailX = this.getTailX();
    const centerY = this.canvasHeight / 2 + this.curDriftY;
    const newPs = TrailParticleRenderHelper.spawnParticlesForTrail(
      this.trailId,
      tailX,
      centerY,
      this.frameCount,
      0,
      1
    );
    for (let i = 0; i < newPs.length; i++) {
      this.particles.push(newPs[i]);
    }
  }

  private updateParticles() {
    const tailX = this.getTailX();
    const centerY = this.canvasHeight / 2 + this.curDriftY;
    const trailLength = 260.0;

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life--;

      if (p.life <= 0) {
        this.particles.splice(i, 1);
        continue;
      }

      const progress = 1.0 - Math.max(0, p.life / p.maxLife);
      const lagRatio = Math.pow(progress, 0.92);
      const targetDist = lagRatio * trailLength;

      const sway = Math.sin(this.frameCount * p.swaySpeed + p.swayPhase) * p.swayAmp;
      const latOff = p.lateralOffset !== undefined ? p.lateralOffset : 0;
      const driftLat = p.driftLateral !== undefined ? p.driftLateral : 0;
      const totalLateral = latOff + progress * driftLat + sway;

      p.x = tailX - targetDist;
      p.y = centerY + totalLateral;
      p.rotation += p.vRot;
    }
  }

  private render() {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;
    const centerY = h / 2;
    const bellyX = this.getBellyX();
    const tailX = this.getTailX();

    ctx.clearRect(0, 0, w, h);

    // 1. ☁️ 首先在最底层绘制多层向左流淌的大气层云朵
    this.drawClouds(ctx);

    // 2. ✈️ 飞机前方（未飞行空域）：从机腹位置向前方贯穿绘制普通经典导航航线 (白色虚线 + 航路点 ◇)
    this.drawClassicRouteSegment(ctx, bellyX, w + 30, centerY);

    // 3. ✈️ 飞机后方（已飞行空域）：航线基底始终保留（从机腹 bellyX 向后延展）
    this.drawRoute(ctx, w, h, centerY, bellyX);

    // 4. 💫 巡航尾迹模式下：在航线基底之上叠加机尾喷气粒子 / 律动五线谱（从机尾 tailX 向后喷涌）
    if (this.activeTab === 'trail') {
      this.drawTrail(ctx, w, h, centerY, tailX);
    }
  }

  /**
   * ☁️ 绘制高空俯视多层流动云朵（外层柔和羽化 + 核心浓密雾层）
   */
  private drawClouds(ctx: CanvasRenderingContext2D) {
    for (let i = 0; i < this.clouds.length; i++) {
      const c = this.clouds[i];
      ctx.save();
      ctx.translate(c.x, c.y);
      ctx.scale(c.scale, c.scale);
      ctx.fillStyle = '#FFFFFF';

      // 1. 俯视视角：外围柔和透光羽化云体
      ctx.globalAlpha = c.alpha;
      ctx.beginPath();
      for (let k = 0; k < c.puffs.length; k++) {
        const p = c.puffs[k];
        ctx.moveTo(p.dx + p.r, p.dy);
        ctx.arc(p.dx, p.dy, p.r, 0, Math.PI * 2);
      }
      ctx.fill();

      // 2. 俯视视角：中心浓密云核层 (增添万米高空俯瞰的厚度与光感层次)
      ctx.globalAlpha = c.alpha * 0.45;
      ctx.beginPath();
      for (let k = 0; k < Math.min(3, c.puffs.length); k++) {
        const p = c.puffs[k];
        ctx.moveTo(p.dx + p.r * 0.65, p.dy);
        ctx.arc(p.dx, p.dy, p.r * 0.65, 0, Math.PI * 2);
      }
      ctx.fill();

      ctx.restore();
    }
  }

  /**
   * ✈️ 渲染航线效果 (笔直水平多色流光光带全屏贯穿向左平滑流淌，支持交叉平滑过渡)
   */
  private drawRoute(ctx: CanvasRenderingContext2D, w: number, h: number, centerY: number, tailX: number) {
    if (this.routeCrossFadeProgress < 1.0 && this.prevRenderRouteId) {
      this.drawSingleRoute(ctx, w, h, centerY, tailX, this.prevRenderRouteId, 1.0 - this.routeCrossFadeProgress);
      this.drawSingleRoute(ctx, w, h, centerY, tailX, this.currentRenderRouteId, this.routeCrossFadeProgress);
    } else {
      this.drawSingleRoute(ctx, w, h, centerY, tailX, this.currentRenderRouteId, 1.0);
    }
  }

  private drawSingleRoute(ctx: CanvasRenderingContext2D, w: number, h: number, centerY: number, tailX: number, routeStyle: string, globalAlpha: number) {
    const startX = tailX;
    const endX = -10;

    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1.0, globalAlpha));

    if (routeStyle === 'rainbow') {
      // 🌈 6 色平行彩虹光带 (从机尾延伸至后方)
      const colors = ['#AF52DE', '#0A84FF', '#34C759', '#FFCC00', '#FF9500', '#FF3B30'];
      for (let i = 0; i < colors.length; i++) {
        const baseLat = (i - 2.5) * 2.5;
        const curY = centerY + baseLat;

        ctx.beginPath();
        ctx.strokeStyle = colors[i];
        ctx.lineWidth = 2.6;
        ctx.lineCap = 'round';
        ctx.moveTo(startX, curY);
        ctx.lineTo(endX, curY);
        ctx.stroke();
      }
    } else if (routeStyle === 'aurora') {
      // ✨ 极光天际：青翠与紫蓝平行光带
      const colors = ['#00FF88', '#00F5D4', '#00BBF9', '#7209B7'];
      for (let i = 0; i < colors.length; i++) {
        const baseLat = (i - 1.5) * 3.0;
        const curY = centerY + baseLat;

        ctx.beginPath();
        ctx.strokeStyle = colors[i];
        ctx.lineWidth = 3.2;
        ctx.lineCap = 'round';
        ctx.moveTo(startX, curY);
        ctx.lineTo(endX, curY);
        ctx.stroke();
      }
    } else if (routeStyle === 'ocean') {
      // 🌊 蔚蓝天路：海洋透光平行流线
      const colors = ['rgba(56, 189, 248, 0.7)', '#0284C7', 'rgba(3, 105, 161, 0.7)'];
      for (let i = 0; i < colors.length; i++) {
        const baseLat = (i - 1.0) * 3.8;
        const curY = centerY + baseLat;

        ctx.beginPath();
        ctx.strokeStyle = colors[i];
        ctx.lineWidth = i === 1 ? 3.6 : 2.2;
        ctx.lineCap = 'round';
        ctx.moveTo(startX, curY);
        ctx.lineTo(endX, curY);
        ctx.stroke();
      }
    } else if (routeStyle === 'blaze') {
      // 🔥 炽热航路：暖阳橙红平行流光
      const colors = ['rgba(251, 146, 60, 0.7)', '#F97316', 'rgba(234, 88, 12, 0.7)'];
      for (let i = 0; i < colors.length; i++) {
        const baseLat = (i - 1.0) * 3.8;
        const curY = centerY + baseLat;

        ctx.beginPath();
        ctx.strokeStyle = colors[i];
        ctx.lineWidth = i === 1 ? 3.6 : 2.2;
        ctx.lineCap = 'round';
        ctx.moveTo(startX, curY);
        ctx.lineTo(endX, curY);
        ctx.stroke();
      }
    } else {
      this.drawClassicRouteSegment(ctx, -30, tailX, centerY);
    }
    ctx.restore();
  }

  /**
   * ✈️ 经典普通航线片段：中心笔直水平导航虚线与航路点 (60FPS 精确计算平滑向左匀速流动)
   */
  private drawClassicRouteSegment(ctx: CanvasRenderingContext2D, minX: number, maxX: number, centerY: number) {
    if (minX >= maxX) return;

    ctx.save();
    const dashLen = 10;
    const gapLen = 10;
    const period = dashLen + gapLen; // 20vp
    const offset = (this.frameCount * 0.8) % period;

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.75)';
    ctx.lineWidth = 2.0;
    ctx.lineCap = 'round';

    for (let x = maxX + period; x > minX - period; x -= period) {
      const segStart = x - offset;
      const segEnd = segStart - dashLen;
      if (segStart > minX && segEnd < maxX) {
        const actualStart = Math.min(maxX, segStart);
        const actualEnd = Math.max(minX, segEnd);
        if (actualStart > actualEnd) {
          ctx.beginPath();
          ctx.moveTo(actualStart, centerY);
          ctx.lineTo(actualEnd, centerY);
          ctx.stroke();
        }
      }
    }

    // 航路点 ◇ 随虚线同步平直向左匀速流动
    const diamondPeriod = 70;
    const dOffset = (this.frameCount * 0.8) % diamondPeriod;
    ctx.fillStyle = 'rgba(255, 255, 255, 0.90)';
    ctx.font = 'bold 11px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (let x = maxX + diamondPeriod; x > minX - diamondPeriod; x -= diamondPeriod) {
      const dx = x - dOffset;
      if (dx <= maxX && dx >= minX) {
        ctx.fillText('◇', dx, centerY);
      }
    }
    ctx.restore();
  }

  private drawTrail(ctx: CanvasRenderingContext2D, w: number, h: number, centerY: number, startX: number) {
    // 1. 律动音符模式下绘制 5 条波动的彩色五线谱
    TrailParticleRenderHelper.renderMelodyStaff(ctx, startX, centerY, this.frameCount, this.melodyStaffAlpha, 260.0);

    

    // 绘制所有浮动粒子 (依据粒子自身的 trailType 渲染，新旧粒子自然推移流动)
    const tailX = this.getTailX();
    const totalDist = tailX + 30;

    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      const progress = 1.0 - Math.max(0, p.life / p.maxLife);

      if (p.trailType === 'bubbles') {
        TrailParticleRenderHelper.renderBubbleParticle(ctx, p, progress, this.frameCount);
      } else if (p.trailType === 'stardust') {
        TrailParticleRenderHelper.renderStardustParticle(ctx, p, progress, this.frameCount);
      } else if (p.trailType === 'melody') {
        TrailParticleRenderHelper.renderMelodyParticle(ctx, p, progress, this.frameCount);
      } else if (p.trailType === 'contrail') {
        TrailParticleRenderHelper.renderContrailParticle(ctx, p, progress);
      }
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onAreaChange((_oldVal: Area, newVal: Area) => {
        const newW = newVal.width as number;
        const newH = newVal.height as number;
        if (newW > 0 && newH > 0 && (newW !== this.canvasWidth || newH !== this.canvasHeight)) {
          this.canvasWidth = newW;
          this.canvasHeight = newH;
          this.reseedParticles();
          this.render();
        }
      })
      .onReady(() => {
        this.reseedParticles();
        this.render();
      })
  }
}
