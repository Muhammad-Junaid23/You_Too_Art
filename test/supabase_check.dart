// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://nvymirbsyzcnsphprbkc.supabase.co',
    'sb_publishable_1KCWaVcKpBTNyhZOU2LhLw_vaVFLKDV',
  );

  print('Testing Supabase connection...');
  try {
    final users = await client.from('users').select().limit(1);
    print('Users table reachable, rows: ${users.length}');
  } catch (e) {
    print('Users table error: $e');
  }
}
