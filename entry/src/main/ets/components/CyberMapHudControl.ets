import { mapCommon } from '@kit.MapKit';

/**
 * CyberMapHudControl.ets
 * 右上角 Cyber HUD 双维度控制组：缩放 + 地图角度微调 + 飞机 Marker 角度微调 + 矢量/卫星图层切换
 */

@Component
export struct CyberMapHudControl {
  @Prop currentZoomLevel: number = 17.2;
  @Prop currentMapBearing: number = 158;
  @Prop planeMarkerRotation: number = 0;
  @Prop currentMapType: mapCommon.MapType = mapCommon.MapType.STANDARD;

  onTweakMapBearing?: (deltaDeg: number) => void;
  onRotateMapNextAngle?: () => void;
  onTweakMarkerRotation?: (deltaDeg: number) => void;
  onToggleMapTypeMode?: () => void;

  build() {
    Column({ space: 6 }) {
      // 第一排：地图视角控制 (缩放倍率 + 地图角度微调 + 90°旋转 + 矢量/卫星切换)
      Row({ space: 6 }) {
        // 缩放
        Row({ space: 4 }) {
          Text('🔍').fontSize(11)
          Text(`${this.currentZoomLevel.toFixed(1)}x`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
        }
        .padding({ left: 8, right: 9, top: 7, bottom: 7 })
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })

        // 地图视角角度与微调
        Row({ space: 3 }) {
          Text('🗺️').fontSize(11)
          Text(`${Math.round(this.currentMapBearing)}°`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
          Text('-1°')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .backgroundColor('rgba(255, 255, 255, 0.18)')
            .borderRadius(6)
            .onClick(() => {
              if (this.onTweakMapBearing) {
                this.onTweakMapBearing(-1);
              }
            })
          Text('+1°')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .backgroundColor('rgba(255, 255, 255, 0.18)')
            .borderRadius(6)
            .onClick(() => {
              if (this.onTweakMapBearing) {
                this.onTweakMapBearing(1);
              }
            })
        }
        .padding({ left: 7, right: 7, top: 7, bottom: 7 })
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })

        // 地图 90° 旋转
        Row({ space: 3 }) {
          Text('🧭').fontSize(11)
          Text('旋转')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .padding({ left: 8, right: 10, top: 7, bottom: 7 })
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.25)', radius: 18 })
        .onClick(() => {
          if (this.onRotateMapNextAngle) {
            this.onRotateMapNextAngle();
          }
        })

        // 矢量 / 卫星模式切换按钮
        Row({ space: 3 }) {
          Text(this.currentMapType === mapCommon.MapType.STANDARD ? '🗺️ 矢量' : '🛰️ 卫星')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapType === mapCommon.MapType.STANDARD ? '#4ADE80' : '#38BDF8')
        }
        .padding({ left: 8, right: 10, top: 7, bottom: 7 })
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({
          width: 1,
          color: this.currentMapType === mapCommon.MapType.STANDARD ? 'rgba(74, 222, 128, 0.4)' : 'rgba(56, 189, 248, 0.4)',
          radius: 18
        })
        .onClick(() => {
          if (this.onToggleMapTypeMode) {
            this.onToggleMapTypeMode();
          }
        })
      }

      // 第二排：飞机 Marker 点标记角度独立微调与控制组
      Row({ space: 6 }) {
        Row({ space: 4 }) {
          Text('✈️').fontSize(11)
          Text(`飞机: ${this.planeMarkerRotation}°`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4ADE80')

          Text('-1°')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('rgba(255, 255, 255, 0.18)')
            .borderRadius(8)
            .margin({ left: 4 })
            .onClick(() => {
              if (this.onTweakMarkerRotation) {
                this.onTweakMarkerRotation(-1);
              }
            })

          Text('+1°')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('rgba(255, 255, 255, 0.18)')
            .borderRadius(8)
            .onClick(() => {
              if (this.onTweakMarkerRotation) {
                this.onTweakMarkerRotation(1);
              }
            })

          Text('-90°')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
            .padding({ left: 5, right: 5, top: 3, bottom: 3 })
            .backgroundColor('rgba(56, 189, 248, 0.2)')
            .borderRadius(8)
            .onClick(() => {
              if (this.onTweakMarkerRotation) {
                this.onTweakMarkerRotation(-90);
              }
            })

          Text('+90°')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
            .padding({ left: 5, right: 5, top: 3, bottom: 3 })
            .backgroundColor('rgba(56, 189, 248, 0.2)')
            .borderRadius(8)
            .onClick(() => {
              if (this.onTweakMarkerRotation) {
                this.onTweakMarkerRotation(90);
              }
            })
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(74, 222, 128, 0.35)', radius: 18 })
      }
    }
    .alignItems(HorizontalAlign.End)
  }
}
