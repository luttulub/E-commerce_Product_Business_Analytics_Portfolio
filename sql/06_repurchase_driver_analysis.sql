/*
olist 재구매 driver 분석

목적:
- 첫 주문 경험에 따른 재구매율 차이를 비교한다.
- 배송 지연, 리뷰 점수, 첫 주문금액별 표본 수와 효과 크기를 확인한다.
- 60일 기준에서도 결과 방향이 유지되는지 검증한다.
*/


-- =========================================================
-- 1. 재구매 driver 분석용 고객 데이터 구성
-- repurchase_driver_base
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_60d,
		eligible_90d,
		repurchase_60d,
		repurchase_90d
	from customer_behavior_mart
)

-- 구조 확인
select
	count(*) as customer_cnt,
	count(distinct customer_unique_id) as distinct_customer_cnt,
	count(*) filter (where eligible_60d = 1) as eligible_60d_customer_cnt,
	count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt
from repurchase_driver_base;
/*
확인 결과:
- 전체 고객 수와 distinct customer_unique_id가 모두 93,358명으로 일치했다.
- 60일 관찰 가능 고객은 81,265명, 90일 관찰 가능 고객은 75,387명이다.
*/



-- =========================================================
-- 2. 재구매 driver 변수 결측 확인
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_60d,
		eligible_90d,
		repurchase_60d,
		repurchase_90d
	from customer_behavior_mart
)

select
	count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
	count(*) filter (where eligible_90d = 1 and first_order_delayed_flag is null) as null_delayed_flag_cnt,
	count(*) filter (where eligible_90d = 1 and first_order_review_score is null) as null_review_score_cnt,
	count(*) filter (where eligible_90d = 1 and first_order_payment_total is null) as null_payment_cnt,
	min(first_order_review_score) filter (where eligible_90d = 1) as min_review_score,
	max(first_order_review_score) filter (where eligible_90d = 1) as max_review_score,
	min(first_order_payment_total) filter (where eligible_90d = 1) as min_payment_total,
	max(first_order_payment_total) filter (where eligible_90d = 1) as max_payment_total
from repurchase_driver_base;
/*
확인 결과:
- 90일 관찰 가능 고객 75,387명 중 배송 지연 여부 null은 2건, 리뷰 점수 null은 533건, 첫 주문금액 null은 1건이다.
- 리뷰 점수는 1~5점 범위이며, 첫 주문금액은 10.07~13,664.08로 분포 폭이 크게 나타났다.
*/



-- =========================================================
-- 3. 첫 주문 배송 지연 여부별 90일 재구매율 비교
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_60d,
		eligible_90d,
		repurchase_60d,
		repurchase_90d
	from customer_behavior_mart
)

select
	first_order_delayed_flag,
	count(*) as customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_customer_cnt,
	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ count(*) * 100,
		2
	) as repurchase_90d_rate
from repurchase_driver_base
where eligible_90d = 1
	and first_order_delayed_flag is not null
group by first_order_delayed_flag
order by first_order_delayed_flag;
/*
확인 결과:
- 정상 배송 고객의 90일 재구매율은 2.30%, 첫 주문 배송 지연 고객은 2.00%로 나타났다.
- 배송 지연 고객의 재구매율이 정상 배송 고객보다 0.30%p 낮게 관찰됐다.
- 배송 지연 여부 null 2건을 제외한 분석 대상 고객 수와 기존 90일 재구매 고객 수가 일치했다.
*/



-- =========================================================
-- 4. 첫 주문 배송 지연 효과 크기 확인
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
	),
	
delay_repurchase_summary as (
	select
		first_order_delayed_flag,
		count(*) as customer_cnt,
		count(*) filter (where repurchase_90d = 1) as repurchase_customer_cnt,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_delayed_flag is not null
	group by first_order_delayed_flag
)

select
	max(repurchase_90d_rate) filter (where first_order_delayed_flag = 0) as normal_delivery_rate,
	max(repurchase_90d_rate) filter (where first_order_delayed_flag = 1) as delayed_delivery_rate,
	round(
		max(repurchase_90d_rate) filter (where first_order_delayed_flag = 1)
		- max(repurchase_90d_rate) filter (where first_order_delayed_flag = 0),
		2
	) as difference_pp,
	round(
		max(repurchase_90d_rate) filter (where first_order_delayed_flag = 1)
		/ max(repurchase_90d_rate) filter (where first_order_delayed_flag = 0),
		2
	) as rate_ratio
from delay_repurchase_summary;
/*
확인 결과:
- 첫 주문 배송 지연 고객의 90일 재구매율은 정상 배송 고객보다 0.30%p 낮게 나타났다.
- 배송 지연 고객의 재구매율은 정상 배송 고객의 약 87% 수준으로 확인됐다.
- 관측 데이터이므로 배송 지연이 재구매 감소의 원인이라고 단정하지 않고 관련성이 관찰된 것으로 해석한다.
*/



