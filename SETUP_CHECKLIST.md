# FCM & Engagement System Setup Checklist

## Pre-Implementation

- [ ] Review `FCM_NOTIFICATIONS_GUIDE.md`
- [ ] Ensure Firebase project is set up in Firebase Console
- [ ] Have Firebase credentials ready

## Firestore Setup

- [ ] Create Firestore indexes for notifications queries
- [ ] Add notification fields to user documents schema
- [ ] Set up Firestore security rules for notifications collection

### Firestore Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      match /notifications/{notificationId} {
        allow read: if request.auth.uid == userId;
        allow write: if request.auth.uid == userId || 
                       request.auth.token.admin == true;
      }
    }
  }
}
```

## Android Setup

- [ ] Add POST_NOTIFICATIONS permission to AndroidManifest.xml
- [ ] Test on Android 12+ (API 31+)
- [ ] Verify notification channel creation
- [ ] Test with Firebase Emulator

## iOS Setup

- [ ] Add remote-notification to UIBackgroundModes in Info.plist
- [ ] Request user permission for notifications
- [ ] Test on iOS 10+
- [ ] Verify APNs certificate in Firebase Console

## Code Integration

- [ ] Verify all service files created:
  - [ ] `lib/services/fcm_service.dart`
  - [ ] `lib/services/notification_service.dart`
  - [ ] `lib/services/engagement_service.dart`
  - [ ] `lib/models/notification_model.dart`

- [ ] Verify all services updated:
  - [ ] `lib/services/chat_service.dart` - Chat notifications
  - [ ] `lib/services/comment_service.dart` - Comment notifications
  - [ ] `lib/services/post_service.dart` - Like notifications
  - [ ] `lib/services/match_service.dart` - Match notifications
  - [ ] `lib/main.dart` - FCM initialization

## Testing

- [ ] Test chat message notifications
- [ ] Test post like notifications
- [ ] Test comment notifications
- [ ] Test match notifications
- [ ] Test engagement notifications
- [ ] Test notification preferences
- [ ] Test with app in foreground
- [ ] Test with app in background
- [ ] Test with app closed
- [ ] Test on both Android and iOS

## Backend (Cloud Functions)

- [ ] Deploy Cloud Functions for FCM sending
- [ ] Test Cloud Functions locally
- [ ] Set up error logging
- [ ] Monitor function execution

## Monitoring & Analytics

- [ ] Set up Firebase Analytics for notifications
- [ ] Create dashboard for notification metrics
- [ ] Monitor delivery rates
- [ ] Track user engagement changes
- [ ] Set up alerts for failures

## Documentation

- [ ] Update API documentation
- [ ] Create user-facing notification settings guide
- [ ] Document notification types for support team
- [ ] Create troubleshooting guide

## Deployment

- [ ] Test in staging environment
- [ ] Get stakeholder approval
- [ ] Plan rollout strategy
- [ ] Monitor initial deployment
- [ ] Gather user feedback
- [ ] Iterate based on feedback

## Post-Launch

- [ ] Monitor notification delivery rates
- [ ] Track user engagement metrics
- [ ] Analyze A/B test results
- [ ] Optimize engagement messages
- [ ] Implement additional notification types as needed
- [ ] Regular maintenance and updates

## Troubleshooting Checklist

If notifications aren't working:

- [ ] Verify FCM token is being saved to Firestore
- [ ] Check notification permissions on device
- [ ] Verify notification preferences are enabled
- [ ] Check Firebase Console for errors
- [ ] Test with Firebase Emulator
- [ ] Check device notification settings
- [ ] Verify notification channel exists (Android)
- [ ] Check app permissions in system settings
- [ ] Review Cloud Functions logs
- [ ] Check network connectivity

## Performance Optimization

- [ ] Implement notification batching
- [ ] Add notification debouncing
- [ ] Cache user preferences locally
- [ ] Optimize Firestore queries
- [ ] Monitor app performance impact
- [ ] Profile memory usage
- [ ] Test with large user base

## Security

- [ ] Validate all notification data
- [ ] Implement rate limiting
- [ ] Verify user permissions before sending
- [ ] Encrypt sensitive notification data
- [ ] Audit notification logs
- [ ] Test security rules
- [ ] Implement abuse detection

## Compliance

- [ ] Review GDPR requirements
- [ ] Implement notification opt-out
- [ ] Document data retention policies
- [ ] Create privacy policy updates
- [ ] Implement user data export
- [ ] Set up data deletion on account removal
