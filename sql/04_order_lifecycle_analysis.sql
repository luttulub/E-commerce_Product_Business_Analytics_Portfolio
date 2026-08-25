/*
olist 주문 lifecycle 분석

목적:
- 주문 생성부터 결제 승인, 배송 완료까지의 주문 처리 흐름을 분석한다.
- 단계별 주문 수와 전환율을 확인해 주문 처리 과정의 병목을 파악한다.
- 결제 미승인, 미배송 및 배송 지연 주문의 상태와 규모를 확인한다.
*/


-- =========================================================
-- 1. 주문 lifecycle 기준 데이터 구성
-- lifecycle_base
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)

-- 구조 확인
select
	count(*) as order_cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(*) filter (where approved_flag = 1) as approved_order_cnt,
	count(*) filter (where delivered_flag = 1) as delivered_order_cnt
from lifecycle_base;
/*
확인 결과:
- 전체 주문 수와 distinct order_id가 모두 99,441건으로 일치했다.
- 결제 승인 주문은 99,281건이며, 배송 완료 조건을 모두 충족한 주문은 96,470건이다.
- delivered 상태 96,478건 중 배송일이 없는 8건은 delivered_flag에서 제외됐다.
*/



-- =========================================================
-- 2. 주문 상태 분포 확인
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select order_status, count(*) as order_cnt
from lifecycle_base
group by order_status
order by order_cnt desc;
/*
확인 결과:
- 전체 주문의 97.02%가 delivered 상태로 완료됐다.
- 미완료 주문은 shipped 1.11%, canceled 0.63%, unavailable 0.61% 순으로 확인됐다.
*/



-- =========================================================
-- 3. lifecycle 단계별 주문 수 확인
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)

select
	count(*) as created_order_cnt,
	count(*) filter (where approved_flag = 1) as approved_order_cnt,
	count(*) filter (where delivered_flag = 1) as delivered_order_cnt
from lifecycle_base;

-- 단계 포함 관계 확인 (위 lifecycle_base 기준 추가 확인)
select
	count(*) as delivered_without_approval_cnt
from lifecycle_base
where delivered_flag = 1
	and approved_flag = 0;
/*
확인 결과:
- 전체 주문 99,441건 중 결제 승인 주문은 99,281건, 배송 완료 주문은 96,470건이다.
- 배송 완료 주문 중 결제 승인일이 없는 주문 14건이 확인되어 단계별 전환율 계산 시 데이터 품질 예외로 구분한다.
*/

-- delivered 상태지만 결제 승인일이 없는 주문 확인
select
	m.order_id,
	m.order_status,
	m.purchase_timestamp,
	o.order_approved_at,
	m.payment_total,
	m.delivered_customer_date
from order_level_mart m
	left join orders o
		on m.order_id = o.order_id
where m.order_status = 'delivered'
	and nullif(trim(m.delivered_customer_date), '') is not null
	and nullif(trim(o.order_approved_at), '') is null;
/*
확인 결과:
- 앞선 주문 14건은 결제금액과 다른 주문·배송 정보는 존재하지만 order_approved_at만 누락돼 있었다.
- 따라서 실제 미승인 주문으로 단정하지 않고 승인 시점 누락 데이터로 구분한다.
*/



-- =========================================================
-- 4. lifecycle 단계별 전환율 계산
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select
	round(
		count(*) filter (where approved_flag = 1)::numeric
		/ count(*) * 100,
		2
	) as created_to_approved_rate,
	
	round(
		count(*) filter (where approved_flag = 1 and delivered_flag = 1)::numeric
		/ count(*) filter (where approved_flag = 1) * 100,
		2
	) as approved_to_delivered_rate,
	
	round(
		count(*) filter (where delivered_flag = 1)::numeric
		/ count(*) * 100,
		2
	) as created_to_delivered_rate
from lifecycle_base;
/*
확인 결과:
- 전체 주문의 99.84%에서 결제 승인 시점이 확인됐다.
- 승인 시점이 확인된 주문 중 97.15%가 배송 완료됐으며, 전체 주문 기준 배송 완료율은 97.01%다.
- 승인 시점이 누락된 배송 완료 주문 14건은 승인→배송 전환율 계산에서 제외했다.
*/



