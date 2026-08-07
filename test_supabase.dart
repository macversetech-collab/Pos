// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://vvuinevpbvzvdrzwwcgm.supabase.co', 'sb_publishable_K_Siqrx9gXE9T22kpUOdHQ_ZI66dB45');
  final res = await client.from('orders').select().order('created_at', ascending: false).limit(2);
  for (var row in res) {
    print('Order: ${row['order_number']}, created_at raw: ${row['created_at']}');
  }
}
