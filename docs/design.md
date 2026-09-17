# 健康生活打卡养成 App — 设计方案

> 版本 v1.0 ｜ 目标平台 HarmonyOS NEXT（Stage 模型）｜ 状态：待评审

---

## 1. 作品定位

### 服务对象

18–28 岁大学生与年轻上班族。三餐主要靠食堂、外卖、便利店解决，作息不规律，有改善健康的意愿，但缺方法、难坚持。

### 三个真实痛点 → 三个设计对策

| 痛点 | 对策 |
|---|---|
| 想记录但嫌麻烦 | 极简打卡：3 步内完成；预置"食堂 / 外卖 / 便利店"场景化食物库，不需要搜索 |
| 记录了看不懂 | 把数字翻译成建议：不只显示热量，直接给出"今晚少吃主食""今天补个鸡蛋"这类可执行的话 |
| 坚持不下去 | 养成机制：连续天数、成长阶段、徽章墙、断卡补签保护 |

### 原创性落点

1. 场景化食物库——不是通用食物库，而是按目标用户真实的三餐来源（食堂 / 外卖 / 便利店 / 自做）组织的
2. 断卡恢复机制——打卡类应用最大的失败点是"断一天就彻底放弃"。设计"补签券 + 连续保护"，用行为经济学对抗放弃心理
3. 健康分——把热量达成度、营养素配比、打卡完成度综合为一个 0–100 的分数，给用户一个可感知的进步标尺

### 明确不用到的能力

以下能力在本方案中不涉及

- Health Service Kit（个人开发者拿不到心率/睡眠等高阶数据，且需先上架）
- 云侧大模型 / 拍照识别食物（前者要求应用已上架 AGC；后者官方 Core Vision Kit 的多目标识别不含食物分类）
- 传感器、定位、后台长时任务、地图服务
- 账号体系与云端同步

---

## 2. 功能范围

- 引导：录入身高 / 体重 / 出生年 / 性别 / 活动量 / 目标 → 生成每日热量与营养素目标
- 打卡：饮水、三餐（选场景 → 选食物 → 选份数）、运动、作息
- 分析：BMR / TDEE、当日热量收支、三大营养素配比、健康分
- 建议：依据分析结果生成 2–3 条具体建议
- 养成：连续天数、成长阶段、徽章墙、补签
- 看板：周 / 月热量趋势、营养素占比、健康分曲线
- 提醒：打卡提醒（代理提醒）

---

## 3. 数据模型

数据库：`relationalStore`（`@kit.ArkData`），共 8 张表。

### 3.1 枚举定义

```
Gender          0=未知 1=男 2=女
ActivityLevel   1=久坐 2=轻度 3=中度 4=高度 5=极高
Goal            0=减脂 1=维持 2=增肌

MealType        0=早餐 1=午餐 2=晚餐 3=加餐
FoodCategory    0=主食 1=荤菜 2=素菜 3=汤 4=饮品 5=零食 6=水果 7=蛋奶
SceneFlag       位标记：1=食堂 2=外卖 4=便利店 8=自做

ActivityType    0=走路 1=跑步 2=骑行 3=球类 4=力量 5=游泳 6=其它
Intensity       1=低 2=中 3=高

CheckinFlag     位标记：1=早餐 2=午餐 4=晚餐 8=运动 16=饮水 32=作息
```

### 3.2 DDL

