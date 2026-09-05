// Plan A38 — "Download my data" from Settings.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/data_export_file.dart';
import '../repositories/data_export_repository.dart';

@injectable
class ExportMyData {
  const ExportMyData(this._repository);

  final DataExportRepository _repository;

  Future<Result<DataExportFile>> call() => _repository.exportMyData();
}
