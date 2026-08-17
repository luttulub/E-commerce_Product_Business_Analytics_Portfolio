/* 
olist 주문 단위 데이터 마트 생성

목적:
- 주문 1건을 1행으로 유지하는 order level mart를 생성한다.
- 결제, 상품, 배송, 리뷰 정보를 주문 단위로 통합한다.
- 이후 customer behavior mart와 주문 lifecycle 분석의 기반으로 활용한다.
*/


-- =========================================================
-- 1. 주문 기본 정보 구성 
-- order_base 
-- =========================================================

with order_base as (
	select 
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o 
		left join customers c
			on o.customer_id = c.customer_id
)

select *
from order_base;



-- =========================================================
-- 2. 주문별 결제 금액 집계
-- payment_summary
-- =========================================================

with payment_summary as (
	select order_id, sum(payment_value) payment_total
	from payments
	group by order_id
)

select count(distinct order_id)
from payment_summary;

-- 결제 정보가 없는 1건의 주문 확인
with payment_summary as (
	select order_id, sum(payment_value) as payment_total
	from payments
	group by order_id
)
select
	o.order_id,
	o.order_status,
	o.order_purchase_timestamp
from orders o
	left join payment_summary p
		on o.order_id = p.order_id
where p.order_id is null;
/*
확인 결과:
- payments 정보가 없는 주문은 delivered 상태 1건이다.
- 주문은 유지하고 payment_total은 null로 보존하며, 결제 금액 기반 지표에서는 제외한다.
*/



-- =========================================================
-- 3. 주문 기본 정보와 결제 정보 결합
-- order_base와 payment_summary join
-- =========================================================

with order_base as (
	select
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o
		left join customers c
			on o.customer_id = c.customer_id
	),
	
payment_summary as (
	select order_id, sum(payment_value) payment_total
	from payments
	group by order_id
	)

select
	count(*),
	count(distinct order_id),
	count(*) filter (where payment_total is null) as null_payment_cnt
from (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		p.payment_total,
		o.estimated_delivery_date,
		o.delivered_customer_date
	from order_base o
		left join payment_summary p
			on o.order_id = p.order_id
	) t;
/*
확인 결과:
- 전체 행 수와 distinct order_id가 모두 99,441건으로 일치했다.
- payment_total null 1건도 기존 확인 결과와 동일하다.
*/



-- =========================================================
-- 4. 주문별 상품 수 집계
-- item_summary
-- =========================================================

with item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	)
	
select
	count(*),
	count(distinct order_id)
from item_summary;
/*
확인 결과:
- items를 order_id 기준으로 집계한 결과 98,666건의 주문이 확인됐다.
- orders 전체보다 775건 적어 items 정보가 없는 주문이 존재한다.
*/

-- items 정보가 없는 주문 상태 확인
with item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	)

select
	o.order_status,
	count(*) as order_cnt
from orders o
	left join item_summary i
		on o.order_id = i.order_id
where i.order_id is null
group by o.order_status
order by order_cnt desc;
/*
확인 결과:
- items 정보가 없는 주문은 총 775건이며, 대부분 unavailable(603건)과 canceled(164건)이다.
- 추가로 created(5건), invoiced(2건), shipped(1건)이 있다.
- 해당 주문도 order level mart에는 유지하고 item_count는 null로 보존한다.
*/



-- =========================================================
-- 5. 주문 기본 정보 + 결제 + 상품 정보 결합
-- order_payment_item
-- =========================================================

with order_base as (
	select
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o
		left join customers c
			on o.customer_id = c.customer_id
	),

payment_summary as (
	select order_id, sum(payment_value) as payment_total
	from payments
	group by order_id
	),

item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	),

order_payment_item as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		p.payment_total,
		i.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date
	from order_base o
		left join payment_summary p
			on o.order_id = p.order_id
		left join item_summary i
			on o.order_id = i.order_id
	)

select
	count(*) as cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(*) filter (where payment_total is null) as null_payment_cnt,
	count(*) filter (where item_count is null) as null_item_cnt
from order_payment_item;
/*
확인 결과:
- 전체 행 수와 distinct order_id가 모두 99,441건으로 일치했다.
- payment_total null 1건, item_count null 775건도 기존 확인 결과와 동일하다.
*/



-- =========================================================
-- 6. 배송 지연 정보 생성
-- order_delivery
-- =========================================================
with order_base as (
	select
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o
		left join customers c
			on o.customer_id = c.customer_id
	),

payment_summary as (
	select order_id, sum(payment_value) as payment_total
	from payments
	group by order_id
	),

item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	),

