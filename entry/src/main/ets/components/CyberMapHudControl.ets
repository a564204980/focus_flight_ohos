import { mapCommon } from '@kit.MapKit';

/**
 * CyberMapHudControl.ets
 * 右上角 Cyber HUD 双维度控制组：缩放 + 地图角度微调 + 飞机 Marker 角度微调 + 矢量/卫星图层切换
 */

@Component
export struct CyberMapHudControl {
  @StorageProp('hudZoomLevel') currentZoomLevel: number = 17.2;
  @StorageProp('hudMapBearing') currentMapBearing: number = 158;
  @StorageProp('hudPlaneRotation') planeMarkerRotation: number = 0;
  @Prop currentMapType: mapCommon.MapType = mapCommon.MapType.STANDARD;

  onTweakMapBearing?: (deltaDeg: number) => void;
  onRotateMapNextAngle?: () => void;
  onTweakMarkerRotation?: (deltaDeg: number) => void;
  onToggleMapTypeMode?: () => void;

  build() {
    Row({ space: 6 }) {
      // 缩放倍率
      Row({ space: 4 }) {
        Text('🔍').fontSize(11)
        Text(`${this.currentZoomLevel.toFixed(1)}x`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#38BDF8')
      }
      .padding({ left: 9, right: 10, top: 7, bottom: 7 })
      .backgroundColor('rgba(10, 15, 26, 0.85)')
      .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })

      // 矢量 / 卫星 / 地形 模式切换按钮
      Row({ space: 3 }) {
        Text(
          this.currentMapType === mapCommon.MapType.STANDARD ? '🗺️ 矢量' :
          this.currentMapType === mapCommon.MapType.SATELLITE ? '🛰️ 卫星' : '⛰️ 地形'
        )
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(
            this.currentMapType === mapCommon.MapType.STANDARD ? '#4ADE80' :
            this.currentMapType === mapCommon.MapType.SATELLITE ? '#38BDF8' : '#F59E0B'
          )
      }
      .padding({ left: 9, right: 11, top: 7, bottom: 7 })
      .backgroundColor('rgba(10, 15, 26, 0.85)')
      .border({
        width: 1,
        color: this.currentMapType === mapCommon.MapType.STANDARD ? 'rgba(74, 222, 128, 0.4)' :
               this.currentMapType === mapCommon.MapType.SATELLITE ? 'rgba(56, 189, 248, 0.4)' : 'rgba(245, 158, 11, 0.4)',
        radius: 18
      })
      .onClick(() => {
        if (this.onToggleMapTypeMode) {
          this.onToggleMapTypeMode();
        }
      })
    }
  }
}
