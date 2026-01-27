# places 컬렉션 스키마 (v0)

목표: 지도에 "쿠폰 사용 가능한 매장" 마커를 표시하기 위한 최소 스키마입니다.

## Collection
- `places` (document id: 임의/slug/auto-id)

## Fields (권장)
- `name` (string, required): 매장명
- `lat` (number, required): 위도 (예: 35.1595)
- `lng` (number, required): 경도 (예: 129.0756)
- `address` (string, optional): 주소/상세 위치
- `category` (string, optional): 카테고리 (예: cafe, restaurant, convenience)
- `hasCoupons` (bool, optional, default false): 쿠폰 사용 가능 매장 여부
- `isActive` (bool, optional, default true): 지도 노출 여부
- `createdAt` (timestamp, optional): 생성 시각 (서버 타임스탬프 권장)
- `updatedAt` (timestamp, optional): 수정 시각 (서버 타임스탬프 권장)

## Notes
- MVP에서는 `lat/lng`를 필수로 저장하고, 주소 검색(geocoding)은 사용하지 않습니다.
- 추후 필터/정렬이 필요하면 `category`, `hasCoupons` 기반 인덱스를 추가합니다.