order_payment_item as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		p.payment_total,
		i.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date
	from order_base o
		left join payment_summary p
			on o.order_id = p.order_id
		left join item_summary i
			on o.order_id = i.order_id
	),
	
order_delivery as (
	select 
		order_id,
		customer_unique_id,
		purchase_timestamp,
		order_status,
		payment_total,
		item_count,
		estimated_delivery_date,
		delivered_customer_date,
		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			else nullif(trim(delivered_customer_date), '')::date - nullif(trim(estimated_delivery_date), '')::date
		end as delivery_delay_days,

		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			when nullif(trim(delivered_customer_date), '')::date > nullif(trim(estimated_delivery_date), '')::date then 1
			else 0
		end as delayed_flag	
	from order_payment_item
)

select 
	count(*) as cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(*) filter (where delayed_flag = 1) as delayed_order_cnt,
	count(*) filter (where delayed_flag is null) as null_delay_flag_cnt
from order_delivery;
/*
확인 결과:
- 전체 행 수와 distinct order_id가 모두 99,441건으로 일치해 주문 1건 = 1행이 유지됐다.
- delayed_flag null 2,965건은 기존에 확인한 order_delivered_customer_date null 건수와 일치한다.
- 배송 지연 주문은 6,535건이다.
*/



-- =========================================================
-- 7. 리뷰 개수 정보 집계
-- review_summary
-- =========================================================

-- 구조 확인
select
	count(*) as review_row_cnt,
	count(distinct order_id) as review_order_cnt
from reviews;
/*
확인 결과:
- reviews 전체 99,224행 중 distinct order_id는 98,673건으로 확인됐다.
- 일부 주문에 리뷰가 여러 건 존재해 주문 단위 집계가 필요하다.
*/

-- 다중 리뷰 구조 확인
select
	count(*),
	max(review_cnt)
from (
	select order_id, count(*) as review_cnt
	from reviews
	group by order_id
	having count(*) > 1
	) r;
/*
확인 결과:
- 다중 리뷰 주문은 547건이며, 주문당 최대 리뷰 수는 3건이다.
- 따라서 review_score는 주문 단위로 집계한 뒤 결합해야 한다.
*/

-- 다중 리뷰 점수 차이 확인
select count(*) filter (where min_score <> max_score) as different_score_order_cnt
from (
	select
		order_id,
		min(review_score) as min_score,
		max(review_score) as max_score
	from reviews
	group by order_id
	having count(*) > 1
	) r;
/*
확인 결과:
- 다중 리뷰 주문 547건 중 202건은 리뷰 점수가 서로 달랐다.
- 단순히 임의의 리뷰 1건을 선택하지 않고 주문 단위 review_score 집계 기준이 필요하다.
*/

-- 리뷰 시점 차이 확인
select
	count(*) as multi_review_order_cnt,
	count(*) filter (where creation_date_cnt > 1) as different_creation_date_order_cnt,
	count(*) filter (where answer_time_cnt > 1) as different_answer_time_order_cnt
from (
	select
		order_id,
		count(distinct nullif(trim(review_creation_date), '')) as creation_date_cnt,
		count(distinct nullif(trim(review_answer_timestamp), '')) as answer_time_cnt
	from reviews
	group by order_id
	having count(*) > 1
	) r;
/*
확인 결과:
- 다중 리뷰 547건 모두 응답 시점이 달랐고, 392건은 리뷰 생성 날짜도 달랐다.
- 단순 중복으로 제거하기 어려워 주문 단위 집계 기준이 필요하다.
*/


with review_summary as (
	select
		order_id,
		avg(review_score) as review_score,
		count(*) as review_count
	from reviews 
	group by order_id
	)

select count(*), count(distinct order_id) as distinct_count
from review_summary;
/*
확인 결과:
- 다중 리뷰는 주문별 평균 review_score로 집계해 주문 1건 = 1행 구조를 유지했다.
- 전체 행 수와 distinct order_id가 모두 98,673건으로 일치했다.
*/



-- =========================================================
-- 8. 리뷰 정보 결합
-- order_reviews로 통합하며 review_flag 생성
-- =========================================================

with order_base as (
	select
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o
		left join customers c
			on o.customer_id = c.customer_id
	),

payment_summary as (
	select order_id, sum(payment_value) as payment_total
	from payments
	group by order_id
	),

item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	),

order_payment_item as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		p.payment_total,
		i.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date
	from order_base o
		left join payment_summary p
			on o.order_id = p.order_id
		left join item_summary i
			on o.order_id = i.order_id
	),

