#!/bin/bash
# 걸음수 측정 이슈 재현 테스트 스크립트
# 작성일: 2026-02-17

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "📱 걸음수 측정 이슈 재현 테스트"
echo "=========================================="
echo ""

# Android 디바이스 체크
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}❌ Android 디바이스가 연결되지 않았습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Android 디바이스 연결됨${NC}"
echo ""

# 메뉴
echo "실행할 테스트를 선택하세요:"
echo "1) Issue #1: iOS 자정 넘김 테스트 (시뮬레이터 필요)"
echo "2) Issue #2: Android 재부팅 후 캐시 테스트"
echo "3) Issue #3: Android 백그라운드 장시간 유지 테스트"
echo "4) 전체 테스트 실행"
echo ""
read -p "선택 (1-4): " choice

case $choice in
    1)
        echo ""
        echo "=========================================="
        echo "🌙 Issue #1: iOS 자정 넘김 테스트"
        echo "=========================================="
        echo ""
        echo -e "${YELLOW}⚠️  이 테스트는 iOS 시뮬레이터가 필요합니다.${NC}"
        echo ""
        echo "수동 테스트 절차:"
        echo "1. iOS 시뮬레이터 실행"
        echo "2. Settings → General → Date & Time"
        echo "3. 'Set Automatically' OFF"
        echo "4. 시간을 23:55로 설정"
        echo "5. 앱 실행 → Walker 화면 진입"
        echo "6. 100보 정도 시뮬레이션 (걷기 시뮬레이터 사용)"
        echo "7. 5분 대기 (자정 넘어갈 때까지)"
        echo "8. 00:05가 되면 추가로 1000보 시뮬레이션"
        echo ""
        echo -e "${RED}예상 결과 (버그):${NC} 1100보 표시 (어제 100 + 오늘 1000)"
        echo -e "${GREEN}수정 후 기대값:${NC} 1000보 표시 (오늘만)"
        echo ""
        read -p "계속하려면 Enter를 누르세요..."
        ;;

    2)
        echo ""
        echo "=========================================="
        echo "🔄 Issue #2: Android 재부팅 후 캐시 테스트"
        echo "=========================================="
        echo ""

        # 앱 실행하여 걸음수 캐시 생성
        echo "1단계: 앱 실행하여 걸음수 캐시 생성..."
        adb shell am start -n com.doyakmin.hangookji.namgu/.MainActivity
        sleep 5

        # 현재 걸음수 캐시 확인
        echo ""
        echo "현재 캐시된 걸음수 확인 중..."
        adb shell "run-as com.doyakmin.hangookji.namgu cat shared_prefs/steps_prefs.xml 2>/dev/null | grep last_today_steps" || echo "캐시 없음"

        echo ""
        read -p "앱에서 걸음수가 표시되는지 확인하고 Enter를 누르세요..."

        echo ""
        echo "2단계: 디바이스 재부팅..."
        echo -e "${YELLOW}⚠️  디바이스가 재부팅됩니다. 약 1-2분 소요됩니다.${NC}"
        read -p "계속하려면 Enter를 누르세요 (Ctrl+C로 취소 가능)..."

        adb reboot

        echo ""
        echo "재부팅 대기 중... (60초)"
        sleep 60

        # 디바이스 재연결 대기
        echo "디바이스 재연결 대기 중..."
        for i in {1..30}; do
            if adb devices | grep -q "device$"; then
                echo -e "${GREEN}✅ 디바이스 재연결됨${NC}"
                break
            fi
            sleep 2
        done

        echo ""
        echo "3단계: 앱 즉시 실행..."
        sleep 5  # 부팅 완료 대기
        adb shell am start -n com.doyakmin.hangookji.namgu/.MainActivity

        echo ""
        echo "=========================================="
        echo "🔍 테스트 결과 확인"
        echo "=========================================="
        echo ""
        echo -e "${RED}현재 버그:${NC}"
        echo "  - 앱 실행 후 1-2초간 재부팅 전 걸음수가 표시됨"
        echo "  - 이후 0으로 수정됨"
        echo ""
        echo -e "${GREEN}수정 후 기대값:${NC}"
        echo "  - 처음부터 0 표시"
        echo ""
        echo "앱 화면을 확인하세요!"
        ;;

    3)
        echo ""
        echo "=========================================="
        echo "⏰ Issue #3: 백그라운드 장시간 유지 테스트"
        echo "=========================================="
        echo ""

        echo "1단계: 백그라운드 측정 ON..."
        adb shell am start -n com.doyakmin.hangookji.namgu/.MainActivity

        echo ""
        echo -e "${YELLOW}수동 작업 필요:${NC}"
        echo "1. 앱에서 Walker 화면 진입"
        echo "2. '백그라운드 측정' 스위치 ON"
        echo "3. 알림에 '오늘 걸음수: N보' 표시 확인"
        echo ""
        read -p "완료했으면 Enter를 누르세요..."

        echo ""
        echo "2단계: 앱을 백그라운드로 전환..."
        adb shell input keyevent KEYCODE_HOME

        echo ""
        echo "3단계: 시스템 시간을 다음날로 변경..."

        # 현재 시간 백업
        ORIGINAL_TIME=$(adb shell date +%m%d%H%M%Y.%S)
        echo "원래 시간: $ORIGINAL_TIME"

        # 내일로 변경
        TOMORROW=$(date -v+1d "+%m%d%H%M%Y.%S" 2>/dev/null || date -d "+1 day" "+%m%d%H%M%Y.%S")
        echo "변경할 시간: $TOMORROW"

        echo ""
        read -p "시간을 변경하려면 Enter를 누르세요 (Ctrl+C로 취소)..."

        adb shell su 0 date "$TOMORROW" || {
            echo -e "${RED}❌ root 권한이 없습니다. 이 테스트는 실기기에서는 불가능할 수 있습니다.${NC}"
            echo "시뮬레이터 또는 root 디바이스를 사용하세요."
            exit 1
        }

        echo ""
        echo "4단계: 알림 확인..."
        echo ""
        echo -e "${YELLOW}수동 확인 필요:${NC}"
        echo "상단 알림을 확인하세요."
        echo ""
        echo -e "${RED}현재 버그 (낮은 확률):${NC}"
        echo "  - monotonic 보정으로 인해 어제 걸음수가 유지될 수 있음"
        echo ""
        echo -e "${GREEN}정상 동작 (대부분):${NC}"
        echo "  - autoDispose로 인해 0으로 리셋됨"
        echo ""

        read -p "확인 후 원래 시간으로 복구하려면 Enter를 누르세요..."

        # 시간 복구
        adb shell su 0 date "$ORIGINAL_TIME"
        echo -e "${GREEN}✅ 시간 복구 완료${NC}"
        ;;

    4)
        echo ""
        echo "전체 테스트는 각 테스트를 순차적으로 실행합니다."
        echo "시간이 오래 걸릴 수 있습니다 (재부팅 포함)."
        echo ""
        read -p "계속하려면 Enter를 누르세요 (Ctrl+C로 취소)..."

        # 각 테스트 실행
        bash "$0" <<< "2"
        echo ""
        echo "=========================================="
        read -p "다음 테스트로 이동하려면 Enter를 누르세요..."
        echo ""

        bash "$0" <<< "3"

        echo ""
        echo "=========================================="
        echo -e "${GREEN}✅ 전체 테스트 완료${NC}"
        echo "=========================================="
        ;;

    *)
        echo -e "${RED}❌ 잘못된 선택입니다.${NC}"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "테스트 완료"
echo "=========================================="
echo ""
echo "결과를 05_step_tracking_critical_fixes.md와 비교하세요."
