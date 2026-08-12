/**
 * 🎯 100% 纯代码像素级还原地图标记 (对称平衡中轴，跑道中心锁定为组件 50% 轴心)
 * 双跑道线: 2vp 宽、6vp 高、0.9 透明度，出发地为琥珀金 #FDE68A
 */
@Builder
export function CustomAirportMarkerBuilder(
  code: string,
  name: string,
  distanceKm: number,
  isSelected: boolean,
  isOrigin: boolean = false
) {
  Row({ space: 5 }) {
    // 0. 左侧隐形平衡垫片 (保证跑道胶囊中心线精确位于整张离屏快照图片的 50.0% 正中央中轴)
    Row()
      .width(105)

    // 1. 中间跑道胶囊与小飞机标志 (位于组件 50% 物理正轴心)
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row()
          .width(2)
          .height(6)
          .backgroundColor(isOrigin ? '#FDE68A' : '#FFFFFF')
          .borderRadius(1)
          .opacity(isOrigin ? 0.95 : 0.9)

        Blank()

        Row()
          .width(2)
          .height(6)
          .backgroundColor(isOrigin ? '#FDE68A' : '#FFFFFF')
          .borderRadius(1)
          .opacity(isOrigin ? 0.95 : 0.9)
      }
      .width(18)
      .height(42)
      .padding({ top: 4, bottom: 4 })
      .alignItems(HorizontalAlign.Center)

      Image($r('app.media.ic_plane_topview'))
        .width(13)
        .height(13)
        .objectFit(ImageFit.Contain)
        .fillColor(isOrigin ? '#FEF3C7' : (isSelected ? '#FFB4A9' : '#FFFFFF'))
    }
    .width(18)
    .height(42)
    .backgroundColor(isOrigin ? '#1E293B' : (isSelected ? '#451717' : '#0B1726'))
    .borderRadius(9)
    .border({
      width: 1.5,
      color: isOrigin ? '#F59E0B' : (isSelected ? '#E05A47' : '#317393')
    })
    .shadow({
      radius: 4,
      color: isOrigin ? 'rgba(245, 158, 11, 0.4)' : (isSelected ? 'rgba(224, 90, 71, 0.35)' : 'rgba(11, 23, 38, 0.5)'),
      offsetY: 1
    })

    // 2. 右侧三行文字层次 (1:1 区分出发地琥珀金、目的地珊瑚红与候选冰白)
    Column({ space: 0.5 }) {
      Text(code)
        .fontSize(14)
        .fontWeight(FontWeight.Bolder)
        .fontColor(isOrigin ? '#F59E0B' : (isSelected ? '#F06553' : '#FFFFFF'))
        .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })

      Text(name.endsWith('机场') ? name : `${name}机场`)
        .fontSize(11.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textShadow({ radius: 3, color: '#000000', offsetX: 1, offsetY: 1 })

      Text(isOrigin
        ? '出发机场'
        : (isSelected
          ? (distanceKm > 0 ? `目的地 · ${Math.round(distanceKm)}km` : '目的地')
          : (distanceKm > 0 ? `候选航线 · ${Math.round(distanceKm)}km` : '候选航线')))
        .fontSize(9.5)
        .fontWeight(FontWeight.Regular)
        .fontColor(isOrigin ? '#FEF3C7' : (isSelected ? '#FFB4A9' : 'rgba(255, 255, 255, 0.72)'))
        .textShadow({ radius: 2, color: '#000000', offsetX: 1, offsetY: 1 })
    }
    .width(105)
    .alignItems(HorizontalAlign.Start)
  }
  .width(238)
  .height(46)
  .justifyContent(FlexAlign.Center)
}
