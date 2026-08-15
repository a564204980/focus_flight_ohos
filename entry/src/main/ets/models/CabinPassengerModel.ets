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

export interface CabinPassengerTemplate {
  icon: Resource;
  emoji: string;
  name: string;
  role: string;
  focusTask: string;
  quotes: string[];
}

export interface CabinPassenger {
  seatId: string;
  icon: Resource;
  emoji: string;
  name: string;
  role: string;
  focusTask: string;
  quote: string;
  quotes: string[];
}

export interface WalkingPassengerState {
  seatId: string;
  icon: Resource;
  emoji: string;
  targetX: number;
  targetY: number;
  walkDuration: number;
  slideDuration: number;
}

export interface AisleWalkingTarget {
  targetX: number;
  targetY: number;
}

/**
 * 计算座位在机舱网格中的目标 (targetX, targetY) 坐标（相对于走道中央 (0,0)）
 */
export function getSeatAisleWalkingTarget(seatId: string): AisleWalkingTarget {
  let row = 1;
  let col = 'A';
  if (seatId.length === 2) {
    row = parseInt(seatId.charAt(0));
    col = seatId.charAt(1);
  } else if (seatId.length === 3) {
    row = parseInt(seatId.substring(0, 2));
    col = seatId.charAt(2);
  }

  let targetX = 0;
  let targetY = 16.5;

  if (row === 1) {
    targetY = 16.5;
    if (col === 'A') targetX = -119;
    else if (col === 'C') targetX = -49;
    else if (col === 'D') targetX = 49;
    else if (col === 'F') targetX = 119;
  } else if (row === 2) {
    targetY = 55.5;
    if (col === 'A') targetX = -119;
    else if (col === 'C') targetX = -49;
    else if (col === 'D') targetX = 49;
    else if (col === 'F') targetX = 119;
  } else {
    // Rows 3 ~ 13
    targetY = 135 + (row - 3) * 36;
    if (col === 'A') targetX = -126;
    else if (col === 'B') targetX = -84;
    else if (col === 'C') targetX = -42;
    else if (col === 'D') targetX = 42;
    else if (col === 'E') targetX = 84;
    else if (col === 'F') targetX = 126;
  }

  const result: AisleWalkingTarget = {
    targetX: targetX,
    targetY: targetY
  };
  return result;
}

/**
 * 🌟 18 款萌宠性格专属语录库（120+ 条超接地气、幽默生活化、打工人与学生党日常吐槽碎碎念）
 */
