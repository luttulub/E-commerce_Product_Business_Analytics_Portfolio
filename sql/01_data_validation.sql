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