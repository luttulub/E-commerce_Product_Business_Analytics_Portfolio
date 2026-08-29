/*
olist 재구매 driver 분석

목적:
- 첫 주문 경험에 따른 재구매율 차이를 비교한다.
- 배송 지연, 리뷰 점수, 첫 주문금액, 상품 카테고리별 재구매 패턴을 확인한다.
- 배송 경험과 리뷰의 관계를 함께 확인해 고객 경험 측면의 개선 신호를 진단한다.
- 첫 주문금액은 30/60/90일 기준에서 재구매율 패턴이 유지되는지 검증한다.
- 첫 주문 경험이 재구매보다 선행하는지 확인해 driver 해석의 시간적 타당성을 점검한다.
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
-- 5. 배송 경험과 재구매 시점 순서 검증
-- =========================================================

with repurchase_timing_base as (
	select
		c.customer_unique_id,
		nullif(trim(c.second_order_timestamp), '')::timestamp as second_order_timestamp,
		nullif(trim(o.order_delivered_customer_date), '')::timestamp as first_delivery_timestamp
	from customer_behavior_mart c
		left join orders o
			on c.first_order_id = o.order_id
	where c.eligible_90d = 1
		and c.repurchase_90d = 1
)

select
	count(*) as repurchase_90d_customer_cnt,
	count(*) filter (
		where first_delivery_timestamp is null
	) as null_delivery_timestamp_cnt,
	count(*) filter (
		where second_order_timestamp < first_delivery_timestamp
	) as repurchase_before_delivery_cnt,
	round(
		count(*) filter (
			where second_order_timestamp < first_delivery_timestamp
		)::numeric
		/ count(*) * 100,
		2
	) as repurchase_before_delivery_rate
from repurchase_timing_base;
/*
확인 결과:
- 90일 재구매 고객 1,716명 중 첫 주문 배송일이 null인 고객은 없었다.
- 이 중 963명(56.12%)은 첫 주문이 실제 배송되기 전에 이미 두 번째 주문을 완료했다.
- 따라서 전체 90일 재구매율과 첫 주문 배송 지연 여부를 직접 비교하는 것만으로는 배송 경험이 후속 재구매와 관련됐다고 해석하기 어렵다.
- 배송 경험의 시간적 선후관계를 보장하기 위해 이후 배송 관련 분석은 첫 주문 배송 완료 이후 발생한 재구매를 별도로 정의해 검증한다.
*/



-- =========================================================
-- 6. 첫 배송 완료 이후 90일 재구매율 비교
-- =========================================================

with observation_end as (
	select
		max(nullif(trim(order_purchase_timestamp), '')::timestamp) as observation_end_timestamp
	from orders
	where order_status = 'delivered'
),

first_order_delivery as (
	select
		c.customer_unique_id,
		c.first_order_id,
		c.first_order_delayed_flag,
		nullif(trim(o.order_delivered_customer_date), '')::timestamp
			as first_delivery_timestamp
	from customer_behavior_mart c
		left join orders o
			on c.first_order_id = o.order_id
),

delivered_order_history as (
	select
		c.customer_unique_id,
		o.order_id,
		nullif(trim(o.order_purchase_timestamp), '')::timestamp as purchase_timestamp
	from orders o
		inner join customers c
			on o.customer_id = c.customer_id
	where o.order_status = 'delivered'
		and nullif(trim(o.order_purchase_timestamp), '') is not null
),

post_delivery_base as (
	select
		f.customer_unique_id,
		f.first_order_delayed_flag,
		f.first_delivery_timestamp,
		min(d.purchase_timestamp) as first_post_delivery_order_timestamp
	from first_order_delivery f
		left join delivered_order_history d
			on f.customer_unique_id = d.customer_unique_id
			and d.purchase_timestamp > f.first_delivery_timestamp
	group by
		f.customer_unique_id,
		f.first_order_delayed_flag,
		f.first_delivery_timestamp
),

eligible_base as (
	select
		p.customer_unique_id,
		p.first_order_delayed_flag,
		p.first_delivery_timestamp,
		p.first_post_delivery_order_timestamp
	from post_delivery_base p
		cross join observation_end o
	where p.first_delivery_timestamp is not null
		and p.first_order_delayed_flag is not null
		and p.first_delivery_timestamp + interval '90 days'
			<= o.observation_end_timestamp
)

