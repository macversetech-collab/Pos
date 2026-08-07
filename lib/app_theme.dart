import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Theme colors for the soft teal + light cyan bakery theme.
class AppColors {
  static const Color tealMain = Color(0xFF00796B);
  static const Color tealDark = Color(0xFF004D40);
  static const Color tealLight = Color(0xFF00897B);
  static const Color cyanLight = Color(0xFFE0F7FA);
  static const Color mintGreen = Color(0xFFE0F2F1);
  
  static const Color backgroundStart = Color(0xFFE0F7FA); // Light Cyan
  static const Color backgroundEnd = Color(0xFFB2DFDB);   // Soft Teal
  
  // Pastels for accent colors
  static const Color orangeAccent = Color(0xFFFFB74D); // Soft pastel orange
  static const Color peachAccent = Color(0xFFFFCC80);
  static const Color purpleAccent = Color(0xFFCE93D8);
  static const Color blueAccent = Color(0xFF90CAF9);
}

/// Shared rounded UI tokens matching the AI Studio web preview.
class AppDecorations {
  static const double radius = 20.0; // Soft, premium roundness

  static BorderRadius get roundedBorderRadius => BorderRadius.circular(radius);

  static InputDecoration input({
    String? labelText,
    String? hintText,
    bool filled = true,
    Color? fillColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: filled,
      fillColor: fillColor ?? AppColors.tealMain.withValues(alpha: 0.04), // Tinted glass surface
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.8), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: const BorderSide(color: Color(0x11FFFFFF)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: roundedBorderRadius,
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: AppColors.tealMain.withValues(alpha: 0.4)),
    );
  }

  static BoxDecoration container({
    Color? color,
    Color borderColor = const Color(0x33FFFFFF), // Translucent white border for glass effect
    double borderWidth = 1.5,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.65), // Glassmorphism backdrop
      borderRadius: roundedBorderRadius,
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// Extensions to easily implement viewport-relative responsive typography.
extension ResponsiveTypography on BuildContext {
  /// Dynamically scales font sizes on the Web platform based on the window/viewport width.
  ///
  /// Formula: `baseSize + (viewportWidth * 0.005)` (adjusted relative to base size)
  /// constrained between [min] and [max] bounds to prevent layouts from breaking.
  double responsiveFont(double baseSize, {double? min, double? max}) {
    if (!kIsWeb) return baseSize;

    final double width = MediaQuery.of(this).size.width;
    if (width <= 800) return baseSize;

    // Viewport-relative scaling factor
    // e.g. For width 1920, factor is 1.0 + (1920 - 800) * 0.0005 = 1.56
    final double scaleFactor = 1.0 + (width - 800) * 0.0005;

    final double computed = baseSize * scaleFactor;
    final double minLimit = min ?? baseSize;
    final double maxLimit = max ?? (baseSize * 1.6);

    return computed.clamp(minLimit, maxLimit);
  }
}

extension ResponsiveTextStyle on TextStyle {
  /// Returns a copy of this [TextStyle] with a dynamic, responsive font size
  /// computed from the current [BuildContext] context.
  TextStyle responsive(BuildContext context, {double? min, double? max}) {
    if (fontSize == null) return this;
    return copyWith(
      fontSize: context.responsiveFont(fontSize!, min: min, max: max),
    );
  }
}
