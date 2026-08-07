import 'dart:io';

void main() {
  String cleanInstructions = '[Additional Items: Cake A (6 inch - Round) x1 [ToysCost: 1000, MoneyPullingCost: 2000]]';
  
  if (cleanInstructions.contains('[Additional Items: ')) {
    final startIdx =
        cleanInstructions.indexOf('[Additional Items: ') +
        '[Additional Items: '.length;
        
    int bracketCount = 1;
    int endIdx = -1;
    for (int i = startIdx; i < cleanInstructions.length; i++) {
      if (cleanInstructions[i] == '[') {
        bracketCount++;
      } else if (cleanInstructions[i] == ']') {
        bracketCount--;
      }
      
      if (bracketCount == 0) {
        endIdx = i;
        break;
      }
    }
    
    if (endIdx != -1) {
      final itemsPart = cleanInstructions.substring(startIdx, endIdx);
      final itemStrings = <String>[];
      int lastSplit = 0;
      int inBrackets = 0;
      for (int i = 0; i < itemsPart.length; i++) {
        if (itemsPart[i] == '[') {
          inBrackets++;
        } else if (itemsPart[i] == ']') {
          inBrackets--;
        } else if (itemsPart.startsWith(', ', i) && inBrackets == 0) {
          itemStrings.add(itemsPart.substring(lastSplit, i));
          lastSplit = i + 2;
          i++;
        }
      }
      if (lastSplit < itemsPart.length) {
        itemStrings.add(itemsPart.substring(lastSplit));
      }
      
      for (var itemStr in itemStrings) {
        final nameEnd = itemStr.indexOf(' (');
        if (nameEnd != -1) {
          final name = itemStr.substring(0, nameEnd);
          final specsStart = nameEnd + 2;
          final specsEnd = itemStr.indexOf(') x', specsStart);
          if (specsEnd != -1) {
            final specs = itemStr.substring(specsStart, specsEnd);
            final qtyStart = specsEnd + 3;
            final qtyPart = itemStr.substring(qtyStart);
            int qty = 1;
            int toysCost = 0;
            int moneyPullingCost = 0;

            if (qtyPart.contains(' [')) {
              final tagStart = qtyPart.indexOf(' [') + 2;
              final tagEnd = qtyPart.indexOf(']', tagStart);
              final qtyStr = qtyPart.substring(0, qtyPart.indexOf(' ['));
              qty = int.tryParse(qtyStr) ?? 1;

              if (tagEnd != -1) {
                final tagsStr = qtyPart.substring(tagStart, tagEnd);
                final tags = tagsStr.split(', ');
                for (var tag in tags) {
                  if (tag.startsWith('ToysCost: ')) {
                    toysCost =
                        int.tryParse(tag.substring('ToysCost: '.length)) ?? 0;
                  } else if (tag.startsWith('MoneyPullingCost: ')) {
                    moneyPullingCost =
                        int.tryParse(
                          tag.substring('MoneyPullingCost: '.length),
                        ) ??
                        0;
                  }
                }
              }
            } else {
              qty = int.tryParse(qtyPart) ?? 1;
            }
            stderr.writeln('Parsed: $name ($specs) x$qty, ToysCost: $toysCost, MoneyPullingCost: $moneyPullingCost');
          }
        }
      }
    }
  }
}