-- =========================================================
-- 5. 결제 승인 시점 미확인 주문 분석
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select order_status, count(*) as order_cnt
from lifecycle_base
where approved_flag = 0
group by order_status
order by order_cnt desc;
/*
확인 결과:
- 결제 승인 시점이 없는 주문은 총 160건으로, canceled 141건, delivered 14건, created 5건이다.
- delivered 14건은 주문·결제·배송 정보가 존재해 승인 시점 결측 데이터로 구분한다.
- 이를 제외하면 승인 시점 미확인 주문은 대부분 canceled 상태에 집중됐다.
*/



-- =========================================================
-- 6. 결제 승인 후 미배송 주문 분석
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select order_status, count(*) as order_cnt
from lifecycle_base
where approved_flag = 1
	and delivered_flag = 0
group by order_status
order by order_cnt desc;
/*
확인 결과:
- 결제 승인 후 배송 완료되지 않은 주문은 총 2,825건이며, shipped가 1,107건(39.2%)으로 가장 많았다.
- unavailable 609건(21.6%), canceled 484건(17.1%)이 뒤를 이었으며, delivered 8건은 배송일 결측 예외다.
*/



-- =========================================================
-- 7. 배송 지연 분석
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select
	count(*) filter (where delivered_flag = 1) as delivered_order_cnt,
	count(*) filter (where delivered_flag = 1 and delayed_flag = 1) as delayed_order_cnt,
	
	round(
		count(*) filter (where delivered_flag = 1 and delayed_flag = 1)::numeric
		/ count(*) filter (where delivered_flag = 1) * 100,
		2
	) as delayed_rate,
	
	round(
		avg(delivery_delay_days) filter (where delivered_flag = 1 and delayed_flag = 1),
		2
	) as avg_delay_days
from lifecycle_base;
/*
확인 결과:
- 실제 배송 완료 주문 96,470건 중 6,534건(6.77%)이 예정 배송일보다 늦게 도착했다.
- 배송 지연 주문은 평균 10.62일 늦게 배송됐다.
*/

-- 배송 지연이지만 lifecycle 배송 완료 기준에서 제외된 주문 확인 (위 lifecycle_base 기준 추가 확인)
select
	order_id,
	order_status,
	delivered_customer_date,
	delivery_delay_days,
	delayed_flag
from lifecycle_base
where delayed_flag = 1
	and delivered_flag = 0;
/*
확인 결과:
- delayed_flag가 1인 canceled 주문 1건은 배송 완료 분석에서 제외했다.
*/



-- =========================================================
-- 8. lifecycle 분석 핵심 결과 요약
-- =========================================================

with lifecycle_base as (
	select
		m.order_id,
		m.order_status,
		o.order_approved_at,
		m.delivered_customer_date,
		m.delivery_delay_days,
		m.delayed_flag,
		case
			when nullif(trim(o.order_approved_at), '') is not null then 1
			else 0
		end as approved_flag,
		case
			when m.order_status = 'delivered'
				and nullif(trim(m.delivered_customer_date), '') is not null then 1
			else 0
		end as delivered_flag
	from order_level_mart m
		left join orders o
			on m.order_id = o.order_id
	)
	
select
	count(*) as created_order_cnt,
	count(*) filter (where approved_flag = 1) as approved_order_cnt,
	count(*) filter (where delivered_flag = 1) as delivered_order_cnt,

	round(
		count(*) filter (where approved_flag = 1)::numeric 
		/ count(*) * 100,
		2
	) as created_to_approved_rate,

	round(
		count(*) filter (where approved_flag = 1 and delivered_flag = 1)::numeric
		/ count(*) filter (where approved_flag = 1) * 100,
		2
	) as approved_to_delivered_rate,

	round(
		count(*) filter (where delivered_flag = 1)::numeric
		/ count(*) * 100,
		2
	) as created_to_delivered_rate,

	count(*) filter (where delivered_flag = 1 and delayed_flag = 1) as delayed_order_cnt,

	round(
		count(*) filter (where delivered_flag = 1 and delayed_flag = 1)::numeric
		/ count(*) filter (where delivered_flag = 1) * 100,
		2
	) as delayed_rate
from lifecycle_base;
/*
확인 결과:
- 전체 주문 99,441건 중 99.84%에서 결제 승인 시점이 확인됐고, 전체 주문 기준 배송 완료율은 97.01%였다.
- 결제 승인 시점이 확인된 주문 중 97.15%가 배송 완료됐다.
- 실제 배송 완료 주문 중 6,534건(6.77%)이 예정 배송일보다 늦게 도착했다.
*/