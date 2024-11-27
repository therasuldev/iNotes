import 'package:dio/dio.dart';

import 'package:inotes/core/models/category.dart';
import 'package:inotes/core/models/note.dart';
import 'package:inotes/core/models/response.dart';
import 'package:inotes/core/service/api_client.dart';
import 'package:inotes/core/service/dio_helper.dart';
import 'package:inotes/core/service/log_service.dart';
import 'package:inotes/core/types.dart';

class NoteService {
  static NoteService? _instance;
  static NoteService get instance => _instance ?? NoteService._();
  late final Dio _dio;

  NoteService._() : _dio = ApiClient.instance.dio;

  Future<Note?> addNote({required Map<String, dynamic> noteJson}) async {
    final data = {
      'title': noteJson['title'],
      'content': noteJson['content'],
      'category': noteJson['category'],
      'delta': noteJson['delta'],
    };

    try {
      final response = await _dio.post('/note', data: data);
      if (response.statusCode == 201) {
        return Note.fromJson(response.data);
      }
      throw 'Failed to add note';
    } on DioException catch (exception) {
      final message = DioErrorHelper.handle(exception);
      CSLog.instance.debug('Add Note Error Message: $message');
      throw DioErrorHelper.handle(exception);
    } catch (e) {
      throw 'Failed to add note';
    }
  }

  Future<PaginatedDataResponse<Note>?> fetchNotes() async {
    try {
      final response = await _dio.get('/notes');
      if (response.statusCode == 200) {
        final products = PaginatedDataResponse<Note>.fromJson(response.data, Note.fromJson);
        return products;
      }
      throw 'Failed to load notes';
    } on DioException catch (exception) {
      throw DioErrorHelper.handle(exception);
    } catch (e) {
      CSLog.instance.debug('Fetch Notes Error Message: $e');
      throw 'Failed to load notes';
    }
  }

  Future<PaginatedDataResponse<Note>?> fetchRecentNotes() async {
    try {
      final response = await _dio.get('/recent-notes');
      if (response.statusCode == 200) {
        final products = PaginatedDataResponse<Note>.fromJson(response.data, Note.fromJson);
        return products;
      }
      throw 'Failed to load recent notes';
    } on DioException catch (exception) {
      throw DioErrorHelper.handle(exception);
    } catch (e) {
      CSLog.instance.debug('Fetch Recent Notes Error Message: $e');
      throw 'Failed to load recent notes';
    }
  }

  Future<PaginatedDataResponse<Category>?> fetchCategories() async {
    try {
      final response = await _dio.get('/categories');
      if (response.statusCode == 200) {
        final products = PaginatedDataResponse<Category>.fromJson(response.data, Category.fromJson);
        return products;
      }
      throw 'Failed to load categories';
    } on DioException catch (exception) {
      throw DioErrorHelper.handle(exception);
    } catch (e) {
      CSLog.instance.debug('Fetch Categories Error Message: $e');
      throw 'Failed to load categories';
    }
  }

  Future<Category?> addCategory({required Json categoryJson}) async {
    try {
      final data = FormData.fromMap({
        'name': categoryJson['name'],
        'avatar': MultipartFile.fromBytes(
          categoryJson['avatar'],
          filename: 'avatar.png',
          contentType: DioMediaType('image', 'png'), // Uygun MIME türü belirtin.
        ),
      });
      final response = await _dio.post('/category', data: data);
      if (response.statusCode == 201) {
        return Category.fromJson(response.data);
      }
      throw 'Failed to add category';
    } on DioException catch (exception) {
      throw DioErrorHelper.handle(exception);
    } catch (e) {
      CSLog.instance.debug('Add Category Error Message: $e');
      throw 'Failed to add category';
    }
  }
}