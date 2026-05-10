import 'package:flutter/material.dart';
import '../config/app_config.dart';

// [개선] 시니어 친화적 접근성 보장 버튼 — 최소 터치 영역, Semantics 자동 적용
class AccessibleButton extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onTap;
  final Widget child;
  final double minSize;

  const AccessibleButton({
    super.key,
    required this.label,
    this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.minSize = AppConfig.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    // [개선] Semantics 위젯으로 스크린 리더 지원
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          // [개선] 최소 48x48dp 터치 영역 보장
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minSize,
              minHeight: minSize,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// [개선] 시니어 친화적 카드 버튼 — 큰 터치 영역과 명확한 라벨
class AccessibleCardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? semanticsLabel;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Widget? trailing;

  const AccessibleCardButton({
    super.key,
    required this.title,
    required this.subtitle,
    this.semanticsLabel,
    this.onTap,
    this.backgroundColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$title. $subtitle',
      button: true,
      child: Material(
        color: backgroundColor ?? Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // [개선] 시니어 최소 폰트 크기 적용
                          fontSize: AppConfig.fontSizeBody,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppConfig.fontSizeSmall,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
