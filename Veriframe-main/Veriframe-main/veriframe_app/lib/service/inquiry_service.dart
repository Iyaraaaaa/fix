import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/service/notification_service.dart';

/// Service responsible for recording Police Inquiries and Legal Consultation
/// requests directly into Firestore under the official recipient account (0784770935)
/// as well as the submitting user's account.
class InquiryService {
  InquiryService._();
  static final InquiryService instance = InquiryService._();

  static const String targetPhone = '0784770935';
  static const String targetPhoneIntl = '94784770935';
  static const String targetEmail = 'sithmiyara2001@gmail.com';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Resolves the Firestore User UID matching 0784770935 / sithmiyara2001@gmail.com.
  /// If the user document does not exist yet, creates a deterministic placeholder
  /// account document so inquiries and notifications are always stored reliably.
  Future<String> _resolveTargetAccountUid() async {
    try {
      final usersColl = _firestore.collection('users');

      // 1. Check by phone matches
      for (final phoneCandidate in ['0784770935', '+94784770935', '94784770935']) {
        final phoneQuery = await usersColl
            .where('phone', isEqualTo: phoneCandidate)
            .limit(1)
            .get();
        if (phoneQuery.docs.isNotEmpty) {
          return phoneQuery.docs.first.id;
        }

        final phoneAltQuery = await usersColl
            .where('phoneNumber', isEqualTo: phoneCandidate)
            .limit(1)
            .get();
        if (phoneAltQuery.docs.isNotEmpty) {
          return phoneAltQuery.docs.first.id;
        }
      }

      // 2. Check by official email
      final emailQuery = await usersColl
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();
      if (emailQuery.docs.isNotEmpty) {
        return emailQuery.docs.first.id;
      }

      // 3. Deterministic account ID fallback for 0784770935
      const deterministicUid = 'account_0784770935';
      final defaultDoc = usersColl.doc(deterministicUid);
      final exists = (await defaultDoc.get()).exists;
      if (!exists) {
        await defaultDoc.set({
          'uid': deterministicUid,
          'name': 'CID Police & Legal Desk (0784770935)',
          'phone': targetPhone,
          'email': targetEmail,
          'role': 'official_desk',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));
      }
      return deterministicUid;
    } catch (e) {
      debugPrint('[InquiryService] Error resolving target UID: $e');
      return 'account_0784770935';
    }
  }

  /// Records an Official Police Inquiry into:
  /// 1. Top-level collection `inquiries`
  /// 2. Target account (0784770935) subcollections: `users/{targetUid}/inquiries` and `notifications`
  /// 3. Submitting user's account subcollections: `users/{currentUid}/inquiries` and `notifications`
  Future<void> recordPoliceInquiry({
    required String inqRef,
    required String reportId,
    required String complainantName,
    required String complainantPhone,
    required String complainantEmail,
    required String complainantAddress,
    required String incidentLocation,
    required String offenceCategory,
    required String statementOfFacts,
    required String suspectMedia,
    required String mediaType,
    required String verdict,
    required double fakeProbability,
    required String reportHash,
    required String dossierText,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUid = currentUser?.uid;
      final currentEmail = currentUser?.email ?? '';

      final targetUid = await _resolveTargetAccountUid();
      final now = DateTime.now();

      final inquiryData = {
        'inquiryRef': inqRef,
        'reportId': reportId,
        'targetPhone': targetPhone,
        'targetEmail': targetEmail,
        'targetRole': 'police_it_department',
        'complainantName': complainantName.isNotEmpty ? complainantName : 'Anonymous / Not provided',
        'complainantPhone': complainantPhone.isNotEmpty ? complainantPhone : 'Not provided',
        'complainantEmail': complainantEmail.isNotEmpty ? complainantEmail : 'Not provided',
        'complainantAddress': complainantAddress.isNotEmpty ? complainantAddress : 'Not provided',
        'incidentLocation': incidentLocation.isNotEmpty ? incidentLocation : 'Not specified',
        'offenceCategory': offenceCategory,
        'statementOfFacts': statementOfFacts,
        'suspectMedia': suspectMedia,
        'mediaType': mediaType,
        'verdict': verdict,
        'fakeProbability': fakeProbability,
        'reportHash': reportHash,
        'dossierText': dossierText,
        'submittedByUid': currentUid ?? 'anonymous',
        'submittedByEmail': currentEmail,
        'status': 'submitted_to_police',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Top-level inquiries collection
      await _firestore.collection('inquiries').doc(inqRef).set(inquiryData, SetOptions(merge: true));

      // 2. Deliver to target account 0784770935
      await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('inquiries')
          .doc(inqRef)
          .set(inquiryData, SetOptions(merge: true));

      final targetNotification = NotificationModel(
        id: 'notif_inq_${DateTime.now().millisecondsSinceEpoch}_$inqRef',
        title: 'New Official Inquiry: $inqRef',
        message: 'Complainant: ${complainantName.isNotEmpty ? complainantName : 'Anonymous'}. Category: $offenceCategory.',
        type: 'police_inquiry',
        reportId: reportId,
        createdAt: now,
        isRead: false,
        score: fakeProbability,
        prediction: verdict.toUpperCase(),
        videoName: suspectMedia,
      );

      await NotificationService.instance.createNotification(targetUid, targetNotification);

      // 3. Deliver to submitting user account if logged in
      if (currentUid != null && currentUid.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUid)
            .collection('inquiries')
            .doc(inqRef)
            .set(inquiryData, SetOptions(merge: true));

        final userNotification = NotificationModel(
          id: 'notif_user_inq_${DateTime.now().millisecondsSinceEpoch}_$inqRef',
          title: 'Inquiry Submitted ($inqRef)',
          message: 'Case filed to Police IT Department Desk (0784770935).',
          type: 'police_inquiry',
          reportId: reportId,
          createdAt: now,
          isRead: false,
          score: fakeProbability,
          prediction: verdict.toUpperCase(),
          videoName: suspectMedia,
        );

        await NotificationService.instance.createNotification(currentUid, userNotification);
      }

      // Local system banner
      await NotificationService.instance.showLocalNotification(
        id: inqRef.hashCode.abs() % 100000,
        title: 'Inquiry Filed: $inqRef',
        body: 'Dispatched to Police Desk (0784770935).',
      );

      debugPrint('[InquiryService] Inquiry $inqRef recorded to 0784770935 account successfully.');
    } catch (e) {
      debugPrint('[InquiryService] Error recording police inquiry: $e');
    }
  }

