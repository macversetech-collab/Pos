import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

target = """            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width < 500 ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: sortedSizeLabels.map((groupKey) {
                final key = "$_selectedDate-$groupKey";"""

replacement = """            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 500 ? 1 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: sortedSizeLabels.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final groupKey = sortedSizeLabels[index];
                final key = "$_selectedDate-$groupKey";"""

content = content.replace(target, replacement)

target2 = """                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),"""

replacement2 = """                  ),
                );
              },
            ),
          ],
        ],
      ),"""

content = content.replace(target2, replacement2)

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)
