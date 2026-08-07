import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# Insert dart:ui if not present
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:ui';")

target_start = content.find("            // FLOATING ACTION PILL")
target_end = content.find("    );\n  }\n}", target_start)

if target_start == -1 or target_end == -1:
    print("Could not find block!")
    exit(1)

original_block = content[target_start:target_end+6]

# Let's replace the AnimatedContainer part
# We will use string replacement to inject the BackdropFilter and outer container.
new_block = original_block.replace("""                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
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
                        color: _isTotalExpanded
                            ? Colors.white.withValues(alpha: 0.95)
                            : null,
                        borderRadius: BorderRadius.circular(
                          _isTotalExpanded ? 24.0 : 32.0,
                        ),
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
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,""", """                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.fastLinearToSlowEaseIn,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _isTotalExpanded ? 24.0 : 32.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: _isTotalExpanded ? 20 : 15,
                            spreadRadius: _isTotalExpanded ? 0 : 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _isTotalExpanded ? 24.0 : 32.0,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.fastLinearToSlowEaseIn,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: _isTotalExpanded
                                  ? null
                                  : LinearGradient(
                                      colors: [
                                        AppColors.tealDark.withValues(alpha: 0.75),
                                        AppColors.tealMain.withValues(alpha: 0.75),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              color: _isTotalExpanded
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : null,
                              border: Border.all(
                                color: _isTotalExpanded
                                    ? AppColors.tealMain.withValues(alpha: 0.15)
                                    : Colors.tealAccent.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.fastLinearToSlowEaseIn,""")

# Update inner AnimatedSwitcher transition to match the new 500ms duration and curve
new_block = new_block.replace("""                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,""", """                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.fastLinearToSlowEaseIn,
                          switchOutCurve: Curves.fastLinearToSlowEaseIn,""")

new_block = new_block.replace("""                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ));
                            
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),""", """                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.fastLinearToSlowEaseIn,
                            ));
                            
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.fastLinearToSlowEaseIn,
                              ),""")

# Wrap the inner AnimatedSwitcher block properly? Actually the above replacement does it. 
# There is one more AnimatedContainer at the end that needs closing?
# Wait, BackdropFilter and ClipRRect are added, so we need two more closing parenthesis at the end of AnimatedSize block!
# Let's find where the AnimatedSize is closed. It is closed right before `), // GestureDetector`
# Let's just use regex or split to insert it.

new_block_lines = new_block.splitlines()
for i, line in enumerate(reversed(new_block_lines)):
    if "                      )," in line:
        # this is the end of AnimatedContainer
        break

# Actually it's easier to just do a smart replace for the end part.
target_end_str = """                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );"""

replacement_end_str = """                        ),
                      ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );"""

new_block = new_block.replace(target_end_str, replacement_end_str)

content = content.replace(original_block, new_block)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
print("Updated pill successfully.")
