/*
olist 데이터 마트 구축 전 핵심 데이터 검증

목적:
- 주문 단위 및 고객 단위 데이터 마트 제작에 필요한 원본 구조를 확인한다.
- 중복 집계와 join 왜곡을 방지하기 위한 처리 기준을 수립한다.
*/


-- =========================================================
-- 1. 핵심 원본 테이블 행 수 확인
-- =========================================================

select 'orders' table_name, count(*) row_count
from orders 

union all

select 'customers', count(*)
from customers

union all

select 'items', count(*) 
from items

union all

select 'payments', count(*) 
from payments

union all

select 'reviews', count(*) 
from reviews

order by row_count;
/*
확인 내용:
- 데이터 마트 제작에 필요한 핵심 테이블이 정상적으로 적재됐는지 확인한다.
- 원본 데이터 적재 과정에서 items, payments, reviews의 중복 적재를 발견했다.
- 세 테이블을 초기화하고 원본 csv를 각각 1회 다시 적재했다.
*/


-- =========================================================
-- 2. 핵심 키 중복 확인
-- =========================================================

select 
    'orders.order_id' name, 
    count(*) total_rows,
    count(distinct order_id) unique_keys,
    count(*) - count(distinct order_id) duplicate_rows
from orders

union all 

select
    'customers.customer_id',
    count(*),
    count(distinct customer_id),
    count(*) - count(distinct customer_id)
from customers

union all

select
    'items.order_id + order_item_id',
    count(*),
    count(distinct (order_id, order_item_id)),
    count(*) - count(distinct (order_id, order_item_id))
from items

union all

select
    'payments.order_id + payment_sequential',
    count(*),
    count(distinct (order_id, payment_sequential)),
    count(*) - count(distinct (order_id, payment_sequential))
from payments

union all

select
    'reviews.review_id + order_id',
    count(*),
    count(distinct (review_id, order_id)),
    count(*) - count(distinct (review_id, order_id))
from reviews;


-- items 키별 반복 횟수 확인

select row_cnt_per_key, count(*) key_cnt
from (
    select order_id, order_item_id, count(*) row_cnt_per_key
    from items
    group by order_id, order_item_id
	) items_key_cnt
group by row_cnt_per_key 
order by row_cnt_per_key;


-- payments 키별 반복 횟수 확인

select row_cnt_per_key, count(*) key_cnt 
from (
    select order_id, payment_sequential, count(*) row_cnt_per_key
    from payments 
    group by order_id, payment_sequential
	) payments_key_cnt
group by row_cnt_per_key 
order by row_cnt_per_key;


-- reviews 키별 반복 횟수 확인

select row_cnt_per_key, count(*) key_cnt
from (
    select review_id, order_id, count(*) row_cnt_per_key
    from reviews
    group by review_id, order_id
	) reviews_key_cnt
group by row_cnt_per_key
order by row_cnt_per_key;
/*
검증 결과:
- orders.order_id는 중복이 없어 주문을 식별하는 논리적 pk로 사용할 수 있다.
- customers.customer_id는 중복이 없어 고객 주문 레코드의 논리적 pk로 사용할 수 있다.
- items와 payments에서 전체 데이터가 2회 적재된 현상을 발견했다.
- reviews에서는 일부 데이터가 중복 적재된 현상을 발견했다.
- 세 테이블을 초기화하고 원본 csv를 각각 1회 다시 적재했다.
- 재적재 후 각 복합키의 중복 건수는 0건으로 확인됐다.
*/


-- =========================================================
-- 3. 주문별 연결 건수 확인
-- =========================================================

-- 주문별 items 행 개수 확인

select rows_per_order, count(*) order_cnt
from (
    select order_id, count(*) rows_per_order
    from items
    group by order_id
	) items_per_order
group by rows_per_order
order by rows_per_order;
/*
확인 결과:
- 아이템 1개로 구성된 주문이 가장 많다.
- 일부 주문에는 여러 아이템이 연결되어 있으며, 최대 21개 아이템이 연결된 주문도 존재한다.
- items를 orders에 바로 join하면 다중 아이템 주문이 여러 행으로 늘어난다.
- 주문 단위 마트 생성 시 items를 order_id별로 먼저 집계해야 한다.
*/


-- 주문별 payments 행 개수 확인

select rows_per_order, count(*) order_cnt
from (
    select order_id, count(*) rows_per_order
    from payments
    group by order_id
	) payments_per_order
