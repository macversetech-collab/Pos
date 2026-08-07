import re

with open("extracted.dart", "r") as f:
    content = f.read()

target = """                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },"""

replacement = """                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previousChildren.map(
                                  (w) => Positioned(bottom: 0, child: w),
                                ),
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },"""

content = content.replace(target, replacement)

with open("extracted.dart", "w") as f:
    f.write(content)
