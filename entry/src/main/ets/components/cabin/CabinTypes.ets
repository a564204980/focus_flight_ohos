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

export interface FocusTagItem {
  id: string;
  name: string;
  sub: string;
  icon: string;
  color: string;
  pastelBg: string;
  borderColor: string;
  activeBg: string;
  shadowColor: string;
  isCustom?: boolean;
}

export const CABIN_FOCUS_TAGS: FocusTagItem[] = [
  {
    id: 'study',
    name: '学习',
    sub: '研读 / 备考',
    icon: '📚',
    color: '#C25E54',
    pastelBg: '#FAECEB',
    borderColor: '#F1CCC8',
    activeBg: '#C25E54',
    shadowColor: 'rgba(194, 94, 84, 0.35)'
  },
  {
    id: 'work',
    name: '工作',
    sub: '编程 / 会议',
    icon: '💼',
    color: '#4B779A',
    pastelBg: '#EBF3F8',
    borderColor: '#CBE0EC',
    activeBg: '#4B779A',
    shadowColor: 'rgba(75, 119, 154, 0.35)'
  },
  {
    id: 'create',
    name: '创意',
    sub: '设计 / 写作',
    icon: '🎨',
    color: '#7D6A87',
    pastelBg: '#F3EEF5',
    borderColor: '#DACEE0',
    activeBg: '#7D6A87',
    shadowColor: 'rgba(125, 106, 135, 0.35)'
  },
  {
    id: 'relax',
    name: '冥想',
    sub: '呼吸 / 放松',
    icon: '🧘',
    color: '#5B8C7A',
    pastelBg: '#ECF5F1',
    borderColor: '#C7E4D7',
    activeBg: '#5B8C7A',
    shadowColor: 'rgba(91, 140, 122, 0.35)'
  },
  {
    id: 'sprint',
    name: '冲刺',
    sub: '高效突击',
    icon: '⚡',
    color: '#C68B45',
    pastelBg: '#FBF4E8',
    borderColor: '#F5DEBC',
    activeBg: '#C68B45',
    shadowColor: 'rgba(198, 139, 69, 0.35)'
  }
];

export function getSeatTypeLabel(seatId: string): string {
  const row = parseInt(seatId);
  if (row === 1 || row === 2) {
    return '👑 头等舱尊享';
  }
  const col = seatId.charAt(seatId.length - 1);
  if (col === 'A' || col === 'F') {
    return '靠窗座位';
  }
  if (col === 'C' || col === 'D') {
    return '过道座位';
  }
  return '中间座位';
}