export const ANIMAL_PASSENGERS_POOL: CabinPassengerTemplate[] = [
  {
    icon: $r('app.media.orange_cat'),
    emoji: '🐱',
    name: '橘宝',
    role: '卷王学霸猫',
    focusTask: '疯狂刷考研真题',
    quotes: [
      '别戳我！这道数学大题我算第三遍了喵！',
      '搞完这套卷子，今晚高低得整两罐金枪鱼！',
      '困得要死...不行，同桌还没睡我绝不能睡！',
      '谁打扰本喵学习，等下下飞机挠谁！',
      '肖四肖八背得我脑壳疼，救命啊喵！',
      '我是一只莫得感情的刷题机器喵~',
      '背完这页单词就去上厕所，憋住！'
    ]
  },
  {
    icon: $r('app.media.puppy'),
    emoji: '🐶',
    name: '阿柴',
    role: '苦逼架构汪',
    focusTask: '修复线上紧急Bug',
    quotes: [
      '汪！谁又在生产环境乱改配置了？！',
      '别理我，再改一个Bug我就能准时下班了！',
      '需求又改了？产品经理你出来咱们聊聊！',
      '这破代码谁写的啊？...哦，上周我自己写的。',
      '只要我敲得够快，Deadline就追不上我汪！',
      '咖啡续命，头发可以掉，系统绝对不能崩！',
      '别催了别催了，正在本地跑测试呢汪！'
    ]
  },
  {
    icon: $r('app.media.brown_bear'),
    emoji: '🐻',
    name: '熊抱抱',
    role: '摸鱼养生大熊',
    focusTask: '假装很忙其实在等饭',
    quotes: [
      '好饿啊...飞机餐到底啥时候才发啊？',
      '今天定的目标三件事，目前完成了第一件：开机。',
      '大熊叹气，成年熊的世界真的没有容易二字。',
      '等下落地下机，第一件事就是去整顿火锅！',
      '先摸五分钟鱼...哎呀怎么半小时过去了！',
      '深呼吸，不生气，世界这么大我想吃炸鸡。',
      '只要我假装很忙，老板就看不出我在摸鱼。'
    ]
  },
  {
    icon: $r('app.media.fox'),
    emoji: '🦊',
    name: '阿狸',
    role: '扑街小说写手',
    focusTask: '极限赶稿防断更',
    quotes: [
      '读者又在评论区寄刀片催更了，手速拉满！',
      '卡文卡得头秃，这男主到底该选谁啊？！',
      '今晚要是码不满六千字，我就直接断章！',
      '灵感全无，正在盯着空白文档发呆...',
      '再水两百字心理描写就够一章了，嘿嘿。',
      '写完这章就去睡！...天怎么快亮了？',
      '小说里暴富了，现实里还在天天赶稿吃土。'
    ]
  },
  {
    icon: $r('app.media.hamster'),
    emoji: '🐹',
    name: '小仓',
    role: '急救突击考生',
    focusTask: '通宵狂背期末考点',
    quotes: [
      '完了完了，明天考高数，我才刚翻开第一页！',
      '老师划的重点是整本书！救救孩子吧！',
      '把这页书贴脑门上，能不能意念吸收知识啊？',
      '抓紧时间抱佛脚，能考60分算我赢！',
      '疯狂灌红牛中！今晚机舱就是我的自习室！',
      '只要胆子大，期末一周当学霸，冲啊！',
      '别跟我说话，我脑子里的公式快溢出来了！'
    ]
  },
  {
    icon: $r('app.media.hedgehog'),
    emoji: '🦔',
    name: '刺猬阿刺',
    role: '重度社恐打工人',
    focusTask: '安静自闭干私活',
    quotes: [
      '戴着降噪耳机呢，看不见我看不见我...',
      '求求了，千万别在群里@我发言！',
      '别戳啦，社恐人的社交电量已经见底了！',
      '安静搞自己的事多舒服，不想社交。',
      '只要我不抬头，邻座就不会找我尬聊。',
      '手头这点活儿干完，我立马隐身遁走！',
      '今日份的沉默是金，谁也别想找我搭话。'
    ]
  },
  {
    icon: $r('app.media.koala'),
    emoji: '🐨',
    name: '考拉慢步',
    role: '终极佛系大师',
    focusTask: '睁着眼睛打瞌睡',
    quotes: [
      '哈欠—— 让我再眯五分钟，就五分钟...',
      '急啥嘛，车到山前必有路，慢慢来呗。',
      '虽然我动作慢，但我偷懒的技术一流啊。',
      '只要躺得够平，生活就没办法把我打倒。',
      '醒着好累，专注看了两行字眼皮就在打架。',
      '佛系度日，做人嘛，最重要的是开心啦。',
      '别催我，我的网速跟我的脑回路一样慢。'
    ]
  },
  {
    icon: $r('app.media.tiger'),
    emoji: '🐯',
    name: '萌小虎',
    role: '暴躁极速冲刺侠',
    focusTask: '疯狂撕裂KPI',
    quotes: [
      '嗷呜！今天必须把这个硬骨头项目给啃下来！',
      '冲冲冲！干就完了，犹豫就会败北！',
      '谁说这活儿做不完的？看我今天通关它！',
      '热血拉满，今天不把方案做出来我不姓虎！',
      '别跟我讲借口，效率！我们要的是效率！',
      '燃起来了！这把我必须拿MVP！',
      '干劲十足，今天谁也别想拦着我冲KPI！'
    ]
  },
  {
    icon: $r('app.media.cow'),
    emoji: '🐮',
    name: '憨憨牛',
    role: '考公考编大军',
    focusTask: '狂刷行测申论真题',
    quotes: [
      '第一百零八次背法条，脑瓜子嗡嗡的。',
      '申论大作文到底怎么写啊，抓狂中！',
      '行测做不完，根本做不完，蒙全是B！',
      '老老实实刷题，考公人每天都在渡劫。',
      '只要卷不死就往死里卷，今年必须上岸！',
      '这道多选题又漏选了，我想静静。',
      '埋头苦干，天道酬勤，我不信我考不上！'
    ]
  },
  {
    icon: $r('app.media.pink_pig'),
    emoji: '🐷',
    name: '麦兜',
    role: '吃货减肥困难户',
    focusTask: '盯着菜单狂咽口水',
    quotes: [
      '专注了十分钟，肚子叫了二十遍...',
      '好想吃螺蛳粉、麻辣烫、炸鸡和奶茶啊！',
      '说好的今天开始减肥，怎么又在想晚饭？',
      '只要我吃得够快，卡路里就追不上我！',
      '写完这页PPT，奖励自己喝大杯珍珠奶茶！',
      '肚子饱了脑子才转得动，这叫科学补脑！',
      '下飞机第一件事：直奔小吃街，开炫！'
    ]
  },
  {
    icon: $r('app.media.green_frog'),
    emoji: '🐸',
    name: '蛙小行',
    role: '特种兵旅行博主',
    focusTask: '熬夜修旅游九宫格',
    quotes: [
      '赶行程赶得腿快断了，但九宫格必须凑齐！',
      '等下落地直奔景点，日行三万步不是梦呱！',
      '修图修了俩小时，原图跟精修判若两人！',
      '机票钱都花了，哪怕困死我也要玩通宵！',
      '查攻略中...这家网红店排队两小时值不值？',
      '行李箱塞爆了，买的特产比衣服还多呱！',
      '旅行特种兵从不认输，下一个打卡点走起！'
    ]
  },
  {
    icon: $r('app.media.yellow_duck'),
    emoji: '🦆',
    name: '鸭鸭',
    role: '疯狂改方案乙方',
    focusTask: '对齐甲方离谱需求',
    quotes: [
      '甲方爸爸又提奇葩需求了，嘎！我忍！',
      '您好在的，马上改，这就改...（抓狂中）',
      '改了八版方案，最后甲方说还是第一版好！',
      '求求老板别在半夜拉语音开会了嘎！',
      '打工人打工魂，打工赚的都是窝囊费嘎！',
      '一边说着好的收到，一边心里默念莫生气。',
      '嘎！今天要是能准点下班，我请大家喝奶茶！'
    ]
  },
  {
    icon: $r('app.media.owl'),
    emoji: '🦉',
    name: '咕咕学者',
    role: '熬夜修仙党',
    focusTask: '深夜猛猛写论文',
    quotes: [
      '凌晨三点才是本咕思维最活跃的黄金时间！',
      '发际线又往后撤退了一厘米，头皮发凉咕。',
      '黑眼圈比机舱窗户还黑，但我还能继续战！',
      '修仙中，请勿打扰，羽化登仙只差最后一步。',
      '再熬夜我就是狗！...汪汪，真香！',
      '白天瞌睡连天，晚上一沾枕头就文思泉涌。',
      '用最贵的眼霜，熬最狠的夜咕！'
    ]
  },
  {
    icon: $r('app.media.deer'),
    emoji: '🦌',
    name: '小鹿',
    role: '脆皮大学生',
    focusTask: '担心答辩被挂掉',
    quotes: [
      '刚才电脑突然蓝屏，吓得我心跳飙到180！',
      '呜呜呜，导师突然在微信群里艾特我了！',
      '脆皮小鹿在线渡劫，每天都在担心挂科。',
      '别吓我，我的精神状态已经非常美丽了。',
      '刚准备摸鱼就被抓包，这也太倒霉了吧！',
      '论文查重率40%？！救命，我明明自己写的！',
      '求老天保佑，这次答辩千万让我顺顺当当过！'
    ]
  },
  {
    icon: $r('app.media.raccoon'),
    emoji: '🦝',
    name: '浣小熊',
    role: '重度强迫症患者',
    focusTask: '把所有文件按像素对齐',
    quotes: [
      '桌面必须一尘不染，图标必须按颜色排齐！',
      '表格里这个空格多敲了一下，浑身难受！',
      '洗了三遍爪子，才敢碰新买的手账本。',
      '文件夹分类必须清清楚楚，强迫症没救了。',
      '收纳整理狂喜中，看着整整齐齐的桌面真爽！',
      '这个标点符号用错了，忍不住想给它改过来！',
      '不把最后这行对齐，今晚睡觉都睡不踏实。'
    ]
  },
  {
    icon: $r('app.media.squirrel'),
    emoji: '🐿️',
    name: '松子',
    role: '资料囤积狂魔',
    focusTask: '收藏一万个教程不看',
    quotes: [
      '收藏夹存了1000套资料，看过的只有0套！',
      '马了等于看了，看了等于学会了，没毛病！',
      '疯狂保存网盘资源，这辈子可能都看不完。',
      '手机内存又告急了，舍不得删截图怎么办！',
      '囤课一时爽，上课火葬场，课债还不起了！',
      '收藏夹吃灰警告！今天必须逼自己看一套！',
      '把资料存起来，心里就有了莫名的安全感。'
    ]
  },
  {
    icon: $r('app.media.otter'),
    emoji: '🦦',
    name: '水獭达达',
    role: '月光族打工人',
    focusTask: '边搬砖边算花呗',
    quotes: [
      '看中了一双新鞋子，看看余额...告辞！',
      '花钱如流水，挣钱如抽丝，穷得叮当响。',
      '今天又是为了五斗米折腰的一天，搬砖！',
      '购物车里有三十件宝贝，等待发工资清空！',
      '钱虽然没挣多少，但花钱的快乐一点没少。',
      '别问我为什么这么拼，下个月花呗要还了！',
      '天天嚷嚷着辞职，结果每天第一个到工位。'
    ]
  },
  {
    icon: $r('app.media.kangaroo'),
    emoji: '🦘',
    name: '袋鼠跳跳',
    role: '运动打卡狂人',
    focusTask: '坐着偷偷绷紧腹肌',
    quotes: [
      '坐久了腰酸背痛，好想在过道做一百个深蹲！',
      '少吃一口高热量，多做一组帕梅拉！',
      '今天微信运动没排第一，浑身难受想跳操！',
      '喝蛋白粉中，肌肉和专注力都要练出来！',
      '别葛优躺了，起来活动活动颈椎！',
      '今天还没去健身房打卡，感觉一天白过了！',
      '满血复活！自律给我自由，打工人冲呀！'
    ]
  }
];