  /// Records a Legal Consultation Request into:
  /// 1. Top-level collection `legal_consultations`
  /// 2. Target lawyer account (0784770935) subcollections: `users/{targetUid}/legal_requests` and `notifications`
  /// 3. Submitting user's account subcollections: `users/{currentUid}/legal_requests` and `notifications`
  Future<void> recordLegalConsultation({
    required String inqRef,
    required String reportId,
    required String clientName,
    required String clientPhone,
    required String clientEmail,
    required String incidentCategory,
    required String briefText,
    required String suspectMedia,
    required String verdict,
    required double fakeProbability,
    required String reportHash,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUid = currentUser?.uid;
      final currentEmail = currentUser?.email ?? '';

      final targetUid = await _resolveTargetAccountUid();
      final now = DateTime.now();

      final legalData = {
        'inquiryRef': inqRef,
        'reportId': reportId,
        'targetPhone': targetPhone,
        'targetEmail': targetEmail,
        'targetRole': 'retained_lawyer',
        'clientName': clientName.isNotEmpty ? clientName : 'Anonymous / Not provided',
        'clientPhone': clientPhone.isNotEmpty ? clientPhone : 'Not provided',
        'clientEmail': clientEmail.isNotEmpty ? clientEmail : 'Not provided',
        'incidentCategory': incidentCategory,
        'briefText': briefText,
        'suspectMedia': suspectMedia,
        'verdict': verdict,
        'fakeProbability': fakeProbability,
        'reportHash': reportHash,
        'submittedByUid': currentUid ?? 'anonymous',
        'submittedByEmail': currentEmail,
        'status': 'pending_consultation',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Top-level collection
      await _firestore
          .collection('legal_consultations')
          .doc(inqRef)
          .set(legalData, SetOptions(merge: true));

      // 2. Deliver to target lawyer account (0784770935)
      await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('legal_requests')
          .doc(inqRef)
          .set(legalData, SetOptions(merge: true));

      final targetNotification = NotificationModel(
        id: 'notif_legal_${DateTime.now().millisecondsSinceEpoch}_$inqRef',
        title: 'New Legal Consultation: $inqRef',
        message: 'Client: ${clientName.isNotEmpty ? clientName : 'Anonymous'}. Category: $incidentCategory.',
        type: 'legal_consultation',
        reportId: reportId,
        createdAt: now,
        isRead: false,
        score: fakeProbability,
        prediction: verdict.toUpperCase(),
        videoName: suspectMedia,
      );

      await NotificationService.instance.createNotification(targetUid, targetNotification);

      // 3. Deliver to submitting user account
      if (currentUid != null && currentUid.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUid)
            .collection('legal_requests')
            .doc(inqRef)
            .set(legalData, SetOptions(merge: true));

        final userNotification = NotificationModel(
          id: 'notif_user_legal_${DateTime.now().millisecondsSinceEpoch}_$inqRef',
          title: 'Legal Consultation Sent ($inqRef)',
          message: 'Legal brief dispatched to lawyer account (0784770935).',
          type: 'legal_consultation',
          reportId: reportId,
          createdAt: now,
          isRead: false,
          score: fakeProbability,
          prediction: verdict.toUpperCase(),
          videoName: suspectMedia,
        );

        await NotificationService.instance.createNotification(currentUid, userNotification);
      }

      // Local system banner
      await NotificationService.instance.showLocalNotification(
        id: ('legal_$inqRef').hashCode.abs() % 100000,
        title: 'Legal Brief Sent: $inqRef',
        body: 'Dispatched to Lawyer Desk (0784770935).',
      );

      debugPrint('[InquiryService] Legal consultation $inqRef recorded to 0784770935 account successfully.');
    } catch (e) {
      debugPrint('[InquiryService] Error recording legal consultation: $e');
    }
  }
}
