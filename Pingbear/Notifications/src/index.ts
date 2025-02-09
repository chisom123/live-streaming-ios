import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
admin.initializeApp();

export const onNotificationCreated = onDocumentCreated('notifications/{notificationId}', async (event) => {
    const notification = event.data?.data();
    if (!notification) return;

    const { type, competitionId, entryId, stars } = notification;

    try {
        // Get competition details
        const competitionDoc = await admin.firestore()
            .collection('competitions')
            .doc(competitionId)
            .get();
        
        if (!competitionDoc.exists) {
            console.log('Competition not found');
            return;
        }
        const competition = competitionDoc.data();

        // Get entry details
        const entryDoc = await admin.firestore()
            .collection('competitions')
            .doc(competitionId)
            .collection('entries')
            .doc(entryId)
            .get();
        
        if (!entryDoc.exists) {
            console.log('Entry not found');
            return;
        }
        const entry = entryDoc.data();

        // Prepare base notification message
        let message = {
            notification: {
                title: '',
                body: ''
            },
            data: {
                competitionId,
                entryId,
                type
            }
        };

        switch (type) {
            case 'new_entry':
                message.notification = {
                    title: `${competition?.description}`,
                    body: `New photo to rate!`
                };
                
                // Send to all competition members
                await admin.messaging().send({
                    ...message,
                    topic: `competition_${competitionId}`
                });
                break;

            case 'new_vote':
                // Check if it's a 5-star vote
                if (stars !== undefined && stars >= 5) {
                    // Broadcast message for 5-star vote
                    const broadcastMessage = {
                        ...message,
                        notification: {
                            title: `5-Star Entry in ${competition?.description}`,
                            body: `An outstanding entry just received a 5-star rating! 🌟 Check it out!`
                        }
                    };

                    // Send to all competition members
                    await admin.messaging().send({
                        ...broadcastMessage,
                        topic: `competition_${competitionId}`
                    });

                    // Personalized notification for entry owner
                    if (entry?.userId) {
                        const userDoc = await admin.firestore()
                            .collection('users')
                            .doc(entry.userId)
                            .get();
                        
                        const userData = userDoc.data();
                        if (userData?.fcmToken) {
                            await admin.messaging().send({
                                ...broadcastMessage,
                                notification: {
                                    title: 'Congratulations! 🎉',
                                    body: 'Your entry just received a 5-star rating!'
                                },
                                token: userData.fcmToken
                            });
                        }
                    }
                } else {
                    // For regular votes, send to entry owner
                    message.notification = {
                        title: `New Vote in ${competition?.description}`,
                        body: `Rate!`
                    };

                    if (entry?.userId) {
                        const userDoc = await admin.firestore()
                            .collection('users')
                            .doc(entry.userId)
                            .get();
                        
                        const userData = userDoc.data();
                        if (userData?.fcmToken) {
                            await admin.messaging().send({
                                ...message,
                                token: userData.fcmToken
                            });
                        }
                    }
                }
                break;

            default:
                console.log('Unknown notification type');
                return;
        }

        return;
    } catch (error) {
        console.error('Error sending notification:', error);
        return;
    }
});