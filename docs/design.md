# 健康生活打卡养成 App — 设计方案

> 版本 v1.1 ｜ 目标平台 HarmonyOS NEXT（Stage 模型）｜ 状态：**已实现**（阶段 0–8 完成）
>
> v1.1 相对 v1.0 的变更：提醒方案由代理提醒改为系统日历日程；新增宠物养成系统（配置驱动）；导航由 Navigation 栈改为悬浮 Dock + 全屏覆盖；补齐工程目录与权限清单；待确认项按实测结论重写。

---

## 1. 作品定位

### 服务对象

18–28 岁大学生与年轻上班族。三餐主要靠食堂、外卖、便利店解决，作息不规律，有改善健康的意愿，但缺方法、难坚持。

### 三个真实痛点 → 三个设计对策

| 痛点 | 对策 |
|---|---|
| 想记录但嫌麻烦 | 极简打卡：3 步内完成；预置"食堂 / 外卖 / 便利店"场景化食物库，不需要搜索 |
| 记录了看不懂 | 把数字翻译成建议：不只显示热量，直接给出"今晚少吃主食""今天补个鸡蛋"这类可执行的话 |
| 坚持不下去 | 养成机制：连续天数、**宠物伙伴**、成长阶段、徽章墙、断卡补签保护 |

### 原创性落点

1. **场景化食物库**——不是通用食物库，而是按目标用户真实的三餐来源（食堂 / 外卖 / 便利店 / 自做）组织的
2. **宠物伙伴与健康数据的绑定**——把"照顾宠物"和"坚持记录"做成同一件事：宠物的饱食 / 活力 / 心情三项状态**全部直接来自当天真实记录**，不引入喂食、清洁这类与健康无关的独立玩法
3. **配置驱动的造型系统**——宠物造型、阶段数、进阶门槛、表情位置全部来自一份 JSON 配置，具备可扩展性与可替换性
4. **断卡恢复机制**——打卡类应用最大的失败点是"断一天就彻底放弃"。设计"补签券 + 连续保护"，用行为经济学对抗放弃心理
5. **健康分**——把热量达成度、营养素配比、打卡完成度综合为一个 0–100 的分数，给用户一个可感知的进步标尺

### 明确不用到的能力

以下能力在本方案中不涉及，均为主动取舍而非遗漏：

| 能力 | 不用的原因 |
|---|---|
| Health Service Kit | 个人开发者拿不到心率 / 睡眠等高阶数据，且需先上架 |
| 云侧大模型 / 拍照识别食物 | 前者要求应用已上架 AGC；后者官方 Core Vision Kit 的多目标识别不含食物分类 |
| **代理提醒（reminderAgentManager）** | **未申请权益的应用提醒数量上限视为 0，功能完全不可用**。官方要求邮件申请且审核周期以月计，学生作品周期内不可控。改用系统日历日程实现，不需要任何权益审批 |
| 传感器、定位、后台长时任务、地图服务 | 与本应用的核心场景无关 |
| 账号体系与云端同步 | 单机应用，无多端同步需求 |

---

## 2. 功能范围

- **引导**：录入身高 / 体重 / 出生年 / 性别 / 活动量 / 目标 → 生成每日热量与营养素目标
- **打卡**：饮水、三餐（选场景 → 选食物 → 选份数）、运动、作息
- **分析**：BMR / TDEE、当日热量收支、三大营养素配比、健康分
- **建议**：依据分析结果生成 2–3 条具体建议
- **养成**：连续天数、宠物伙伴（成长阶段 + 实时表情）、徽章墙、补签
- **看板**：7 天 / 30 天热量趋势柱状图、营养素占比条、日均热量 / 消耗 / 健康分、摄入达标天数
- **提醒**：早 / 午 / 晚三个饭点的打卡提醒（写入系统日历日程）

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

**宠物数据不在这 8 张表里**——它不吃任何查询、聚合、历史追溯，只有"当前养的是哪个物种"这一个值，因此存在 `preferences`（`pet_setting`）里，与提醒配置同样单独一个文件。

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
未填性别：取男女均值
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

边界处理：无目标或无摄入时该维度不计分，而不是记 0 分——新用户第一次打开不该看到 0 分。

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

> 配比类规则只在**当天有饮食记录**时才判定。否则新用户第一天没记饮食，就会收到"脂肪偏高"这种误报。

