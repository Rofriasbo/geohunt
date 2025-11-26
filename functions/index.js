const functions = require("firebase-functions");
const admin = require("firebase-admin");
const geolib = require("geolib");

admin.initializeApp();

const db = admin.firestore();

exports.notifyNearbyUsersOnTreasureCreation = functions.firestore
  .document("treasures/{treasureId}")
  .onCreate(async (snap, context) => {
    const treasure = snap.data();

    if (!treasure) {
      console.log("❌ No hay datos del tesoro");
      return;
    }

    // --- 1. UBICACIÓN ---
    const tLoc = treasure.location;
    const tLat = tLoc?.latitude ?? tLoc?._latitude ?? (typeof tLoc?.latitude === 'function' ? tLoc.latitude() : null);
    const tLng = tLoc?.longitude ?? tLoc?._longitude ?? (typeof tLoc?.longitude === 'function' ? tLoc.longitude() : null);

    if (typeof tLat !== "number" || typeof tLng !== "number") return;

    // --- 2. PREPARAR DATOS COMUNES ---
    const usersSnapshot = await db.collection("users").get();
    const notifications = [];
    const RADIO_BUSQUEDA = 500; // Radio amplio

    // --- 3. LOGICA DE DISTINCIÓN (NUEVO) ---
    const isLimited = treasure.isLimitedTime === true;
    let notifTitle = "Nuevo tesoro cercano";
    let notifBody = "¡Hay un tesoro cerca de ti! Ve a buscarlo.";
    let expirationMillis = "";

    if (isLimited) {
        notifTitle = "⏳ ¡CORRE! Tesoro temporal";
      
        const limitDate = treasure.limitedUntil.toDate 
                          ? treasure.limitedUntil.toDate() 
                          : new Date(treasure.limitedUntil);
        
        // 2. Calcular cuántos minutos faltan desde "ahora"
        const now = new Date();
        const diffMs = limitDate.getTime() - now.getTime();
        // Convertimos milisegundos a minutos (y redondeamos hacia arriba)
        const minutesLeft = Math.ceil(diffMs / (1000 * 60));

        // 3. Crear el mensaje
        if (minutesLeft > 0) {
             notifBody = `¡Desaparecerá pronto! Tienes ${minutesLeft} minutos para encontrarlo.`;
        } else {
             notifBody = "¡Corre! Está a punto de desaparecer. Te queda 1 minuto.";
        }
        // Convertimos el Timestamp de Firestore a milisegundos (String)
        if (treasure.limitedUntil) {
            // Manejo robusto de Timestamp
            const dateObj = treasure.limitedUntil.toDate ? treasure.limitedUntil.toDate() : new Date(treasure.limitedUntil);
            expirationMillis = dateObj.getTime().toString();
        }
    }

    console.log(`Procesando tesoro. Es limitado: ${isLimited}`);

    // --- 4. FILTRADO DE USUARIOS ---
    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data();
      if (!user.fcmToken) continue;

      const uLoc = user.lastKnownLocation ?? user.location;
      if (!uLoc) continue;

      let uLat = uLoc.latitude ?? uLoc._latitude;
      let uLng = uLoc.longitude ?? uLoc._longitude;
      
      if (typeof uLoc.latitude === "function") { uLat = uLoc.latitude(); uLng = uLoc.longitude(); }
      if (typeof uLat !== "number" || typeof uLng !== "number") continue;

      const distance = geolib.getDistance(
        { latitude: tLat, longitude: tLng },
        { latitude: uLat, longitude: uLng }
      );

      if (distance <= RADIO_BUSQUEDA) {
          
          // Personalizamos el body con la distancia exacta
          const finalBody = isLimited 
              ? `¡A ${Math.round(distance)}m! ${notifBody}`
              : `¡Tienes un tesoro a ${Math.round(distance)}m de ti!`;

          // Construimos el objeto DATA
          const dataPayload = {
              treasureId: context.params.treasureId,
              distance: distance.toString(),
              type: isLimited ? "true" : "false", // Para que el frontend sepa qué es
              click_action: "FLUTTER_NOTIFICATION_CLICK"
          };

          // Si es limitado, agregamos la fecha de expiración al payload oculto
          if (isLimited && expirationMillis) {
              dataPayload.limitedUntil = expirationMillis;
          }

          notifications.push({
            token: user.fcmToken,
            notification: {
              title: notifTitle,
              body: finalBody,
            },
            android: {
              notification: {
                channelId: "treasure_alerts",
                priority: "high",
                sound: "default",
                // tag: Agrupa notificaciones para no llenar la barra
                tag: isLimited ? "limited_treasure" : "normal_treasure" 
              }
            },
            data: dataPayload // <--- AQUÍ VAN LOS DATOS QUE USAREMOS EN FLUTTER
          });
      }
    }

    if (notifications.length === 0) return null;

    try {
        const batchResponse = await admin.messaging().sendEach(notifications);
        console.log(`✅ Enviadas: ${batchResponse.successCount}`);
        return batchResponse;
    } catch (e) {
        console.error("🔥 Error:", e);
        return null;
    }
  });


