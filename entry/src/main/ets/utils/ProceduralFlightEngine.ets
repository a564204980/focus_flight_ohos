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

import { mapCommon } from '@kit.MapKit';
import { ctuAirportConfig } from '../models/airports/ctu';
import {
  generateGreatCirclePoints,
  generateCubicBezierPoints,
  chaikinSmoothPath,
  LatLngPoint,
  interpolateLatLng
} from './GeodesicUtils';

const CTU_RUNWAY_BEARING = 202.5; // 成都双流跑道朝向
const EARTH_RADIUS_KM = 6371.0;   // 地球平均半径 (KM)
const CRUISE_SPEED_KMH = 800.0;   // 民航标准平流层巡航速度 (KM/H)
const CRUISE_SPEED_KM_PER_SEC = CRUISE_SPEED_KMH / 3600.0; // 约 0.222 KM/S

/**
 * ProceduralFlightEngine.ets
 * 漫游模式核心引擎：基于超低频连续气流噪声的大圆程序化航迹生成与地理向心导航系统
 */
export class ProceduralFlightEngine {
  /**
   * 🌊 极轻量 1D 平滑渐变噪声 (Smooth Gradient Noise)
   * 输出范围 [-1.0, 1.0]，具备 C2 连续性，导数平滑无尖峰
   */
  private static smoothNoise1D(t: number, seed: number = 42): number {
    const x = t + seed * 137.17;
    const x0 = Math.floor(x);
    const x1 = x0 + 1;
    const f = x - x0;

    // 五次平滑缓动函数 (Quintic Smoother: 6t^5 - 15t^4 + 10t^3)
    const smoothT = f * f * f * (f * (f * 6 - 15) + 10);

    // 伪随机伪梯度计算
    const grad0 = Math.sin(x0 * 12.9898 + seed * 78.233) * 43758.5453;
    const g0 = (grad0 - Math.floor(grad0)) * 2 - 1;

    const grad1 = Math.sin(x1 * 12.9898 + seed * 78.233) * 43758.5453;
    const g1 = (grad1 - Math.floor(grad1)) * 2 - 1;

    const n0 = g0 * f;
    const n1 = g1 * (f - 1);

    return n0 + (n1 - n0) * smoothT;
  }

  /**
   * 🌐 大圆球面正向航位推算 (Great-Circle Dead Reckoning)
   * @param current 当前经纬度
   * @param bearingDeg 当前航向角 (0°~360°)
   * @param distanceKm 推进距离 (公里)
   */
  public static stepGreatCircle(current: mapCommon.LatLng, bearingDeg: number, distanceKm: number): mapCommon.LatLng {
    const rad = Math.PI / 180;
    const lat1 = current.latitude * rad;
    const lon1 = current.longitude * rad;
    const brng = bearingDeg * rad;
    const dR = distanceKm / EARTH_RADIUS_KM;

    const lat2 = Math.asin(
      Math.sin(lat1) * Math.cos(dR) +
      Math.cos(lat1) * Math.sin(dR) * Math.cos(brng)
    );

    const lon2 = lon1 + Math.atan2(
      Math.sin(brng) * Math.sin(dR) * Math.cos(lat1),
      Math.cos(dR) - Math.sin(lat1) * Math.sin(lat2)
    );

    return {
      latitude: lat2 / rad,
      longitude: lon2 / rad
    };
  }

  /**
   * 🧭 柔性地理向心力矩 (Geographic Soft Repulsion Field)
   * 当飞机接近大陆边缘或极高纬度时，施加温柔的向心偏角，确保飞机永远在辽阔大地上空漫游
   */
  public static calculateRepulsionAngle(lat: number, lon: number): number {
    let deltaAngle = 0;

    // 纬度边界保护 (北纬 18° ~ 45°)
    if (lat > 42.0) {
      const weight = Math.min(1.0, (lat - 42.0) / 4.0);
      deltaAngle += weight * 35.0; // 偏南转向
    } else if (lat < 20.0) {
      const weight = Math.min(1.0, (20.0 - lat) / 4.0);
      deltaAngle -= weight * 35.0; // 偏北转向
    }

    // 经度边界保护 (东经 90° ~ 124°)
    if (lon > 122.0) {
      const weight = Math.min(1.0, (lon - 122.0) / 4.0);
      deltaAngle += weight * 30.0; // 向西偏转
    } else if (lon < 92.0) {
      const weight = Math.min(1.0, (92.0 - lon) / 4.0);
      deltaAngle -= weight * 30.0; // 向东偏转
    }

    return deltaAngle;
  }