> 以上公式与阈值为参考值，需在真机上用真实数据校准后定稿。

---

## 5. 宠物养成系统

宠物是"坚持不下去"这个痛点的核心对策。设计上有一条不可动摇的原则：

> **宠物的状态完全由用户的真实健康记录推导，不引入任何独立玩法。**

没有喂食道具、没有清洁、没有金币。想让宠物状态好，唯一的路就是记录饮食、运动和饮水。这样"照顾宠物"和"照顾自己"是同一个动作，激励不需要额外解释。

### 5.1 三项状态

| 状态 | 计算 | 数据来源 |
|---|---|---|
| 饱食 | `min(主餐数 / 3, 1) × 100` | 当天早 / 午 / 晚记录了几餐（加餐不计） |
| 活力 | `min(运动分钟 / 20, 1) × 50 + (饮水达标 ? 50 : 0)` | 运动时长 + 饮水目标达成 |
| 心情 | `min(连续天数 / 7, 1) × 100` | 连续打卡天数 |

表情由三项均值决定：≥70 开心 ｜ ≥35 普通 ｜ 否则难过。

### 5.2 台词优先级

台词给的是**最欠缺那一项的可行建议**，不是笼统的加油：

```
1. 第一阶段且配置了 hint          → 用它（如"再记录 3 天就能孵化了"，给一个短期目标）
2. 三项都 ≥ 80                    → "今天把我照顾得很好，继续保持"
3. 饱食最低 → "肚子有点饿了，记一餐吧"
4. 活力最低 → "想活动一下，陪我动一动？"
5. 心情最低 → "好久没一起打卡了，别断呀"
```

判断最低项时**每个分支都同时比较另外两项**。只写"饱食 ≤ 活力"会在并列时（饱食与活力都是满分）把真正最低的心情漏掉——这个 bug 已有专门的单元测试守着。

### 5.3 阶段：配置驱动

**代码里不存在任何阶段门槛常量。** 阶段数、阶段名、进阶天数、体型、图片全部来自 `pet_config.json`：

```json
{
  "code": "duck", "label": "小鸭",
  "face": { "cx": 14, "cy": -10, "single": true, ... },
  "stages": [
    { "name": "蛋",   "minDays": 0,  "scale": 1.0,  "image": "pets/duck_1.svg",
      "hint": "再记录 {n} 天就能孵化了",
      "face": { "cx": 0, "cy": 8, "single": false, ... } },
    { "name": "小鸭", "minDays": 7,  "scale": 0.85, "image": "pets/duck_2.svg" },
    { "name": "大鸭", "minDays": 30, "scale": 1.0,  "image": "pets/duck_3.svg" }
  ]
}
```

四个可配置维度：

| 字段 | 作用 |
|---|---|
| `minDays` | 触发条件。累计记录天数达到即进入该阶段，取最后一个满足条件的 |
| `stages` 长度 | 阶段数。想 2 个就 2 个，想 5 个就 5 个，物种之间可以不同 |
| `image` | 造型图片。**SVG / PNG 通用，换图只改这一行文件名** |
| `hint` | 第一阶段的短期目标，`{n}` 自动替换为距下一阶段的天数 |

"累计记录天数"而不是"注册天数"是刻意的：后者躺着也能涨，前者必须真的记录过才算。

### 5.4 为什么先做小鸭和水果、且水果没有蛋阶段

小鸭走"蛋 → 小鸭 → 大鸭"是自然的孵化过程。而水果从蛋里孵出来显然不合理——这一点在实现上**不是靠特判**，而是靠配置本身：水果那三张图的名称与画面分别是"青果 / 半熟 / 熟透"，`minDays` 同样从 0 起。

也就是说，所谓"水果没有蛋阶段"并不需要额外逻辑，它只是配置数据的自然结果。这正是配置驱动的好处——语义差异交给数据，判定逻辑保持单一。

### 5.5 造型：图片画身体，表情单独叠加

```
┌─ Image（来自配置的 SVG / PNG）   ← 只画身体，随阶段变化
└─ Canvas（透明）                  ← 只画眼睛和腮红，随当天数据变化
```

**不把表情烘焙进图片**，因为两者生命周期不同：体型 30 天里只变 3 次，表情一天可能变好几次。烘焙进同一张图就得为「阶段 × 表情」准备 9 倍资源，而且改一次表情要重导所有图片。