select
	case
		when first_order_delayed_flag = 0 then 'normal'
		else 'delayed'
	end as delivery_group,
	count(*) as eligible_after_delivery_90d_customer_cnt,
	count(*) filter (
		where first_post_delivery_order_timestamp
			<= first_delivery_timestamp + interval '90 days'
	) as repurchase_after_delivery_90d_customer_cnt,
	round(
		count(*) filter (
			where first_post_delivery_order_timestamp
				<= first_delivery_timestamp + interval '90 days'
		)::numeric
		/ count(*) * 100,
		2
	) as repurchase_after_delivery_90d_rate
from eligible_base
group by first_order_delayed_flag
order by first_order_delayed_flag;
/*
확인 결과:
- 첫 배송 완료 이후 90일을 온전히 관찰할 수 있는 고객은 정상 배송 67,826명, 배송 지연 5,217명이었다.
- 배송 완료 이후 90일 재구매율은 정상 배송 고객 1.16%, 배송 지연 고객 0.79%로 나타나 배송 지연 고객이 0.37%p 낮았다.
- 배송 지연 고객의 재구매율은 정상 배송 고객의 약 68% 수준이었다.
- 기존 첫 주문일 기준 비교에서도 배송 지연 고객의 재구매율이 0.30%p 낮았으며, 배송 완료 이후로 기준을 제한해도 동일한 방향이 유지됐다.
- 따라서 첫 배송 이전 재구매가 다수 존재한다는 시간 순서 문제를 보정한 뒤에도 배송 지연 고객의 후속 재구매율이 상대적으로 낮게 관찰됐다.
- 다만 관측 데이터 기반 결과이므로 배송 지연이 재구매 감소의 직접적인 원인이라고 단정하지 않는다.
*/



-- =========================================================
-- 7-1. 첫 주문 배송 지연 여부별 리뷰 경험 비교
-- =========================================================

with delivery_review_base as (
	select
		customer_unique_id,
		first_order_delayed_flag,
		first_order_review_score
	from customer_behavior_mart
	where first_order_delayed_flag is not null
)

select
	case
		when first_order_delayed_flag = 0 then 'normal'
		else 'delayed'
	end as delivery_group,
	count(*) as customer_cnt,
	count(*) filter (where first_order_review_score is not null) as reviewed_customer_cnt,
	round(
		avg(first_order_review_score)::numeric,
		2
	) as avg_review_score,
	count(*) filter (
		where first_order_review_score < 3
	) as low_review_customer_cnt,
	round(
		count(*) filter (
			where first_order_review_score < 3
		)::numeric
		/ nullif(count(*) filter (where first_order_review_score is not null), 0) * 100,
		2
	) as low_review_rate,
	round(
		count(*) filter (
			where first_order_review_score is null
		)::numeric
		/ count(*) * 100,
		2
	) as no_review_rate
from delivery_review_base
group by first_order_delayed_flag
order by first_order_delayed_flag;
/*
확인 결과:
- 배송 지연 여부 null 8건을 제외한 93,350명이 분석됐으며, 기존 고객 수 검증 결과와 일치했다.
- 평균 리뷰 점수는 정상 배송 4.29점, 배송 지연 2.27점으로 배송 지연 고객이 2.02점 낮았다.
- 리뷰 작성 고객 중 3점 미만 저리뷰 비율은 정상 배송 9.28%, 배송 지연 62.54%로 53.26%p 차이가 나타났다.
- 리뷰 미작성률도 정상 배송 0.54%, 배송 지연 2.30%로 배송 지연 고객에서 더 높았다.
- 따라서 리뷰 점수는 재구매 타깃을 구분하는 변수로서는 패턴이 약했지만, 배송 경험의 고객 만족도를 진단하는 CX 결과지표로서는 뚜렷한 차이를 보였다.
- 관측 데이터의 그룹 비교이므로 배송 지연이 낮은 리뷰 점수의 직접적인 원인이라고 단정하지 않는다.
*/



-- =========================================================
-- 7-2. 첫 주문 배송 지연 강도별 리뷰 경험 비교
-- =========================================================

