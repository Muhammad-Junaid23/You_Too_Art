// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://nvymirbsyzcnsphprbkc.supabase.co',
    'sb_publishable_1KCWaVcKpBTNyhZOU2LhLw_vaVFLKDV',
  );

  print('Testing Supabase connection...');
  try {
    final posts = await client.from('posts').select();
    print('Posts table content: $posts');
  } catch (e) {
    print('Posts error: $e');
  }

  try {
    final users = await client.from('users').select();
    print('Users table content: $users');
  } catch (e) {
    print('Users error: $e');
  }
}
