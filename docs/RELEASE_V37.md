# 富客与怀表玩法发布记录 · v37

2026-09-23。独立发布分支 `codex/release-wealthy-watch-v37` 合入线上 main `e891dc20976d0a38abe013e755d4b9a053270125` 后验证。默认入口使用 `named_wealthy_ten`，自动存档为 `user://named_wealthy_ten/autosave_v37.json`；原工作目录和旧版入口、存档保留。

## 本次内容

- 五类富客、十种高档货、商誉客流、宣传与累计交易；专属立绘接入柜台。
- 基础外观检查、器材鉴定与知识柜；百达翡丽猎壳金怀表采用专用实物、机芯、上弦、姿态和试听界面。
- 第二柜《名表鉴定指南》保留听走时及原厂机芯对照；样音与实物共用生成规则。仿制机芯有固定处、英文刻字及齿轮比例图样。
- 怀表实际货值生成时固定，客人认识、玩家手记、对客说法与真实证据分开保存。点击试听即可记录；未查完可落笔，成功后回柜台。相信、部分让价、坚持原价、识破虚假说法各有结果；同一问题不重复谈。
- 富客固定为周锦生、李衡、程玉笙、沈季安、Edward；柜台、谈价、当票和赎回保持同一身份。
- 保留线上铜镜、阿七、军方关系及普通物品美术。旧版本继续按各自内容与存档规则运行，不重新抽取货况。
- 合并回归修复库存页刷新函数与 Godot 自动绘制回调重名的问题，避免旧版缺少展示模型时访问不存在的字段。历史鉴定测试改为检查保存的判断与证据估值，不再依赖已移除的判断文案。

## 本轮实测

Godot 4.6.1，隔离 APPDATA，全部下列检查通过。断言数来自各检查的最终输出，不表示所有仓库历史测试均已运行。

| 检查 | 通过项数 |
| --- | ---: |
| wealthy_customers | 1554 |
| tiered_appraisal（180种组合） | 6233 |
| watch_appraisal（216种组合） | 4950 |
| watch_economy（27种组合） | 916 |
| watch_guide_audio | 57 |
| watch_partial_seal | 55 |
| luxury_appraisal_summary | 227 |
| watch_negotiation | 1070 |
| watch_negotiation_storage | 223 |
| watch_movement_patterns | 409 |
| named_wealthy | 1211 |
| fan_condition | 2078 |
| appraisal_release_entries | 18 |
| social_v27_fixtures / social_v27 | 617 / 1706 |
| unified_appraisal | 2185 |
| named_wealthy_story（铜镜） | 3491 |
| named_wealthy_companion（阿七） | 3282 |
| named_wealthy_journey（两局十夜） | 523 |
| run_all（M0—M7） | 1801 |
| named_wealthy_ui，1280×720 / 1600×900 | 56 / 56 |
| watch_negotiation_ui，1280×720 / 1600×900 | 71 / 71 |
| watch_movement_ui，1280×720 / 1600×900 | 46 / 46 |
| silver_ring_art_ui | 59 |

Godot重新导入无脚本或解析错误；本机仍有根证书存储读取提示，不影响本轮离线验证。未生成 Windows 安装包或运行仓库全部历史测试。

统一启动验证通过：`play.cmd -Wide -Verify`、`play-unified.cmd -Stage watch -WatchCase engraving -Wide -Verify`、旧知识柜兼容入口 `play-unified.cmd -Stage knowledge -Verify`。常规启动去掉 `-Verify` 即可；后两者使用隔离试玩进度。

## 截图与细则

- [李衡 · 1280柜台](qa/named-wealthy/named_1280_gold_watch.png)
- [Edward · 1600柜台](qa/named-wealthy/named_1600_repeater.png)
- [385→39的反馈](qa/named-wealthy/named_1280_39_price.png)
- [怀表谈价界面](qa/watch-v35/watch35_1600_claims.png)
- [固定姓名、价格算例及试玩](NAMED_WEALTHY_V37.md)

发布副本中排除引擎、缓存、嵌套工作树、历史备份与无关导入变化。版本规则与故障回滚的验收覆盖见上述测试；后续数值仍可根据试玩反馈调整。