group by rows_per_order
order by rows_per_order;
/*
확인 결과:
- 대부분의 주문은 결제 행이 1개지만, 일부 주문에서는 여러 결제 행이 존재한다.
- 주문당 최대 29개의 결제 행이 존재한다.
- payments를 orders에 바로 join하면 다중 결제 주문이 여러 행으로 늘어난다.
- 주문 단위 마트 생성 시 payments를 order_id별로 먼저 집계해야 한다.
 */


-- 주문별 reviews 행 개수 확인

select review_cnt, count(*) order_cnt
from (
	select o.order_id, count(r.review_id) review_cnt
	from orders o
	left join reviews r
		on o.order_id = r.order_id
	group by o.order_id
	) reviews_per_order
group by review_cnt
order by review_cnt;
/*
확인 결과:
- 대부분의 주문에는 리뷰가 1개이다.
- 리뷰를 작성하지 않은 주문은 768개, 리뷰가 2개인 주문은 543개, 3개인 주문은 4개 존재한다.
- reviews를 orders에 바로 join하면 일부 주문이 여러 행으로 늘어난다.
- 주문 단위 마트 생성 전 다중 리뷰의 처리 기준을 결정해야 한다.
 */


-- =========================================================
-- 4. 고객 식별키(customer_unique_id) 확인
-- =========================================================

-- customers 기본 행 개수 확인

select
	count(*) total_rows,
	count(distinct customer_id) customer_id_cnt,
	count(distinct customer_unique_id) unique_customer_cnt,
	count(*) - count(customer_unique_id) null_cnt
from customers;

-- customer_unique_id별 주문 횟수 분포 확인

select customer_id_cnt, count(*) customer_cnt 
from (
	select customer_unique_id, count(*) customer_id_cnt 
	from customers
	group by customer_unique_id 
	) customer_order_cnt
group by customer_id_cnt 
order by customer_id_cnt; 
/*
확인 결과:
- 전체 96,096명의 고유 고객 중 93,099명은 1회 주문 고객이다.
- 2회 이상 주문한 재구매 고객은 2,997명으로, 전체 고유 고객의 약 3.12%이다.
- 가장 많은 주문 기록을 가진 고객은 총 17회 주문했다.
- customer_id는 주문별 고객 레코드를 식별하고, customer_unique_id는 실제 고객을 식별한다.
- 고객별 주문 횟수와 재구매 분석에서는 customer_unique_id를 기준으로 사용해야 한다.
*/


-- =========================================================
-- 5. 주문 상태 및 핵심 날짜 결측치 확인
-- =========================================================

-- 5-1. orders 핵심 컬럼별 null 개수 확인
-- 배송 소요시간과 지연 여부 계산에 필요한 컬럼이 비어 있는지 확인

select
	count(*) total_orders,

	count(*) filter (
		where nullif(trim(order_status), '') is null
	) order_status_null_cnt,

	count(*) filter (
		where nullif(trim(order_purchase_timestamp), '') is null
	) purchase_timestamp_null_cnt,

	count(*) filter (
		where nullif(trim(order_approved_at), '') is null
	) approved_at_null_cnt,

	count(*) filter (
		where nullif(trim(order_delivered_carrier_date), '') is null
	) carrier_date_null_cnt,

	count(*) filter (
		where nullif(trim(order_delivered_customer_date), '') is null
	) customer_date_null_cnt,

	count(*) filter (
		where nullif(trim(order_estimated_delivery_date), '') is null
	) estimated_date_null_cnt

from orders;
/*
확인 결과:
- order_status와 order_purchase_timestamp에는 null 값이 없다.
- order_approved_at은 160건의 null 값이 확인되었다.
- order_delivered_carrier_date는 1,783건의 null 값이 확인되었다.
- order_delivered_customer_date는 2,965건의 null 값이 확인되었다.
- order_estimated_delivery_date에는 null 값이 없다.
- 주문 생성일과 배송 예정일은 모든 주문에 기록되어 있지만, 결제 승인일과 실제 배송 관련 날짜에는 일부 null 값이 존재한다.
- 해당 null 값은 데이터 오류로 단정할 수 없으며, 취소·미승인·미배송 주문에서 정상적으로 발생한 값인지 order_status별로 추가 확인해야 한다.
*/


-- 5-2. 주문 상태별 null 분포 확인
-- 앞에서 확인한 배송 날짜의 null이 어떤 주문 상태에서 발생했는지(취소, 미승인, 미승인 등) 확인