with delayed_delivery_base as (
	select
		c.customer_unique_id,
		c.first_order_review_score,
		nullif(trim(o.order_delivered_customer_date), '')::date
			- nullif(trim(o.order_estimated_delivery_date), '')::date as delay_days
	from customer_behavior_mart c
		left join orders o
			on c.first_order_id = o.order_id
	where c.first_order_delayed_flag = 1
),
delay_thresholds as (
	select
		percentile_cont(0.25) within group (order by delay_days) as q1,
		percentile_cont(0.50) within group (order by delay_days) as median,
		percentile_cont(0.75) within group (order by delay_days) as q3
	from delayed_delivery_base
),
delay_group_base as (
	select
		d.customer_unique_id,
		d.first_order_review_score,
		case
			when d.delay_days <= t.q1 then 'q1'
			when d.delay_days <= t.median then 'q2'
			when d.delay_days <= t.q3 then 'q3'
			else 'q4'
		end as delay_group
	from delayed_delivery_base d
		cross join delay_thresholds t
)

select
	delay_group,
	count(*) as customer_cnt,
	count(*) filter (where first_order_review_score is not null) as reviewed_customer_cnt,
	round(
		avg(first_order_review_score)::numeric,
		2
	) as avg_review_score,
	round(
		count(*) filter (where first_order_review_score < 3)::numeric
		/ nullif(count(*) filter (where first_order_review_score is not null), 0) * 100,
		2
	) as low_review_rate,
	round(
		count(*) filter (where first_order_review_score is null)::numeric
		/ count(*) * 100,
		2
	) as no_review_rate
from delay_group_base
group by delay_group
order by delay_group;
/*
확인 결과:
- 배송 지연 고객 6,355명을 지연일수 사분위 기준으로 구분했으며, 전체 고객 수와 리뷰 작성 고객 수 6,209명이 기존 결과와 일치했다.
- 평균 리뷰 점수는 q1(3일 이하) 3.29점, q2(4~7일) 2.09점, q3(8~13일) 1.69점, q4(14일 이상) 1.70점으로 지연이 길어질수록 전반적으로 크게 낮아졌다.
- 저리뷰율도 q1 32.08%에서 q2 68.08%, q3 79.79%, q4 79.00%로 높아졌으며, 특히 4일 이상 지연부터 부정적 리뷰가 급격히 증가했다.
- q3와 q4의 리뷰 수준은 거의 유사해 8일 이상에서는 추가 지연에 따른 악화보다 이미 낮은 만족도가 지속되는 패턴으로 해석했다.
- 따라서 배송 지연 여부뿐 아니라 지연 강도 역시 고객 만족도와 뚜렷한 관련성을 보였으며, 장기 지연 고객은 CX 개선 우선 대상 후보로 볼 수 있다.
- 관측 데이터 기반 비교이므로 지연일수가 낮은 리뷰의 직접적인 원인이라고 단정하지 않는다.
*/


-- =========================================================
-- 8. 첫 주문 리뷰 점수별 90일 재구매율 확인
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
-- 9. 첫 주문 리뷰 구간별 90일 재구매율 비교
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
-- 10. 첫 주문금액 분포 확인
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
-- 11. 첫 주문금액 사분위별 90일 재구매율 비교
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
-- 12. 첫 주문 카테고리 구조 검증
-- =========================================================

with first_order_category_base as (
	select
		c.customer_unique_id,
		c.first_order_id,
		i.order_item_id,
		nullif(trim(cat.product_category_name_english), '') as product_category_name_english
	from customer_behavior_mart c
		left join items i
			on c.first_order_id = i.order_id
		left join products p
			on i.product_id = p.product_id
		left join category cat
			on p.product_category_name = cat.product_category_name
),

first_order_category_summary as (
	select
		customer_unique_id,
		first_order_id,
		count(order_item_id) as item_cnt,
		count(distinct product_category_name_english) as category_cnt,
		count(*) filter (
			where order_item_id is not null
				and product_category_name_english is null
		) as null_category_item_cnt
	from first_order_category_base
	group by
		customer_unique_id,
		first_order_id
)

select
	count(*) as customer_cnt,
	count(*) filter (where category_cnt = 0) as no_category_customer_cnt,
	count(*) filter (
		where category_cnt = 1
			and null_category_item_cnt = 0
	) as single_category_customer_cnt,
	round(
		count(*) filter (
			where category_cnt = 1
				and null_category_item_cnt = 0
		)::numeric
		/ count(*) * 100,
		2
	) as single_category_rate,
	count(*) filter (
		where category_cnt >= 2
			and null_category_item_cnt = 0
	) as multi_category_customer_cnt,
	round(
		count(*) filter (
			where category_cnt >= 2
				and null_category_item_cnt = 0
		)::numeric
		/ count(*) * 100,
		2
	) as multi_category_rate,
	count(*) filter (
		where null_category_item_cnt > 0
	) as unknown_category_customer_cnt,
	max(category_cnt) as max_category_cnt,
	max(item_cnt) as max_item_cnt