```sql
-- 用户档案（单行，id 固定为 1）
CREATE TABLE IF NOT EXISTS user_profile (
  id               INTEGER PRIMARY KEY,
  nickname         TEXT    NOT NULL DEFAULT '',
  gender           INTEGER NOT NULL DEFAULT 0,
  birth_year       INTEGER NOT NULL DEFAULT 2000,
  height_cm        REAL    NOT NULL DEFAULT 170,
  weight_kg        REAL    NOT NULL DEFAULT 60,
  activity_level   INTEGER NOT NULL DEFAULT 2,
  goal             INTEGER NOT NULL DEFAULT 1,
  target_weight_kg REAL    NOT NULL DEFAULT 60,
  updated_at       INTEGER NOT NULL DEFAULT 0
);

-- 场景化食物库
CREATE TABLE IF NOT EXISTS food_item (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  name             TEXT    NOT NULL,
  category         INTEGER NOT NULL DEFAULT 0,
  scene_flags      INTEGER NOT NULL DEFAULT 0,
  unit_name        TEXT    NOT NULL DEFAULT '份',
  unit_gram        REAL    NOT NULL DEFAULT 100,
  kcal_per_100g    REAL    NOT NULL DEFAULT 0,
  protein_per_100g REAL    NOT NULL DEFAULT 0,
  fat_per_100g     REAL    NOT NULL DEFAULT 0,
  carb_per_100g    REAL    NOT NULL DEFAULT 0,
  is_custom        INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_food_scene ON food_item(scene_flags);

-- 用餐记录（冗余存营养快照）
CREATE TABLE IF NOT EXISTS meal_record (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  record_date TEXT    NOT NULL,           -- 'YYYY-MM-DD'
  meal_type   INTEGER NOT NULL,
  scene       INTEGER NOT NULL DEFAULT 1,
  food_id     INTEGER NOT NULL,
  food_name   TEXT    NOT NULL,           -- 快照：食物改名/删除后历史仍可读
  amount      REAL    NOT NULL DEFAULT 1,
  kcal        REAL    NOT NULL DEFAULT 0,
  protein_g   REAL    NOT NULL DEFAULT 0,
  fat_g       REAL    NOT NULL DEFAULT 0,
  carb_g      REAL    NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_meal_date ON meal_record(record_date);

-- 运动记录
CREATE TABLE IF NOT EXISTS activity_record (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  record_date   TEXT    NOT NULL,
  activity_type INTEGER NOT NULL,
  duration_min  INTEGER NOT NULL DEFAULT 0,
  intensity     INTEGER NOT NULL DEFAULT 2,
  kcal_burned   REAL    NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_activity_date ON activity_record(record_date);

-- 饮水记录
CREATE TABLE IF NOT EXISTS water_record (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  record_date TEXT    NOT NULL,
  amount_ml   INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_water_date ON water_record(record_date);

-- 每日汇总（物化）
CREATE TABLE IF NOT EXISTS daily_summary (
  record_date   TEXT PRIMARY KEY,
  intake_kcal   REAL    NOT NULL DEFAULT 0,
  burned_kcal   REAL    NOT NULL DEFAULT 0,
  protein_g     REAL    NOT NULL DEFAULT 0,
  fat_g         REAL    NOT NULL DEFAULT 0,
  carb_g        REAL    NOT NULL DEFAULT 0,
  water_ml      INTEGER NOT NULL DEFAULT 0,
  activity_min  INTEGER NOT NULL DEFAULT 0,
  checkin_flags INTEGER NOT NULL DEFAULT 0,
  score         INTEGER NOT NULL DEFAULT 0,
  streak_days   INTEGER NOT NULL DEFAULT 0
);

-- 连续打卡
CREATE TABLE IF NOT EXISTS checkin_streak (
  record_date     TEXT PRIMARY KEY,
  completed_items INTEGER NOT NULL DEFAULT 0,
  is_broken       INTEGER NOT NULL DEFAULT 0,
  repair_used     INTEGER NOT NULL DEFAULT 0
);

-- 成就徽章
CREATE TABLE IF NOT EXISTS badge (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  badge_code  TEXT    NOT NULL UNIQUE,
  unlocked_at INTEGER NOT NULL
);
```

### 3.3 四个关键设计决策

- `meal_record` 冗余存营养快照（`food_name` / `kcal` / `protein_g` / `fat_g` / `carb_g`）
  食物库数据后期修正时，不应改变历史记录。若只存 `food_id`，改一次食物库就会篡改全部历史。
- `daily_summary` 物化
  看板页不扫全量明细，只读一张汇总表；在打卡写入时同步更新，避免每次打开首页都做聚合查询。
- `record_date` 用文本 `'YYYY-MM-DD'`
  便于按天分组与跨天切分，避开时间戳与时区换算的坑。
- `checkin_flags` 用位标记
  一个整数存下"今天完成了哪几项打卡"，比六个布尔列更省事，扩展新打卡项不需要改表结构。

---

## 4. 核心算法

`engine/` 层全部是纯函数，不依赖任何系统 API，可用 `src/test` 本地单元测试 100% 覆盖。

### 4.1 BMR（基础代谢率，Mifflin-St Jeor 公式）

```
男：BMR = 10 × 体重(kg) + 6.25 × 身高(cm) − 5 × 年龄 + 5
女：BMR = 10 × 体重(kg) + 6.25 × 身高(cm) − 5 × 年龄 − 161
```

### 4.2 TDEE（每日总消耗）

```
TDEE = BMR × 活动系数
活动系数：1 久坐 1.2 ｜ 2 轻度 1.375 ｜ 3 中度 1.55 ｜ 4 高度 1.725 ｜ 5 极高 1.9
```

### 4.3 每日目标热量

```
减脂：TDEE × 0.85   （下限保护：不低于 BMR × 1.1）
维持：TDEE
增肌：TDEE × 1.10
```

### 4.4 宏量营养素目标占比

```
减脂：蛋白 30% / 脂肪 25% / 碳水 45%
维持：蛋白 25% / 脂肪 25% / 碳水 50%
增肌：蛋白 30% / 脂肪 20% / 碳水 50%
换算：蛋白 4 kcal/g ｜ 碳水 4 kcal/g ｜ 脂肪 9 kcal/g
```