表情的位置与大小写在配置里（`face`），并按该阶段的 `scale` 一起缩放，所以身体变小时表情跟着变小，不会出现"小身体顶着大脸"。`face` 支持**阶段 > 物种 > 内置默认**三级回退——鸭子的蛋和长大后的脸不在同一个位置，用的就是这个机制。

### 5.6 资源规模

12 个物种 × 3 个阶段 = **36 张 SVG**，位于 `resources/rawfile/pets/`。所有造型按 112×116 的统一逻辑坐标系产出，表情叠加层复用同一坐标系，因此换图不影响表情定位。

同物种的三个阶段共用同一套路径数据，只改填充色与缩放系数（如草莓 `#A9CB86 → #E58C86 → #E9564F`，即由青转熟）。小鸭是例外：三张图结构不同（蛋 / 小鸭 / 大鸭），不是缩放关系。

---

## 6. 页面与导航

### 6.1 页面清单

| 页面 | 职责 | 层级 |
|---|---|---|
| `Index` | 应用入口，启动路由 + 承载 Dock 与覆盖层 | 宿主 |
| `HomePage` | 宠物卡片、热量进度环、四类打卡入口、今日建议 | 一级（tab） |
| `AnalysisPage` | 7 天 / 30 天热量趋势柱状图、营养素占比条、日均指标、摄入达标天数 | 一级（tab） |
| `ProfilePage` | 档案编辑入口、连续天数、徽章墙、饭点提醒设置 | 一级（tab） |
| `OnboardingPage` | 首次录入档案；有档案时兼作编辑页 | 覆盖层 |
| `CheckinPage` | 选场景 → 选分类 → 选食物 → 选份数 → 提交 | 覆盖层 |
| `ActivityPage` | 选运动类型 → 调时长与强度 → 提交 | 覆盖层 |
| `PetPickerPanel` | 更换宠物物种 | 覆盖层 |

### 6.2 导航结构

```
Index
 ├─ Stack
 │   ├─ Tab 内容（100%）
 │   │   ├─ HomePage
 │   │   ├─ AnalysisPage
 │   │   └─ ProfilePage
 │   ├─ FloatingDock           悬浮胶囊，距底 22
 │   └─ 覆盖层（100%）         记录三餐 / 记录运动 / 编辑档案 / 换伙伴 / 宠物调试
```

**一级页不用路由栈**：首页、趋势、我的三者是平级的，没有"返回"语义。用栈会让返回行为变得含糊——在「我的」按返回应该回首页还是退出应用？用 Dock 平级切换后这个问题不存在。

**二级页用全屏覆盖**，盖住 Dock，物理上阻止"记录到一半去切页签"。它们有明确的"进入 → 完成 → 退出"流程，配统一的 `OverlayHeader`（左侧取消 + 居中标题）。

**数据联动用一个版本号**：任何写入完成后 `dataVersion + 1`，各页用 `@Prop @Watch` 感知并重新取数。页面不需要判断"我是不是被返回的那个"，也不依赖导航栈的回调时机。

### 6.3 隐藏的调试入口

长按首页宠物卡片会打开调试面板，可一键切换宠物到四个典型状态（刚开始 / 第 4 天 / 第 10 天 / 第 35 天），用于演示成长系统而不必真的等 30 天。

做成隐藏入口是为了让正式演示时评委看不到。调试状态**只存在内存**，重启即恢复真实数据——调试状态若被持久化，很容易忘记关掉，之后看到的全是假象。

---

