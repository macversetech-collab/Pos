import 'dart:ui';
import 'package:flutter/material.dart';

class AnchoredDropdown<T> extends FormField<T> {
  AnchoredDropdown({
    super.key,
    T? value,
    T? initialValue,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    InputDecoration? decoration,
    super.validator,
    Widget? hint,
  }) : super(
          initialValue: value ?? initialValue,
          builder: (FormFieldState<T> state) {
            final effectiveDecoration = (decoration ?? const InputDecoration())
                .applyDefaults(Theme.of(state.context).inputDecorationTheme);

            Widget? selectedWidget;
            if (state.value != null) {
              final selectedItem = items.firstWhere(
                (item) => item.value == state.value,
                orElse: () => items.first,
              );
              selectedWidget = selectedItem.child;
            } else {
              selectedWidget = hint;
            }

            return Builder(
              builder: (BuildContext context) {
                return InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _showAnchoredMenu(
                      context: context,
                      items: items,
                      currentValue: state.value,
                      onSelected: (val) {
                        state.didChange(val);
                        onChanged(val);
                      },
                    );
                  },
                  child: InputDecorator(
                    decoration: effectiveDecoration.copyWith(errorText: state.errorText),
                    isEmpty: state.value == null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: selectedWidget ?? const SizedBox()),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

  static void _showAnchoredMenu<T>({
    required BuildContext context,
    required List<DropdownMenuItem<T>> items,
    required T? currentValue,
    required void Function(T?) onSelected,
  }) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _AnchoredDropdownRoute<T>(
            items: items,
            currentValue: currentValue,
            onSelected: onSelected,
            fieldOffset: offset,
            fieldSize: size,
            animation: animation,
          );
        },
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
      ),
    );
  }
}

class _AnchoredDropdownRoute<T> extends StatelessWidget {
  final List<DropdownMenuItem<T>> items;
  final T? currentValue;
  final void Function(T?) onSelected;
  final Offset fieldOffset;
  final Size fieldSize;
  final Animation<double> animation;

  const _AnchoredDropdownRoute({
    super.key,
    required this.items,
    required this.currentValue,
    required this.onSelected,
    required this.fieldOffset,
    required this.fieldSize,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Estimate menu height based on item count (approx 48px per item)
    final double maxMenuHeight = (items.length * 48.0).clamp(0, 300.0);
    
    // Check space below
    final double spaceBelow = screenSize.height - fieldOffset.dy - fieldSize.height - safeAreaBottom - 16;
    
    bool openUpward = spaceBelow < maxMenuHeight && fieldOffset.dy > spaceBelow;
    
    double? top;
    double? bottom;
    
    if (openUpward) {
      bottom = screenSize.height - fieldOffset.dy + 8; // 8px gap
    } else {
      top = fieldOffset.dy + fieldSize.height + 8; // 8px gap
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.fastLinearToSlowEaseIn,
      reverseCurve: Curves.easeOut,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Glass blur backdrop (static blur for performance)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: FadeTransition(
              opacity: animation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          
          // The anchored menu
          Positioned(
            left: fieldOffset.dx,
            width: fieldSize.width,
            top: top,
            bottom: bottom,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation),
              alignment: openUpward ? Alignment.bottomCenter : Alignment.topCenter,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = item.value == currentValue;
                        
                        return InkWell(
                          onTap: () {
                            onSelected(item.value);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: index < items.length - 1 
                                  ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                                  : null,
                              color: isSelected ? const Color(0xFF00796B).withValues(alpha: 0.05) : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF00796B) : const Color(0xFF2D241E),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    child: item.child,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, color: Color(0xFF00796B), size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
