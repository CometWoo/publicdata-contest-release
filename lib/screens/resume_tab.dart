import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';

class ResumeTab extends StatefulWidget {
  final Map<String, dynamic>? resume;
  final List<String> missingKorean;
  final VoidCallback onReset;
  final VoidCallback onNavigateToHome;
  // [수정] 이력서 필드 수정 콜백 추가
  final void Function(String key, String value)? onFieldChanged;
  final VoidCallback? onSave;

  const ResumeTab({
    super.key,
    required this.resume,
    required this.missingKorean,
    required this.onReset,
    required this.onNavigateToHome,
    this.onFieldChanged,
    this.onSave,
  });

  static const Map<String, String> _fieldLabels = {
    'name': '성명',
    'age': '연령',
    'location': '거주지',
    'career': '최근 직장명 (경력)',
    'preferred_work_type': '희망 근무 형태',
    'physical_condition': '건강 상태',
  };

  static const Map<String, String> _fieldPlaceholders = {
    'name': '예: 홍길동',
    'age': '예: 65',
    'location': '예: 서울시 강남구',
    'career': '예: 삼성전자 생산직 20년',
    'preferred_work_type': '예: 시간제, 주 3일',
    'physical_condition': '예: 양호, 무릎이 조금 불편함',
  };

  static const Map<String, String> _fieldToKorean = {
    'name': '이름',
    'age': '나이',
    'location': '거주지',
    'career': '경력',
    'preferred_work_type': '희망 근무형태',
    'physical_condition': '건강 상태/체력',
  };

  @override
  State<ResumeTab> createState() => _ResumeTabState();
}

class _ResumeTabState extends State<ResumeTab> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    for (final key in ResumeTab._fieldLabels.keys) {
      final value = widget.resume?[key]?.toString() ?? '';
      final displayValue = (key == 'age' && value == '0') ? '' : value;
      _controllers[key] = TextEditingController(text: displayValue);
      _focusNodes[key] = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant ResumeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resume != widget.resume) {
      _syncControllersFromResume();
    }
  }

  void _syncControllersFromResume() {
    for (final key in ResumeTab._fieldLabels.keys) {
      final value = widget.resume?[key]?.toString() ?? '';
      final displayValue = (key == 'age' && value == '0') ? '' : value;
      final controller = _controllers[key]!;
      if (controller.text != displayValue && !_focusNodes[key]!.hasFocus) {
        controller.text = displayValue;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onFieldEdited(String key, String value) {
    setState(() => _hasUnsavedChanges = true);
    widget.onFieldChanged?.call(key, value);
  }

  void _saveAll() {
    HapticFeedback.lightImpact();
    for (final key in ResumeTab._fieldLabels.keys) {
      final value = _controllers[key]!.text.trim();
      widget.onFieldChanged?.call(key, value);
    }
    widget.onSave?.call();
    setState(() => _hasUnsavedChanges = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '이력서가 저장되었습니다.',
          style: TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(child: _buildResumeCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '어르신의',
                style: TextStyle(
                  fontSize: AppConfig.fontSizeTitle,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
              const Text(
                '멋진 이력서입니다!',
                style: TextStyle(
                  fontSize: AppConfig.fontSizeTitle,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: '이력서 초기화 버튼',
          button: true,
          child: Material(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.onReset,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppConfig.minTouchTarget,
                  minHeight: AppConfig.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.trash2, size: 16, color: Colors.red[500]),
                      const SizedBox(width: 4),
                      Text(
                        '초기화',
                        style: TextStyle(
                          color: Colors.red[500],
                          fontWeight: FontWeight.bold,
                          fontSize: AppConfig.fontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListView(
        children: [
          // [수정] 편집 안내 배너
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.pencil, size: 18, color: Colors.blue[600]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '각 항목을 눌러 직접 수정할 수 있습니다',
                    style: TextStyle(
                      fontSize: AppConfig.fontSizeSmall,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ...ResumeTab._fieldLabels.keys.map((key) => _buildEditableField(key)),

          const SizedBox(height: 10),

          // [수정] 저장 버튼
          Semantics(
            label: '이력서 저장',
            button: true,
            child: ElevatedButton.icon(
              onPressed: _saveAll,
              icon: Icon(
                _hasUnsavedChanges ? LucideIcons.save : LucideIcons.checkCircle2,
                size: 20,
              ),
              label: Text(
                _hasUnsavedChanges ? '변경사항 저장' : '저장 완료',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeCaption,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges ? Colors.blue[600] : Colors.green[500],
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, AppConfig.minTouchTarget),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Semantics(
            label: '홈 화면으로 이동하여 음성으로 이력서 작성하기',
            button: true,
            child: ElevatedButton(
              onPressed: widget.onNavigateToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[600],
                elevation: 0,
                minimumSize: const Size(double.infinity, AppConfig.minTouchTarget),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '음성으로 이력서 채우러 가기',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeCaption,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [수정] 읽기 전용 → 편집 가능한 텍스트 필드로 변경
  Widget _buildEditableField(String key) {
    final controller = _controllers[key]!;
    final focusNode = _focusNodes[key]!;
    final koreanKey = ResumeTab._fieldToKorean[key];
    final isMissing = koreanKey != null && widget.missingKorean.contains(koreanKey);
    final hasValue = controller.text.trim().isNotEmpty;
    final isAge = key == 'age';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ResumeTab._fieldLabels[key]!,
                style: TextStyle(
                  fontSize: AppConfig.fontSizeSmall,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 6),
              if (isMissing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    '미입력',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (hasValue)
                Icon(LucideIcons.checkCircle2, color: Colors.green[500], size: 16),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: isAge ? TextInputType.number : TextInputType.text,
            inputFormatters: isAge ? [FilteringTextInputFormatter.digitsOnly] : null,
            style: const TextStyle(
              fontSize: AppConfig.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: ResumeTab._fieldPlaceholders[key],
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: AppConfig.fontSizeCaption,
                fontWeight: FontWeight.normal,
              ),
              filled: true,
              fillColor: focusNode.hasFocus ? Colors.blue[50] : Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasValue ? Colors.green[200]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
              ),
              suffixIcon: hasValue
                  ? IconButton(
                      icon: Icon(LucideIcons.x, size: 18, color: Colors.grey[400]),
                      onPressed: () {
                        controller.clear();
                        _onFieldEdited(key, '');
                      },
                    )
                  : Icon(LucideIcons.pencil, size: 18, color: Colors.grey[400]),
              suffixText: isAge && hasValue ? '세' : null,
              suffixStyle: TextStyle(
                fontSize: AppConfig.fontSizeBody,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: (value) => _onFieldEdited(key, value),
          ),
        ],
      ),
    );
  }
}
