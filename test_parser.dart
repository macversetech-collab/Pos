import 'dart:io';

void main() {
  String cleanInstructions = '[Additional Items: Cake A x1 [ToysCost: 1000], Cake B x1 [ToysCost: 1000, MoneyPullingCost: 2000]]';
  
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
      stderr.writeln('itemsPart: $itemsPart');
      
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
        stderr.writeln('itemStr: $itemStr');
        final nameEnd = itemStr.indexOf(' x');
        final qtyStart = nameEnd + 2;
        final qtyPart = itemStr.substring(qtyStart);
        stderr.writeln('qtyPart: $qtyPart');
        
        if (qtyPart.contains(' [')) {
          final tagStart = qtyPart.indexOf(' [') + 2;
          final tagEnd = qtyPart.indexOf(']', tagStart);
          stderr.writeln('tagStart: $tagStart, tagEnd: $tagEnd');
          
          if (tagEnd != -1) {
            final tagsStr = qtyPart.substring(tagStart, tagEnd);
            stderr.writeln('tagsStr: $tagsStr');
            final tags = tagsStr.split(', ');
            for (var tag in tags) {
              stderr.writeln('tag: "$tag"');
            }
          }
        }
      }
    }
  }
}
