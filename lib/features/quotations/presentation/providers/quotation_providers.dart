import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quotations_repository.dart';
import '../../domain/quotation.dart';

final quotationMyRequestsProvider = FutureProvider.autoDispose<List<QuotationRequestSummary>>((ref) async {
  return ref.watch(quotationsRepositoryProvider).getMyRequests();
});

final quotationWorkshopInboxProvider = FutureProvider.autoDispose<List<QuotationWorkshopInboxItemResponse>>((ref) async {
  return ref.watch(quotationsRepositoryProvider).getWorkshopInbox();
});

final quotationRequestQuotesProvider = FutureProvider.family.autoDispose<List<QuotationQuote>, String>((ref, requestId) async {
  return ref.watch(quotationsRepositoryProvider).getRequestQuotes(requestId);
});

class QuotationCreateRequestController extends AsyncNotifier<QuotationRequest?> {
  @override
  FutureOr<QuotationRequest?> build() {
    return null;
  }

  Future<QuotationRequest> createRequest(QuotationRequestCreate create) async {
    state = const AsyncValue.loading();
    try {
      final request = await ref.read(quotationsRepositoryProvider).createRequest(create);
      state = AsyncValue.data(request);
      return request;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final quotationCreateRequestControllerProvider = AsyncNotifierProvider<QuotationCreateRequestController, QuotationRequest?>(() {
  return QuotationCreateRequestController();
});

class QuotationCancelRequestController extends AsyncNotifier<QuotationRequest?> {
  @override
  FutureOr<QuotationRequest?> build() {
    return null;
  }

  Future<QuotationRequest> cancelRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      final request = await ref.read(quotationsRepositoryProvider).cancelRequest(requestId);
      state = AsyncValue.data(request);
      return request;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final quotationCancelRequestControllerProvider =
    AsyncNotifierProvider<QuotationCancelRequestController, QuotationRequest?>(() {
  return QuotationCancelRequestController();
});

class QuotationSelectionController extends AsyncNotifier<QuotationIncident?> {
  @override
  FutureOr<QuotationIncident?> build() {
    return null;
  }

  Future<QuotationIncident> selectQuote({
    required String requestId,
    required String quoteId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final incident = await ref.read(quotationsRepositoryProvider).selectQuote(
            requestId: requestId,
            quoteId: quoteId,
          );
      state = AsyncValue.data(incident);
      return incident;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final quotationSelectionControllerProvider = AsyncNotifierProvider<QuotationSelectionController, QuotationIncident?>(() {
  return QuotationSelectionController();
});
