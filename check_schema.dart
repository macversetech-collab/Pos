// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://vvuinevpbvzvdrzwwcgm.supabase.co', 'sb_publishable_K_Siqrx9gXE9T22kpUOdHQ_ZI66dB45');
  
  try {
    final ordersRes = await client.from('orders').select().limit(1);
    print('Orders Schema: ${ordersRes.first.keys.toList()}');
    print('Sample Order: ${ordersRes.first}');
  } catch (e) {
    print('Error orders: $e');
  }

  try {
    final itemsRes = await client.from('order_items').select().limit(1);
    print('Order Items Schema: ${itemsRes.first.keys.toList()}');
    print('Sample Order Item: ${itemsRes.first}');
  } catch (e) {
    print('Error order_items: $e');
  }
}
