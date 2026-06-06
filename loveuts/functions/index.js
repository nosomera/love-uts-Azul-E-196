const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

exports.enviarPushNotificacion = onDocumentCreated(
  'notificaciones/{notificacionId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notificacion = snap.data();
    const uidDestino = notificacion.uidDestino;
    if (!uidDestino) return;

    const tokensSnap = await admin
      .firestore()
      .collection('usuarios')
      .doc(uidDestino)
      .collection('fcmTokens')
      .get();

    const tokenDocs = tokensSnap.docs.filter((doc) => doc.get('token'));
    const tokens = tokenDocs.map((doc) => doc.get('token'));
    if (tokens.length === 0) {
      await snap.ref.update({
        push: {
          enviado: false,
          motivo: 'sin_tokens',
          actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      logger.info('No hay tokens FCM para el usuario', { uidDestino });
      return;
    }

    const data = {
      notificacionId: snap.id,
      tipo: String(notificacion.tipo || ''),
      matchId: String(notificacion.matchId || ''),
      mensajeId: String(notificacion.mensajeId || ''),
      uidOrigen: String(notificacion.uidOrigen || ''),
      asunto: String(notificacion.asunto || ''),
      preview: String(notificacion.preview || ''),
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: notificacion.asunto || 'LoveUTS',
        body: notificacion.preview || notificacion.contenido || 'Nueva notificación',
      },
      data,
      android: {
        priority: 'high',
        notification: {
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    });

    const eliminaciones = [];
    response.responses.forEach((result, index) => {
      const code = result.error && result.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        eliminaciones.push(tokenDocs[index].ref.delete());
      } else if (code) {
        logger.warn('No se pudo enviar FCM', { uidDestino, code });
      }
    });

    if (eliminaciones.length > 0) await Promise.all(eliminaciones);

    await snap.ref.update({
      push: {
        enviado: response.successCount > 0,
        successCount: response.successCount,
        failureCount: response.failureCount,
        enviadoEn: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    if (response.successCount > 0) await marcarMensajeRecibido(notificacion);

    logger.info('Push FCM procesado', {
      uidDestino,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);

async function marcarMensajeRecibido(notificacion) {
  if (notificacion.tipo !== 'mensaje') return;
  if (!notificacion.matchId || !notificacion.mensajeId) return;

  const mensajeRef = admin
    .firestore()
    .collection('matches')
    .doc(notificacion.matchId)
    .collection('mensajes')
    .doc(notificacion.mensajeId);

  await admin.firestore().runTransaction(async (transaction) => {
    const mensajeSnap = await transaction.get(mensajeRef);
    if (!mensajeSnap.exists) return;
    if (mensajeSnap.get('estado') !== 'enviado') return;
    transaction.update(mensajeRef, { estado: 'recibido' });
  });
}