from first_order_category_summary;
/*
확인 결과:
- 전체 고객 93,358명 중 첫 주문이 단일 카테고리인 고객은 91,320명으로 97.82%를 차지했다.
- 복수 카테고리 고객은 671명으로 0.72%였으며, 한 첫 주문에 포함된 최대 카테고리 수는 3개였다.
- 카테고리 정보가 불완전한 unknown_category 고객은 1,367명(1.46%)이었고, 이 중 1,309명은 확인 가능한 카테고리가 하나도 없었다.
- 나머지 58명은 확인 가능한 카테고리와 카테고리 미확인 item이 함께 포함된 첫 주문으로 확인됐다.
- 첫 주문의 97.82%가 단일 카테고리이므로 대표 카테고리를 임의로 선정하지 않고, 단일 카테고리는 실제 영어 카테고리명, 복수 카테고리는 multi_category, 카테고리 정보가 불완전한 주문은 unknown_category로 분류한다.
*/



-- =========================================================
-- 13-1. 첫 주문 카테고리별 90일 재구매율 비교
-- =========================================================

with first_order_category_base as (
	select
		c.customer_unique_id,
		c.first_order_id,
		c.eligible_90d,
		c.repurchase_90d,
		i.order_item_id,
		nullif(trim(cat.product_category_name_english), '') as product_category_name_english
	from customer_behavior_mart c
		left join items i
			on c.first_order_id = i.order_id
		left join products p
			on i.product_id = p.product_id
		left join category cat
			on p.product_category_name = cat.product_category_name
),

first_order_category_summary as (
	select
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d,
		count(distinct product_category_name_english) as category_cnt,
		count(*) filter (
			where order_item_id is not null
				and product_category_name_english is null
		) as null_category_item_cnt,
		max(product_category_name_english) as single_category_name
	from first_order_category_base
	group by
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d
),

category_group_base as (
	select
		customer_unique_id,
		eligible_90d,
		repurchase_90d,
		case
			when null_category_item_cnt > 0 then 'unknown_category'
			when category_cnt = 1 then single_category_name
			when category_cnt >= 2 then 'multi_category'
			else 'unknown_category'
		end as first_order_category
	from first_order_category_summary
)

select
	first_order_category,
	count(*) filter (
		where eligible_90d = 1
	) as eligible_90d_customer_cnt,
	count(*) filter (
		where repurchase_90d = 1
	) as repurchase_90d_customer_cnt,
	round(
		count(*) filter (
			where repurchase_90d = 1
		)::numeric
		/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
		2
	) as repurchase_90d_rate
from category_group_base
group by first_order_category
order by eligible_90d_customer_cnt desc;
/*
확인 결과:
- 첫 주문 카테고리별 90일 재구매율은 서로 다른 수준으로 나타났으나, 카테고리별 표본 수 차이가 매우 컸다.
- 표본이 충분한 주요 카테고리 중 bed_bath_table 3.91%, furniture_decor 3.40%, sports_leisure 2.86%, fashion_bags_accessories 4.49% 등은 전체 90일 재구매율 2.28%보다 높게 나타났다.
- 반면 cool_stuff 0.93%, electronics 1.08%, stationery 1.33%, telephony 1.52%, watches_gifts 1.59% 등은 전체 재구매율보다 낮았다.
- 소규모 카테고리는 재구매 고객 몇 명의 차이만으로 비율이 크게 변동하므로 단순 재구매율 순위만으로 해석하지 않는다.
- 이후 충분한 표본을 가진 카테고리로 범위를 제한해 전체 재구매율 대비 차이를 비교한다.
*/



-- =========================================================
-- 13-2. 주요 첫 주문 카테고리별 90일 재구매율 비교
-- =========================================================

with first_order_category_base as (
	select
		c.customer_unique_id,
		c.first_order_id,
		c.eligible_90d,
		c.repurchase_90d,
		i.order_item_id,
		nullif(trim(cat.product_category_name_english), '') as product_category_name_english
	from customer_behavior_mart c
		left join items i
			on c.first_order_id = i.order_id
		left join products p
			on i.product_id = p.product_id
		left join category cat
			on p.product_category_name = cat.product_category_name
),

