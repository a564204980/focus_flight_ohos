/**
 * Antigravity IDE / TypeScript Language Server 特效类型补充声明
 * 用于为 @kit.MapKit 及原生 Kit 模块提供 IDE 代码高亮与智能感知支持
 */

declare module '@kit.MapKit' {
  export namespace mapCommon {
    export interface LatLng {
      latitude: number;
      longitude: number;
    }
    export enum MapType {
      STANDARD = 0,
      SATELLITE = 1,
      TERRAIN = 2
    }
    export enum DayNightMode {
      DAY = 0,
      NIGHT = 1
    }
    export enum PatternItemType {
      DASH = 0,
      GAP = 1
    }
    export interface PatternItem {
      type: PatternItemType;
      length: number;
    }
    export interface PolygonOptions {
      points: LatLng[];
      fillColor?: number;
      strokeColor?: number;
      strokeWidth?: number;
    }
    export interface PolylineOptions {
      points: LatLng[];
      width?: number;
      color?: number;
      patterns?: PatternItem[];
    }
    export interface MarkerOptions {
      position: LatLng;
      icon?: any;
      anchorU?: number;
      anchorV?: number;
      flat?: boolean;
      rotation?: number;
      clickable?: boolean;
      zIndex?: number;
    }
    export interface CameraPosition {
      target?: LatLng;
      zoom?: number;
      bearing?: number;
      tilt?: number;
    }
    export interface MapOptions {
      mapType?: MapType;
      position?: CameraPosition;
      zoomControlsEnabled?: boolean;
      compassControlsEnabled?: boolean;
      rotateGesturesEnabled?: boolean;
      zoomGesturesEnabled?: boolean;
      scrollGesturesEnabled?: boolean;
      tiltGesturesEnabled?: boolean;
    }
  }

  export namespace map {
    export class Polyline {
      setPatterns(patterns: mapCommon.PatternItem[]): void;
      setWidth(width: number): void;
      setColor(color: number): void;
      setVisible(visible: boolean): void;
      remove(): void;
    }
    export class Marker {
      setPosition(position: mapCommon.LatLng): void;
      setRotation(rotation: number): void;
      setZIndex(zIndex: number): void;
      setFlat(flat: boolean): void;
      setAlpha(alpha: number): void;
      setClickable(clickable: boolean): void;
      setVisible(visible: boolean): void;
      setIcon(icon: any): void;
      remove(): void;
    }
    export class TranslateAnimation {
      constructor(target: mapCommon.LatLng);
      setDuration(duration: number): void;
    }
    export function newCameraPosition(options: mapCommon.CameraPosition): mapCommon.CameraPosition;
    export class MapComponentController {
      addPolygon(options: mapCommon.PolygonOptions): Promise<void>;
      addPolyline(options: mapCommon.PolylineOptions): Promise<object>;
      addMarker(options: mapCommon.MarkerOptions): Promise<Marker>;
      moveCamera(update: mapCommon.CameraPosition): void;
      animateCamera(update: mapCommon.CameraPosition, duration?: number): void;
      getCameraPosition(): mapCommon.CameraPosition;
      setMapType(type: mapCommon.MapType): void;
      setDayNightMode(mode: mapCommon.DayNightMode): void;
      on(type: string, callback: any): void;
    }
  }
}