-- =========================================================
-- 5. 첫 주문 리뷰 점수별 90일 재구매율 확인
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_review_score,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
)

select
	first_order_review_score,
	count(*) as customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_customer_cnt,
	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ count(*) * 100,
		2
	) as repurchase_90d_rate
from repurchase_driver_base
where eligible_90d = 1
group by first_order_review_score
order by first_order_review_score nulls last;
/*
확인 결과:
- 첫 주문 리뷰 점수는 1~5점 사이에 분포하며, 정수 점수 고객이 대부분을 차지했다.
- 1.5, 2.5, 3.5, 4.5점 그룹은 표본 수가 매우 작아 개별 재구매율이 크게 변동했다.
- 안정적인 비교를 위해 이후 리뷰 점수를 low(1/1.5/2/2.5), middle(3/3.5), high(4/4.5/5) 구간으로 묶어 분석한다.
*/



-- =========================================================
-- 6. 첫 주문 리뷰 구간별 90일 재구매율 비교
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_review_score,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
),

review_group_base as (
	select
		customer_unique_id,
		repurchase_90d,
		case
			when first_order_review_score is null then 'no_review'
			when first_order_review_score < 3 then 'low'
			when first_order_review_score < 4 then 'middle'
			else 'high'
		end as review_group
	from repurchase_driver_base
	where eligible_90d = 1
)

select
	review_group,
	count(*) as customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_customer_cnt,
	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ count(*) * 100,
		2
	) as repurchase_90d_rate
from review_group_base
group by review_group
order by
	case review_group
		when 'low' then 1
		when 'middle' then 2
		when 'high' then 3
		when 'no_review' then 4
	end;
/*
확인 결과:
- 리뷰 구간별 90일 재구매율은 low 2.29%, middle 2.29%, high 2.27%, no_review 2.25%로 유사하게 나타났다.
- 그룹 간 최대 차이는 0.04%p에 불과했고, 리뷰 점수에 따른 일관된 재구매율 패턴은 확인되지 않았다.
- 전체 고객 수 75,387명과 재구매 고객 수 1,716명이 기존 90일 분석 결과와 일치했다.
*/



-- =========================================================
-- 7. 첫 주문금액 분포 확인
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
)

select
	count(*) as customer_cnt,
	round(avg(first_order_payment_total)::numeric, 2) as avg_payment_total,
	round((percentile_cont(0.25) within group (order by first_order_payment_total))::numeric, 2) as q1_payment_total,
	round((percentile_cont(0.50) within group (order by first_order_payment_total))::numeric, 2) as median_payment_total,
	round((percentile_cont(0.75) within group (order by first_order_payment_total))::numeric, 2) as q3_payment_total,
	min(first_order_payment_total) as min_payment_total,
	max(first_order_payment_total) as max_payment_total
from repurchase_driver_base
where eligible_90d = 1
	and first_order_payment_total is not null;
/*
확인 결과:
- 90일 관찰 가능 고객 중 첫 주문금액이 존재하는 고객은 75,386명으로, 결제금액 null 1건을 제외한 수와 일치했다.
- 첫 주문금액 중앙값은 105.00, 평균은 159.70으로 평균이 더 높았으며, 최대값은 13,664.08로 분포의 오른쪽 꼬리가 길게 나타났다.
- 안정적인 비교를 위해 q1 61.83, median 105.00, q3 175.98을 기준으로 사분위 구간을 구성한다.
*/



-- =========================================================
-- 8. 첫 주문금액 사분위별 90일 재구매율 비교
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
),

payment_thresholds as (
	select
		percentile_cont(0.25) within group (order by first_order_payment_total) as q1,
		percentile_cont(0.50) within group (order by first_order_payment_total) as median,
		percentile_cont(0.75) within group (order by first_order_payment_total) as q3
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_payment_total is not null
),

payment_group_base as (
	select
		b.customer_unique_id,
		b.repurchase_90d,
		case
			when b.first_order_payment_total <= t.q1 then 'q1'
			when b.first_order_payment_total <= t.median then 'q2'
			when b.first_order_payment_total <= t.q3 then 'q3'
			else 'q4'
		end as payment_group
	from repurchase_driver_base b
		cross join payment_thresholds t
	where b.eligible_90d = 1
		and b.first_order_payment_total is not null
)

select
	payment_group,
	count(*) as customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_customer_cnt,
	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ count(*) * 100,
		2
	) as repurchase_90d_rate
from payment_group_base
group by payment_group
order by payment_group;
/*
확인 결과:
- 첫 주문금액이 높은 구간일수록 90일 재구매율이 낮아졌으며, q1 2.46%에서 q4 2.07%로 0.39%p 차이가 났다.
- 전체 고객 수 75,386명과 재구매 고객 수 1,716명이 기존 결과와 일치했다.
*/