## 7. 工程目录分层

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets
├─ entrybackupability/EntryBackupAbility.ets
├─ pages/                        # 只写 UI，不碰数据库、不碰系统 API
│   ├─ Index.ets                 # 宿主：启动路由 + Dock + 覆盖层
│   ├─ HomePage.ets
│   ├─ AnalysisPage.ets
│   ├─ ProfilePage.ets
│   ├─ OnboardingPage.ets
│   ├─ CheckinPage.ets
│   └─ ActivityPage.ets
├─ components/                   # 可复用的 UI 零件
│   ├─ FloatingDock.ets          # 底部悬浮胶囊导航
│   ├─ OverlayHeader.ets         # 覆盖页统一头部
│   ├─ SectionTitle.ets          # 分节标题（左侧短竖线）
│   ├─ SegmentedBar.ets          # 分段选择器
│   ├─ PetView.ets               # 宠物渲染：图片 + 表情叠加
│   ├─ PetPickerPanel.ets        # 换伙伴
│   └─ PetDebugPanel.ets         # 演示用调试面板
├─ viewmodel/                    # 页面状态 + 业务编排
│   ├─ HomeViewModel.ets
│   ├─ MealCheckinViewModel.ets
│   ├─ ActivityCheckinViewModel.ets
│   ├─ AnalysisViewModel.ets
│   ├─ ProfileViewModel.ets
│   └─ OnboardingViewModel.ets
├─ model/                        # 实体与枚举，纯数据无逻辑
│   ├─ Enums.ets                 # 全部枚举与位标记工具
│   ├─ UserProfile.ets  FoodItem.ets  MealRecord.ets
│   ├─ ActivityRecord.ets  WaterRecord.ets  DailySummary.ets
│   ├─ CheckinStreak.ets  Badge.ets  Totals.ets
│   └─ PetSpecies.ets            # 宠物物种配置模型 + PetCatalog 装载
├─ database/                     # 持久化
│   ├─ DbHelper.ets              # 建库建表、首次导入食物库
│   ├─ UserProfileDao.ets   FoodItemDao.ets   MealRecordDao.ets
│   ├─ ActivityRecordDao.ets  WaterRecordDao.ets  DailySummaryDao.ets
│   ├─ CheckinStreakDao.ets   BadgeDao.ets
├─ service/                      # 与系统能力打交道
│   ├─ CheckinService.ets        # 打卡编排：写记录 → 更新汇总 → 算分 → 查徽章（所有写操作的唯一入口）
│   ├─ PlanService.ets           # 档案 → 每日目标
│   ├─ StreakService.ets         # 连续天数、补签
│   ├─ BadgeService.ets          # 徽章解锁判定
│   ├─ MealReminderService.ets   # 饭点提醒（写入系统日历）
│   └─ PetService.ets            # 宠物物种选择的持久化
├─ engine/                       # 纯函数，零系统依赖，全部单元测试覆盖
│   ├─ EnergyCalculator.ets      # BMR / TDEE / 运动消耗 / 饮水目标
│   ├─ NutritionAnalyzer.ets     # 营养素配比与偏差分析
│   ├─ HealthScoreCalculator.ets
│   ├─ AdviceEngine.ets          # 建议生成规则库
│   └─ PetEngine.ets             # 宠物状态与阶段判定
└─ utils/
    ├─ DateUtils.ets  FormatUtils.ets
    ├─ Theme.ets                 # 视觉规范唯一来源
    ├─ MealSchedule.ets          # 饭点窗口判定（纯函数）
    ├─ AppContext.ets            # 全局 AbilityContext 持有者
    └─ PetDebug.ets              # 演示用状态预设
```

分层原则：页面不碰数据库、不碰系统 API；`service` 层不碰 UI；`engine` 层不依赖任何系统能力。

`engine/` 是本设计的重点：这些公式最容易算错（BMR 有多个版本、活动系数取值、配比阈值、并列时的最低项判定），纯函数用单元测试能测得比真机运行还彻底。

现实收益：`engine/` + `model/` + `database/` 三层不需要设备与签名即可开发和验证，可与签名手续并行推进。

---

## 8. 关键时序

### 打卡

```
用户选食物 → MealCheckinViewModel.submit()
 → 查 food_item 取营养数据
 → 插入 meal_record（带营养快照）
 → CheckinService 重算当日 daily_summary
 → StreakService 更新连续天数
 → BadgeService 检查徽章解锁
 → 返回 Home：进度环更新 + 宠物状态刷新 + 徽章弹出
```

`CheckinService` 是**所有写操作的唯一入口**——饮水、作息、三餐、运动都走它，避免"某个入口漏了更新汇总"这类问题。

### 首次启动

```
Index.boot()
 → await DbHelper.waitReady()     建库建表 + 首次导入 109 条食物库
 → UserProfileDao.exists()
 → 有档案：BOOT_HOME；无档案：BOOT_ONBOARDING

OnboardingPage 提交
 → 写 user_profile
 → EnergyCalculator 计算 BMR / TDEE
 → 生成每日热量与营养素目标
 → 进入 HomePage
```

### 打开首页

```
HomeViewModel.load()
 → CheckinService.currentPlan()     无档案则返回空数据
 → CheckinService.refresh(今天)     重算汇总 → 算分 → 更新连续天数 → 查徽章
 → 查今日已记录的餐次
 → MealSchedule 判定饭点提示
 → await PetCatalog.waitReady()     等造型配置就绪
 → PetEngine.evaluate(...)          算宠物状态
 → AdviceEngine 生成今日建议
 → 渲染