select
	trim(order_status) order_status,
	count(*) order_cnt,
	
	count(*) filter (
		where nullif(trim(order_approved_at), '') is null
	) approved_at_null_cnt,
	
	count(*) filter (
		where nullif(trim(order_delivered_carrier_date), '') is null
	) carrier_date_null_cnt,

	count(*) filter (
		where nullif(trim(order_delivered_customer_date), '') is null
	) customer_date_null_cnt
from orders
group by trim(order_status)
order by order_cnt desc;
/*
확인 결과:
- delivered 상태는 주문 처리가 완료된 상태이므로, 해당 결측치는 데이터 불일치 가능성이 있어 별도 확인이 필요하다.
- shipped, unavailable, invoiced, processing, created, approved 상태의 배송 관련 null은 각 주문 처리 단계와 대체로 일치한다.
- canceled 주문은 취소 시점에 따라 승인일과 배송 관련 날짜가 없을 수 있으므로 대부분의 null은 업무 흐름상 발생 가능한 값이다.
- 다만 canceled 주문 중 택배사 전달일이 존재하는 주문은 75건, 고객 배송 완료일이 존재하는 주문은 6건이므로 취소 시점과 날짜 순서를 추가 확인해야 한다.
- 따라서 모든 null을 데이터 오류로 처리하지 않고, delivered 상태의 결측 주문과 배송 기록이 있는 canceled 주문을 우선 점검한다.
*/


-- 5-3. delivered 상태의 핵심 날짜 null 주문 상세 확인
-- 각 결측치가 동일한 주문에서 중복 발생했는지 확인하고 이후 분석 제외 기준을 결정
select
	order_id,
	customer_id,
	order_status,
	order_purchase_timestamp,
	order_approved_at, 
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date 
from orders
where trim(order_status) = 'delivered'
	and (
		nullif(trim(order_approved_at), '') is null
		or nullif(trim(order_delivered_carrier_date), '') is null
		or nullif(trim(order_delivered_customer_date), '') is null
	)
order by order_purchase_timestamp; 
/*
확인 결과:
- delivered 상태에서 승인일 14건, 물류사 인계일 2건, 고객 배송 완료일 8건의 null이 확인되었다.
- 1개 주문에서 배송 관련 날짜 2개가 함께 null이므로, 실제 결측 주문은 총 23건이다.
- 전체 delivered 주문의 약 0.024%로, 일부 주문의 날짜 기록 누락으로 판단한다.
- 원본 값은 수정하지 않고, 해당 날짜가 필요한 분석에서만 제외한다.
*/


-- 5-4. canceled 상태이면서 고객 배송 완료일이 존재하는 주문 확인
-- 배송 완료 후 취소된 주문인지, 상태와 날짜 정보가 불일치하는지 확인

select
	order_id,
	customer_id,
	order_status,
	order_purchase_timestamp,
	order_approved_at, 
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date 
from orders 
where trim(order_status) = 'canceled'
	and nullif(trim(order_delivered_customer_date),'') is not null 
order by order_delivered_customer_date;
/*
확인 결과:
- canceled 상태이면서 고객 배송 완료일이 존재하는 주문은 6건이다.
- 6건 모두 주문 생성, 승인, 물류사 인계, 고객 배송 완료의 날짜 순서가 정상적이다.
- 배송 후 취소·환불된 주문이거나 주문 상태와 날짜 정보가 불일치한 예외 데이터로 판단한다.
- 원본 값은 수정하지 않고, 완료 주문 분석에서는 제외하며 별도 예외 주문으로 관리한다.
*/


-- =========================================================
-- 6. 주문 핵심 날짜 순서 검증
-- =========================================================


-- 6-1. 주문 처리 단계별 날짜 역전 건수 확인
-- 주문 생성, 승인, 물류사 인계, 배송 완료 날짜가 정상 순서인지 확인

select 
	count(*) filter (
		where nullif(trim(order_approved_at), '')::timestamp 
			< nullif(trim(order_purchase_timestamp), '')::timestamp 
	) approved_before_purchase_cnt,
	
	count(*) filter (
		where nullif(trim(order_delivered_carrier_date), '')::timestamp 
			< nullif(trim(order_approved_at), '')::timestamp 
	) carrier_before_approved_cnt,
	
	count(*) filter (
		where nullif(trim(order_delivered_customer_date), '')::timestamp
			< nullif(trim(order_delivered_carrier_date), '')::timestamp
	) customer_before_carrier_cnt,

	count(*) filter (
		where nullif(trim(order_estimated_delivery_date), '')::timestamp
			< nullif(trim(order_purchase_timestamp), '')::timestamp
	) estimated_before_purchase_cnt
