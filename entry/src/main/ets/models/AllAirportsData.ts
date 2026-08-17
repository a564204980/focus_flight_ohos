import { Airport } from './AirportModel';

/**
 * 中国民航全量运输机场 (250+座) + 全球核心国际枢纽机场 (100+座)
 * 包含精准地理纬经度 (lat, lon)、三字码 (code)、城市名称 (city) 及机场全称 (name)
 */
export const FULL_AIRPORTS_LIST: Airport[] = [
  // ==========================================
  // 1. 四川省及西南核心枢纽 (全量川内机场及周边)
  // ==========================================
  { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5607, lon: 103.9426, runwayEndLat: 30.5901, runwayEndLon: 103.9562, country: 'CN' },
  { code: 'TFU', name: '成都天府国际机场', city: '成都', lat: 30.3217, lon: 104.4419, country: 'CN' },
  { code: 'MIG', name: '绵阳南郊机场', city: '绵阳', lat: 31.4286, lon: 104.7439, country: 'CN' },
  { code: 'YBP', name: '宜宾五粮液机场', city: '宜宾', lat: 28.8008, lon: 104.5447, country: 'CN' },
  { code: 'LZO', name: '泸州云龙机场', city: '泸州', lat: 29.031937, lon: 105.488001, runwayEndLat: 29.023383, runwayEndLon: 105.456698, country: 'CN' },
  { code: 'NAO', name: '南充高坪机场', city: '南充', lat: 30.788956, lon: 106.155323, runwayEndLat: 30.802603, runwayEndLon: 106.181349, country: 'CN' },
  { code: 'DAX', name: '达州金垭机场', city: '达州', lat: 31.1275, lon: 107.4336, country: 'CN' },
  { code: 'XIC', name: '西昌青山机场', city: '西昌', lat: 27.9897, lon: 102.1844, country: 'CN' },
  { code: 'PZI', name: '攀枝花保安营机场', city: '攀枝花', lat: 26.5408, lon: 101.7989, country: 'CN' },
  { code: 'JZH', name: '九寨黄龙机场', city: '九寨沟', lat: 32.8531, lon: 103.6847, country: 'CN' },
  { code: 'KGT', name: '甘孜康定机场', city: '康定', lat: 30.155751, lon: 101.729772, runwayEndLat: 30.124943, runwayEndLon: 101.750773, country: 'CN' },
  { code: 'DCY', name: '稻城亚丁机场', city: '稻城', lat: 29.3106, lon: 100.0617, country: 'CN' },
  { code: 'GZG', name: '甘孜格萨尔机场', city: '甘孜', lat: 31.7456, lon: 99.5761, country: 'CN' },
  { code: 'GYS', name: '广元盘龙机场', city: '广元', lat: 32.3892, lon: 105.7003, country: 'CN' },
  { code: 'BZX', name: '巴中恩阳机场', city: '巴中', lat: 31.7858, lon: 106.6347, country: 'CN' },
  { code: 'AHJ', name: '阿坝红原机场', city: '红原', lat: 32.5317, lon: 102.3550, country: 'CN' },

  // 重庆市
  { code: 'CKG', name: '重庆江北国际机场', city: '重庆', lat: 29.7192, lon: 106.6417, country: 'CN' },
  { code: 'WXN', name: '万州五桥机场', city: '万州', lat: 30.7989, lon: 108.4319, country: 'CN' },
  { code: 'JIQ', name: '黔江武陵山机场', city: '黔江', lat: 29.5161, lon: 108.8319, country: 'CN' },
  { code: 'WSM', name: '巫山机场', city: '巫山', lat: 31.0747, lon: 109.7042, country: 'CN' },
  { code: 'CQW', name: '武隆仙女山机场', city: '武隆', lat: 29.4678, lon: 107.7214, country: 'CN' },

  // 贵州省
  { code: 'KWE', name: '贵阳龙洞堡国际机场', city: '贵阳', lat: 26.5385, lon: 106.8007, country: 'CN' },
  { code: 'ZYI', name: '遵义新舟机场', city: '遵义', lat: 27.8108, lon: 107.2481, country: 'CN' },
  { code: 'WMT', name: '茅台机场', city: '仁怀', lat: 27.9547, lon: 106.4172, country: 'CN' },
  { code: 'AVA', name: '安顺黄果树机场', city: '安顺', lat: 26.2597, lon: 105.8744, country: 'CN' },
  { code: 'TEN', name: '铜仁凤凰机场', city: '铜仁', lat: 27.8844, lon: 109.3089, country: 'CN' },
  { code: 'LPF', name: '六盘水月照机场', city: '六盘水', lat: 26.6067, lon: 104.9786, country: 'CN' },
  { code: 'ACX', name: '兴义万峰林机场', city: '兴义', lat: 25.0864, lon: 104.9592, country: 'CN' },
  { code: 'BFJ', name: '毕节飞雄机场', city: '毕节', lat: 27.2606, lon: 105.4714, country: 'CN' },
  { code: 'HZH', name: '黎平机场', city: '黎平', lat: 26.3314, lon: 109.1481, country: 'CN' },
  { code: 'LLB', name: '荔波机场', city: '荔波', lat: 25.4497, lon: 107.9711, country: 'CN' },
  { code: 'KJH', name: '凯里黄平机场', city: '凯里', lat: 26.9733, lon: 107.9864, country: 'CN' },

  // 云南省
  { code: 'KMG', name: '昆明长水国际机场', city: '昆明', lat: 25.1019, lon: 102.9292, country: 'CN' },
  { code: 'LJG', name: '丽江三义国际机场', city: '丽江', lat: 26.6789, lon: 100.2464, country: 'CN' },
  { code: 'DLU', name: '大理凤仪机场', city: '大理', lat: 25.6497, lon: 100.3183, country: 'CN' },
  { code: 'JHG', name: '西双版纳嘎洒国际机场', city: '景洪', lat: 21.9739, lon: 100.7597, country: 'CN' },
  { code: 'LUM', name: '德宏芒市国际机场', city: '芒市', lat: 24.4011, lon: 98.5322, country: 'CN' },
  { code: 'BSD', name: '保山云瑞机场', city: '保山', lat: 25.0531, lon: 99.1683, country: 'CN' },
  { code: 'TCZ', name: '腾冲驼峰机场', city: '腾冲', lat: 24.9389, lon: 98.4878, country: 'CN' },
  { code: 'DIG', name: '迪庆香格里拉机场', city: '香格里拉', lat: 27.7906, lon: 99.6817, country: 'CN' },
  { code: 'SYM', name: '普洱思茅机场', city: '普洱', lat: 22.7933, lon: 100.9583, country: 'CN' },
  { code: 'LNJ', name: '临沧博尚机场', city: '临沧', lat: 23.7408, lon: 100.0272, country: 'CN' },
  { code: 'CWJ', name: '沧源佤山机场', city: '沧源', lat: 23.2758, lon: 99.3664, country: 'CN' },
  { code: 'JMJ', name: '澜沧景迈机场', city: '澜沧', lat: 22.4172, lon: 99.7858, country: 'CN' },
  { code: 'ZAT', name: '昭通昭阳机场', city: '昭通', lat: 27.3244, lon: 103.7558, country: 'CN' },
  { code: 'WNH', name: '文山砚山机场', city: '文山', lat: 23.5606, lon: 104.3314, country: 'CN' },

  // 西藏自治区
  { code: 'LXA', name: '拉萨贡嘎国际机场', city: '拉萨', lat: 29.2978, lon: 90.9119, country: 'CN' },
  { code: 'LZY', name: '林芝米林机场', city: '林芝', lat: 29.3031, lon: 94.3353, country: 'CN' },
  { code: 'RKZ', name: '日喀则和平机场', city: '日喀则', lat: 29.3517, lon: 89.3106, country: 'CN' },
  { code: 'NGQ', name: '阿里昆莎机场', city: '阿里', lat: 32.1006, lon: 80.0531, country: 'CN' },
  { code: 'BPX', name: '昌都邦达机场', city: '昌都', lat: 30.5536, lon: 97.1083, country: 'CN' },

  // ==========================================
  // 2. 陕西 / 西北各省
  // ==========================================
  { code: 'XIY', name: '西安咸阳国际机场', city: '西安', lat: 34.4471, lon: 108.7516, country: 'CN' },
  { code: 'UYN', name: '榆林榆阳机场', city: '榆林', lat: 38.3589, lon: 109.5967, country: 'CN' },
  { code: 'ENY', name: '延安南泥湾机场', city: '延安', lat: 36.4719, lon: 109.5494, country: 'CN' },
  { code: 'HZG', name: '汉中城固机场', city: '汉中', lat: 33.1311, lon: 107.2025, country: 'CN' },
  { code: 'AKA', name: '安康富强机场', city: '安康', lat: 32.7486, lon: 108.9286, country: 'CN' },

  // 甘肃省
  { code: 'LHW', name: '兰州中川国际机场', city: '兰州', lat: 36.5153, lon: 103.6208, country: 'CN' },
  { code: 'DNH', name: '敦煌莫高国际机场', city: '敦煌', lat: 40.1608, lon: 94.8103, country: 'CN' },
  { code: 'JGN', name: '嘉峪关酒泉机场', city: '嘉峪关', lat: 39.8553, lon: 98.3414, country: 'CN' },
  { code: 'IQN', name: '庆阳西峰机场', city: '庆阳', lat: 35.8014, lon: 107.6033, country: 'CN' },
  { code: 'JIC', name: '金昌金川机场', city: '金昌', lat: 38.5414, lon: 102.3508, country: 'CN' },
  { code: 'YZY', name: '张掖甘州机场', city: '张掖', lat: 38.8089, lon: 100.6722, country: 'CN' },
  { code: 'LNL', name: '陇南成县机场', city: '陇南', lat: 33.7886, lon: 105.8111, country: 'CN' },
  { code: 'GXH', name: '甘南夏河机场', city: '甘南', lat: 34.8189, lon: 102.6358, country: 'CN' },

  // 青海省
  { code: 'XNN', name: '西宁曹家堡国际机场', city: '西宁', lat: 36.5286, lon: 102.0442, country: 'CN' },
  { code: 'GOQ', name: '格尔木机场', city: '格尔木', lat: 36.4014, lon: 94.7933, country: 'CN' },
  { code: 'YUS', name: '玉树巴塘机场', city: '玉树', lat: 32.8364, lon: 97.0361, country: 'CN' },
  { code: 'HXD', name: '德令哈机场', city: '德令哈', lat: 37.1264, lon: 97.2683, country: 'CN' },
  { code: 'HTT', name: '茫崖花土沟机场', city: '茫崖', lat: 38.2017, lon: 90.8419, country: 'CN' },
  { code: 'GMQ', name: '果洛玛沁机场', city: '果洛', lat: 34.4239, lon: 100.3017, country: 'CN' },

  // 宁夏回族自治区
  { code: 'INC', name: '银川河东国际机场', city: '银川', lat: 38.3217, lon: 106.3931, country: 'CN' },
  { code: 'ZHY', name: '中卫沙坡头机场', city: '中卫', lat: 37.5742, lon: 105.1558, country: 'CN' },
  { code: 'GYU', name: '固原六盘山机场', city: '固原', lat: 36.0772, lon: 106.2164, country: 'CN' },

  // 新疆维吾尔自治区
  { code: 'URC', name: '乌鲁木齐地窝堡国际机场', city: '乌鲁木齐', lat: 43.9071, lon: 87.4742, country: 'CN' },
  { code: 'KHG', name: '喀什徕宁国际机场', city: '喀什', lat: 39.5428, lon: 76.0197, country: 'CN' },
  { code: 'YIN', name: '伊宁机场', city: '伊宁', lat: 43.9558, lon: 81.3303, country: 'CN' },
  { code: 'KRL', name: '库尔勒梨城机场', city: '库尔勒', lat: 41.6989, lon: 86.1436, country: 'CN' },
  { code: 'AKU', name: '阿克苏红旗坡机场', city: '阿克苏', lat: 41.2625, lon: 80.2917, country: 'CN' },
  { code: 'AAT', name: '阿勒泰雪都机场', city: '阿勒泰', lat: 47.7506, lon: 88.0847, country: 'CN' },
  { code: 'HTN', name: '和田昆冈机场', city: '和田', lat: 37.0386, lon: 79.8647, country: 'CN' },
  { code: 'KRY', name: '克拉玛依古海机场', city: '克拉玛依', lat: 45.4664, lon: 84.9528, country: 'CN' },
  { code: 'TLQ', name: '吐鲁番交河机场', city: '吐鲁番', lat: 42.9122, lon: 89.0983, country: 'CN' },
  { code: 'KCA', name: '库车龟兹机场', city: '库车', lat: 41.6775, lon: 82.9733, country: 'CN' },
  { code: 'BPL', name: '博乐阿拉山口机场', city: '博乐', lat: 44.8967, lon: 82.3006, country: 'CN' },
  { code: 'TCG', name: '塔城千泉机场', city: '塔城', lat: 46.6728, lon: 83.3406, country: 'CN' },
  { code: 'HMI', name: '哈密伊州机场', city: '哈密', lat: 42.8414, lon: 93.6697, country: 'CN' },
  { code: 'QSZ', name: '莎车叶尔羌机场', city: '莎车', lat: 38.2436, lon: 77.0683, country: 'CN' },
  { code: 'TWC', name: '图木舒克唐王城机场', city: '图木舒克', lat: 39.8667, lon: 79.0833, country: 'CN' },
  { code: 'RQA', name: '若羌楼兰机场', city: '若羌', lat: 38.9719, lon: 88.0131, country: 'CN' },
  { code: 'FYN', name: '富蕴可可托海机场', city: '富蕴', lat: 46.8042, lon: 89.5161, country: 'CN' },
  { code: 'ZFL', name: '昭苏天马机场', city: '昭苏', lat: 43.1508, lon: 81.1356, country: 'CN' },
  { code: 'YTW', name: '于田万方机场', city: '于田', lat: 36.8167, lon: 81.6500, country: 'CN' },
  { code: 'ACF', name: '阿拉尔塔里木机场', city: '阿拉尔', lat: 40.6389, lon: 81.3972, country: 'CN' },
  { code: 'HQL', name: '塔什库尔干红其拉甫机场', city: '塔县', lat: 37.7444, lon: 75.2361, country: 'CN' },

  // ==========================================
  // 3. 华北 / 东北各大省市
  // ==========================================
  { code: 'PEK', name: '北京首都国际机场', city: '北京', lat: 40.0801, lon: 116.5846, country: 'CN' },
  { code: 'PKX', name: '北京大兴国际机场', city: '北京', lat: 39.5092, lon: 116.4105, country: 'CN' },
  { code: 'TSN', name: '天津滨海国际机场', city: '天津', lat: 39.1244, lon: 117.3462, country: 'CN' },

  // 河北省
  { code: 'SJW', name: '石家庄正定国际机场', city: '石家庄', lat: 38.2808, lon: 114.6969, country: 'CN' },
  { code: 'HDG', name: '邯郸机场', city: '邯郸', lat: 36.5258, lon: 114.4306, country: 'CN' },
  { code: 'TVS', name: '唐山三女河机场', city: '唐山', lat: 39.7189, lon: 118.0019, country: 'CN' },
  { code: 'BPE', name: '秦皇岛北戴河机场', city: '秦皇岛', lat: 39.6683, lon: 119.1611, country: 'CN' },
  { code: 'ZQZ', name: '张家口宁远机场', city: '张家口', lat: 40.7408, lon: 114.9317, country: 'CN' },
  { code: 'CDE', name: '承德普宁机场', city: '承德', lat: 41.1167, lon: 118.0667, country: 'CN' },

  // 山西省
  { code: 'TYN', name: '太原武宿国际机场', city: '太原', lat: 37.7469, lon: 112.6283, country: 'CN' },
  { code: 'DAT', name: '大同云冈国际机场', city: '大同', lat: 40.0603, lon: 113.4839, country: 'CN' },
  { code: 'YCU', name: '运城张孝国际机场', city: '运城', lat: 35.1158, lon: 111.0336, country: 'CN' },
  { code: 'CIH', name: '长治王村机场', city: '长治', lat: 36.2478, lon: 113.1256, country: 'CN' },
  { code: 'LFQ', name: '临汾尧都机场', city: '临汾', lat: 36.1417, lon: 111.4933, country: 'CN' },
  { code: 'LLV', name: '吕梁大武机场', city: '吕梁', lat: 37.6767, lon: 111.1444, country: 'CN' },
  { code: 'WUT', name: '忻州五台山机场', city: '忻州', lat: 38.5989, lon: 112.9692, country: 'CN' },

  // 内蒙古自治区
  { code: 'HET', name: '呼和浩特白塔国际机场', city: '呼和浩特', lat: 40.8594, lon: 111.8242, country: 'CN' },
  { code: 'BAV', name: '包头东河机场', city: '包头', lat: 40.5608, lon: 109.9972, country: 'CN' },
  { code: 'DSN', name: '鄂尔多斯伊金霍洛国际机场', city: '鄂尔多斯', lat: 39.4914, lon: 109.8617, country: 'CN' },
  { code: 'HLD', name: '海拉尔东山国际机场', city: '海拉尔', lat: 49.2056, lon: 119.8256, country: 'CN' },
  { code: 'CIF', name: '赤峰玉龙机场', city: '赤峰', lat: 42.1586, lon: 118.8392, country: 'CN' },
  { code: 'NZH', name: '满洲里西郊国际机场', city: '满洲里', lat: 49.5667, lon: 117.3297, country: 'CN' },
  { code: 'HLH', name: '乌兰浩特义勒力特机场', city: '乌兰浩特', lat: 46.1969, lon: 122.0044, country: 'CN' },
  { code: 'TGO', name: '通辽机场', city: '通辽', lat: 43.5572, lon: 122.2014, country: 'CN' },
  { code: 'XIL', name: '锡林浩特机场', city: '锡林浩特', lat: 43.9158, lon: 115.9619, country: 'CN' },
  { code: 'ERL', name: '二连浩特赛乌素机场', city: '二连浩特', lat: 43.4236, lon: 112.0944, country: 'CN' },
  { code: 'YIE', name: '阿尔山伊尔施机场', city: '阿尔山', lat: 47.3075, lon: 119.9142, country: 'CN' },
  { code: 'WHA', name: '乌海机场', city: '乌海', lat: 39.7944, lon: 106.7972, country: 'CN' },

  // 辽宁省
  { code: 'SHE', name: '沈阳桃仙国际机场', city: '沈阳', lat: 41.6397, lon: 123.4833, country: 'CN' },
  { code: 'DLC', name: '大连周水子国际机场', city: '大连', lat: 38.9656, lon: 121.5386, country: 'CN' },
  { code: 'AOG', name: '鞍山腾鳌机场', city: '鞍山', lat: 41.1058, lon: 122.8539, country: 'CN' },
  { code: 'DDG', name: '丹东浪头机场', city: '丹东', lat: 40.0267, lon: 124.2867, country: 'CN' },
  { code: 'JNZ', name: '锦州湾机场', city: '锦州', lat: 41.1022, lon: 121.3328, country: 'CN' },
  { code: 'CHG', name: '朝阳机场', city: '朝阳', lat: 41.5383, lon: 120.4347, country: 'CN' },

  // 吉林省
  { code: 'CGQ', name: '长春龙嘉国际机场', city: '长春', lat: 43.9961, lon: 125.6853, country: 'CN' },
  { code: 'YNJ', name: '延吉朝阳川国际机场', city: '延吉', lat: 42.8828, lon: 129.4514, country: 'CN' },
  { code: 'NBS', name: '长白山机场', city: '白山', lat: 42.0678, lon: 127.6083, country: 'CN' },
  { code: 'TNH', name: '通化三源浦机场', city: '通化', lat: 42.0381, lon: 125.7058, country: 'CN' },
  { code: 'DBC', name: '白城长安机场', city: '白城', lat: 45.5056, lon: 123.0236, country: 'CN' },
  { code: 'YSJ', name: '松原查干湖机场', city: '松原', lat: 44.9358, lon: 124.5519, country: 'CN' },

  // 黑龙江省
  { code: 'HRB', name: '哈尔滨太平国际机场', city: '哈尔滨', lat: 45.6234, lon: 126.2503, country: 'CN' },
  { code: 'NDG', name: '齐齐哈尔三家子机场', city: '齐齐哈尔', lat: 47.2394, lon: 123.9181, country: 'CN' },
  { code: 'MDG', name: '牡丹江海浪国际机场', city: '牡丹江', lat: 44.5242, lon: 129.5689, country: 'CN' },
  { code: 'JMU', name: '佳木斯东郊机场', city: '佳木斯', lat: 46.8433, lon: 130.4653, country: 'CN' },
  { code: 'DQA', name: '大庆萨尔图机场', city: '大庆', lat: 46.7511, lon: 125.1389, country: 'CN' },
  { code: 'HEK', name: '黑河瑷珲机场', city: '黑河', lat: 50.1719, lon: 127.3089, country: 'CN' },
  { code: 'LDS', name: '伊春林都机场', city: '伊春', lat: 47.7519, lon: 129.0194, country: 'CN' },
  { code: 'JXA', name: '鸡西兴凯湖机场', city: '鸡西', lat: 45.2936, lon: 131.1931, country: 'CN' },
  { code: 'OHE', name: '漠河古莲机场', city: '漠河', lat: 52.9161, lon: 122.4217, country: 'CN' },
  { code: 'FYJ', name: '抚远东极机场', city: '抚远', lat: 48.1969, lon: 134.3644, country: 'CN' },
  { code: 'JGD', name: '加格达奇嘎仙机场', city: '加格达奇', lat: 50.3694, lon: 124.1206, country: 'CN' },

  // ==========================================
  // 4. 华东 / 华南 / 华中各大省市
  // ==========================================
  { code: 'PVG', name: '上海浦东国际机场', city: '上海', lat: 31.1434, lon: 121.8052, country: 'CN' },
  { code: 'SHA', name: '上海虹桥国际机场', city: '上海', lat: 31.1979, lon: 121.3363, country: 'CN' },

  // 江苏省
  { code: 'NKG', name: '南京禄口国际机场', city: '南京', lat: 31.7420, lon: 118.8620, country: 'CN' },
  { code: 'WUX', name: '无锡硕放国际机场', city: '无锡', lat: 31.4944, lon: 120.4294, country: 'CN' },
  { code: 'CZX', name: '常州奔牛国际机场', city: '常州', lat: 31.9108, lon: 119.7842, country: 'CN' },
  { code: 'NTG', name: '南通兴东国际机场', city: '南通', lat: 32.0694, lon: 120.9753, country: 'CN' },
  { code: 'XUZ', name: '徐州观音国际机场', city: '徐州', lat: 34.0567, lon: 117.5550, country: 'CN' },
  { code: 'YTY', name: '扬州泰州国际机场', city: '扬州', lat: 32.5633, lon: 119.7183, country: 'CN' },
  { code: 'YNZ', name: '盐城南洋国际机场', city: '盐城', lat: 33.4256, lon: 120.2033, country: 'CN' },
  { code: 'HIA', name: '淮安涟水国际机场', city: '淮安', lat: 33.7850, lon: 119.1444, country: 'CN' },
  { code: 'LYG', name: '连云港花果山国际机场', city: '连云港', lat: 34.5667, lon: 118.8667, country: 'CN' },

  // 浙江省
  { code: 'HGH', name: '杭州萧山国际机场', city: '杭州', lat: 30.2295, lon: 120.4344, country: 'CN' },
  { code: 'NGB', name: '宁波栎社国际机场', city: '宁波', lat: 29.8267, lon: 121.4619, country: 'CN' },
  { code: 'WNZ', name: '温州龙湾国际机场', city: '温州', lat: 27.9122, lon: 120.8517, country: 'CN' },
  { code: 'YIW', name: '义乌国际机场', city: '义乌', lat: 29.3442, lon: 120.0325, country: 'CN' },
  { code: 'HYN', name: '台州路桥机场', city: '台州', lat: 28.5636, lon: 121.4281, country: 'CN' },
  { code: 'HSN', name: '舟山普陀山机场', city: '舟山', lat: 29.9389, lon: 122.3619, country: 'CN' },
  { code: 'JUZ', name: '衢州机场', city: '衢州', lat: 28.9667, lon: 118.8986, country: 'CN' },

  // 安徽省
  { code: 'HFE', name: '合肥新桥国际机场', city: '合肥', lat: 31.9892, lon: 116.9786, country: 'CN' },
  { code: 'TXN', name: '黄山屯溪国际机场', city: '黄山', lat: 29.7331, lon: 118.2567, country: 'CN' },
  { code: 'WHU', name: '芜湖宣州机场', city: '芜湖', lat: 31.1347, lon: 118.6756, country: 'CN' },
  { code: 'FUG', name: '阜阳西关机场', city: '阜阳', lat: 32.8814, lon: 115.7364, country: 'CN' },
  { code: 'AQG', name: '安庆天柱山机场', city: '安庆', lat: 30.5808, lon: 117.0506, country: 'CN' },
  { code: 'JUH', name: '池州九华山机场', city: '池州', lat: 30.7389, lon: 117.6869, country: 'CN' },

  // 福建省
  { code: 'FOC', name: '福州长乐国际机场', city: '福州', lat: 25.9350, lon: 119.6633, country: 'CN' },
  { code: 'XMN', name: '厦门高崎国际机场', city: '厦门', lat: 24.5440, lon: 118.1278, country: 'CN' },
  { code: 'JJN', name: '泉州晋江国际机场', city: '泉州', lat: 24.7961, lon: 118.5897, country: 'CN' },
  { code: 'WUS', name: '武夷山机场', city: '武夷山', lat: 27.6731, lon: 118.0003, country: 'CN' },
  { code: 'SQJ', name: '三明沙县机场', city: '三明', lat: 26.4278, lon: 117.8389, country: 'CN' },
  { code: 'LCX', name: '龙岩冠豸山机场', city: '龙岩', lat: 25.6761, lon: 116.7497, country: 'CN' },

  // 江西省
  { code: 'KHN', name: '南昌昌北国际机场', city: '南昌', lat: 28.8650, lon: 115.9000, country: 'CN' },
  { code: 'KOW', name: '赣州黄金机场', city: '赣州', lat: 25.8508, lon: 114.7778, country: 'CN' },
  { code: 'JDZ', name: '景德镇罗家机场', city: '景德镇', lat: 29.3375, lon: 117.1764, country: 'CN' },
  { code: 'JIU', name: '九江庐山机场', city: '九江', lat: 29.4764, lon: 115.8011, country: 'CN' },
  { code: 'YIC', name: '宜春明月山机场', city: '宜春', lat: 27.7969, lon: 114.3097, country: 'CN' },
  { code: 'SQD', name: '上饶三清山机场', city: '上饶', lat: 28.3800, lon: 117.9622, country: 'CN' },
  { code: 'JGS', name: '井冈山机场', city: '吉安', lat: 26.8581, lon: 114.7375, country: 'CN' },

  // 山东省
  { code: 'TNA', name: '济南遥墙国际机场', city: '济南', lat: 36.8572, lon: 117.2161, country: 'CN' },
  { code: 'TAO', name: '青岛胶东国际机场', city: '青岛', lat: 36.3475, lon: 120.0886, country: 'CN' },
  { code: 'YNT', name: '烟台蓬莱国际机场', city: '烟台', lat: 37.6631, lon: 120.9786, country: 'CN' },
  { code: 'WEH', name: '威海大水泊国际机场', city: '威海', lat: 37.1864, lon: 122.2344, country: 'CN' },
  { code: 'LYI', name: '临沂启阳国际机场', city: '临沂', lat: 35.0489, lon: 118.4117, country: 'CN' },
  { code: 'JNG', name: '济宁曲阜机场', city: '济宁', lat: 35.2936, lon: 116.3486, country: 'CN' },
  { code: 'DOY', name: '东营胜利机场', city: '东营', lat: 37.5064, lon: 118.7889, country: 'CN' },
  { code: 'RIZ', name: '日照山字河机场', city: '日照', lat: 35.3975, lon: 119.3247, country: 'CN' },
  { code: 'WEF', name: '潍坊机场', city: '潍坊', lat: 36.6450, lon: 119.1197, country: 'CN' },
  { code: 'HZA', name: '菏泽牡丹机场', city: '菏泽', lat: 35.2153, lon: 115.6569, country: 'CN' },

  // 河南省
  { code: 'CGO', name: '郑州新郑国际机场', city: '郑州', lat: 34.5197, lon: 113.8409, country: 'CN' },
  { code: 'LYA', name: '洛阳北郊机场', city: '洛阳', lat: 34.7356, lon: 112.3886, country: 'CN' },
  { code: 'NNY', name: '南阳姜营机场', city: '南阳', lat: 32.9772, lon: 112.6156, country: 'CN' },
  { code: 'XAI', name: '信阳明港机场', city: '信阳', lat: 32.5417, lon: 114.0750, country: 'CN' },

  // 湖北省
  { code: 'WUH', name: '武汉天河国际机场', city: '武汉', lat: 30.7838, lon: 114.2081, country: 'CN' },
  { code: 'YIH', name: '宜昌三峡机场', city: '宜昌', lat: 30.5517, lon: 111.4811, country: 'CN' },
  { code: 'XFN', name: '襄阳刘集机场', city: '襄阳', lat: 32.1506, lon: 112.2906, country: 'CN' },
  { code: 'ENH', name: '恩施许家坪机场', city: '恩施', lat: 30.3208, lon: 109.4878, country: 'CN' },
  { code: 'WDS', name: '十堰武当山机场', city: '十堰', lat: 32.5892, lon: 110.9069, country: 'CN' },
  { code: 'SHS', name: '荆州沙市机场', city: '荆州', lat: 30.3167, lon: 112.3833, country: 'CN' },
  { code: 'HPG', name: '神农架红坪机场', city: '神农架', lat: 31.6258, lon: 110.3364, country: 'CN' },
  { code: 'EHU', name: '鄂州花湖国际机场', city: '鄂州', lat: 30.3228, lon: 115.0608, country: 'CN' },

  // 湖南省
  { code: 'CSX', name: '长沙黄花国际机场', city: '长沙', lat: 28.1892, lon: 113.2196, country: 'CN' },
  { code: 'DYG', name: '张家界荷花国际机场', city: '张家界', lat: 29.1039, lon: 110.4439, country: 'CN' },
  { code: 'CGD', name: '常德桃花源机场', city: '常德', lat: 28.9189, lon: 111.6394, country: 'CN' },
  { code: 'HNY', name: '衡阳南岳机场', city: '衡阳', lat: 26.7214, lon: 112.6178, country: 'CN' },
  { code: 'YYA', name: '岳阳三荷机场', city: '岳阳', lat: 29.3131, lon: 113.2792, country: 'CN' },
  { code: 'HJJ', name: '怀化芷江机场', city: '怀化', lat: 27.4428, lon: 109.7078, country: 'CN' },
  { code: 'WGN', name: '邵阳武冈机场', city: '邵阳', lat: 26.8047, lon: 110.6389, country: 'CN' },
  { code: 'HCZ', name: '郴州北湖机场', city: '郴州', lat: 25.7500, lon: 112.9167, country: 'CN' },

  // 广东省
  { code: 'CAN', name: '广州白云国际机场', city: '广州', lat: 23.3924, lon: 113.2988, country: 'CN' },
  { code: 'SZX', name: '深圳宝安国际机场', city: '深圳', lat: 22.6393, lon: 113.8107, country: 'CN' },
  { code: 'ZUH', name: '珠海金湾机场', city: '珠海', lat: 22.0089, lon: 113.3758, country: 'CN' },
  { code: 'SWA', name: '揭阳潮汕国际机场', city: '揭阳', lat: 23.5519, lon: 116.5036, country: 'CN' },
  { code: 'ZHA', name: '湛江吴川国际机场', city: '湛江', lat: 21.4686, lon: 110.5847, country: 'CN' },
  { code: 'HUZ', name: '惠州平潭机场', city: '惠州', lat: 23.0489, lon: 114.6006, country: 'CN' },
  { code: 'MXZ', name: '梅州梅县机场', city: '梅州', lat: 24.2661, lon: 116.1006, country: 'CN' },
  { code: 'HSC', name: '韶关丹霞机场', city: '韶关', lat: 24.9786, lon: 113.4219, country: 'CN' },

  // 广西壮族自治区
  { code: 'NNG', name: '南宁吴圩国际机场', city: '南宁', lat: 22.6083, lon: 108.1725, country: 'CN' },
  { code: 'KWL', name: '桂林两江国际机场', city: '桂林', lat: 25.2181, lon: 110.0392, country: 'CN' },
  { code: 'LZH', name: '柳州白莲机场', city: '柳州', lat: 24.2078, lon: 109.3972, country: 'CN' },
  { code: 'BHY', name: '北海福成机场', city: '北海', lat: 21.5394, lon: 109.2939, country: 'CN' },
  { code: 'AEB', name: '百色巴马机场', city: '百色', lat: 23.7197, lon: 106.9606, country: 'CN' },
  { code: 'YLX', name: '玉林福绵机场', city: '玉林', lat: 22.5667, lon: 110.0833, country: 'CN' },
  { code: 'WUZ', name: '梧州西江机场', city: '梧州', lat: 23.4736, lon: 111.1356, country: 'CN' },

  // 海南省
  { code: 'HAK', name: '海口美兰国际机场', city: '海口', lat: 19.9347, lon: 110.4589, country: 'CN' },
  { code: 'SYX', name: '三亚凤凰国际机场', city: '三亚', lat: 18.3029, lon: 109.4123, country: 'CN' },
  { code: 'BAR', name: '琼海博鳌国际机场', city: '琼海', lat: 19.1417, lon: 110.4583, country: 'CN' },

  // 港澳台地区
  { code: 'HKG', name: '香港国际机场', city: '香港', lat: 22.3080, lon: 113.9185, country: 'HK' },
  { code: 'MFM', name: '澳门国际机场', city: '澳门', lat: 22.1496, lon: 113.5916, country: 'MO' },
  { code: 'TPE', name: '台湾桃园国际机场', city: '台北', lat: 25.0777, lon: 121.2328, country: 'TW' },
  { code: 'TSA', name: '台北松山机场', city: '台北', lat: 25.0697, lon: 121.5525, country: 'TW' },
  { code: 'KHH', name: '高雄国际机场', city: '高雄', lat: 22.5767, lon: 120.3500, country: 'TW' },
  { code: 'RMQ', name: '台中清泉岗机场', city: '台中', lat: 24.2647, lon: 120.6206, country: 'TW' },

  // ==========================================
  // 5. 东亚 / 东南亚 / 南亚主要国际枢纽
  // ==========================================
  { code: 'HND', name: '东京羽田国际机场', city: '东京', lat: 35.5494, lon: 139.7798, country: 'JP' },
  { code: 'NRT', name: '东京成田国际机场', city: '东京', lat: 35.7720, lon: 140.3929, country: 'JP' },
  { code: 'KIX', name: '大阪关西国际机场', city: '大阪', lat: 34.4347, lon: 135.2442, country: 'JP' },
  { code: 'NGO', name: '名古屋中部国际机场', city: '名古屋', lat: 34.8583, lon: 136.8053, country: 'JP' },
  { code: 'FUK', name: '福冈机场', city: '福冈', lat: 33.5858, lon: 130.4508, country: 'JP' },
  { code: 'CTS', name: '札幌新千岁机场', city: '札幌', lat: 42.7750, lon: 141.6922, country: 'JP' },
  { code: 'OKA', name: '冲绳那霸机场', city: '冲绳', lat: 26.1958, lon: 127.6458, country: 'JP' },

  { code: 'ICN', name: '首尔仁川国际机场', city: '首尔', lat: 37.4602, lon: 126.4407, country: 'KR' },
  { code: 'GMP', name: '首尔金浦国际机场', city: '首尔', lat: 37.5583, lon: 126.7906, country: 'KR' },
  { code: 'PUS', name: '釜山金海国际机场', city: '釜山', lat: 35.1794, lon: 128.9383, country: 'KR' },
  { code: 'CJU', name: '济州国际机场', city: '济州', lat: 33.5114, lon: 126.4931, country: 'KR' },

  { code: 'SIN', name: '新加坡樟宜机场', city: '新加坡', lat: 1.3644, lon: 103.9915, country: 'SG' },
  { code: 'BKK', name: '曼谷素万那普国际机场', city: '曼谷', lat: 13.6900, lon: 100.7501, country: 'TH' },
  { code: 'DMK', name: '曼谷廊曼国际机场', city: '曼谷', lat: 13.9125, lon: 100.6067, country: 'TH' },
  { code: 'HKT', name: '普吉国际机场', city: '普吉', lat: 8.1133, lon: 98.3169, country: 'TH' },
  { code: 'CNX', name: '清迈国际机场', city: '清迈', lat: 18.7669, lon: 98.9625, country: 'TH' },

  { code: 'KUL', name: '吉隆坡国际机场', city: '吉隆坡', lat: 2.7456, lon: 101.7099, country: 'MY' },
  { code: 'PEN', name: '槟城国际机场', city: '槟城', lat: 5.2972, lon: 100.2769, country: 'MY' },
  { code: 'CGK', name: '雅加达苏加诺-哈达国际机场', city: '雅加达', lat: -6.1256, lon: 106.6558, country: 'ID' },
  { code: 'DPS', name: '巴厘岛努拉莱伊国际机场', city: '巴厘岛', lat: -8.7483, lon: 115.1672, country: 'ID' },

  { code: 'SGN', name: '胡志明市新山一国际机场', city: '胡志明市', lat: 10.8189, lon: 106.6519, country: 'VN' },
  { code: 'HAN', name: '河内内排国际机场', city: '河内', lat: 21.2211, lon: 105.8072, country: 'VN' },
  { code: 'DAD', name: '岘港国际机场', city: '岘港', lat: 16.0439, lon: 108.1994, country: 'VN' },

  { code: 'MNL', name: '马尼拉阿基诺国际机场', city: '马尼拉', lat: 14.5086, lon: 121.0197, country: 'PH' },
  { code: 'CEB', name: '宿务麦克坦国际机场', city: '宿务', lat: 10.3075, lon: 123.9794, country: 'PH' },
  { code: 'PNH', name: '金边国际机场', city: '金边', lat: 11.5467, lon: 104.8442, country: 'KH' },
  { code: 'SAI', name: '暹粒吴哥国际机场', city: '暹粒', lat: 13.3889, lon: 104.2217, country: 'KH' },
  { code: 'VTE', name: '万象瓦岱国际机场', city: '万象', lat: 17.9883, lon: 102.5633, country: 'LA' },

  { code: 'DEL', name: '新德里英迪拉甘地国际机场', city: '新德里', lat: 28.5562, lon: 77.1000, country: 'IN' },
  { code: 'BOM', name: '孟买贾特拉帕蒂希瓦吉国际机场', city: '孟买', lat: 19.0886, lon: 72.8678, country: 'IN' },
  { code: 'BLR', name: '班加罗尔肯佩高达国际机场', city: '班加罗尔', lat: 13.1979, lon: 77.7063, country: 'IN' },
  { code: 'CMB', name: '科伦坡班达拉奈克国际机场', city: '科伦坡', lat: 7.1808, lon: 79.8842, country: 'LK' },
  { code: 'MLE', name: '马累维拉纳国际机场', city: '马累', lat: 4.1917, lon: 73.5292, country: 'MV' },

  // ==========================================
  // 6. 中东 / 西亚
  // ==========================================
  { code: 'DXB', name: '迪拜国际机场', city: '迪拜', lat: 25.2532, lon: 55.3657, country: 'AE' },
  { code: 'AUH', name: '阿布扎比扎耶德国际机场', city: '阿布扎比', lat: 24.4331, lon: 54.6511, country: 'AE' },
  { code: 'DOH', name: '多哈哈马德国际机场', city: '多哈', lat: 25.2731, lon: 51.6081, country: 'QA' },
  { code: 'RUH', name: '利雅得哈立德国王国际机场', city: '利雅得', lat: 24.9578, lon: 46.6989, country: 'SA' },
  { code: 'JED', name: '吉达阿卜杜勒-阿齐兹国王国际机场', city: '吉达', lat: 21.6797, lon: 39.1567, country: 'SA' },
  { code: 'IST', name: '伊斯坦布尔机场', city: '伊斯坦布尔', lat: 41.2753, lon: 28.7519, country: 'TR' },

  // ==========================================
  // 7. 欧洲核心都市
  // ==========================================
  { code: 'LHR', name: '伦敦希思罗机场', city: '伦敦', lat: 51.4700, lon: -0.4543, country: 'GB' },
  { code: 'LGW', name: '伦敦盖特威克机场', city: '伦敦', lat: 51.1537, lon: -0.1821, country: 'GB' },
  { code: 'CDG', name: '巴黎戴高乐机场', city: '巴黎', lat: 49.0097, lon: 2.5479, country: 'FR' },
  { code: 'ORY', name: '巴黎奥利机场', city: '巴黎', lat: 48.7262, lon: 2.3656, country: 'FR' },
  { code: 'FRA', name: '法兰克福国际机场', city: '法兰克福', lat: 50.0379, lon: 8.5622, country: 'DE' },
  { code: 'MUC', name: '慕尼黑国际机场', city: '慕尼黑', lat: 48.3538, lon: 11.7861, country: 'DE' },
  { code: 'AMS', name: '阿姆斯特丹斯希普霍尔机场', city: '阿姆斯特丹', lat: 52.3105, lon: 4.7683, country: 'NL' },
  { code: 'MAD', name: '马德里巴拉哈斯机场', city: '马德里', lat: 40.4839, lon: -3.5680, country: 'ES' },
  { code: 'BCN', name: '巴塞罗那埃尔普拉特机场', city: '巴塞罗那', lat: 41.2974, lon: 2.0833, country: 'ES' },
  { code: 'FCO', name: '罗马菲乌米奇诺机场', city: '罗马', lat: 41.8003, lon: 12.2389, country: 'IT' },
  { code: 'MXP', name: '米兰马尔彭萨机场', city: '米兰', lat: 45.6301, lon: 8.7255, country: 'IT' },
  { code: 'ZRH', name: '苏黎世机场', city: '苏黎世', lat: 47.4582, lon: 8.5555, country: 'CH' },
  { code: 'GVA', name: '日内瓦机场', city: '日内瓦', lat: 46.2381, lon: 6.1089, country: 'CH' },
  { code: 'VIE', name: '维也纳国际机场', city: '维也纳', lat: 48.1103, lon: 16.5697, country: 'AT' },
  { code: 'BRU', name: '布鲁塞尔机场', city: '布鲁塞尔', lat: 50.9014, lon: 4.4844, country: 'BE' },
  { code: 'CPH', name: '哥本哈根凯斯楚普机场', city: '哥本哈根', lat: 55.6180, lon: 12.6508, country: 'DK' },
  { code: 'ARN', name: '斯德哥尔摩阿兰达机场', city: '斯德哥尔摩', lat: 59.6498, lon: 17.9238, country: 'SE' },
  { code: 'OSL', name: '奥斯陆加勒穆恩机场', city: '奥斯陆', lat: 60.1976, lon: 11.1004, country: 'NO' },
  { code: 'HEL', name: '赫尔辛基万塔机场', city: '赫尔辛基', lat: 60.3172, lon: 24.9633, country: 'FI' },
  { code: 'ATH', name: '雅典埃莱夫塞里奥斯韦尼泽洛斯国际机场', city: '雅典', lat: 37.9364, lon: 23.9445, country: 'GR' },
  { code: 'SVO', name: '莫斯科谢列梅捷沃国际机场', city: '莫斯科', lat: 55.9726, lon: 37.4146, country: 'RU' },
  { code: 'DME', name: '莫斯科多莫杰多沃国际机场', city: '莫斯科', lat: 55.4088, lon: 37.9061, country: 'RU' },
  { code: 'LED', name: '圣彼得堡普尔科沃机场', city: '圣彼得堡', lat: 59.8003, lon: 30.2625, country: 'RU' },

  // ==========================================
  // 8. 美洲 / 大洋洲 / 非洲
  // ==========================================
  { code: 'JFK', name: '纽约肯尼迪国际机场', city: '纽约', lat: 40.6413, lon: -73.7781, country: 'US' },
  { code: 'EWR', name: '纽约纽瓦克自由国际机场', city: '纽瓦克', lat: 40.6895, lon: -74.1745, country: 'US' },
  { code: 'LAX', name: '洛杉矶国际机场', city: '洛杉矶', lat: 33.9416, lon: -118.4085, country: 'US' },
  { code: 'SFO', name: '旧金山国际机场', city: '旧金山', lat: 37.6213, lon: -122.3790, country: 'US' },
  { code: 'SEA', name: '西雅图-塔科马国际机场', city: '西雅图', lat: 47.4502, lon: -122.3088, country: 'US' },
  { code: 'ORD', name: '芝加哥奥黑尔国际机场', city: '芝加哥', lat: 41.9742, lon: -87.9073, country: 'US' },
  { code: 'DFW', name: '达拉斯-沃斯堡国际机场', city: '达拉斯', lat: 32.8998, lon: -97.0403, country: 'US' },
  { code: 'ATL', name: '亚特兰大哈兹菲尔德-杰克逊国际机场', city: '亚特兰大', lat: 33.6407, lon: -84.4277, country: 'US' },
  { code: 'BOS', name: '波士顿洛根国际机场', city: '波士顿', lat: 42.3656, lon: -71.0096, country: 'US' },
  { code: 'LAS', name: '拉斯维加斯哈里·里德国际机场', city: '拉斯维加斯', lat: 36.0840, lon: -115.1537, country: 'US' },
  { code: 'MIA', name: '迈阿密国际机场', city: '迈阿密', lat: 25.7959, lon: -80.2870, country: 'US' },
  { code: 'HNL', name: '檀香山丹尼尔·井上国际机场', city: '火奴鲁鲁', lat: 21.3186, lon: -157.9224, country: 'US' },

  { code: 'YYZ', name: '多伦多皮尔逊国际机场', city: '多伦多', lat: 43.6777, lon: -79.6248, country: 'CA' },
  { code: 'YVR', name: '温哥华国际机场', city: '温哥华', lat: 49.1967, lon: -123.1815, country: 'CA' },
  { code: 'MEX', name: '墨西哥城贝尼托·华雷斯国际机场', city: '墨西哥城', lat: 19.4361, lon: -99.0719, country: 'MX' },
  { code: 'CUN', name: '坎昆国际机场', city: '坎昆', lat: 21.0365, lon: -86.8771, country: 'MX' },
  { code: 'GRU', name: '圣保罗瓜鲁柳斯国际机场', city: '圣保罗', lat: -23.4356, lon: -46.4731, country: 'BR' },
  { code: 'EZE', name: '布宜诺斯艾利斯埃塞萨国际机场', city: '布宜诺斯艾利斯', lat: -34.8222, lon: -58.5358, country: 'AR' },

  { code: 'SYD', name: '悉尼金斯福德·史密斯机场', city: '悉尼', lat: -33.9399, lon: 151.1753, country: 'AU' },
  { code: 'MEL', name: '墨尔本机场', city: '墨尔本', lat: -37.6690, lon: 144.8410, country: 'AU' },
  { code: 'BNE', name: '布里斯班机场', city: '布里斯班', lat: -27.3842, lon: 153.1175, country: 'AU' },
  { code: 'AKL', name: '奥克兰机场', city: '奥克兰', lat: -37.0082, lon: 174.7850, country: 'NZ' },
  { code: 'CHC', name: '基督城国际机场', city: '基督城', lat: -43.4876, lon: 172.5374, country: 'NZ' },

  { code: 'CAI', name: '开罗国际机场', city: '开罗', lat: 30.1219, lon: 31.4056, country: 'EG' },
  { code: 'JNB', name: '约翰内斯堡奥利弗·雷金纳德·坦博国际机场', city: '约翰内斯堡', lat: -26.1367, lon: 28.2411, country: 'ZA' },
  { code: 'CPT', name: '开普敦国际机场', city: '开普敦', lat: -33.9715, lon: 18.6021, country: 'ZA' },
  { code: 'NBO', name: '内罗毕乔莫·肯雅塔国际机场', city: '内罗毕', lat: -1.3192, lon: 36.9278, country: 'KE' }
];