-- =========================================================
-- 9. 30 / 60 / 90일 기준 driver 민감도 분석
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_30d,
		eligible_60d,
		eligible_90d,
		repurchase_30d,
		repurchase_60d,
		repurchase_90d
	from customer_behavior_mart
),

payment_thresholds as (
	select
		percentile_cont(0.25) within group (order by first_order_payment_total) as q1,
		percentile_cont(0.50) within group (order by first_order_payment_total) as median,
		percentile_cont(0.75) within group (order by first_order_payment_total) as q3
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_payment_total is not null
),

delay_sensitivity as (
	select
		'delivery_delay' as driver,
		case
			when first_order_delayed_flag = 0 then 'normal'
			else 'delayed'
		end as driver_group,
		count(*) filter (where eligible_30d = 1) as eligible_30d_customer_cnt,
		round(
			count(*) filter (where repurchase_30d = 1)::numeric
			/ nullif(count(*) filter (where eligible_30d = 1), 0) * 100,
			2
		) as repurchase_30d_rate,
		count(*) filter (where eligible_60d = 1) as eligible_60d_customer_cnt,
		round(
			count(*) filter (where repurchase_60d = 1)::numeric
			/ nullif(count(*) filter (where eligible_60d = 1), 0) * 100,
			2
		) as repurchase_60d_rate,
		count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
		round(
			count(*) filter (where repurchase_90d = 1)::numeric
			/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
			2
		) as repurchase_90d_rate
	from repurchase_driver_base
	where first_order_delayed_flag is not null
	group by first_order_delayed_flag
),

review_group_base as (
	select
		eligible_30d,
		eligible_60d,
		eligible_90d,
		repurchase_30d,
		repurchase_60d,
		repurchase_90d,
		case
			when first_order_review_score is null then 'no_review'
			when first_order_review_score < 3 then 'low'
			when first_order_review_score < 4 then 'middle'
			else 'high'
		end as driver_group
	from repurchase_driver_base
),

review_sensitivity as (
	select
		'review' as driver,
		driver_group,
		count(*) filter (where eligible_30d = 1) as eligible_30d_customer_cnt,
		round(
			count(*) filter (where repurchase_30d = 1)::numeric
			/ nullif(count(*) filter (where eligible_30d = 1), 0) * 100,
			2
		) as repurchase_30d_rate,
		count(*) filter (where eligible_60d = 1) as eligible_60d_customer_cnt,
		round(
			count(*) filter (where repurchase_60d = 1)::numeric
			/ nullif(count(*) filter (where eligible_60d = 1), 0) * 100,
			2
		) as repurchase_60d_rate,
		count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
		round(
			count(*) filter (where repurchase_90d = 1)::numeric
			/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
			2
		) as repurchase_90d_rate
	from review_group_base
	group by driver_group
),

payment_group_base as (
	select
		b.eligible_30d,
		b.eligible_60d,
		b.eligible_90d,
		b.repurchase_30d,
		b.repurchase_60d,
		b.repurchase_90d,
		case
			when b.first_order_payment_total <= t.q1 then 'q1'
			when b.first_order_payment_total <= t.median then 'q2'
			when b.first_order_payment_total <= t.q3 then 'q3'
			else 'q4'
		end as driver_group
	from repurchase_driver_base b
		cross join payment_thresholds t
	where b.first_order_payment_total is not null
),

payment_sensitivity as (
	select
		'first_order_payment' as driver,
		driver_group,
		count(*) filter (where eligible_30d = 1) as eligible_30d_customer_cnt,
		round(
			count(*) filter (where repurchase_30d = 1)::numeric
			/ nullif(count(*) filter (where eligible_30d = 1), 0) * 100,
			2
		) as repurchase_30d_rate,
		count(*) filter (where eligible_60d = 1) as eligible_60d_customer_cnt,
		round(
			count(*) filter (where repurchase_60d = 1)::numeric
			/ nullif(count(*) filter (where eligible_60d = 1), 0) * 100,
			2
		) as repurchase_60d_rate,
		count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
		round(
			count(*) filter (where repurchase_90d = 1)::numeric
			/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
			2
		) as repurchase_90d_rate
	from payment_group_base
	group by driver_group
)

select *
from delay_sensitivity

union all

select *
from review_sensitivity

union all

select *
from payment_sensitivity

