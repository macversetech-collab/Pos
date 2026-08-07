import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

target1 = """    // Prune very old historical orders (older than 180 days) at database stream layer
    final DateTime startRange = now.subtract(const Duration(days: 180));
    final String startFilterStr =
        "${startRange.year}-${startRange.month.toString().padLeft(2, '0')}-01";
    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .gte('delivery_date', startFilterStr);"""

replacement1 = """    _updateOrdersStream();"""

content = content.replace(target1, replacement1)

target2 = """  void _handlePrevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      _selectedOrder = null;
    });
  }"""

replacement2 = """  void _updateOrdersStream() {
    // Restrict stream to current month +/- 1 month to reduce memory and websocket load
    int prevM = _currentMonth == 1 ? 12 : _currentMonth - 1;
    int prevY = _currentMonth == 1 ? _currentYear - 1 : _currentYear;
    
    int nextM = _currentMonth == 12 ? 1 : _currentMonth + 1;
    int nextY = _currentMonth == 12 ? _currentYear + 1 : _currentYear;

    final String startFilterStr = "${prevY}-${prevM.toString().padLeft(2, '0')}-01";
    // We add 1 to next month to get the first day of the month after next
    int endM = nextM == 12 ? 1 : nextM + 1;
    int endY = nextM == 12 ? nextY + 1 : nextY;
    final String endFilterStr = "${endY}-${endM.toString().padLeft(2, '0')}-01";

    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .gte('delivery_date', startFilterStr)
        .lt('delivery_date', endFilterStr);
  }

  void _handlePrevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      _selectedOrder = null;
      _updateOrdersStream();
    });
  }"""

content = content.replace(target2, replacement2)

target3 = """  void _handleNextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
      _selectedOrder = null;
    });
  }"""

replacement3 = """  void _handleNextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
      _selectedOrder = null;
      _updateOrdersStream();
    });
  }"""

content = content.replace(target3, replacement3)

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)

