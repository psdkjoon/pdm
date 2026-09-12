import 'dart:convert';
import 'dart:io';
import '../../models.dart';
import '../context.dart';
import '../parser.dart';
import '../render.dart';
Future<int> runList(CliContext ctx, ParsedArgs args) async {
  await ctx.client.connect(allowSpawn: ctx.allowSpawn);
  final resp = await ctx.client.request('list');
  await ctx.client.close();
  if (!resp.ok) {
    stderr.writeln(ctx.theme.error('Error: ${resp.error}'));
    return 1;
  }
  var records = (resp.data as List)
      .map((e) => TaskRecord.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
  final statusFilter = args.str('status');
  if (statusFilter != null) {
    records = records.where((r) => r.status.name == statusFilter).toList();
  }
  final sortField = args.str('sort') ?? 'created';
  records.sort((a, b) {
    switch (sortField) {
      case 'updated':
        return a.updatedAt.compareTo(b.updatedAt);
      case 'progress':
        return a.progress.compareTo(b.progress);
      case 'name':
        return a.savePath.compareTo(b.savePath);
      case 'created':
      default:
        return a.createdAt.compareTo(b.createdAt);
    }
  });
  if (args.flag('reverse')) records = records.reversed.toList();
  final limit = args.intVal('limit');
  if (limit != null && limit < records.length) {
    records = records.sublist(0, limit);
  }
  if (ctx.jsonOutput) {
    stdout.writeln(jsonEncode(records.map((r) => r.toJson()).toList()));
  } else {
    printTaskTable(records, ctx.theme);
  }
  return 0;
}
