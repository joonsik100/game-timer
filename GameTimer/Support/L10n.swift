import Foundation

/// 화면에 나오는 모든 한국어 문자열. 한곳에 모아 두면 문구를 고칠 때 코드를 뒤질 필요가 없다.
enum L10n {
    // 앱 전반
    static let appTitle = "게임 타이머"
    static let done = "완료"
    static let cancel = "취소"
    static let save = "저장"
    static let delete = "삭제"
    static let ok = "확인"

    // 본인 확인 (Face ID / Touch ID / 기기 암호)
    static let authReasonAdjust = "게임 시간을 조정하려면 본인 확인이 필요합니다"
    static let authReasonDelete = "기록을 지우려면 본인 확인이 필요합니다"
    static let authReasonSettings = "설정을 열려면 본인 확인이 필요합니다"
    static let authFailedTitle = "본인 확인에 실패했어요"
    static let authFailedMessage = "Face ID 또는 기기 암호로 확인해야 시간을 바꿀 수 있습니다."

    // 메인
    static let remainingTime = "이번 주 남은 시간"
    static let overdrawn = "시간을 초과했어요"
    static let penaltyColumn = "차감"
    static let benefitColumn = "추가"
    static let noPresets = "설정에서 항목을 추가하세요"
    static let saveFailed = "저장하지 못했습니다. 저장 공간을 확인해 주세요"

    // 히스토리
    static let history = "기록"
    static let noHistory = "아직 기록이 없어요"
    static let noHistoryHint = "메인 화면에서 차감/추가 버튼을 누르면 여기에 쌓입니다."
    static let thisWeek = "이번 주"
    static let lastWeek = "지난 주"

    // 설정
    static let settings = "설정"
    static let weeklyBaseSection = "주간 기본 시간"
    static let weeklyBaseFooter = "매주 시작일이 되면 이 시간으로 초기화됩니다."
    static let minuteUnit = "분"
    static let weekStartSection = "주 시작 요일"
    static let weekStartFooter = "주 시작 요일을 바꾸면 이번 주 남은 시간과 지난 기록의 묶음이 다시 계산됩니다."
    static let monday = "월요일"
    static let sunday = "일요일"
    static let penaltySection = "차감 항목"
    static let benefitSection = "추가 항목"
    static let addPenalty = "차감 항목 추가"
    static let addBenefit = "추가 항목 추가"
    static let emptyPresets = "항목이 없습니다"

    // 항목 편집
    static let newPenalty = "새 차감 항목"
    static let newBenefit = "새 추가 항목"
    static let editPenalty = "차감 항목 편집"
    static let editBenefit = "추가 항목 편집"
    static let presetNameLabel = "이름"
    static let presetNamePlaceholder = "예: 숙제 미완료"
    static let presetMinutesLabel = "시간"
}
