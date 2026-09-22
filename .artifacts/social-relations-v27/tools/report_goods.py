"""Summarize the deterministic v21 gameplay checkpoints; never chooses actions."""
import json
import math
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / '.godot/qa/goods'
OUT = ROOT / 'docs/qa/goods-expertise'
OUT.mkdir(parents=True, exist_ok=True)
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
buyers = {b['id']: b for b in read(ROOT/'data/market_seven/buyers.json')['records']}
defs = {b['id']: b for b in read(ROOT/'data/goods_expertise/items.json')['records']}
rows = []
daily = []
for policy in ('plain', 'review'):
    for seed in range(32):
        data = read(QA/f'{policy}_{seed}_7.json')
        assert data['phase'] == 'run_ended' and len(data['summaries']) == 7
        items = {i['instance_id']: i for i in data['inventory_instances']}
        history = data['expertise_history']
        fan_gain = 0
        for s in data['sale_records']:
            i = items[s['item_instance_id']]
            if i['definition_id'] == 'item_folding_fan' and i.get('expert_reviewed'):
                b = buyers[s['buyer_id']]
                base = math.floor(20*b['value_multiplier']+.5)
                premium = math.floor(base*b.get('provenance', {}).get('premium_bps',0)/10000) if i['provenance']['status']=='verified' else 0
                fan_gain += s['price'] - base - premium
        pair_gain = 0
        for batch in data['sale_batches']:
            for pair in batch.get('pairs', []):
                pair_gain += math.floor(2*math.floor(35*buyers[batch['buyer_id']]['value_multiplier']+.5)*.25)
        row = dict(policy=policy, seed=seed,
                   fan_fee=sum(h['fee'] for h in history if h['action']=='fan'),
                   pair_fee=sum(h['fee'] for h in history if h['action']=='pair'),
                   seek_fee=sum(h['cost'] for h in data['preparation_history'] if h['action']=='seek'),
                   fan_incremental_receipts=fan_gain,
                   pair_matched=sum(h['action']=='pair' and h['result']=='matched' for h in history),
                   pair_bonus=pair_gain,
                   expert_minutes=sum(h['minute']-h['start'] for h in history),
                   sell_minutes=sum(h['minute']-h['start'] for h in data['sale_batches']),
                   sold_goods=len(data['sale_records']),
                   sales_gross_profit=sum(h['realized_profit'] for h in data['sale_records']),
                   daily_expense=sum(h['interest']+h['overhead'] for h in data['fee_history']),
                   preparation_actions=sum(h['action']=='seek' for h in data['preparation_history']),
                   inventory_cost=sum(i['acquisition_price'] for i in items.values() if i['ownership_state']=='owned'),
                   peak_daily_inventory_cost=max(s['inventory_cost'] for s in data['summaries']),
                   end_cash=data['cash'],
                   missed_customers=sum(h['outcome'] in ['timed_out', 'missed', 'left', 'expired'] for h in data['visit_history']))
        row['direct_expert_net'] = fan_gain+pair_gain-row['fan_fee']-row['pair_fee']-row['seek_fee']
        rows.append(row)
        daily.extend(dict(policy=policy,seed=seed,**s) for s in data['summaries'])
(OUT/'comparison.json').write_text(json.dumps({'runs':rows,'daily':daily}, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
distribution = read(QA/'distribution.json')
(OUT/'distribution.json').write_text(json.dumps(distribution,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
names = dict(fan_fee='折扇复核支出', pair_fee='验配支出', seek_fee='寻货支出', fan_incremental_receipts='已售折扇复核新增收入', pair_matched='验配原配组合数（含损伤）', pair_bonus='实际原配加价', direct_expert_net='直接新增收入减复核与寻货费', expert_minutes='复核耗时/分钟', sell_minutes='外出卖货耗时/分钟', sold_goods='卖出件数', sales_gross_profit='售货毛利', daily_expense='七夜息费与铺面开支', inventory_cost='期末现货成本占款', peak_daily_inventory_cost='每日末现货成本峰值', end_cash='期末现银（辅助指标）')
text = '# v21 新品专项经营对照\n\n固定种子0–31，各跑两种策略，共64局；每局实际完成七夜，使用正常指令和可校验存档。金额单位银元。首版数值未调整，本表不代表已经平衡。\n\n'
text += '## 决策方法与比较范围\n\n两组都只收新品：有卖断选项、现银大于100时做三步柜台检查，按当时叫价买入；其他来客送走。相同的报价与收购门槛，不使用隐藏归属、隐藏制式、未来需求或未来来客。剩余约75分钟关门，保留准备、费用与原有剧情流程。因复核耗时和现金变化会影响接待，两组不保证买到相同数量；这是策略整体比较，不能把总现金差归因于单一服务。\n\n'
text += '- **直接出售**：空柜时按当前公开最高报价卖出，不请行家、不寻配。\n- **逐件复核并持杯**：有空就复核未认证折扇与未验组合，持有茶盏到末夜，每夜对首只可寻配茶盏委托寻货；末夜按当前最高报价出售并勾选可用原配。此策略有意包含盲目验配损伤盏的低效决策，用来观察费用和占款代价，并非最优玩法建议。\n\n'
text += '## 每局平均\n\n| 指标 | 直接出售 | 逐件复核并持杯 |\n|---|---:|---:|\n'
for key, title in names.items():
    text += f'| {title} | {mean(r[key] for r in rows if r["policy"]=="plain"):.2f} | {mean(r[key] for r in rows if r["policy"]=="review"):.2f} |\n'
reviews=[r for r in rows if r['policy']=='review']
text += '\n“已售折扇复核新增收入”按实际成交买家，与未复核20基数的同一买家报价比较；未售折扇不计假想收入。“直接净额”不含新增货物成本、库存终值和机会成本，不能当作整局净利润。完整每种子、逐夜数据见 [comparison.json](comparison.json)。\n\n'
text += f'32局复核策略中，有{sum(r["direct_expert_net"]<0 for r in reviews)}局直接净额为负；有{sum(r["pair_bonus"]>0 for r in reviews)}局实际拿到原配加价。\n\n'
text += '## 保留的负收益样例\n\n| 种子 | 折扇新增收入 | 原配加价 | 复核+寻货费 | 直接净额 | 期末库存成本 |\n|---|---:|---:|---:|---:|---:|\n'
for r in sorted(reviews,key=lambda r:r['direct_expert_net'])[:5]:
    text+=f'| {r["seed"]} | {r["fan_incremental_receipts"]} | {r["pair_bonus"]} | {r["fan_fee"]+r["pair_fee"]+r["seek_fee"]} | {r["direct_expert_net"]} | {r["inventory_cost"]} |\n'
text += '\n## 下一步建议\n\n先人工验收信息是否足够支撑“跳过损伤盏验配、只为已知完好且可等候的盏寻货、为现金留余地”。再增加只验可获溢价组合的选择性策略，比较其接待损失与占款；不要根据盲目复核策略的劣势直接下调全部服务费。折扇原作、临摹和后添款分别看服务回报，茶盏则分别看寻货命中、品相和可出售时段三个门槛。\n'
(OUT/'COMPARISON.md').write_text(text,encoding='utf-8')
print(json.dumps({'runs':len(rows), 'review_negative':sum(r['direct_expert_net']<0 for r in reviews), 'actual_pair_bonus_runs':sum(r['pair_bonus']>0 for r in reviews)},ensure_ascii=False))