```

### 跨天处理

```
应用启动 / 首页加载时
 → 比较 daily_summary 中最新 record_date 与今天
 → 若今天无记录：新建 daily_summary；并结算昨日连续打卡状态
```

### 饭点提醒

```
ProfilePage 拨动开关
 → 申请 READ_CALENDAR + WRITE_CALENDAR（用户授权，仅此时申请）
 → 开启：先清空本应用日历账户下的全部日程，再按设置逐个写入
 → 关闭：只清理，不申请权限

重复日程：每天重复，时长 15 分钟，重复 365 次
```

幂等式同步（每次全清再全写）比逐个比对增删简单，而且即使用户在系统日历里手动删了日程，重新保存一次就恢复。

---

## 9. 权限清单

| 权限 | 授权方式 | 用途 |
|---|---|---|
| `ohos.permission.READ_CALENDAR` | user_grant | 读取本应用的日历账户，用于幂等同步与清理 |
| `ohos.permission.WRITE_CALENDAR` | user_grant | 写入三个饭点的重复日程 |

**只有两个权限，且都是用户主动开启提醒时才申请。** 打开「我的」页面不会触发任何弹窗——提醒配置存在本地 `preferences`，读它不需要权限。

这里有一个明确的取舍记录：`PUBLISH_AGENT_REMINDER`（代理提醒）本该是更干净的做法——不会在用户日历里留下痕迹。但官方错误码文档写明未申请权益的应用**提醒数量上限视为 0**，功能完全不可用，而权益申请需要邮件审批。相比之下，日历方案不需要任何审批，代价是日程会出现在用户的系统日历里。**在"功能可用"和"不留痕迹"之间选择了前者。**

---

## 10. 分期落地

| 阶段 | 内容 | 需要设备 / 签名 | 状态 |
|---|---|---|---|
| 0 | 建工程 + 真机签名跑通 | 需要（依赖开发者实名认证） | 已完成 |
| 1 | `DbHelper` + 8 张表 + 全部 DAO + 实体类 + 食物库导入 | 不需要 | 已完成 |
| 2 | `engine/` 全部引擎（能量 / 营养 / 健康分 / 建议）+ 单元测试 | 不需要 | 已完成 |
| 3 | `OnboardingPage` + `HomePage` | 预览器可验 | 已完成 |
| 4 | `CheckinPage` + `ActivityPage` + 食物库浏览与选中 | 预览器可验 | 已完成 |
| 5 | `AnalysisPage`（趋势图、占比图） | 预览器可验 | 已完成 |
| 6 | `ProfilePage` + 徽章墙 + 饭点提醒 | 提醒需真机验 | 已完成 |
| 7 | 宠物养成系统（配置驱动的造型 + 阶段 + 表情） | 预览器可验 | 已完成 |
| 8 | 视觉打磨（手帐风视觉规范、Dock 动效） | 需真机 | 已完成 |

并行策略：开发者实名认证与阶段 1、2 可同时进行。这两阶段产出的代码不依赖任何设备，签名办好后可直接接续，不浪费工期。

**实际执行结论：这条并行策略是有效的。** 阶段 1、2 在签名手续办理期间完成，阶段 0 一通即直接进入界面开发，没有等待期。

---

## 11. 待确认项与风险

### 11.1 已由实测解决

| # | 原待确认项 | 结论 |
|---|---|---|
| 1 | 开发者实名认证 | 个人认证即可，需要人脸识别。是阶段 0 的硬前置，且有审核周期，应最早启动 |
| 2 | 图表组件 | 环形进度用原生 `Progress(ProgressType.Ring)`；柱状图用 ArkUI 布局手绘（`Column` 高度按比例），未引入三方库 |
| 3 | 预览器能力边界 | 本地单元测试不执行完整 ArkUI 编译，数据库等系统能力不可用。但 `engine/` 层是纯函数，测试完全可跑 |
| 4 | ArkTS 严格语法 | 已确认。主要踩坑点是**自定义组件的成员名不能与 ArkUI 内置属性同名**，详见 11.2 |

### 11.2 实现中确认的高频陷阱

| 陷阱 | 说明 |
|---|---|
| **组件成员名与 ArkUI 内置属性冲突** | `tabIndex` / `overlay` / `width` / `height` 等都是 `CommonComponent` 的保留名，用作成员变量或方法名会直接编译失败。**IDE 诊断器抓不到这类错误**，只有 hvigor 的 `CompileArkTS` 会报 |
| **@Builder 按值传递不刷新** | 多参数的 @Builder 在状态变化时不会重新执行。必须改为"单个对象字面量参数"才会走按引用传递 |
| **ForEach 的 key 影响样式刷新** | 选中态之类的样式若依赖状态，key 必须把该状态包含进去，否则节点被复用、样式不更新 |
| **Canvas 内容不会自动更新** | Canvas 是绘制上去的内容，@Prop 变化不会重绘，必须用 `@Watch` 显式触发重绘；`onReady` 之前绘制无效 |
| **部分图形 API 有版本门槛** | 如 `Circle`/`Ellipse` 的 `.fill()` 需要 API 26，而工程 `compatibleSdkVersion` 是 `6.1.0(23)`。用 `Canvas`（API 8 起可用）绕开 |

### 11.3 仍存的风险

| # | 项 | 说明 |
|---|---|---|
| 1 | 食物库数据准确性 | 109 条种子数据为常见食物成分的近似参考值，正式使用前应人工校对 |
| 2 | 算法阈值校准 | 第 4 节的系数与阈值需用真实数据校准 |
| 3 | 造型资源的视觉校验 | 36 张 SVG 的路径坐标为计算产出，未经人眼确认。比例、叶位、喙角度可能需要微调 |
| 4 | 动态 `$rawfile` 路径 | `Image($rawfile(变量))` 的运行时求值行为需真机确认。若不可用，退路是 `resourceManager.getRawFd` + `image.createImageSource` 解码为 PixelMap |
| 5 | 补签语义 | `CheckinStreakDao.repair` 目前只置 `isBroken = 0`，未同步 `completedItems`，与 `StreakService` 的计数口径（`completedItems >= 2` 才达标）不一致。补签功能尚未接入 UI，接入前需一并修正 |

---

## 附录 A：食物库种子数据

文件位置：`entry/src/main/resources/rawfile/food_seed.json`

- 结构与字段含义见文件内 `schema` 字段说明
- 预置 **109 条**，覆盖主食(20) / 荤菜(20) / 素菜(15) / 汤(8) / 饮品(15) / 零食(12) / 水果(12) / 蛋奶(7) 八类
- 每条带 `scene` 数组，标识该条目适用的场景（食堂 / 外卖 / 便利店 / 自做）
- 运行时通过 `resourceManager.getRawFileContent('food_seed.json')` 读取，**首次启动**导入 `food_item` 表
- 导入失败不阻断应用启动，用户仍可手动新增食物
- 营养数值为近似参考值，需人工校对后使用

## 附录 B：宠物造型配置

文件位置：`entry/src/main/resources/rawfile/pet_config.json`

- 12 个物种（小鸭 + 11 种水果），每个物种 3 个阶段
- 图片位于 `entry/src/main/resources/rawfile/pets/`，共 36 张 SVG，逻辑坐标系统一为 112×116
- 运行时通过 `resourceManager.getRawFileContent('pet_config.json')` 读取并解析为 `PetCatalog`
- 装载时按 `minDays` 排序一次，避免配置写反顺序导致阶段判定出错
- 物种被下线或配置写坏时，页面上会降级为一句提示，而不是崩溃或空白
- **扩展方式**：加物种、改进阶天数、把 SVG 换成 PNG 都只需改配置文件与资源文件，不需要改任何代码

## 附录 C：本地单元测试

| 测试文件 | 用例数 |
|---|---|
| `EnergyCalculator.test.ets` | 19 |
| `HealthScoreCalculator.test.ets` | 14 |
| `NutritionAnalyzer.test.ets` | 11 |
| `AdviceEngine.test.ets` | 10 |
| `PetEngine.test.ets` | 36 |
| **合计** | **90** |

（另有 `LocalUnit.test.ets` 为 DevEco 模板生成的占位用例。）

除常规值外，重点覆盖边界：性别未填、减脂的热量下限保护、饮水目标的上下限裁剪、空数据与除零、建议引擎的时段规则与防误报、阶段门槛的差一天边界、台词并列时的最低项判定、配置脸型的三级回退。
