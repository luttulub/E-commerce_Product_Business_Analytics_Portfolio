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


## 2026-07-29 — Olist 데이터 구조 파악 및 ERD 구성

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