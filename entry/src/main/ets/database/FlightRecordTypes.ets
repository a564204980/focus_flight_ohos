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

/**
 * 航班历史记录日期筛选器
 */
export interface FlightRecordDateFilter {
  type: 'all' | 'year' | 'month' | 'day';
  year?: number;
  month?: number; // 1 ~ 12
  day?: number;   // 1 ~ 31
}

/**
 * 单条航班执飞历史记录
 */
export interface FlightRecordItem {
  id: string;
  flightNo: string;
  originCode: string;
  destCode: string;
  taskTitle: string;
  durationMin: number;
  actualDurationMin: number;
  distanceKm: number;
  status: 'completed' | 'aborted';
  seatId: string;
  startTime: number;
  endTime: number;
  eventsJson: string;
}

/**
 * 宏观飞行专注统计总览
 */
export interface FlightStatsSummary {
  totalFlights: number; // 只有飞到终点 (status = 'completed') 才算完成专注次数
  totalMinutes: number;
  totalDistanceKm: number;
  uniqueDestinationsCount: number;
  currentStreakDays: number;
  shortHaulCount: number;
  longHaulCount: number;
  abortedFlightsCount: number; // 只要没有飞到终点算被打断的次数
  avgDistractedMin: number; // 平均在第几分钟分心迫降
}

/**
 * 最严重中途分心/迫降航程记录
 */
export interface WorstDelayRecord {
  durationMin: number;
  taskTitle: string;
  reason: string;
}

/**
 * 分页航班历史记录返回包
 */
export interface PagedFlightRecordsResult {
  records: FlightRecordItem[];
  totalCount: number;
  hasMore: boolean;
}

/**
 * 专注与准点表现分类统计
 */
export interface PerformanceCategory {
  title: string;
  percentText: string;
  color: string;
  progress: number;
}

/**
 * 趋势图单项数据点
 */
export interface TrendChartItem {
  label: string;
  value: number;
}

/**
 * 热门专注标签排行项
 */
export interface TopTagItem {
  tag: string;
  count: number;
  percentWidth: string;
  ratioPercent: number;
}

/**
 * 分心黑名单项
 */
export interface DistractionBlacklistItem {
  tag: string;
  failText: string;
  failRate: number;
}

/**
 * 标签计数内部结构
 */
export interface TagCountItem {
  total: number;
  aborted: number;
}

/**
 * 分心与准点率深度复盘报告
 */
export interface DistractionReportSummary {
  totalCount: number;
  interruptedCount: number;
  interruptedPercent: number;
  totalLostMinutes: number;
  avgLostMinutes: number;
  worstRecord: WorstDelayRecord;
  performanceList: Array<PerformanceCategory>;
  blacklist: Array<DistractionBlacklistItem>;
}

export interface UnlockedStampItem {
  airportCode: string;
  cityName: string;
  stampTitle: string;
  firstUnlockTime: number;
  visitCount: number;
}

/**
 * 历史已飞航线段 (供 3D 地球全景航迹绘制使用)
 */
export interface HistoricalRouteSegment {
  originCode: string;
  originCity: string;
  originLat: number;
  originLon: number;
  destCode: string;
  destCity: string;
  destLat: number;
  destLon: number;
  flightCount: number;
  lastFlightTime: number;
}

export interface RouteAggItem {
  orig: string;
  dest: string;
  count: number;
  latestTime: number;
}
