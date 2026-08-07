// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://vvuinevpbvzvdrzwwcgm.supabase.co', 'sb_publishable_K_Siqrx9gXE9T22kpUOdHQ_ZI66dB45');
  
  // Fix order 19
  await client.from('orders').update({
    'created_at': '2026-07-12T14:30:09.908692Z'
  }).eq('id', 'ord-1783866609908');
  
  // Fix order 32
  await client.from('orders').update({
    'created_at': '2026-07-12T14:28:22.217187Z'
  }).eq('id', 'ord-1783866502217');
  
  print('Fixed orders 19 and 32');
}