first_order_category_summary as (
	select
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d,
		count(distinct product_category_name_english) as category_cnt,
		count(*) filter (
			where order_item_id is not null
				and product_category_name_english is null
		) as null_category_item_cnt,
		max(product_category_name_english) as single_category_name
	from first_order_category_base
	group by
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d
),

category_group_base as (
	select
		customer_unique_id,
		eligible_90d,
		repurchase_90d,
		case
			when null_category_item_cnt > 0 then 'unknown_category'
			when category_cnt = 1 then single_category_name
			when category_cnt >= 2 then 'multi_category'
			else 'unknown_category'
		end as first_order_category
	from first_order_category_summary
),

category_summary as (
	select
		first_order_category,
		count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
		count(*) filter (where repurchase_90d = 1) as repurchase_90d_customer_cnt,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100
			as repurchase_90d_rate
	from category_group_base
	group by first_order_category
),

overall_summary as (
	select
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) filter (where eligible_90d = 1) * 100
			as overall_repurchase_90d_rate
	from customer_behavior_mart
)

select
	c.first_order_category,
	c.eligible_90d_customer_cnt,
	c.repurchase_90d_customer_cnt,
	round(c.repurchase_90d_rate, 2) as repurchase_90d_rate,
	round(
		c.repurchase_90d_rate - o.overall_repurchase_90d_rate,
		2
	) as diff_from_overall_pp
from category_summary c
	cross join overall_summary o
where c.eligible_90d_customer_cnt >= 1000
	and c.first_order_category not in ('unknown_category', 'multi_category')
order by c.repurchase_90d_rate desc;
/*
확인 결과:
- 90일 관찰 가능 고객이 1,000명 이상인 실제 상품 카테고리 19개를 비교한 결과, 카테고리별 재구매율 차이가 뚜렷하게 나타났다.
- fashion_bags_accessories 4.49%(+2.21%p), bed_bath_table 3.91%(+1.63%p), furniture_decor 3.40%(+1.12%p), sports_leisure 2.86%(+0.58%p)는 전체 90일 재구매율보다 높았다.
- 반면 cool_stuff 0.93%(-1.35%p), electronics 1.08%(-1.20%p), stationery 1.33%(-0.95%p), office_furniture 1.49%(-0.79%p), telephony 1.52%(-0.76%p)는 전체보다 낮았다.
- health_beauty는 2.26%로 전체 재구매율과 거의 유사했다.
- unknown_category와 multi_category는 실제 단일 상품 카테고리 비교에서 제외했다.
- 따라서 첫 주문 카테고리는 이후 90일 재구매율 차이를 해석하는 중요한 상품 특성 변수로 확인됐으며, 충분한 표본을 가진 카테고리를 중심으로 해석한다.
*/



-- =========================================================
-- 13-3. 주요 카테고리 내 첫 주문금액 사분위별 90일 재구매율 비교
-- =========================================================

with first_order_category_base as (
	select
		c.customer_unique_id,
		c.first_order_id,
		c.first_order_payment_total,
		c.eligible_90d,
		c.repurchase_90d,
		i.order_item_id,
		nullif(trim(cat.product_category_name_english), '') as product_category_name_english
	from customer_behavior_mart c
		left join items i
			on c.first_order_id = i.order_id
		left join products p
			on i.product_id = p.product_id
		left join category cat
			on p.product_category_name = cat.product_category_name
),

first_order_category_summary as (
	select
		customer_unique_id,
		first_order_id,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d,
		count(distinct product_category_name_english) as category_cnt,
		count(*) filter (
			where order_item_id is not null
				and product_category_name_english is null
		) as null_category_item_cnt,
		max(product_category_name_english) as single_category_name
	from first_order_category_base
	group by
		customer_unique_id,
		first_order_id,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d
),

category_group_base as (
	select
		customer_unique_id,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d,
		case
			when null_category_item_cnt > 0 then 'unknown_category'
			when category_cnt = 1 then single_category_name
			when category_cnt >= 2 then 'multi_category'
			else 'unknown_category'
		end as first_order_category
	from first_order_category_summary
),

major_category as (
	select
		first_order_category
	from category_group_base
	where eligible_90d = 1
		and first_order_category not in ('unknown_category', 'multi_category')
	group by first_order_category
	having count(*) >= 1000
),

payment_thresholds as (
	select
		percentile_cont(0.25) within group (order by first_order_payment_total) as q1,
		percentile_cont(0.50) within group (order by first_order_payment_total) as median,
		percentile_cont(0.75) within group (order by first_order_payment_total) as q3
	from customer_behavior_mart
	where eligible_90d = 1
		and first_order_payment_total is not null
),