from orders;
/*
확인 결과:
- 주문일보다 승인일이 빠른 주문과 주문일보다 배송 예정일이 빠른 주문은 0건이다.
- 물류사 인계일이 승인일보다 빠른 주문은 1,359건 확인되었다.
- 고객 배송 완료일이 물류사 인계일보다 빠른 주문은 23건 확인되었다.
- 날짜 역전 건은 즉시 오류로 단정하지 않고 시간 차이와 실제 주문 내역을 추가 확인한 뒤 분석 기준을 결정한다.
*/


-- 6-2. 물류사 인계일이 승인일보다 빠른 주문의 시간 차이 확인
-- 날짜 역전이 단순한 기록 시차인지 큰 데이터 불일치인지 판단
select 
	count(*) order_cnt,
	
	min(
		nullif(trim(order_approved_at), '')::timestamp
		- nullif(trim(order_delivered_carrier_date), '')::timestamp 
	) min_time_gap,
	
	avg(
		nullif(trim(order_approved_at), '')::timestamp
		- nullif(trim(order_delivered_carrier_date), '')::timestamp
	) avg_time_gap,

	max(
		nullif(trim(order_approved_at), '')::timestamp
		- nullif(trim(order_delivered_carrier_date), '')::timestamp
	) max_time_gap
from orders
where nullif(trim(order_approved_at), '') is not null 
	and nullif(trim(order_delivered_carrier_date), '') is not null
	and nullif(trim(order_delivered_carrier_date), '')::timestamp
		< nullif(trim(order_approved_at), '')::timestamp;
/*
확인 결과:
- 날짜가 역전된 주문 1,359건에서 승인 기록은 물류사 인계 기록보다 최소 21초, 평균 약 24시간 45분 늦게 기록되었다.
- 최대 차이는 약 171일로, 일부 주문에는 단순한 시스템 기록 시차로 보기 어려운 이상값이 존재한다.
- 평균은 큰 이상값의 영향을 받을 수 있으므로 시간 차이의 분포와 중앙값을 추가 확인한다.
- 원본 값은 수정하지 않고, 차이가 큰 주문을 구분해 분석 기준을 결정한다.
*/


-- 6-3. 승인일과 물류사 인계일 역전 시간의 분포 확인
-- 평균이 일부 큰 이상값의 영향을 받았는지 확인하기 위해 중앙값과 시간 구간별 주문 수를 집계
with reversed_orders as (
	select
		order_id,
		nullif(trim(order_approved_at), '')::timestamp
			- nullif(trim(order_delivered_carrier_date), '')::timestamp time_gap
	from orders
	where nullif(trim(order_approved_at), '') is not null 
		and nullif(trim(order_delivered_carrier_date), '') is not null
		and nullif(trim(order_delivered_carrier_date), '')::timestamp
			< nullif(trim(order_approved_at), '')::timestamp
)
select 
	count(*) order_cnt,
	
	percentile_cont(0.5) within group (
		order by time_gap
	) median_time_gap,

	count(*) filter (
		where time_gap <= interval '1 minute'
	) within_1_minute_cnt,

	count(*) filter (
		where time_gap > interval '1 minute'
			and time_gap <= interval '1 hour'
	) within_1_hour_cnt,

	count(*) filter (
		where time_gap > interval '1 hour'
			and time_gap <= interval '1 day'
	) within_1_day_cnt,

	count(*) filter (
		where time_gap > interval '1 day'
			and time_gap <= interval '7 days'
	) within_7_days_cnt,

	count(*) filter (
		where time_gap > interval '7 days'
	) over_7_days_cnt
from reversed_orders; 
/*
확인 결과:
- 날짜 역전 주문 1,359건의 중앙 시간차는 약 17시간 10분이다.
- 901건은 1일 이내, 444건은 1일 초과 7일 이내이며, 7일 초과 주문은 14건이다.
- 단순한 초 단위 기록 시차만의 문제는 아니지만, 대부분의 차이는 7일 이내에 분포한다.
- 7일을 초과한 14건은 별도 이상 주문으로 상세 확인한다.
*/


-- 6-4. 승인일과 물류사 인계일의 차이가 7일을 초과한 주문 확인
-- 장기간 날짜 역전이 발생한 주문의 상태와 실제 날짜를 상세 확인

