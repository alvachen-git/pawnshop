"""Summarize the paired, player-information-only Godot business experiment."""
import json
import statistics
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".godot/qa/market_seven/comparison.json"
DEST = ROOT / "docs/qa/market-seven"
POLICIES = {"immediate": "空柜即售", "positive": "只卖正毛利", "patient": "优先等陆掌眼或预约"}
FIELDS = {
    "cash_shortages": "报价时现银不足次数",
    "missed_customers": "错过客人数",
    "sale_gross_profit": "售货毛利（银元）",
    "remaining_inventory_cost": "剩余自有库存成本（银元）",
    "pledged_inventory_cost": "另有在当占款（银元）",
    "sale_minutes": "出货耗时（分钟）",
}


def main():
    rows = json.loads(SOURCE.read_text(encoding="utf-8"))
    assert len(rows) == 96
    assert {(r["policy"], r["seed"]) for r in rows} == {
        (policy, seed) for policy in POLICIES for seed in range(32)
    }
    for row in rows:
        assert row["sale_gross_profit"] == sum(s["realized_profit"] for s in row["sales"])
        assert row["missed_customers"] == sum(
            h["outcome"] in ("timed_out", "shop_closed") for h in row["visit_history"]
        )
        assert row["sale_minutes"] % 20 == 0
        assert len({s["item_instance_id"] for s in row["sales"]}) == len(row["sales"])
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / ".gdignore").touch()
    (DEST / "comparison.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    grouped = {p: sorted((r for r in rows if r["policy"] == p), key=lambda r: r["seed"]) for p in POLICIES}
    lines = ["# 七夜经营策略对照", "", "固定种子0–31，每个种子运行三种策略，共96局。金额单位为银元。", "",
             "## 统一决策方法", "",
             "所有策略按同一顺序做当前可用的普通货鉴定，使用已经揭露且有议价作用的证据压价；只报一次：现有估值下限与当前叫价中的较低值。只愿活当的客人固定尝试40银元。现银不足不提交，报价未成交则送客。第二夜若付得起5银元则准备茶水，经营到第四夜时调查预约，其他准备不使用。拒收鬼货以隔离普通经营差异；铜镜与调查用独立完整路线验证。", "",
             "只读取当前可见的买家货单和报价，不读取未来需求、隐藏底价、真实变体或编排角色。每件货先比较当前可成交报价；若分属不同买家，先交总收款最高的一批，下趟重新询价。空柜即售允许亏本回款；正毛利策略要求报价高于入手成本；等待策略前六夜只去陆掌眼或预约，末夜按当前最高报价清理可售库存。三者均在18:00开铺，经营至02:00后关铺，沿用相同休息与结算流程。", "",
             "错过客人数包括等待超时和关铺离场，包含鉴定、议价拖延导致的离场，不能全部归因于外出。现金不足统计报价前付不起这次报价的来客数，并不表示该客必然会接受报价。毛利不扣每日息费和准备费用；剩余库存按入手成本列示，不当作已经回款。", "",
             "## 每局平均值与范围", "", "| 指标 | " + " | ".join(POLICIES.values()) + " |", "|---|---:|---:|---:|"]
    for field, label in FIELDS.items():
        values = []
        for group in grouped.values():
            data = [r[field] for r in group]
            values.append(f"{statistics.mean(data):.2f}（{min(data)}–{max(data)}）")
        lines.append("| " + label + " | " + " | ".join(values) + " |")
    lines += ["", "## 每日费用与完成情况", "", "| 策略 | 七夜完成局数 | 各夜平均应付息费 | 平均实付总息费 | 平均期末现金（辅助指标） |", "|---|---:|---|---:|---:|"]
    for policy, group in grouped.items():
        daily = []
        for night in range(1, 8):
            fees = [f["interest"] + f["overhead"] for r in group for f in r["daily_fees"] if f["night"] == night]
            daily.append(f"{statistics.mean(fees):g}" if fees else "—")
        lines.append(f"| {POLICIES[policy]} | {sum(r['phase'] == 'run_ended' for r in group)}/32 | {' / '.join(daily)} | {statistics.mean(sum(f['paid'] for f in r['daily_fees']) for r in group):.2f} | {statistics.mean(r['cash'] for r in group):.2f} |")
    tea_costs = {sum(h["cost"] for h in r["preparations"]) for r in rows}
    assert tea_costs == {5}, tea_costs
    endings = []
    for policy, group in grouped.items():
        counts = Counter(r["night_reached"] for r in group if r["phase"] == "bankrupt")
        if counts:
            endings.append(POLICIES[policy] + "：" + "、".join(f"第{night}夜{count}局" for night, count in sorted(counts.items())))
    lines += ["", "每日应付费用只对实际经营到该夜的局计算；原始数据逐局保留paid、arrears和overdue。本批96局均实际付了茶水费5银元，第四夜调查免费。", "",
              "因费用短款到期而破铺的分布为：" + "；".join(endings) + "。提前结束会减少错过客人和出货耗时，不能直接解释为七夜经营效率更高；期末现金也混合了不同经营长度。", "",
              "## 买家成交与同种子比较", "", "| 策略 | 陆掌眼成交件数 | 预约成交件数 | 全部成交件数 |", "|---|---:|---:|---:|"]
    for policy, group in grouped.items():
        buyers = {}
        for row in group:
            for buyer, count in row["buyers"].items():
                buyers[buyer] = buyers.get(buyer, 0) + count
        # Derive the appointment id from the exported content, rather than a display name.
        appointment = next(b["id"] for b in json.loads((ROOT / "data/market_seven/buyers.json").read_text(encoding="utf-8"))["records"] if b["night_min"] == b["night_max"] == 6)
        lines.append(f"| {POLICIES[policy]} | {buyers.get('buyer_lu', 0)} | {buyers.get(appointment, 0)} | {sum(buyers.values())} |")
    for policy in ("positive", "patient"):
        changes = [a["sale_gross_profit"] - b["sale_gross_profit"] for a, b in zip(grouped[policy], grouped["immediate"])]
        lines += ["", f"与同种子的空柜即售比较，{POLICIES[policy]}毛利更高 / 相同 / 更低的局数为 {sum(x > 0 for x in changes)} / {sum(x == 0 for x in changes)} / {sum(x < 0 for x in changes)}；平均毛利差 {statistics.mean(changes):+.2f}。这不代表资金周转或时间利用也更好，需结合库存和客人损失阅读。"]
    lines += ["", "原始逐局记录：[comparison.json](comparison.json)。重跑：先执行经营对照，再运行 `python tools/market_seven_report.py`。固定收购策略是控制变量，不是推荐给玩家的最佳玩法，也不是对所有玩法的平衡证明。"]
    (DEST / "COMPARISON.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Validated and summarized 96 paired runs.")


if __name__ == "__main__":
    main()
