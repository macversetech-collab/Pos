import re

with open("lib/tabs/dashboard_tab.dart", "r") as f:
    content = f.read()

target = """    // 1. Fetch Orders
    try {
      final res = await Supabase.instance.client.from('orders').select();"""

replacement = """    // 1. Fetch Orders
    try {
      final now = DateTime.now();
      var query = Supabase.instance.client.from('orders').select();

      if (_activeFilter == 'Today') {
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        query = query.eq('delivery_date', todayStr);
      } else if (_activeFilter == 'Month') {
        final startStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00";
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final endStr = "${nextYear}-${nextMonth.toString().padLeft(2, '0')}-01T00:00:00";
        query = query.gte('created_at', startStr).lt('created_at', endStr);
      } else {
        final startClean = "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}";
        final endClean = "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}";
        query = query.gte('delivery_date', startClean).lte('delivery_date', endClean);
      }

      final res = await query;"""

content = content.replace(target, replacement)

# Remove the unconditional fetch on didUpdateWidget
target2 = """  @override
  void didUpdateWidget(covariant SalesDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _fetchDashboardData();
    }
  }"""

# We can replace it with a stale check, but since we are not storing the last fetch time,
# let's just remove it or change it to check if _dbOrders is empty. Actually, if they create an order and come back, they might want to see it.
# Let's add a last fetched timestamp.
replacement2 = """  DateTime? _lastFetched;

  @override
  void didUpdateWidget(covariant SalesDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (_lastFetched == null || DateTime.now().difference(_lastFetched!).inMinutes > 2) {
        _fetchDashboardData();
      }
    }
  }"""

content = content.replace(target2, replacement2)

target3 = """      _dbOrders = orders;
      _isLoading = false;
    });
  }"""

replacement3 = """      _dbOrders = orders;
      _isLoading = false;
      _lastFetched = DateTime.now();
    });
  }"""

content = content.replace(target3, replacement3)

with open("lib/tabs/dashboard_tab.dart", "w") as f:
    f.write(content)
