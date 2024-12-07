import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inotes/core/provider/category/category_bloc.dart';
import 'package:inotes/main.dart';
import '../../models/note.dart';
import '../../models/response.dart';
import '../../utils/note_helper.dart';
import '../../service/log_service.dart';
import '../../service/remote/note_service.dart';
import '../../types.dart';

part 'note_event.dart';
part 'note_state.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  NoteBloc() : super(NoteState.initial()) {
    on<NoteEvent>((event, emit) async {
      switch (event.event) {
        case NoteEvents.addNoteStart:
          await _onAddNoteStart(event, emit);
          break;
        case NoteEvents.fetchNotesByCategoryStart:
          await _onfetchNotesByCategoryStart(event, emit);
          break;
        case NoteEvents.fetchRecentNotesStart:
          await _onfetchRecentNotesStart(event, emit);
          break;
        case NoteEvents.deleteNoteStart:
          await _onDeleteNoteStart(event, emit);
          break;
        case NoteEvents.updateNoteStart:
          await _onUpdateNoteStart(event, emit);
          break;
        case NoteEvents.deleteNotesStart:
          await _onDeleteNotesStart(event, emit);
          break;
        default:
      }
    });
  }

  Future<void> _onAddNoteStart(NoteEvent event, Emitter<NoteState> emit) async {
    emit(state.copyWith(event: NoteEvents.addNoteStart));

    try {
      final Note? note = await _service.addNote(noteJson: event.payload);
      if (note == null) return;

      final payload = {'category_name': note.category};
      final event0 = CategoryEvent.incrementNotesCountStart(payload: payload);
      navigatorKey.currentContext?.read<CategoryBloc>().add(event0);

      final recentNotes = state.recentNotes?.data;
      if (recentNotes != null) {
        ListHelper.addItem(
          recentNotes,
          note,
          uniqueChecker: (note0) => note0.id == note.id,
        );
      }

      final notesByCategory = state.notesByCategory?[note.category]?.data;
      if (notesByCategory != null) {
        ListHelper.addItem(
          notesByCategory,
          note,
          uniqueChecker: (note0) => note0.id == note.id,
        );
      }

      emit(state.copyWith(event: NoteEvents.addNoteSuccess));
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to add note',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(event: NoteEvents.addNoteFailure));
    }
  }

  Future<void> _onfetchRecentNotesStart(NoteEvent event, Emitter<NoteState> emit) async {
    emit(state.copyWith(
      event: NoteEvents.fetchRecentNotesStart,
    ));

    final bool isForceRefresh = event.payload['is_force_refresh'];

    final data = state.recentNotes?.data;
    final isExistData = data != null && data.isNotEmpty;

    // If there's existing data and it's not a forced refresh, emit the current state
    if (isExistData && !isForceRefresh) {
      emit(state.copyWith(event: NoteEvents.fetchRecentNotesSuccess));
      return;
    }

    try {
      final PaginatedDataResponse<Note>? recentNotes = await _service.fetchRecentNotes(userId: event.payload['user_id']);

      emit(state.copyWith(
        recentNotes: recentNotes,
        event: NoteEvents.fetchRecentNotesSuccess,
      ));
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to fetch recent notes',
        error: error,
        stackTrace: stackTrace,
      );

      emit(state.copyWith(
        event: NoteEvents.fetchRecentNotesFailure,
      ));
    }
  }

  Future<void> _onfetchNotesByCategoryStart(NoteEvent event, Emitter<NoteState> emit) async {
    emit(state.copyWith(
      event: NoteEvents.fetchNotesByCategoryStart,
    ));

    final data = state.notesByCategory![event.payload['category']]?.data;

    // If there's existing data and it's not a forced refresh, emit the current state
    if (data != null && data.isNotEmpty) {
      emit(state.copyWith(event: NoteEvents.fetchNotesByCategorySuccess));
      return;
    }

    try {
      final PaginatedDataResponse<Note>? notesByCategory = await _service.fetchNotesByCategory(
        userId: event.payload['user_id'],
        categoryId: event.payload['category_id'],
      );

      emit(state.copyWith(
        notesByCategory: {
          ...state.notesByCategory!,
          event.payload['category']: notesByCategory,
        },
        event: NoteEvents.fetchNotesByCategorySuccess,
      ));
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to fetch recent notes',
        error: error,
        stackTrace: stackTrace,
      );

      emit(state.copyWith(
        event: NoteEvents.fetchNotesByCategoryFailure,
      ));
    }
  }

  Future<void> _onDeleteNoteStart(NoteEvent event, Emitter<NoteState> emit) async {
    emit(state.copyWith(
      event: NoteEvents.deleteNoteStart,
    ));

    try {
      final bool isDeleted = await _service.deleteNote(
        noteId: event.payload['note_id'],
        userId: event.payload['user_id'],
        categoryId: event.payload['category_id'],
      );

      if (isDeleted) {
        emit(state.copyWith(
          event: NoteEvents.deleteNoteSuccess,
        ));

        final recentNotes = state.recentNotes?.data;
        if (recentNotes != null) {
          ListHelper.removeItem(
            recentNotes,
            (note) => note.id == event.payload['note_id'],
          );
        }
        final notesByCategory = state.notesByCategory?[event.payload['category']]?.data;
        if (notesByCategory != null) {
          ListHelper.removeItem<Note>(
            state.notesByCategory?[event.payload['category']]?.data ?? [],
            (note) => note.id == event.payload['note_id'],
          );
        }

        final payload = {'category_name': event.payload['category']};
        final event0 = CategoryEvent.decrementNotesCountStart(payload: payload);
        navigatorKey.currentContext?.read<CategoryBloc>().add(event0);
      }

      emit(state);
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to delete note',
        error: error,
        stackTrace: stackTrace,
      );

      emit(state.copyWith(
        event: NoteEvents.deleteNoteFailure,
      ));
    }
  }

  Future<void> _onUpdateNoteStart(NoteEvent event, Emitter<NoteState> emit) async {
    emit(state.copyWith(
      event: NoteEvents.updateNoteStart,
    ));

    try {
      final Note? updateNote = await _service.updateNote(
        noteId: event.payload['id'],
        userId: event.payload['user_id'],
        title: event.payload['title'],
        content: event.payload['content'],
        delta: event.payload['delta'],
      );

      if (updateNote != null) {
        emit(state.copyWith(
          event: NoteEvents.updateNoteSuccess,
        ));

        final recentNotes = state.recentNotes?.data;
        if (recentNotes != null) {
          ListHelper.updateItem(
            recentNotes,
            (note) => note.id == updateNote.id,
            updateNote,
          );
        }

        final notesByCategory = state.notesByCategory?[event.payload['category']]?.data;
        if (notesByCategory != null) {
          ListHelper.updateItem(
            notesByCategory,
            (note) => note.id == updateNote.id,
            updateNote,
          );
        }
      }

      // if you back to `notes view` from `note editor view`, you need to fetch notes again
      emit(state.copyWith(event: NoteEvents.fetchNotesByCategorySuccess));
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to update note',
        error: error,
        stackTrace: stackTrace,
      );

      emit(state.copyWith(
        event: NoteEvents.updateNoteFailure,
      ));
    }
  }

  Future<void> _onDeleteNotesStart(NoteEvent event, Emitter<NoteState> emit) async {
    try {
      final recentNotes = state.recentNotes?.data;
      if (recentNotes != null) {
        ListHelper.removeItems(
          recentNotes,
          (note) => note.categoryId == event.payload['category_id'],
        );
      }

      final notesByCategory = state.notesByCategory?[event.payload['category']]?.data;
      if (notesByCategory != null) {
        ListHelper.removeItems<Note>(
          state.notesByCategory?[event.payload['category']]?.data ?? [],
          (note) => note.categoryId == event.payload['category_id'],
        );
      }

      emit(state.copyWith(event: NoteEvents.fetchRecentNotesSuccess));
    } catch (error, stackTrace) {
      AppLog.instance.error(
        'Failed to delete note',
        error: error,
        stackTrace: stackTrace,
      );

      emit(state.copyWith(
        event: NoteEvents.deleteNoteFailure,
      ));
    }
  }

  final _service = NoteService.instance;
}