### 4.5 运动消耗（MET 法）

```
kcal = MET × 体重(kg) × 时长(h) × 强度系数
MET 参考：走路 3.0 ｜ 慢跑 7.0 ｜ 快跑 10.0 ｜ 骑行 6.0
          球类 6.5 ｜ 力量 5.0 ｜ 游泳 7.0 ｜ 其它 4.0
强度系数：低 0.85 ｜ 中 1.0 ｜ 高 1.15
```

### 4.6 健康分（0–100）

| 维度 | 满分 | 计算方式 |
|---|---|---|
| 热量达成度 | 40 | `40 × (1 − |摄入 − 目标| / 目标)`，下限 0 |
| 营养素配比 | 30 | 三大营养素实际占比与目标占比偏差之和，偏差越小分越高 |
| 打卡完成度 | 30 | `30 × 已完成项数 / 总项数` |

### 4.7 建议生成（规则库）

`AdviceEngine` 按优先级匹配规则，取前 2–3 条输出：

| 触发条件 | 建议文案 |
|---|---|
| 摄入 > 目标 × 1.15 | 今天热量超了，晚上可以只吃点蔬菜和蛋白质 |
| 摄入 < 目标 × 0.6 且已过 20:00 | 今天吃得太少了，长期低于基础代谢会掉肌肉 |
| 蛋白占比 < 目标 × 0.8 | 蛋白质摄入偏少，加个鸡蛋或一份鸡胸 |
| 脂肪占比 > 目标 × 1.3 | 脂肪偏高了，明天少点油炸和红烧类 |
| 碳水占比 > 目标 × 1.3 | 主食偏多，可以把一半米饭换成杂粮或蔬菜 |
| 饮水 < 1200ml 且已过 18:00 | 今天水喝得太少，睡前补两杯 |
| 运动时长为 0 且已过 20:00 | 今天还没动，饭后散步 20 分钟也算 |
| 连续打卡 ≥ 7 天 | 已经坚持一周了，保持住 |

> 以上公式与阈值为参考值，需在真机上用真实数据校准后定稿。

---

## 5. 页面与导航

| 页面 | 职责 |
|---|---|
| `OnboardingPage` | 首次启动录入档案，计算 BMR/TDEE，生成初始目标 |
| `HomePage` | 今日进度环（热量收支）、四类打卡入口、今日建议 |
| `CheckinPage` | 选类型 → 选场景 → 选食物 → 选份数 → 提交 |
| `AnalysisPage` | 周 / 月趋势、营养素占比、健康分曲线 |
| `ProfilePage` | 档案编辑、连续天数、徽章墙、提醒设置 |

导航使用 `Navigation` + `NavPathStack`：

```
Navigation(stack)
 └─ HomePage（根页面）
     ├─ OnboardingPage    仅首次启动进入
     ├─ CheckinPage       点打卡入口
     ├─ AnalysisPage      点分析
     └─ ProfilePage       点我的
```

注意：`CheckinPage` 未提交就返回时需要确认，避免误触丢失录入。

---

## 6. 工程目录分层

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets
├─ pages/                        # 只写 UI，不碰数据库、不碰系统 API
│   ├─ HomePage.ets
│   ├─ CheckinPage.ets
│   ├─ AnalysisPage.ets
│   ├─ ProfilePage.ets
│   └─ OnboardingPage.ets
├─ viewmodel/                    # 页面状态 + 业务编排
│   ├─ HomeViewModel.ets
│   ├─ CheckinViewModel.ets
│   ├─ AnalysisViewModel.ets
│   └─ ProfileViewModel.ets
├─ model/                        # 实体与枚举，纯数据无逻辑
│   ├─ UserProfile.ets
│   ├─ FoodItem.ets
│   ├─ MealRecord.ets
│   ├─ ActivityRecord.ets
│   ├─ DailySummary.ets
│   └─ Enums.ets
├─ database/                     # 持久化
│   ├─ DbHelper.ets              # 建库建表、版本升级
│   ├─ UserProfileDao.ets
│   ├─ FoodItemDao.ets
│   ├─ MealRecordDao.ets
│   ├─ ActivityRecordDao.ets
│   └─ DailySummaryDao.ets
├─ service/                      # 与系统能力打交道
│   ├─ CheckinService.ets        # 打卡编排：写记录 → 更新汇总 → 算分 → 查徽章
│   ├─ StreakService.ets         # 连续天数、补签
│   ├─ BadgeService.ets          # 徽章解锁判定
│   └─ ReminderService.ets       # 代理提醒
├─ engine/                       # 纯函数，零系统依赖，全部单元测试覆盖
│   ├─ EnergyCalculator.ets      # BMR / TDEE / 运动消耗
│   ├─ NutritionAnalyzer.ets     # 营养素配比分析
│   ├─ HealthScoreCalculator.ets
│   └─ AdviceEngine.ets          # 建议生成规则库
└─ utils/
    ├─ DateUtils.ets
    └─ FormatUtils.ets