order_delivery as (
	select
		order_id,
		customer_unique_id,
		purchase_timestamp,
		order_status,
		payment_total,
		item_count,
		estimated_delivery_date,
		delivered_customer_date,
		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			else nullif(trim(delivered_customer_date), '')::date - nullif(trim(estimated_delivery_date), '')::date
		end as delivery_delay_days,
		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			when nullif(trim(delivered_customer_date), '')::date > nullif(trim(estimated_delivery_date), '')::date then 1
			else 0
		end as delayed_flag
	from order_payment_item
	),

review_summary as (
	select
		order_id,
		avg(review_score) as review_score,
		count(*) as review_count
	from reviews
	group by order_id
	),

order_review as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		o.payment_total,
		o.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date,
		o.delivery_delay_days,
		o.delayed_flag,
		r.review_score,
		coalesce(r.review_count, 0) as review_count,
		case
			when r.order_id is not null then 1
			else 0
		end as reviewed_flag
	from order_delivery o
		left join review_summary r
			on o.order_id = r.order_id
	)

-- 결합 결과 확인
select
	count(*) as cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(*) filter (where reviewed_flag = 1) as reviewed_order_cnt,
	count(*) filter (where reviewed_flag = 0) as unreviewed_order_cnt
from order_review;
/*
확인 결과:
- 전체 행 수와 distinct order_id가 모두 99,441건으로 일치해 주문 1건 = 1행이 유지됐다.
- 리뷰 작성 주문은 98,673건, 미작성 주문은 768건으로 확인됐다.
*/



-- =========================================================
-- 9. order level mart 생성
-- =========================================================

drop view if exists order_level_mart;

create view order_level_mart as

with order_base as (
	select
		o.order_id,
		c.customer_unique_id,
		o.order_purchase_timestamp as purchase_timestamp,
		o.order_status,
		o.order_estimated_delivery_date as estimated_delivery_date,
		o.order_delivered_customer_date as delivered_customer_date
	from orders o
		left join customers c
			on o.customer_id = c.customer_id
	),

payment_summary as (
	select order_id, sum(payment_value) as payment_total
	from payments
	group by order_id
	),

item_summary as (
	select order_id, count(*) as item_count
	from items
	group by order_id
	),

order_payment_item as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		p.payment_total,
		i.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date
	from order_base o
		left join payment_summary p
			on o.order_id = p.order_id
		left join item_summary i
			on o.order_id = i.order_id
	),

order_delivery as (
	select
		order_id,
		customer_unique_id,
		purchase_timestamp,
		order_status,
		payment_total,
		item_count,
		estimated_delivery_date,
		delivered_customer_date,
		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			else nullif(trim(delivered_customer_date), '')::date - nullif(trim(estimated_delivery_date), '')::date
		end as delivery_delay_days,
		case
			when nullif(trim(delivered_customer_date), '') is null
				or nullif(trim(estimated_delivery_date), '') is null then null
			when nullif(trim(delivered_customer_date), '')::date > nullif(trim(estimated_delivery_date), '')::date then 1
			else 0
		end as delayed_flag
	from order_payment_item
	),

review_summary as (
	select
		order_id,
		avg(review_score) as review_score,
		count(*) as review_count
	from reviews
	group by order_id
	),

order_review as (
	select
		o.order_id,
		o.customer_unique_id,
		o.purchase_timestamp,
		o.order_status,
		o.payment_total,
		o.item_count,
		o.estimated_delivery_date,
		o.delivered_customer_date,
		o.delivery_delay_days,
		o.delayed_flag,
		r.review_score,
		coalesce(r.review_count, 0) as review_count,
		case
			when r.order_id is not null then 1
			else 0
		end as reviewed_flag
	from order_delivery o
		left join review_summary r
			on o.order_id = r.order_id
	)

select
	order_id,
	customer_unique_id,
	purchase_timestamp,
	order_status,
	payment_total,
	item_count,
	estimated_delivery_date,
	delivered_customer_date,
	delivery_delay_days,
	delayed_flag,
	review_score,
	reviewed_flag
from order_review;


-- 검증
select
	count(*) as cnt,
	count(distinct order_id) as distinct_order_cnt,
	count(*) filter (where payment_total is null) as null_payment_cnt,
	count(*) filter (where item_count is null) as null_item_cnt,
	count(*) filter (where delayed_flag is null) as null_delay_flag_cnt,
	count(*) filter (where reviewed_flag = 0) as unreviewed_order_cnt
from order_level_mart;
/*
확인 결과:
- 전체 행 수와 distinct order_id가 모두 99,441건으로 일치했다.
- 주요 null 및 리뷰 미작성 건수도 이전 단계 검증 결과와 동일했다.
*/