select
	order_id,
	customer_id,
	order_status,
	order_purchase_timestamp,
	order_approved_at,
	order_delivered_carrier_date,
	order_delivered_customer_date,
	nullif(trim(order_approved_at), '')::timestamp
		- nullif(trim(order_delivered_carrier_date), '')::timestamp time_gap
from orders
where nullif(trim(order_approved_at), '') is not null
	and nullif(trim(order_delivered_carrier_date), '') is not null
	and nullif(trim(order_delivered_carrier_date), '')::timestamp
		< nullif(trim(order_approved_at), '')::timestamp
	and nullif(trim(order_approved_at), '')::timestamp
		- nullif(trim(order_delivered_carrier_date), '')::timestamp
		> interval '7 days'
order by time_gap desc;
/*
확인 결과:
- 승인일과 물류사 인계일의 차이가 7일을 초과한 주문은 총 14건이며, 모두 delivered 상태다.
- 13건은 승인일이 물류사 인계일보다 약 7~9일 늦게 기록되어 승인 정보의 지연 입력 가능성이 있다.
- 1건은 물류사 인계일이 주문 생성일보다 약 6개월 앞서 있어 명확한 날짜 오류로 판단한다.
- 원본 값은 수정하지 않고, 14건은 날짜 기반 소요시간 분석에서 제외한다.
*/


-- 6-5. 주문 생성일보다 배송 관련 날짜가 빠른 주문 확인
-- 물류사 인계 또는 고객 배송 완료가 주문 생성 전에 기록된 날짜 오류를 확인

select
	count(*) filter (
		where nullif(trim(order_delivered_carrier_date), '')::timestamp
			< nullif(trim(order_purchase_timestamp), '')::timestamp
	) carrier_before_purchase_cnt,
	
	count(*) filter (
		where nullif(trim(order_delivered_customer_date), '')::timestamp
			< nullif(trim(order_purchase_timestamp), '')::timestamp
	) customer_before_purchase_cnt
from orders;
/*
확인 결과:
- 물류사 인계일이 주문 생성일보다 빠른 주문은 166건이며 고객 배송 완료일이 주문 생성일보다 빠른 주문은 0건이다.
- 166건은 실제 주문 처리 순서와 맞지 않는 날짜 불일치로 판단한다.
*/


-- 6-6. 주문 생성 전 물류사 인계 주문(166건)의 상태별 분포 확인
-- 날짜 불일치가 특정 주문 상태에 집중되어 있는지 확인
select
	trim(order_status) order_status,
	count(*) order_cnt
from orders
where nullif(trim(order_delivered_carrier_date), '') is not null
	and nullif(trim(order_purchase_timestamp), '') is not null
	and nullif(trim(order_delivered_carrier_date), '')::timestamp
		< nullif(trim(order_purchase_timestamp), '')::timestamp
group by trim(order_status)
order by order_cnt desc;
/*
확인 결과:
- 주문 생성 전 물류사 인계가 기록된 166건 중 delivered가 165건, shipped가 1건이다.
- 약 99.4%가 delivered 상태로, 대부분 실제 배송까지 완료된 주문에서 날짜 불일치가 발생했다.
*/


-- 6-7. 고객 배송 완료일이 물류사 인계일보다 빠른 주문 상세 확인
-- 배송 완료가 물류사 인계보다 먼저 기록된 주문의 상태와 시간 차이를 확인

select
	order_id,
	customer_id,
	order_status,
	order_purchase_timestamp,
	order_approved_at,
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date,
	nullif(trim(order_delivered_carrier_date), '')::timestamp
		- nullif(trim(order_delivered_customer_date), '')::timestamp reverse_time_gap
from orders
where nullif(trim(order_delivered_carrier_date), '') is not null
	and nullif(trim(order_delivered_customer_date), '') is not null
	and nullif(trim(order_delivered_customer_date), '')::timestamp
		< nullif(trim(order_delivered_carrier_date), '')::timestamp
order by reverse_time_gap desc;
/*
확인 결과:
- 고객 배송 완료일이 물류사 인계일보다 빠른 주문은 23건이며, 모두 delivered 상태다.
- 역전 시간은 약 23분부터 16일까지 분포해 단순한 기록 시차로 보기 어렵다.
- 물류사 인계일의 기록 오류 가능성이 높으므로, 인계일을 사용하는 배송 단계 및 소요시간 분석에서만 제외한다.
- 고객 배송 완료일과 배송 예정일이 유효한 경우 배송 지연 분석에는 유지한다.
*/

