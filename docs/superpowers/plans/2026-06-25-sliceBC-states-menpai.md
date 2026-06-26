# 子切片 B+C 实现计划(内联执行,跳过 review)

Spec: `docs/superpowers/specs/2026-06-25-sliceBC-states-menpai-design.md`(数值/stats 以 spec 为准)。TDD,每任务一提交。

## B — 状态系统
- [ ] **B1 Move.grants_guard 字段** — `move.gd` 加 `@export var grants_guard: int = 0`;`deck.gd _m` 读 `opts.get("guard",0)`;`combat_state.clone` 无关(Move 不在 state)。无需独立测试(随 B3)。
- [ ] **B2 借力** — `combat_sim`:`_Actor` 加 `leverage_until:=-1`;常数 `LEVERAGE_WINDOW=3` `LEVERAGE_PCT=60`。成功 BLOCK / 成功 DODGE → 设 defender 借力窗口 + 发 `&"leverage"`。干净命中前:attacker 借力有效 → dmg=`int(ceil(dmg*(100+PCT)/100))`,消耗,发 `&"leverage"`。
  - 测试 `test_states.gd`:防守方格挡成功后,其下一击 dmg = 基线×1.6(同一招对照);闪避同理;窗口过期不增。
- [ ] **B3 护体** — `combat_sim`:`_Actor` 加 `guard_until:=-1`;常数 `GUARD_REDUCTION_PCT=50`。干净命中后 `atk.grants_guard>0` → 设 attacker 护体 + 发 `&"guard"`。`_apply_damage` 末尾:`t<guard_until[defender]` 且 dmg>0 → `dmg=int(ceil(dmg*0.5))`。
  - 测试:带 `grants_guard` 的招命中后,接下来几拍内对该方的攻击 dmg 减半;过期恢复。
- [ ] **B4 事件本地化** — `loc.gd event_zh`+`log_line`:`leverage→借力`、`guard→护体`;`combat_feed.gd`:这两个事件给 marker/tone(借力亮黄、护体金)。测试 `test_loc`/`test_combat_feed` 各加一条。

## C — 门派
- [ ] **C1 新招 + 连招模板** — `deck.gd`:加 7 新招(spec 表)+ 3 模板函数 `luohan()`/`jingang_fumo()`(guard:4,armor)/`taiji_yunshou()`(delta:-1,priority:6)。测试 `test_deck`/`test_content`:新招存在、关键属性对(如 shaolin_gun range[1,2]、jingang_fumo grants_guard=4)。
- [ ] **C2 门派数据 + 配方** — `menpai.gd`:`pool(id)`/`rules(id)`/`get(id)`。rules = `ComboLibrary.build()` + 门派配方(少林:拳×3→罗汉拳、[格挡,韦陀]→金刚伏魔;武当:绵掌×2→云手)。
  - 测试 `test_menpai.gd`:少林池=7招且皆 ATTACK;武当池=5;`rules(&"shaolin").recipe_result([jab,hook,beng])` 出罗汉拳;`recipe_result([guard,weituo])` 出金刚伏魔且 grants_guard=4;武当 `recipe_result([mian,mian])` 出云手;base build() **不**出拳×3(回归)。
- [ ] **C3 fight 集成** — `fight.gd`:`configure(... , menpai_id := &"shaolin")` 存 `_cfg.menpai`;`_ready` 里 `_pool=Menpai.pool(menpai_id)`、`_rules=Menpai.rules(menpai_id)`。测试 `test_fight`:默认手牌的 6 进攻牌都来自少林池(id ∈ 少林池)。
- [ ] **C4 开局选派** — `menpai_select.{tscn,gd}`(标题 + 少林/武当两按钮 + 简介);按钮设 `RunState.pending_menpai` 并 `change_scene_to_file(run)`。`main_menu` 开始游戏 → menpai_select。`run_state.gd` 加 `var menpai_id` + `static var pending_menpai:=&"shaolin"`;`run.gd` `RunState.new(3,40,RunState.pending_menpai)` 并 `_fight.configure(..., _run.menpai_id)`。测试 `test_menpai_select`(场景结构 + 按钮设 pending)、`test_run`(RunState 带 menpai_id)。
- [ ] **C5 全量绿 + 合并** — `bash run_tests.sh` 全绿;门派截图自检(少林手牌=少林招);合并 master 部署。
