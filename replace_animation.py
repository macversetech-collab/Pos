import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

target = """                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTotalExpanded = !_isTotalExpanded;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _isTotalExpanded
                            ? null
                            : const LinearGradient(
                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealMain,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isTotalExpanded ? Colors.white.withValues(alpha: 0.95) : null,
                        borderRadius: BorderRadius.circular(_isTotalExpanded ? 24.0 : 32.0),
                        border: Border.all(
                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : Colors.tealAccent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isTotalExpanded 
                                ? Colors.black.withValues(alpha: 0.1)
                                : AppColors.tealDark.withValues(alpha: 0.4),
                            blurRadius: _isTotalExpanded ? 15 : 12,
                            spreadRadius: _isTotalExpanded ? 0 : 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isTotalExpanded
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: ["""

replacement = """                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTotalExpanded = !_isTotalExpanded;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _isTotalExpanded
                            ? null
                            : const LinearGradient(
                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealMain,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isTotalExpanded ? Colors.white.withValues(alpha: 0.95) : null,
                        borderRadius: BorderRadius.circular(_isTotalExpanded ? 24.0 : 32.0),
                        border: Border.all(
                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : Colors.tealAccent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isTotalExpanded 
                                ? Colors.black.withValues(alpha: 0.1)
                                : AppColors.tealDark.withValues(alpha: 0.4),
                            blurRadius: _isTotalExpanded ? 15 : 12,
                            spreadRadius: _isTotalExpanded ? 0 : 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        alignment: Alignment.bottomCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previousChildren.map((w) => Positioned(
                                      bottom: 0,
                                      child: w,
                                    )),
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
                                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: _isTotalExpanded
                          ? SizedBox(
                              key: const ValueKey('expanded'),
                              width: MediaQuery.of(context).size.width - 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: ["""

target2 = """                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ["""

replacement2 = """                          : Row(
                              key: const ValueKey('collapsed'),
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ["""

content = content.replace(target, replacement)
content = content.replace(target2, replacement2)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)

