/*
olist 코호트 리텐션 분석

목적:
- 첫 구매월 기준 고객 코호트를 구성한다.
- 코호트별 m+1, m+2, m+3 리텐션과 30/60/90일 재구매율을 비교한다.
- 관찰 기간을 고려해 코호트별 재구매 성과를 분석한다.
*/


-- =========================================================
-- 1. 코호트 분석용 주문 데이터 구성
-- cohort_order_base
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	)

-- 구조 확인
select
	count(*) as order_cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(distinct customer_unique_id) as customer_cnt,
	count(*) filter (where cohort_month is null) as null_cohort_cnt
from cohort_order_base;
/*
확인 결과:
- delivered 주문 수와 distinct order_id가 모두 96,478건으로 일치했다.
- 코호트 분석 대상 고객은 93,358명이며 cohort_month null은 없었다.
*/



-- =========================================================
-- 2. 주문월 및 코호트 경과개월 계산
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	)

-- 구조 확인
select
	count(*) as order_cnt,
	count(*) filter (where order_month is null) as null_order_month_cnt,
	count(*) filter (where month_number < 0) as negative_month_cnt,
	min(month_number) as min_month_number,
	max(month_number) as max_month_number
from cohort_order_period;
/*
확인 결과:
- delivered 주문 96,478건 모두 order_month가 정상적으로 계산됐으며, 음수 month_number는 없었다.
- month_number는 0부터 20까지 분포해 첫 구매월부터 최대 m+20까지 재구매 기록이 확인됐다.
*/



-- =========================================================
-- 3. 코호트별 고객 수 확인
-- cohort_size
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
)

select *
from cohort_size
order by cohort_month;

-- 구조 확인 (위 cte 생략)
select
	count(*) as cohort_cnt,
	sum(cohort_size) as total_customer_cnt,
	min(cohort_month) as first_cohort_month,
	max(cohort_month) as last_cohort_month
from cohort_size;
/*
확인 결과:
- 첫 구매월 기준 총 23개 코호트가 생성됐으며, 코호트별 고객 수 합계는 전체 고객 93,358명과 일치했다.
- 코호트는 2016-09부터 2018-08까지 분포하며, 2016-11에는 신규 고객 코호트가 존재하지 않았다.
- 초기 코호트는 표본 수가 매우 작아 이후 리텐션율 해석 시 표본 크기를 함께 고려한다.
*/



-- =========================================================
-- 4. m+1 / m+2 / m+3 재구매 고객 수 확인
-- cohort_retained_customer
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
	),
	
cohort_retained_customer as (
	select
		cohort_month,
		count(distinct customer_unique_id) filter (where month_number = 1) as m1_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 2) as m2_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 3) as m3_customer_cnt
	from cohort_order_period
	group by cohort_month
)

select *
from cohort_retained_customer
order by cohort_month;
/*
확인 결과:
- 총 23개 코호트에서 m+1, m+2, m+3 재구매 고객 수를 확인했다.
- 최근 코호트는 데이터 종료 시점으로 인해 일부 기간을 완전히 관찰할 수 없어, 해당 값은 이후 리텐션율 계산에서 제외한다.
*/



-- =========================================================
-- 5. m+1 / m+2 / m+3 관찰 가능 여부 확인
-- cohort_observation
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
	),
	
cohort_retained_customer as (
	select
		cohort_month,
		count(distinct customer_unique_id) filter (where month_number = 1) as m1_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 2) as m2_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 3) as m3_customer_cnt
	from cohort_order_period
	group by cohort_month
	), 

cohort_observation as (
	select
		cohort_month,
		case
			when cohort_month + interval '1 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m1,
		case
			when cohort_month + interval '2 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m2,
		case
			when cohort_month + interval '3 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m3
	from cohort_size
)

-- 구조 확인
select
	count(*) as cohort_cnt,
	sum(eligible_m1) as eligible_m1_cohort_cnt,
	sum(eligible_m2) as eligible_m2_cohort_cnt,
	sum(eligible_m3) as eligible_m3_cohort_cnt
from cohort_observation;
/*
확인 결과:
- 총 23개 코호트 중 m+1은 21개, m+2는 20개, m+3는 19개 코호트에서 완전한 관찰이 가능했다.
- 마지막 완전 관찰월인 2018-07을 기준으로 이후 기간이 불완전한 코호트는 리텐션율 계산에서 제외한다.
*/



-- =========================================================
-- 6. m+1 / m+2 / m+3 코호트 리텐션율 계산
-- cohort_retention_summary
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
	),
	
cohort_retained_customer as (
	select
		cohort_month,
		count(distinct customer_unique_id) filter (where month_number = 1) as m1_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 2) as m2_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 3) as m3_customer_cnt
	from cohort_order_period
	group by cohort_month
	), 

