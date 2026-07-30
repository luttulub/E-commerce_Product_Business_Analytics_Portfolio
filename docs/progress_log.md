# Progress Log

## 2026-07-27

- PostgreSQL 및 DBeaver 분석 환경 구축
- Olist CSV 데이터 9개 테이블 적재 완료
- CSV 문자열 길이 및 Escape 문자 오류 해결
- 분석 편의를 위해 테이블명 정리
- 테이블별 컬럼과 의미 확인
- 데이터 딕셔너리 작성
- ERD 작성을 위한 테이블 관계 탐색 시작

## Next

- 테이블별 고유키와 중복 여부 확인
- 테이블 간 관계 검증
- ERD 작성
- 행 수, 결측치, 중복 데이터 검증


## 2026-07-28 — Olist 데이터 구조 파악 및 ERD 구성

### 진행 내용

- PostgreSQL에 적재한 Olist 데이터셋의 테이블과 컬럼 구조를 확인했다.
- 원본 CSV 적재 과정에서 실제 PK·FK 제약조건이 설정되지 않았다는 점을 확인했다.
- 컬럼의 고유성과 테이블 간 연결 구조를 기준으로 논리적 PK와 FK 관계를 정리했다.

### 논리적 기본키 판단

- `customers`: `customer_id`
- `orders`: `order_id`
- `products`: `product_id`
- `sellers`: `seller_id`
- `category`: `product_category_name`
- `order_items`: (`order_id`, `order_item_id`)
- `order_payments`: (`order_id`, `payment_sequential`)

`reviews`와 `geolocation`은 원본 데이터만으로 신뢰할 수 있는 단일 기본키를 확인하기 어려워 별도의 PK를 지정하지 않았다.

### 주요 테이블 관계

- `customers.customer_id` → `orders.customer_id`
- `orders.order_id` → `order_items.order_id`
- `orders.order_id` → `order_payments.order_id`
- `orders.order_id` → `reviews.order_id`
- `products.product_id` → `order_items.product_id`
- `sellers.seller_id` → `order_items.seller_id`
- `category.product_category_name` → `products.product_category_name`

### 모델링 결정

- 원본 데이터 구조를 유지하기 위해 PostgreSQL에 실제 PK·FK 제약조건은 추가하지 않았다.
- DBeaver의 Virtual Key와 가상 관계 기능을 사용해 논리적 관계를 ERD에 표현했다.
- `geolocation_zip_code_prefix`는 중복값이 존재하므로 `geolocation` 테이블을 다른 테이블과 직접 연결하지 않았다.
- 향후 지역 분석이 필요할 경우 중복을 정제하거나 집계한 별도 데이터로 활용할 예정이다.

### 산출물

- Olist ERD 이미지 생성 및 저장  
  - `docs/olist_Erd.png`
- 데이터 모델링 기준과 주요 관계 문서화  
  - `docs/data_modeling.md`

### GitHub 작업 환경 정리

- GitHub Desktop을 설치하고 원격 저장소를 컴퓨터에 Clone했다.
- 로컬 프로젝트 폴더와 GitHub 저장소의 Commit·Push 흐름을 확인했다.
- VS Code를 설치하고 프로젝트 폴더를 열어 Markdown 문서를 수정할 수 있도록 설정했다.
- Markdown 문법 앞에 불필요한 백슬래시가 들어가 제목과 표가 깨지는 문제를 수정했다.
- VS Code Preview와 GitHub 화면에서 문서가 정상적으로 표시되는 것을 확인했다.

### 배운 점

- CSV를 데이터베이스에 적재했다고 해서 PK와 FK가 자동으로 생성되는 것은 아니다.
- ERD를 구성하기 전에 컬럼의 고유성, 중복 여부, 테이블 간 참조 관계를 확인해야 한다.
- 실제 제약조건과 분석을 위해 설정한 논리적 관계는 구분해서 문서화해야 한다.
- GitHub에서는 결과물뿐 아니라 모델링 기준과 의사결정 과정도 함께 남기는 것이 중요하다.

### 다음 단계

- 전체 테이블의 행 수 확인
- 주요 컬럼의 NULL 및 중복값 검증
- 주문 날짜 범위와 주문 상태값 확인
- 데이터 품질 검증 SQL 작성


## 2026-07-29~30 — Olist 데이터 품질 검증

### 진행 내용

- 데이터마트 생성 전에 원천 데이터의 품질과 조인 구조를 확인하기 위해 `sql/01_data_validation.sql` 작성을 시작했다.
- 테이블별 행 수와 논리적 기본키의 중복 여부를 확인했다.
- 데이터 적재 과정에서 `items`, `payments`, `reviews` 테이블에 중복 적재된 데이터가 있음을 확인했다.
- 해당 테이블을 다시 적재한 뒤 행 수와 논리적 키 중복 여부를 재검증했다.
- 각 검증 쿼리 아래에 확인 결과와 이후 분석에서 적용할 기준을 주석으로 기록했다.

### 중복 데이터 검증

