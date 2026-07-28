\# 데이터 모델링



\## 1. 개요



Olist 이커머스 데이터셋의 구조를 이해하기 위해 테이블 간 관계를 분석하고 ERD(Entity Relationship Diagram)를 작성하였다.



원본 데이터는 CSV 형태로 제공되어 실제 Primary Key(PK)와 Foreign Key(FK)가 데이터베이스에 설정되어 있지 않았기 때문에, 컬럼의 고유성과 테이블 간 관계를 분석하여 논리적인 데이터 모델을 구성하였다.



\---



\## 2. 테이블 간 관계



분석 결과 다음과 같은 관계를 확인하였다.



| 부모 테이블 | 자식 테이블 | 연결 컬럼 |

|-------------|------------|----------|

| customers | orders | customer\_id |

| orders | order\_items | order\_id |

| orders | order\_payments | order\_id |

| orders | reviews | order\_id |

| products | order\_items | product\_id |

| sellers | order\_items | seller\_id |

| category | products | product\_category\_name |



\---



\## 3. 논리적 기본키(PK)



원본 데이터에는 PK 제약조건이 존재하지 않으므로 다음 컬럼을 논리적인 기본키로 판단하였다.



| 테이블 | 논리적 PK |

|--------|-----------|

| customers | customer\_id |

| orders | order\_id |

| products | product\_id |

| sellers | seller\_id |

| category | product\_category\_name |

| order\_items | (order\_id, order\_item\_id) |

| order\_payments | (order\_id, payment\_sequential) |



`reviews`와 `geolocation` 테이블은 원본 데이터만으로는 신뢰할 수 있는 단일 기본키를 확인하기 어려워 별도의 PK를 지정하지 않았다.



\---



\## 4. 모델링 과정



ERD는 실제 데이터베이스 제약조건을 추가하지 않고 DBeaver의 Virtual Key 기능을 이용하여 논리적인 관계를 표현하였다.



또한 `geolocation` 테이블은 `geolocation\_zip\_code\_prefix` 값이 중복되므로 다른 테이블과 연결하지 않았다.



이는 원본 데이터를 최대한 유지하면서 분석에 필요한 관계만 표현하기 위한 결정이다.



\---



\## 5. ERD



!\[Olist ERD](./olist\_Erd.png)