category_payment_base as (
	select
		c.customer_unique_id,
		c.first_order_category,
		c.repurchase_90d,
		case
			when c.first_order_payment_total <= p.q1 then 'q1'
			when c.first_order_payment_total <= p.median then 'q2'
			when c.first_order_payment_total <= p.q3 then 'q3'
			else 'q4'
		end as payment_group
	from category_group_base c
		inner join major_category m
			on c.first_order_category = m.first_order_category
		cross join payment_thresholds p
	where c.eligible_90d = 1
		and c.first_order_payment_total is not null
)

select
	first_order_category,

	count(*) filter (where payment_group = 'q1') as q1_customer_cnt,
	round(
		count(*) filter (where payment_group = 'q1' and repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where payment_group = 'q1'), 0) * 100,
		2
	) as q1_repurchase_rate,

	count(*) filter (where payment_group = 'q2') as q2_customer_cnt,
	round(
		count(*) filter (where payment_group = 'q2' and repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where payment_group = 'q2'), 0) * 100,
		2
	) as q2_repurchase_rate,

	count(*) filter (where payment_group = 'q3') as q3_customer_cnt,
	round(
		count(*) filter (where payment_group = 'q3' and repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where payment_group = 'q3'), 0) * 100,
		2
	) as q3_repurchase_rate,

	count(*) filter (where payment_group = 'q4') as q4_customer_cnt,
	round(
		count(*) filter (where payment_group = 'q4' and repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where payment_group = 'q4'), 0) * 100,
		2
	) as q4_repurchase_rate

from category_payment_base
group by first_order_category
having count(*) filter (where payment_group = 'q1') >= 100
	and count(*) filter (where payment_group = 'q2') >= 100
	and count(*) filter (where payment_group = 'q3') >= 100
	and count(*) filter (where payment_group = 'q4') >= 100
order by first_order_category;
/*
확인 결과:
- q1~q4 각 금액 구간에 최소 100명 이상 존재하는 18개 주요 카테고리를 비교했다.
- 18개 중 13개 카테고리에서 q4 재구매율이 q1보다 낮아 전체 고객에서 관찰된 고금액군의 낮은 재구매율과 같은 방향이 다수 카테고리에서 유지됐다.
- 반면 bed_bath_table, computers_accessories, pet_shop, sports_leisure, telephony에서는 q4 재구매율이 q1보다 높아 모든 카테고리에서 동일한 관계가 나타나지는 않았다.
- 또한 q1→q4로 재구매율이 단조롭게 감소하지 않는 카테고리도 있어 첫 주문금액과 재구매의 관계가 상품군에 따라 달라질 수 있음을 확인했다.
- 따라서 전체 고객에서 나타난 첫 주문금액 패턴이 단순히 카테고리 구성 차이만으로 설명되지는 않지만, 첫 주문금액을 독립적인 영향 요인으로 해석하지 않고 상품 카테고리 특성과 함께 고려한다.
*/



-- =========================================================
-- 14. 첫 주문금액 30 / 60 / 90일 민감도 분석
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
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
		end as payment_group
	from repurchase_driver_base b
		cross join payment_thresholds t
	where b.first_order_payment_total is not null
)

select
	payment_group,
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
group by payment_group
order by payment_group;
/*
확인 결과:
- 첫 주문금액은 30/60/90일 모두 저금액군의 재구매율이 상대적으로 높게 나타났다.
- q1과 q4의 재구매율 차이는 30일 0.31%p, 60일 0.41%p, 90일 0.39%p로 기간을 변경해도 동일한 방향이 유지됐다.
- 30일 기준에서는 q1 1.74%, q2 1.75%로 거의 동일했으며, 전반적으로 q1·q2 저금액군이 q3·q4 고금액군보다 높은 재구매율을 보였다.
- 다만 주요 카테고리 내부 비교에서는 모든 카테고리가 동일한 방향을 보이지 않았고, 카테고리별 금액 분포도 크게 달랐다.
- 따라서 첫 주문금액은 기간 기준을 변경해도 일관된 전체 패턴을 보였으나, 독립적인 영향 요인으로 단정하지 않고 상품 카테고리 특성과 함께 해석한다.
*/



-- =========================================================
-- 15. 재구매 관련 요인 최종 결과 요약
-- =========================================================

