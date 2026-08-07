import re

with open("lib/tabs/counter_showline_tab.dart", "r") as f:
    content = f.read()

target1 = """    // 2. Fetch Showline Entries
    try {
      final res =
          await Supabase.instance.client.from('showline_entries').select();"""

replacement1 = """    // 2. Fetch Showline Entries
    try {
      final now = DateTime.now();
      final startOfMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00";
      final res =
          await Supabase.instance.client.from('showline_entries').select().gte('date', startOfMonth);"""

content = content.replace(target1, replacement1)

target2 = """    // 3. Fetch Counter Revenue Entries
    try {
      final res = await Supabase.instance.client
          .from('counter_cake_revenue_entries')
          .select();"""

replacement2 = """    // 3. Fetch Counter Revenue Entries
    try {
      final now = DateTime.now();
      final startOfMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00";
      final res = await Supabase.instance.client
          .from('counter_cake_revenue_entries')
          .select()
          .gte('created_at', startOfMonth);"""

content = content.replace(target2, replacement2)


with open("lib/tabs/counter_showline_tab.dart", "w") as f:
    f.write(content)