/**
 * 随机生成当前航班的同行乘客列表（严格保持在 50%~70% 客座率区间：头等舱 4~5 位，普通舱 36~40 位）
 */
export function generateRandomCabinPassengers(): Map<string, CabinPassenger> {
  const result = new Map<string, CabinPassenger>();
  
  // 全部头等舱座位 (8座)
  const firstClassSeats: string[] = ['1A', '1C', '1D', '1F', '2A', '2C', '2D', '2F'];
  
  // 全部普通舱座位 (66座)
  const economySeats: string[] = [];
  const cols = ['A', 'B', 'C', 'D', 'E', 'F'];
  for (let r = 3; r <= 13; r++) {
    for (let c = 0; c < cols.length; c++) {
      economySeats.push(`${r}${cols[c]}`);
    }
  }

  // 1. 头等舱选 4~5 个座位 (50%~65% 满座率)
  const firstCount = Math.floor(Math.random() * 2) + 4; // 4 或 5
  const shuffledFirst: string[] = [...firstClassSeats].sort((): number => Math.random() - 0.5);
  for (let i = 0; i < firstCount; i++) {
    const seatId: string = shuffledFirst[i];
    const templateIdx = Math.floor(Math.random() * ANIMAL_PASSENGERS_POOL.length);
    const item: CabinPassengerTemplate = ANIMAL_PASSENGERS_POOL[templateIdx];
    const randomQuoteIdx = Math.floor(Math.random() * item.quotes.length);
    result.set(seatId, {
      seatId: seatId,
      icon: item.icon,
      emoji: item.emoji,
      name: item.name,
      role: item.role,
      focusTask: item.focusTask,
      quote: item.quotes[randomQuoteIdx],
      quotes: item.quotes
    });
  }

  // 2. 普通舱选 36~40 个座位 (55%~60% 满座率)
  const ecoCount = Math.floor(Math.random() * 5) + 36; // 36 ~ 40
  const shuffledEco: string[] = [...economySeats].sort((): number => Math.random() - 0.5);
  for (let i = 0; i < ecoCount; i++) {
    const seatId: string = shuffledEco[i];
    const templateIdx = Math.floor(Math.random() * ANIMAL_PASSENGERS_POOL.length);
    const item: CabinPassengerTemplate = ANIMAL_PASSENGERS_POOL[templateIdx];
    const randomQuoteIdx = Math.floor(Math.random() * item.quotes.length);
    result.set(seatId, {
      seatId: seatId,
      icon: item.icon,
      emoji: item.emoji,
      name: item.name,
      role: item.role,
      focusTask: item.focusTask,
      quote: item.quotes[randomQuoteIdx],
      quotes: item.quotes
    });
  }

  return result;
}