with repurchase_driver_base as (
	select
		customer_unique_id,
		first_order_id,
		first_order_delayed_flag,
		first_order_review_score,
		first_order_payment_total,
		eligible_90d,
		repurchase_90d
	from customer_behavior_mart
),

payment_thresholds as (
	select
		percentile_cont(0.25) within group (order by first_order_payment_total) as q1,
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
			when b.first_order_payment_total > t.q3 then 'q4'
		end as payment_group
	from repurchase_driver_base b
		cross join payment_thresholds t
	where b.eligible_90d = 1
		and b.first_order_payment_total is not null
),

payment_summary as (
	select
		payment_group,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from payment_group_base
	where payment_group is not null
	group by payment_group
),

observation_end as (
	select
		max(nullif(trim(order_purchase_timestamp), '')::timestamp) as observation_end_timestamp
	from orders
	where order_status = 'delivered'
),

first_order_delivery as (
	select
		c.customer_unique_id,
		c.first_order_delayed_flag,
		nullif(trim(o.order_delivered_customer_date), '')::timestamp
			as first_delivery_timestamp
	from customer_behavior_mart c
		left join orders o
			on c.first_order_id = o.order_id
),

delivered_order_history as (
	select
		c.customer_unique_id,
		nullif(trim(o.order_purchase_timestamp), '')::timestamp as purchase_timestamp
	from orders o
		inner join customers c
			on o.customer_id = c.customer_id
	where o.order_status = 'delivered'
		and nullif(trim(o.order_purchase_timestamp), '') is not null
),

post_delivery_base as (
	select
		f.customer_unique_id,
		f.first_order_delayed_flag,
		f.first_delivery_timestamp,
		min(d.purchase_timestamp) as first_post_delivery_order_timestamp
	from first_order_delivery f
		left join delivered_order_history d
			on f.customer_unique_id = d.customer_unique_id
			and d.purchase_timestamp > f.first_delivery_timestamp
	group by
		f.customer_unique_id,
		f.first_order_delayed_flag,
		f.first_delivery_timestamp
),

delivery_summary as (
	select
		case
			when p.first_order_delayed_flag = 0 then 'normal'
			else 'delayed'
		end as delivery_group,
		count(*) filter (
			where p.first_post_delivery_order_timestamp
				<= p.first_delivery_timestamp + interval '90 days'
		)::numeric
		/ count(*) * 100 as repurchase_90d_rate
	from post_delivery_base p
		cross join observation_end o
	where p.first_delivery_timestamp is not null
		and p.first_order_delayed_flag is not null
		and p.first_delivery_timestamp + interval '90 days'
			<= o.observation_end_timestamp
	group by p.first_order_delayed_flag
),

review_group_base as (
	select
		repurchase_90d,
		case
			when first_order_review_score < 3 then 'low'
			when first_order_review_score >= 4 then 'high'
		end as review_group
	from repurchase_driver_base
	where eligible_90d = 1
		and first_order_review_score is not null
),

review_summary as (
	select
		review_group,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) * 100 as repurchase_90d_rate
	from review_group_base
	where review_group is not null
	group by review_group
),

first_order_category_base as (
	select
		c.customer_unique_id,
		c.first_order_id,
		c.eligible_90d,
		c.repurchase_90d,
		i.order_item_id,
		nullif(trim(cat.product_category_name_english), '') as product_category_name_english
	from customer_behavior_mart c
		left join items i
			on c.first_order_id = i.order_id
		left join products p
			on i.product_id = p.product_id
		left join category cat
			on p.product_category_name = cat.product_category_name
),

first_order_category_summary as (
	select
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d,
		count(distinct product_category_name_english) as category_cnt,
		count(*) filter (
			where order_item_id is not null
				and product_category_name_english is null
		) as null_category_item_cnt,
		max(product_category_name_english) as single_category_name
	from first_order_category_base
	group by
		customer_unique_id,
		first_order_id,
		eligible_90d,
		repurchase_90d
),

category_group_base as (
	select
		customer_unique_id,
		eligible_90d,
		repurchase_90d,
		case
			when null_category_item_cnt > 0 then 'unknown_category'
			when category_cnt = 1 then single_category_name
			when category_cnt >= 2 then 'multi_category'
			else 'unknown_category'
		end as first_order_category
	from first_order_category_summary
),

category_summary as (
	select
		first_order_category,
		count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
		count(*) filter (where repurchase_90d = 1)::numeric
			/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100
			as repurchase_90d_rate
	from category_group_base
	where first_order_category not in ('unknown_category', 'multi_category')
	group by first_order_category
	having count(*) filter (where eligible_90d = 1) >= 1000
),