order by driver, driver_group;
/*
확인 결과:
- 첫 주문금액은 30/60/90일 모두 저금액군의 재구매율이 상대적으로 높게 나타났다.
  q1과 q4의 재구매율 차이는 30일 0.31%p, 60일 0.41%p, 90일 0.39%p로 기간을 바꿔도 방향이 유지됐다.
- 배송 지연 고객의 재구매율은 정상 배송 고객보다 30일 0.10%p, 60일 0.15%p, 90일 0.30%p 낮아 모든 기간에서 동일한 방향이 확인됐다.
- 리뷰 점수는 low와 high 그룹 차이가 30일 0.21%p, 60일 0.10%p, 90일 0.02%p로 점차 축소돼 일관된 재구매 관련 요인으로 보기 어려웠다.
- 30/60/90일 기준을 변경해도 첫 주문금액과 배송 지연은 동일한 방향의 차이가 유지됐으며, 이 중 첫 주문금액이 가장 안정적인 패턴을 보였다.
- 다만 관측 데이터 기반 비교이므로 첫 주문금액이나 배송 지연이 재구매율 차이의 원인이라고 단정하지 않고 관련성이 관찰된 요인으로 해석한다.
*/



-- =========================================================
-- 10. 재구매 driver 핵심 결과 비교
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
),

delivery_summary as (
	select
		case
			when first_order_delayed_flag = 0 then 'normal'
			else 'delayed'
		end as driver_group,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_delayed_flag is not null
	group by first_order_delayed_flag
),

review_group_base as (
	select
		repurchase_90d,
		case
			when first_order_review_score < 3 then 'low'
			when first_order_review_score < 4 then 'middle'
			else 'high'
		end as driver_group
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_review_score is not null
),

review_summary as (
	select
		driver_group,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from review_group_base
	group by driver_group
),

payment_thresholds as (
	select
		percentile_cont(0.25) within group (order by first_order_payment_total) as q1,
		percentile_cont(0.50) within group (order by first_order_payment_total) as median,
		percentile_cont(0.75) within group (order by first_order_payment_total) as q3
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_payment_total is not null
),

payment_group_base as (
	select
		b.repurchase_90d,
		case
			when b.first_order_payment_total <= t.q1 then 'q1'
			when b.first_order_payment_total <= t.median then 'q2'
			when b.first_order_payment_total <= t.q3 then 'q3'
			else 'q4'
		end as driver_group
	from repurchase_driver_base b
		cross join payment_thresholds t
	where b.eligible_90d = 1
		and b.first_order_payment_total is not null
),

payment_summary as (
	select
		driver_group,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from payment_group_base
	group by driver_group
),

driver_summary as (
	select
		'delivery_delay' as driver,
		'normal vs delayed' as comparison,
		round(max(repurchase_90d_rate) filter (where driver_group = 'normal'), 2) as reference_rate,
		round(max(repurchase_90d_rate) filter (where driver_group = 'delayed'), 2) as comparison_rate,
		round(
			max(repurchase_90d_rate) filter (where driver_group = 'delayed')
			- max(repurchase_90d_rate) filter (where driver_group = 'normal'),
			2
		) as difference_pp
	from delivery_summary

	union all

	select
		'review_score',
		'low vs high',
		round(max(repurchase_90d_rate) filter (where driver_group = 'low'), 2),
		round(max(repurchase_90d_rate) filter (where driver_group = 'high'), 2),
		round(
			max(repurchase_90d_rate) filter (where driver_group = 'high')
			- max(repurchase_90d_rate) filter (where driver_group = 'low'),
			2
		)
	from review_summary

	union all

	select
		'first_order_payment',
		'q1 vs q4',
		round(max(repurchase_90d_rate) filter (where driver_group = 'q1'), 2),
		round(max(repurchase_90d_rate) filter (where driver_group = 'q4'), 2),
		round(
			max(repurchase_90d_rate) filter (where driver_group = 'q4')
			- max(repurchase_90d_rate) filter (where driver_group = 'q1'),
			2
		)
	from payment_summary
)

select
	driver,
	comparison,
	reference_rate,
	comparison_rate,
	difference_pp,
	abs(difference_pp) as absolute_difference_pp
from driver_summary
order by absolute_difference_pp desc;
/*
확인 결과:
- 90일 재구매율 차이는 첫 주문금액 q1 대비 q4가 -0.39%p로 가장 컸으며, q1 2.46% → q2 2.41% → q3 2.16% → q4 2.07%로 금액이 높아질수록 낮아지는 패턴이 확인됐다.
- 배송 지연 고객은 정상 배송 고객보다 0.30%p 낮았고, 리뷰 low와 high 그룹의 차이는 0.02%p에 불과했다.
- 30/60/90일 민감도 분석에서도 첫 주문금액과 배송 지연은 동일한 방향이 유지됐으며, 첫 주문금액이 가장 일관된 재구매 관련 요인 후보로 나타났다.
- 단, 관측 데이터의 그룹 간 차이이므로 각 요인이 재구매율 변화의 원인이라고 단정하지 않는다.
*/