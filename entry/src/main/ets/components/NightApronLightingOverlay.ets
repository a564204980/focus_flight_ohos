/**
 * NightApronLightingOverlay.ets
 * 夜间模式已移除，保留空壳以兼容现有 import
 */

@Component
export struct TaxiwayGroundLightsOverlay {
  @Prop isMapBackgroundVisible: boolean = false;

  build() {
  }
}

@Component
export struct NightApronLightingOverlay {
  @Prop isMapBackgroundVisible: boolean = false;
  @Prop planeX: number = 0;
  @Prop planeY: number = -45;
  @Prop planeScale: number = 1.0;
  @Prop planeRotate: number = 0;

  build() {
  }
}