category_range as (
	select
		(select first_order_category
		from category_summary
		order by repurchase_90d_rate desc
		limit 1) as highest_category,
		(select repurchase_90d_rate
		from category_summary
		order by repurchase_90d_rate desc
		limit 1) as highest_rate,
		(select first_order_category
		from category_summary
		order by repurchase_90d_rate
		limit 1) as lowest_category,
		(select repurchase_90d_rate
		from category_summary
		order by repurchase_90d_rate
		limit 1) as lowest_rate
),

final_summary as (
	select
		1 as sort_order,
		'first_order_payment' as factor,
		'targeting_signal' as analysis_role,
		'q1 vs q4' as comparison,
		round(max(repurchase_90d_rate) filter (where payment_group = 'q1'), 2) as reference_rate,
		round(max(repurchase_90d_rate) filter (where payment_group = 'q4'), 2) as comparison_rate,
		round(
			max(repurchase_90d_rate) filter (where payment_group = 'q4')
			- max(repurchase_90d_rate) filter (where payment_group = 'q1'),
			2
		) as difference_pp
	from payment_summary

	union all

	select
		2,
		'delivery_delay',
		'operational_experience',
		'normal vs delayed after delivery',
		round(max(repurchase_90d_rate) filter (where delivery_group = 'normal'), 2),
		round(max(repurchase_90d_rate) filter (where delivery_group = 'delayed'), 2),
		round(
			max(repurchase_90d_rate) filter (where delivery_group = 'delayed')
			- max(repurchase_90d_rate) filter (where delivery_group = 'normal'),
			2
		)
	from delivery_summary

	union all

	select
		3,
		'review_score',
		'cx_metric',
		'low vs high',
		round(max(repurchase_90d_rate) filter (where review_group = 'low'), 2),
		round(max(repurchase_90d_rate) filter (where review_group = 'high'), 2),
		round(
			max(repurchase_90d_rate) filter (where review_group = 'high')
			- max(repurchase_90d_rate) filter (where review_group = 'low'),
			2
		)
	from review_summary

	union all

	select
		4,
		'first_order_category',
		'product_context',
		highest_category || ' vs ' || lowest_category,
		round(highest_rate, 2),
		round(lowest_rate, 2),
		round(
			lowest_rate - highest_rate,
			2
		)
	from category_range
)

select
	factor,
	analysis_role,
	comparison,
	reference_rate,
	comparison_rate,
	difference_pp
from final_summary
order by sort_order;
/*
확인 결과:
- 첫 주문금액은 q1 2.46%, q4 2.07%로 0.39%p 차이가 나타났으며, 30/60/90일 기준에서도 저금액군의 재구매율이 상대적으로 높은 전체 패턴이 유지됐다.
- 다만 카테고리 내부 분석에서는 일부 상품군에서 반대 방향이나 비선형 패턴도 확인돼 첫 주문금액을 독립적인 영향 요인으로 해석하지 않고 타깃 구분 신호로 활용한다.
- 첫 배송 완료 이후 90일 기준에서도 정상 배송 고객 1.16%, 배송 지연 고객 0.79%로 0.37%p 차이가 유지돼 배송 지연은 운영 경험 개선 후보로 볼 수 있다.
- 배송 지연 고객은 평균 리뷰 점수와 저리뷰율에서도 큰 차이를 보였으며, 특히 장기 지연 고객의 만족도가 크게 낮아 리뷰는 재구매 driver보다 고객 경험(CX) 결과지표로 활용하는 것이 적절하다.
- 리뷰 low와 high 그룹의 90일 재구매율 차이는 0.02%p에 불과해 재구매 타깃 구분 변수로서의 우선순위는 낮았다.
- 표본 1,000명 이상 주요 카테고리에서도 재구매율 차이가 크게 나타났으며, 첫 주문 상품 카테고리는 재구매 패턴을 해석하는 중요한 상품 특성 변수로 확인됐다.
- 카테고리의 3.56%p 차이는 서로 다른 상품군 간 재구매율 범위이므로 첫 주문금액이나 배송 지연의 효과 크기와 직접 비교하지 않는다.
- 모든 결과는 관측 데이터 기반 그룹 비교이며 각 요인이 재구매율 변화의 직접적인 원인이라고 단정하지 않는다.
*/