  /**
   * ✈️ 计算给定时刻下的平流层平滑目标航向角
   * @param elapsedSec 相对起飞的时间（秒）
   * @param lat 当前纬度
   * @param lon 当前经度
   * @param seed 随机漫游种子
   */
  public static getProceduralHeading(elapsedSec: number, lat: number, lon: number, seed: number = 42): number {
    // 1. 低频主气流波动 (周期约 7~10 分钟一个优美大弯)
    const lowFreq = ProceduralFlightEngine.smoothNoise1D(elapsedSec * 0.0018, seed);
    // 2. 超低频次级气流微扰 (周期约 3~5 分钟)
    const midFreq = ProceduralFlightEngine.smoothNoise1D(elapsedSec * 0.0045, seed + 101);

    // 基础航向：从起飞 202.5° 逐渐过渡为主巡航航向基准 (如东北朝向 045° ~ 065°)
    const baseHeading = 55.0;

    // 复合气流偏航摆幅 (±40°)
    const airflowYaw = lowFreq * 32.0 + midFreq * 12.0;

    // 柔性地理向心修正
    const repulsion = ProceduralFlightEngine.calculateRepulsionAngle(lat, lon);

    const targetHeading = (baseHeading + airflowYaw + repulsion + 360) % 360;
    return targetHeading;
  }

  /**
   * 🚀 生成从起飞开始的完整平滑程序化漫游航迹点集 (单次专注全程高密度样条)
   * @param totalDurationSec 规划航程总时长（秒，默认 12 小时无尽巡航 43200s）
   * @param seed 漫游航迹种子 (每次起飞赋予不同种子，产生独一无二的航线)
   */
  public static generateRoamingTrajectory(totalDurationSec: number = 43200, seed: number = Date.now() % 10000): mapCommon.LatLng[] {
    const ctuStart = ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
    const ctuEnd = ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };

    // 1. 跑道滑跑拉升段 (0 ~ 30s)
    const turnStartPoint = interpolateLatLng(ctuStart, ctuEnd, 0.65);
    const taxiSegment: mapCommon.LatLng[] = generateGreatCirclePoints(ctuStart, turnStartPoint, 25);

    // 2. 离场平滑切线转弯段 (30s ~ 90s)
    const c0 = interpolateLatLng(ctuStart, ctuEnd, 2.2);

    // 巡航起始点 (位于双流南侧约 22km 处)
    const cruiseStartPos = ProceduralFlightEngine.stepGreatCircle(turnStartPoint, CTU_RUNWAY_BEARING, 22.0);
    const c1 = interpolateLatLng(cruiseStartPos, { latitude: ctuStart.latitude, longitude: ctuStart.longitude }, 0.5);
    const departureArc: mapCommon.LatLng[] = generateCubicBezierPoints(turnStartPoint, c0, c1, cruiseStartPos, 120);

    // 3. 平流层程序化自然气流无尽巡航段 (90s ~ totalDurationSec)
    const cruisePoints: mapCommon.LatLng[] = [cruiseStartPos];
    let currentPos = cruiseStartPos;
    let currentHeading = CTU_RUNWAY_BEARING;

    // 步长：每 6 秒计算一个航路控制点 (约 1.33 km 间隔)
    const STEP_SEC = 6;
    const totalSteps = Math.floor((totalDurationSec - 90) / STEP_SEC);

    for (let step = 1; step <= totalSteps; step++) {
      const elapsedSec = 90 + step * STEP_SEC;
      const targetHeading = ProceduralFlightEngine.getProceduralHeading(elapsedSec, currentPos.latitude, currentPos.longitude, seed);

      // 航向平滑指数滤波 (最大转向率限制在 0.35°/s，避免任何突兀转向)
      let headingDiff = targetHeading - currentHeading;
      while (headingDiff > 180) headingDiff -= 360;
      while (headingDiff < -180) headingDiff += 360;

      const maxTurnThisStep = 0.35 * STEP_SEC;
      const clampedTurn = Math.max(-maxTurnThisStep, Math.min(maxTurnThisStep, headingDiff * 0.15));
      currentHeading = (currentHeading + clampedTurn + 360) % 360;

      const stepDistKm = CRUISE_SPEED_KM_PER_SEC * STEP_SEC;
      currentPos = ProceduralFlightEngine.stepGreatCircle(currentPos, currentHeading, stepDistKm);
      cruisePoints.push(currentPos);
    }

    const rawPoints = taxiSegment
      .concat(departureArc.slice(1))
      .concat(cruisePoints.slice(1));

    // 使用 Chaikin 算法平滑曲线消除任何微小折角
    return chaikinSmoothPath(rawPoints, 1);
  }

  /**
   * 🔮 生成前方 15 分钟（约 200km）的动态微光引导航向线
   */
  public static generateForecastHorizonPoints(
    allTrajectoryPoints: mapCommon.LatLng[],
    currentIndex: number,
    forecastPointsCount: number = 80
  ): mapCommon.LatLng[] {
    if (!allTrajectoryPoints || allTrajectoryPoints.length === 0) {
      return [];
    }
    const startIdx = Math.max(0, Math.min(allTrajectoryPoints.length - 1, Math.floor(currentIndex)));
    const endIdx = Math.min(allTrajectoryPoints.length, startIdx + forecastPointsCount);
    return allTrajectoryPoints.slice(startIdx, endIdx);
  }
}