```

分层原则：页面不碰数据库、不碰系统 API；`service` 层不碰 UI；`engine` 层不依赖任何系统能力。

`engine/` 是本设计的重点：这些公式最容易算错（BMR 有多个版本、活动系数取值、配比阈值），纯函数用单元测试能测得比真机运行还彻底。

现实收益：`engine/` + `model/` + `database/` 三层不需要设备与签名即可开发和验证，可与签名手续并行推进。

---

## 7. 关键时序

### 打卡

```
用户选食物 → CheckinViewModel.submit()
 → 查 food_item 取营养数据
 → 插入 meal_record（带营养快照）
 → CheckinService 重算当日 daily_summary
 → StreakService 更新连续天数
 → BadgeService 检查徽章解锁
 → 返回 Home：进度环动画更新 + 徽章弹出
```

### 首次启动

```
OnboardingPage 提交
 → 写 user_profile
 → EnergyCalculator 计算 BMR / TDEE
 → 生成每日热量与营养素目标
 → 进入 HomePage
```

### 打开首页

```
HomeViewModel.load()
 → 读 user_profile + 今日 daily_summary（不存在则初始化一条）
 → AdviceEngine 生成今日建议
 → 渲染
```

### 跨天处理

```
应用启动 / 首页加载时
 → 比较 daily_summary 中最新 record_date 与今天
 → 若今天无记录：新建 daily_summary；并结算昨日连续打卡状态
```

---

## 8. 权限清单

| 权限 | 授权方式 | 用途 |
|---|---|---|
| `ohos.permission.PUBLISH_AGENT_REMINDER` | system_grant（安装即授予） | 打卡提醒 |

---

## 9. 分期落地

| 阶段 | 内容 | 需要设备 / 签名 |
|---|---|---|
| 0 | 建工程 + 真机签名跑通 | 需要（依赖开发者实名认证） |
| 1 | `DbHelper` + 8 张表 + 全部 DAO + 实体类 + 食物库导入 | 不需要 |
| 2 | `engine/` 四个引擎 + 单元测试 | 不需要 |
| 3 | `OnboardingPage` + `HomePage`（进度环、打卡入口、今日建议） | 预览器可验 |
| 4 | `CheckinPage` + 食物库浏览与选中 | 预览器可验 |
| 5 | `AnalysisPage`（趋势图、占比图） | 预览器可验 |
| 6 | `ProfilePage` + 徽章墙 + 提醒 | 提醒需真机验 |
| 7 | 动画与视觉打磨 | 需真机 |

并行策略：开发者实名认证与阶段 1、2 可同时进行。这两阶段产出的代码不依赖任何设备，签名办好后可直接接续，不浪费工期。

---

## 10. 待确认项与风险

| # | 项 | 说明 |
|---|---|---|
| 1 | 开发者实名认证 | 真机安装必须签名，签名必须实名。这是阶段 0 的前置，且有审核周期，应最早启动 |
| 2 | 图表组件 | 环形进度可用原生 `Progress`（`ProgressType.Ring`）。折线图 / 柱状图官方无现成组件，需确认是用 Canvas 自绘还是三方库（ohpm 上有 `@ohos/mpchart` 等） |
| 3 | 预览器能力边界 | 预览器不执行完整编译，数据库等系统能力可能不可用。阶段 3–5 是否真能在预览器验证，需实测 |
| 4 | ArkTS 严格语法 | 比 TypeScript 严格：不能用 `any`、对象字面量必须标注类型、不支持结构化类型。这是主要踩坑区 |
| 5 | 食物库数据准确性 | 种子数据为常见食物成分的近似参考值，正式使用前应人工校对 |
| 6 | 算法阈值校准 | 第 4 节的系数与阈值需用真实数据校准 |

---

## 附录：食物库种子数据

文件位置：`entry/src/main/resources/rawfile/food_seed.json`

- 结构与字段含义见文件内 `schema` 字段说明
- 预置约 110 条，覆盖主食 / 荤菜 / 素菜 / 汤 / 饮品 / 零食 / 水果 / 蛋奶 八类
- 每条带 `scene` 数组，标识该条目适用的场景（食堂 / 外卖 / 便利店 / 自做）
- 运行时通过 `resourceManager.getRawFileContent('food_seed.json')` 读取，首次启动导入 `food_item` 表
- 营养数值为近似参考值，需人工校对后使用