cohort_observation as (
	select
		cohort_month,
		case
			when cohort_month + interval '1 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m1,
		case
			when cohort_month + interval '2 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m2,
		case
			when cohort_month + interval '3 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m3
	from cohort_size
	),

cohort_retention_summary as (
	select
		s.cohort_month,
		s.cohort_size,
		r.m1_customer_cnt,
		r.m2_customer_cnt,
		r.m3_customer_cnt,
		case
			when o.eligible_m1 = 1 then round(
				r.m1_customer_cnt::numeric 
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m1_retention_rate,

		case
			when o.eligible_m2 = 1 then round(
				r.m2_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m2_retention_rate,

		case
			when o.eligible_m3 = 1 then round(
				r.m3_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m3_retention_rate
	from cohort_size s
		left join cohort_retained_customer r
			on s.cohort_month = r.cohort_month
		left join cohort_observation o
			on s.cohort_month = o.cohort_month
)

select *
from cohort_retention_summary
order by cohort_month;
/*
확인 결과:
- 관찰 가능한 코호트의 m+1, m+2, m+3 리텐션율은 대부분 1% 미만으로 낮게 나타났다.
- 2016-12 코호트의 m+1 리텐션율은 100%였지만 cohort_size가 1명이므로 대표적인 성과로 해석하지 않는다.
- 최근 코호트의 관찰 불가능한 기간은 0%가 아닌 null로 처리했다.
*/



-- =========================================================
-- 7. 코호트별 30 / 60 / 90일 재구매율 계산
-- =========================================================

select
	cohort_month,
	count(*) filter (where eligible_30d = 1) as eligible_30d_customer_cnt,
	count(*) filter (where eligible_60d = 1) as eligible_60d_customer_cnt,
	count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,

	count(*) filter (where repurchase_30d = 1) as repurchase_30d_customer_cnt,
	count(*) filter (where repurchase_60d = 1) as repurchase_60d_customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_90d_customer_cnt,

	round(
		count(*) filter (where repurchase_30d = 1)::numeric
		/ nullif(count(*) filter (where eligible_30d = 1), 0) * 100,
		2
	) as repurchase_30d_rate,

	round(
		count(*) filter (where repurchase_60d = 1)::numeric
		/ nullif(count(*) filter (where eligible_60d = 1), 0) * 100,
		2
	) as repurchase_60d_rate,

	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
		2
	) as repurchase_90d_rate
from customer_behavior_mart
group by cohort_month
order by cohort_month;
/*
확인 결과:
- 코호트별 30/60/90일 재구매율은 관찰 가능한 고객만 분모에 포함해 계산했다.
- 대부분의 코호트에서 관찰 기간이 길어질수록 누적 재구매율이 증가했으며, 대체로 1~3% 수준으로 나타났다.
- 관찰 가능한 고객이 없는 최근 코호트는 재구매율을 0%가 아닌 null로 처리했다.
*/



-- =========================================================
-- 8. 전체 코호트 리텐션 수준 확인
-- =========================================================

select
	sum(case when o.eligible_m1 = 1 then s.cohort_size else 0 end) as eligible_m1_customer_cnt,
	sum(case when o.eligible_m2 = 1 then s.cohort_size else 0 end) as eligible_m2_customer_cnt,
	sum(case when o.eligible_m3 = 1 then s.cohort_size else 0 end) as eligible_m3_customer_cnt,

	sum(case when o.eligible_m1 = 1 then r.m1_customer_cnt else 0 end) as m1_customer_cnt,
	sum(case when o.eligible_m2 = 1 then r.m2_customer_cnt else 0 end) as m2_customer_cnt,
	sum(case when o.eligible_m3 = 1 then r.m3_customer_cnt else 0 end) as m3_customer_cnt,

	round(
		sum(case when o.eligible_m1 = 1 then r.m1_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m1 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m1_retention_rate,

	round(
		sum(case when o.eligible_m2 = 1 then r.m2_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m2 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m2_retention_rate,

	round(
		sum(case when o.eligible_m3 = 1 then r.m3_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m3 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m3_retention_rate
from cohort_size s
	left join cohort_retained_customer r
		on s.cohort_month = r.cohort_month
	left join cohort_observation o
		on s.cohort_month = o.cohort_month;
/*
확인 결과:
- 코호트별 30/60/90일 재구매율은 관찰 가능한 고객만 분모에 포함해 계산했다.
- 대부분의 코호트에서 관찰 기간이 길어질수록 누적 재구매율이 증가했으며, 대체로 1~3% 수준으로 나타났다.
- 관찰 가능한 고객이 없는 최근 코호트는 재구매율을 0%가 아닌 null로 처리했다.
*/



-- =========================================================
-- 8. 전체 코호트 리텐션 수준 확인
-- =========================================================


with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
	),
	
cohort_retained_customer as (
	select
		cohort_month,
		count(distinct customer_unique_id) filter (where month_number = 1) as m1_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 2) as m2_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 3) as m3_customer_cnt
	from cohort_order_period
	group by cohort_month
	), 

cohort_observation as (
	select
		cohort_month,
		case
			when cohort_month + interval '1 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m1,
		case
			when cohort_month + interval '2 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m2,
		case
			when cohort_month + interval '3 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m3
	from cohort_size
	),

cohort_retention_summary as (
	select
		s.cohort_month,
		s.cohort_size,
		r.m1_customer_cnt,
		r.m2_customer_cnt,
		r.m3_customer_cnt,
		case
			when o.eligible_m1 = 1 then round(
				r.m1_customer_cnt::numeric 
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m1_retention_rate,

		case
			when o.eligible_m2 = 1 then round(
				r.m2_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m2_retention_rate,

		case
			when o.eligible_m3 = 1 then round(
				r.m3_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m3_retention_rate
	from cohort_size s
		left join cohort_retained_customer r
			on s.cohort_month = r.cohort_month
		left join cohort_observation o
			on s.cohort_month = o.cohort_month
)

select
	sum(case when o.eligible_m1 = 1 then s.cohort_size else 0 end) as eligible_m1_customer_cnt,
	sum(case when o.eligible_m2 = 1 then s.cohort_size else 0 end) as eligible_m2_customer_cnt,
	sum(case when o.eligible_m3 = 1 then s.cohort_size else 0 end) as eligible_m3_customer_cnt,

	sum(case when o.eligible_m1 = 1 then r.m1_customer_cnt else 0 end) as m1_customer_cnt,
	sum(case when o.eligible_m2 = 1 then r.m2_customer_cnt else 0 end) as m2_customer_cnt,
	sum(case when o.eligible_m3 = 1 then r.m3_customer_cnt else 0 end) as m3_customer_cnt,

	round(
		sum(case when o.eligible_m1 = 1 then r.m1_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m1 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m1_retention_rate,

	round(
		sum(case when o.eligible_m2 = 1 then r.m2_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m2 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m2_retention_rate,

	round(
		sum(case when o.eligible_m3 = 1 then r.m3_customer_cnt else 0 end)::numeric
		/ sum(case when o.eligible_m3 = 1 then s.cohort_size else 0 end) * 100,
		2
	) as m3_retention_rate
from cohort_size s
	left join cohort_retained_customer r
		on s.cohort_month = r.cohort_month
	left join cohort_observation o
		on s.cohort_month = o.cohort_month;
/*
확인 결과:
- 관찰 가능한 전체 고객 기준 리텐션율은 m+1 0.48%, m+2 0.34%, m+3 0.26%로 나타났다.
- 첫 구매 후 시간이 지날수록 해당 월에 다시 구매한 고객 비율이 낮아지는 패턴이 확인됐다.
- 코호트별 단순 평균이 아닌 관찰 가능한 전체 고객 수를 기준으로 리텐션율을 계산했다.
*/



-- =========================================================
-- 9. 코호트별 90일 재구매 성과 비교
-- =========================================================

select
	cohort_month,
	count(*) filter (where eligible_90d = 1) as eligible_90d_customer_cnt,
	count(*) filter (where repurchase_90d = 1) as repurchase_90d_customer_cnt,

	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100,
		2
	) as repurchase_90d_rate,

	round(
		count(*) filter (where repurchase_90d = 1)::numeric
		/ nullif(count(*) filter (where eligible_90d = 1), 0) * 100 - 2.28,
		2
	) as diff_from_overall_rate
from customer_behavior_mart
group by cohort_month
having count(*) filter (where eligible_90d = 1) > 0
order by cohort_month;
/*
확인 결과:
- 코호트별 30/60/90일 재구매율을 함께 확인했으며, 90일 재구매율을 초기 3개월 성과의 대표 지표로 비교했다.
- 90일 재구매율은 코호트별 차이가 있었으며, 전체 평균은 2.28%였다.
- 표본이 충분한 코호트 중 2018-02는 2.99%로 상대적으로 높았고, 2018-04와 2018-05는 각각 1.70%, 1.61%로 낮았다.
- 초기 소규모 코호트의 극단적인 재구매율은 표본 수가 매우 작아 성과 비교에서 주의해 해석한다.
*/



-- =========================================================
-- 10. 코호트 리텐션 분석 핵심 결과 요약
-- =========================================================

with cohort_order_base as (
	select
		m.order_id,
		m.customer_unique_id,
		m.purchase_timestamp,
		c.cohort_month
	from order_level_mart m
		left join customer_behavior_mart c
			on m.customer_unique_id = c.customer_unique_id
	where m.order_status = 'delivered'
	),
	
cohort_order_month as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		date_trunc(
			'month',
			nullif(trim(purchase_timestamp), '')::timestamp
		)::date as order_month
	from cohort_order_base
	),
	
cohort_order_period as (
	select
		order_id,
		customer_unique_id,
		cohort_month,
		order_month,
		(
			(extract(year from order_month) - extract(year from cohort_month)) * 12
			+ extract(month from order_month) - extract(month from cohort_month)
		)::int as month_number
	from cohort_order_month
	),
	
cohort_size as (
	select cohort_month, count(distinct customer_unique_id) as cohort_size
	from cohort_order_period
	group by cohort_month
	),
	
cohort_retained_customer as (
	select
		cohort_month,
		count(distinct customer_unique_id) filter (where month_number = 1) as m1_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 2) as m2_customer_cnt,
		count(distinct customer_unique_id) filter (where month_number = 3) as m3_customer_cnt
	from cohort_order_period
	group by cohort_month
	), 

cohort_observation as (
	select
		cohort_month,
		case
			when cohort_month + interval '1 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m1,
		case
			when cohort_month + interval '2 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m2,
		case
			when cohort_month + interval '3 month' <= date '2018-07-01' then 1
			else 0
		end as eligible_m3
	from cohort_size
	),

cohort_retention_summary as (
	select
		s.cohort_month,
		s.cohort_size,
		r.m1_customer_cnt,
		r.m2_customer_cnt,
		r.m3_customer_cnt,
		case
			when o.eligible_m1 = 1 then round(
				r.m1_customer_cnt::numeric 
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m1_retention_rate,

		case
			when o.eligible_m2 = 1 then round(
				r.m2_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m2_retention_rate,

		case
			when o.eligible_m3 = 1 then round(
				r.m3_customer_cnt::numeric
				/ s.cohort_size * 100,
				2
			)
			else null
		end as m3_retention_rate
	from cohort_size s
		left join cohort_retained_customer r
			on s.cohort_month = r.cohort_month
		left join cohort_observation o
			on s.cohort_month = o.cohort_month
	), 

overall_retention as (
	select
		round(
			sum(case when o.eligible_m1 = 1 then r.m1_customer_cnt else 0 end)::numeric
			/ sum(case when o.eligible_m1 = 1 then s.cohort_size else 0 end) * 100,
			2
		) as m1_retention_rate,
		
		round(
			sum(case when o.eligible_m2 = 1 then r.m2_customer_cnt else 0 end)::numeric
			/ sum(case when o.eligible_m2 = 1 then s.cohort_size else 0 end) * 100,
			2
		) as m2_retention_rate,
		
		round(
			sum(case when o.eligible_m3 = 1 then r.m3_customer_cnt else 0 end)::numeric
			/ sum(case when o.eligible_m3 = 1 then s.cohort_size else 0 end) * 100,
			2
		) as m3_retention_rate
		
	from cohort_size s
		left join cohort_retained_customer r
			on s.cohort_month = r.cohort_month
		left join cohort_observation o
			on s.cohort_month = o.cohort_month
	),
	
overall_repurchase as (
	select
		round(
			count(*) filter (where repurchase_30d = 1)::numeric
			/ count(*) filter (where eligible_30d = 1) * 100,
			2
		) as repurchase_30d_rate,
		
		round(
			count(*) filter (where repurchase_60d = 1)::numeric
			/ count(*) filter (where eligible_60d = 1) * 100,
			2
		) as repurchase_60d_rate,
		
		round(
			count(*) filter (where repurchase_90d = 1)::numeric
			/ count(*) filter (where eligible_90d = 1) * 100,
			2
		) as repurchase_90d_rate
	from customer_behavior_mart
	)

select
	r.m1_retention_rate,
	r.m2_retention_rate,
	r.m3_retention_rate,
	p.repurchase_30d_rate,
	p.repurchase_60d_rate,
	
	p.repurchase_90d_rate
from overall_retention r
	cross join overall_repurchase p;
/*
확인 결과:
- 관찰 가능한 고객 기준 월간 리텐션율은 m+1 0.48%, m+2 0.34%, m+3 0.26%로 시간이 지날수록 낮아졌다.;
- 누적 재구매율은 30일 1.59%, 60일 1.96%, 90일 2.28%로 관찰 기간이 길어질수록 증가했다.
- 코호트별 재구매 성과에도 차이가 확인돼, 이후 첫 주문 경험 요인과의 관련성을 추가 분석한다.
*/