exports.checkTreasureLifecycle = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    
    const now = admin.firestore.Timestamp.now();
    
    // --- 1. BORRAR EXPIRADOS (Tu lógica original) ---
    const expiredSnapshot = await db.collection("treasures")
      .where("isLimitedTime", "==", true)
      .where("limitedUntil", "<=", now)
      .get();

    if (!expiredSnapshot.empty) {
      const batch = db.batch();
      expiredSnapshot.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`🧹 Se eliminaron ${expiredSnapshot.size} tesoros expirados.`);
    }

    // --- 2. AVISAR DE VENCIMIENTO ---
    const nowMillis = Date.now();
    const oneMinFuture = new Date(nowMillis + 60 * 1000); 
    const twoMinFuture = new Date(nowMillis + 120 * 1000); // Ventana de 1 a 2 minutos
    
    const tsStart = admin.firestore.Timestamp.fromDate(oneMinFuture);
    const tsEnd = admin.firestore.Timestamp.fromDate(twoMinFuture);

    const warningSnapshot = await db.collection("treasures")
      .where("isLimitedTime", "==", true)
      .where("notificationSent", "==", false) 
      .where("limitedUntil", ">=", tsStart)
      .where("limitedUntil", "<=", tsEnd)
      .get();

    if (!warningSnapshot.empty) {
        const batch = db.batch();
        const messagesToSend = [];

        console.log(`⚠️ Procesando ${warningSnapshot.size} tesoros por vencer...`);

        // Recorremos los tesoros que van a vencer
        for (const doc of warningSnapshot.docs) {
            const treasure = doc.data();
            
            // A. Marcar como notificado en la BD para no repetir
            batch.update(doc.ref, { notificationSent: true });

            // B. Buscar al dueño para avisarle
            if (treasure.createdBy) {
                try {
                    const userDoc = await db.collection("users").doc(treasure.createdBy).get();
                    
                    if (userDoc.exists) {
                        const userData = userDoc.data();

                        if (userData && userData.fcmToken) {
                            messagesToSend.push({
                                token: userData.fcmToken,
                                notification: {
                                    title: "⏳ ¡Tic Tac!",
                                    body: "Uno de tus tesoros expira en menos de 2 minutos.",
                                },
                                // IMPORTANTE: Configuración de canal para Android
                                android: {
                                  notification: {
                                    channelId: "treasure_alerts", 
                                    priority: "high",
                                    sound: "default"
                                  }
                                },
                                data: {
                                    treasureId: doc.id,
                                    type: "EXPIRATION_WARNING"
                                }
                            });
                        } else {
                            console.log(`El usuario ${treasure.createdBy} no tiene fcmToken.`);
                        }
                    }
                } catch (err) {
                    console.error(`Error obteniendo usuario dueño del tesoro ${doc.id}:`, err);
                }
            }
        }

        // C. Ejecutar actualización en BD (marcar como notificados)
        await batch.commit();

        // D. Enviar notificaciones masivas
        if (messagesToSend.length > 0) {
            console.log(`🚀 Enviando ${messagesToSend.length} avisos de expiración.`);
            
            try {
                const response = await admin.messaging().sendEach(messagesToSend);
                
                // Diagnóstico de errores
                if (response.failureCount > 0) {
                     console.log(`⚠️ Hubo ${response.failureCount} fallos de envío.`);
                     response.responses.forEach((r, i) => {
                         if(!r.success) console.error(`Error enviando a ${messagesToSend[i].token}:`, r.error);
                     });
                } else {
                    console.log(`✅ Avisos enviados con éxito: ${response.successCount}`);
                }
            } catch (e) {
                console.error("Error en envío masivo:", e);
            }
        } else {
            console.log("⚠️ Tesoros procesados, pero no se encontraron tokens de usuario para notificar.");
        }
    }

    return null;
  });