- `orders`, `customers`, `products`, `sellers` 등 단일 기본키를 사용하는 테이블의 키 중복 여부를 확인했다.
- `items`는 `order_id`와 `order_item_id`의 조합을 기준으로 중복 여부를 확인했다.
- `payments`는 `order_id`와 `payment_sequential`의 조합을 기준으로 중복 여부를 확인했다.
- `reviews`는 신뢰할 수 있는 단일 기본키가 없어 주문별 리뷰 행 수와 전체 행의 중복 구조를 별도로 확인했다.
- 데이터 자체의 정상적인 다중 행과 적재 오류로 발생한 완전 중복을 구분해야 한다는 점을 확인했다.

### 주문당 다중 행 구조 확인

- 한 주문에 여러 상품이 포함될 수 있으므로 `items`에는 동일한 `order_id`가 여러 행 존재할 수 있다.
- 한 주문에서 여러 결제 방식이나 결제 순서가 기록될 수 있으므로 `payments`에도 동일한 `order_id`가 여러 행 존재할 수 있다.
- `reviews`를 주문별로 확인한 결과, 대부분의 주문에는 리뷰가 1개 연결되어 있지만 일부 주문에는 2개 이상의 리뷰가 연결되어 있었다.
- 리뷰 1개가 연결된 주문은 98,126건, 리뷰 2개가 연결된 주문은 543건, 리뷰 3개가 연결된 주문은 4건이었다.
- 따라서 `items`, `payments`, `reviews`를 원본 상태로 동시에 `orders`에 조인하면 주문 행이 중복되어 금액이나 주문 수가 과대 집계될 수 있다.
- 이후 주문 단위 데이터마트를 만들 때는 각 테이블을 먼저 `order_id` 기준으로 집계한 뒤 조인하기로 결정했다.

### `orders` 주요 컬럼의 null 검증

- `orders`의 주요 상태 및 날짜 컬럼에서 `null`, 빈 문자열, 공백 문자열의 개수를 확인했다.
- 현재 날짜 컬럼이 문자열 자료형이므로 `trim()`과 `nullif()`를 사용해 빈 문자열과 공백 문자열도 결측치로 처리했다.

확인 결과:

- `order_status`: null 0건
- `order_purchase_timestamp`: null 0건
- `order_approved_at`: null 160건
- `order_delivered_carrier_date`: null 1,783건
- `order_delivered_customer_date`: null 2,965건
- `order_estimated_delivery_date`: null 0건

- 주문 상태, 주문 생성일, 배송 예정일은 모든 주문에 기록되어 있었다.
- 결제 승인일과 실제 배송 관련 날짜에는 일부 null 값이 존재했다.
- 해당 null 값은 단순한 데이터 오류로 단정하지 않고, 취소·미승인·미배송 주문에서 정상적으로 발생한 값인지 `order_status`별로 추가 확인하기로 했다.

### 분석 기준 결정

- 문자열 컬럼의 결측치는 `null`뿐 아니라 빈 문자열과 공백 문자열까지 포함해 검증한다.
- 다중 행이 발생하는 테이블은 원본 상태로 동시에 조인하지 않는다.
- `items`, `payments`, `reviews`는 각각 `order_id` 단위로 먼저 집계한 뒤 `orders`와 결합한다.
- 결제 승인일과 배송 관련 날짜의 null은 주문 상태와 업무 흐름을 함께 확인한 뒤 분석 포함·제외 여부를 결정한다.
- 데이터 검증 결과와 분석 기준은 재실행 가능한 sql 쿼리와 주석으로 함께 남긴다.

### 배운 점

- 동일한 식별자가 여러 번 등장한다고 해서 모두 중복 오류인 것은 아니다.
- 주문과 상품, 결제, 리뷰처럼 일대다 관계를 가진 테이블에서는 동일한 `order_id`가 여러 행 존재하는 것이 정상일 수 있다.
- 적재 오류로 발생한 완전 중복과 데이터 구조상 정상적인 다중 행을 구분해야 한다.
- 날짜처럼 보이는 값도 문자열 자료형으로 저장되어 있으면 `null` 외에 빈 문자열과 공백 문자열을 함께 확인해야 한다.
- null 값은 발견 즉시 삭제하는 것이 아니라 주문 상태와 실제 업무 흐름을 기준으로 발생 원인을 먼저 확인해야 한다.
- 데이터마트를 만들기 전에 조인으로 행이 증가하는 구조를 검증해야 중복 집계를 방지할 수 있다.

### 현재 산출물

- 데이터 품질 검증 sql 작성 중
  - `sql/01_data_validation.sql`
- 데이터 검증 진행 내용 문서화
  - `docs/progress_log.md`

### 다음 단계

- `order_status`별 결제 승인일과 배송 관련 날짜의 null 분포 확인
- 주문 생성일 → 결제 승인일 → 택배사 전달일 → 고객 배송 완료일의 날짜 순서 검증
- 주요 테이블 간 고아 레코드 확인
- `items`, `payments`, `reviews`의 주문당 행 수 분포 추가 검증
- 취소, 미승인, 미배송 주문의 분석 포함·제외 기준 결정
- 데이터 검증 sql 정리 후 GitHub commit 및 push