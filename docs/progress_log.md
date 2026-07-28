# Progress Log

## 2026-07-27 — 분석 환경 구축 및 데이터 준비

- PostgreSQL 및 DBeaver 분석 환경 구축
- Olist CSV 데이터 9개 테이블 적재 완료
- CSV 문자열 길이 및 Escape 문자 오류 해결
- 분석 편의를 위해 테이블명 정리
- 테이블별 컬럼과 의미 확인
- 데이터 딕셔너리 작성
- ERD 작성을 위한 테이블 관계 탐색 시작
- 


## 2026-07-28 — 데이터 구조 분석 및 ERD 구성

### 진행 내용

- Olist 데이터셋의 테이블과 컬럼 구조를 확인했다.
- 주요 식별자의 고유성과 테이블 간 연결 관계를 검토했다.
- 원본 CSV에 실제 PK·FK 제약조건이 설정되어 있지 않아 논리적 키를 기준으로 ERD를 구성했다.

### 주요 모델링 결과

- 단일 기본키
  - `customers.customer_id`
  - `orders.order_id`
  - `products.product_id`
  - `sellers.seller_id`
  - `category.product_category_name`

- 복합 기본키
  - `order_items`: (`order_id`, `order_item_id`)
  - `order_payments`: (`order_id`, `payment_sequential`)

- 주요 관계
  - `customers` → `orders`
  - `orders` → `order_items`
  - `orders` → `order_payments`
  - `orders` → `reviews`
  - `products` → `order_items`
  - `sellers` → `order_items`
  - `category` → `products`

### 모델링 결정

- 원본 데이터 구조를 유지하기 위해 PostgreSQL에 실제 PK·FK 제약조건은 추가하지 않았다.
- DBeaver의 Virtual Key와 가상 관계를 활용해 논리적 데이터 모델을 표현했다.
- `reviews`는 신뢰할 수 있는 단일 기본키를 확인하기 어려워 PK를 지정하지 않았다.
- `geolocation_zip_code_prefix`는 중복값이 존재하므로 `geolocation` 테이블을 ERD에서 직접 연결하지 않았다.

### 산출물

- ERD: `docs/olist_Erd.png`
- 모델링 문서: `docs/data_modeling.md`

### 다음 단계

- 테이블별 행 수 확인
- 주요 컬럼의 NULL 및 중복 검증
- 날짜 범위와 주문 상태값 점검
- 데이터 품질 검증 SQL 작성
