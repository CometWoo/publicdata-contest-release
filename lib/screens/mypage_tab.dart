import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';

// [개선] 마이페이지 탭을 독립 위젯으로 분리
class MyPageTab extends StatelessWidget {
  final Map<String, dynamic>? resume;
  final int jobCount;
  final VoidCallback onNavigateToResume;
  final VoidCallback onResetResume;
  final VoidCallback onToggleDebug;
  // [개선] 알림 토글 상태를 외부에서 관리
  final bool notificationEnabled;
  final ValueChanged<bool> onNotificationToggle;

  const MyPageTab({
    super.key,
    required this.resume,
    required this.jobCount,
    required this.onNavigateToResume,
    required this.onResetResume,
    required this.onToggleDebug,
    required this.notificationEnabled,
    required this.onNotificationToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildMenuList(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = resume?['name']?.toString() ?? '회원';

    return Semantics(
      label: '$name님의 프로필',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: AppConfig.fontSizeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '님,',
                      style: TextStyle(
                        fontSize: AppConfig.fontSizeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '오늘도 활기찬 하루 보내세요!',
                  style: TextStyle(
                    color: Colors.grey[700],
                    // [개선] 보조 텍스트 크기 상향
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                ),
              ],
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.user, size: 32, color: Colors.blue[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('지원한 일자리', '0'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('관심 일자리', '$jobCount'),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Semantics(
      label: '$label $value건',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                // [개선] 라벨 폰트 크기 상향
                fontSize: AppConfig.fontSizeSmall,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
                const Text(
                  '건',
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeCaption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            '내 이력서 확인하기',
            onTap: onNavigateToResume,
          ),
          _buildMenuItem(
            '이력서 및 대화 초기화',
            onTap: onResetResume,
            isDanger: true,
          ),
          // [개선] 커스텀 Container 토글 → Flutter Switch 위젯으로 교체
          _buildToggleMenuItem(
            '일자리 추천 알림',
            value: notificationEnabled,
            onChanged: onNotificationToggle,
          ),
          _buildMenuItem(
            '고객센터 (디버그 켜기)',
            onTap: onToggleDebug,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title, {
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    // [개선] Semantics + InkWell로 접근성 보장
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // [개선] 최소 48dp 높이 보장
          constraints: const BoxConstraints(minHeight: AppConfig.minTouchTarget),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDanger ? Colors.red : Colors.black87,
                  // [개선] 메뉴 텍스트 크기 상향
                  fontSize: AppConfig.fontSizeCaption,
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: isDanger ? Colors.red[300] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [개선] 기존 시각적 토글을 실제 Switch 위젯으로 교체 — 접근성 트리에 토글 역할 등록
  Widget _buildToggleMenuItem(
    String title, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: '$title, ${value ? "켜짐" : "꺼짐"}',
      toggled: value,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppConfig.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: AppConfig.fontSizeCaption,
              ),
            ),
            // [개선] Container 토글 → Switch 위젯으로 교체
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue[500],
            ),
          ],
        ),
      ),
    );
  }
}
