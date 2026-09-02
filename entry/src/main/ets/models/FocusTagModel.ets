/**
 * FocusTagModel.ets
 * Focus Flight 专注场景主题与任务标签数据模型
 */

export interface FocusTagItem {
  id: string;
  icon: string;
  title: string;
  sub: string;
  color: string;
  bg: string;
  shadow: string;
  isCustom?: boolean;
}

/** 预设高品质专注主题场景 */
export const PRESET_FOCUS_TAGS: Array<FocusTagItem> = [
  {
    id: 'study',
    icon: '📚',
    title: '深度学习',
    sub: '研读 / 备考',
    color: '#F06553',
    bg: '#FFF5F3',
    shadow: 'rgba(240, 101, 83, 0.22)'
  },
  {
    id: 'work',
    icon: '💻',
    title: '深度编程',
    sub: '代码 / 架构',
    color: '#0EA5E9',
    bg: '#F0F9FF',
    shadow: 'rgba(14, 165, 233, 0.22)'
  },
  {
    id: 'write',
    icon: '✍️',
    title: '创作灵感',
    sub: '撰写 / 构思',
    color: '#8B5CF6',
    bg: '#F3E8FF',
    shadow: 'rgba(139, 92, 246, 0.22)'
  },
  {
    id: 'design',
    icon: '🎨',
    title: '视觉设计',
    sub: 'UI / 美术',
    color: '#EC4899',
    bg: '#FDF2F8',
    shadow: 'rgba(236, 72, 153, 0.22)'
  },
  {
    id: 'relax',
    icon: '🧘',
    title: '正念冥想',
    sub: '呼吸 / 放松',
    color: '#10B981',
    bg: '#ECFDF5',
    shadow: 'rgba(16, 185, 129, 0.22)'
  },
  {
    id: 'sprint',
    icon: '⚡',
    title: '极速冲刺',
    sub: '高效 / 攻坚',
    color: '#F59E0B',
    bg: '#FFFBEB',
    shadow: 'rgba(245, 158, 11, 0.22)'
  }
];

/** 自定义主题可选高定配色板 */
export interface TagColorOption {
  color: string;
  bg: string;
  shadow: string;
}

export const TAG_COLOR_PALETTE: Array<TagColorOption> = [
  { color: '#F06553', bg: '#FFF5F3', shadow: 'rgba(240, 101, 83, 0.22)' }, // 暖珊瑚
  { color: '#0EA5E9', bg: '#F0F9FF', shadow: 'rgba(14, 165, 233, 0.22)' }, // 冰川蓝
  { color: '#8B5CF6', bg: '#F3E8FF', shadow: 'rgba(139, 92, 246, 0.22)' }, // 极光紫
  { color: '#10B981', bg: '#ECFDF5', shadow: 'rgba(16, 185, 129, 0.22)' }, // 薄荷绿
  { color: '#EC4899', bg: '#FDF2F8', shadow: 'rgba(236, 72, 153, 0.22)' }, // 蔷薇粉
  { color: '#F59E0B', bg: '#FFFBEB', shadow: 'rgba(245, 158, 11, 0.22)' }  // 晨曦金
];

/** 自定义主题可选 Emoji 库 */
export const TAG_EMOJI_PRESETS: string[] = [
  '🎯', '📖', '📝', '💡', '🚀', '☕', '🔥', '🎧', '🔭', '🎹', '🏋️', '🧠'
];
