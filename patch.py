import re

with open("extracted.dart", "r") as f:
    content = f.read()

# 1. Update AnimatedContainer animation curve and duration
content = content.replace("duration: const Duration(milliseconds: 350),", "duration: const Duration(milliseconds: 400),")
content = content.replace("curve: Curves.easeOutBack,", "curve: Curves.easeOutCubic,")

# 2. Update AnimatedSwitcher layoutBuilder and transitionBuilder to make it smoother
target_switcher = """                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previousChildren.map(
                                  (w) => Positioned(bottom: 0, child: w),
                                ),
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.9,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                            );
                          },"""

replacement_switcher = """                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            final isExpanded = child.key == const ValueKey('expanded');
                            final slideTween = Tween<Offset>(
                              begin: isExpanded ? const Offset(0.0, 0.1) : const Offset(0.0, -0.1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ));
                            
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                              child: SlideTransition(
                                position: slideTween,
                                child: child,
                              ),
                            );
                          },"""

content = content.replace(target_switcher, replacement_switcher)

with open("extracted.dart", "w") as f:
    f.write(content)
