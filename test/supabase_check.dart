// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://nvymirbsyzcnsphprbkc.supabase.co',
    'sb_publishable_1KCWaVcKpBTNyhZOU2LhLw_vaVFLKDV',
  );

  print('Testing Supabase connection...');
  try {
    final users = await client.from('users').select().limit(5);
    print('Users table count: ${users.length}');
    if (users.isNotEmpty) {
      print('First user keys: ${users.first.keys}');
      print('First user sample: ${users.first}');
    }
  } catch (e) {
    print('Users table error: $e');
  }

  try {
    final port = await client.from('portfolio_items').select().limit(5);
    print('Portfolio_items table count: ${port.length}');
    if (port.isNotEmpty) {
      print('First port item: ${port.first}');
    }
  } catch (e) {
    print('Portfolio_items table error: $e');
  }
}
