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
      console.log("No hay datos del tesoro");
      return;
    }

      // --- EXTRAER GEOPOINT ---
    const loc = treasure.location;

    const treasureLat = loc.latitude ?? loc._latitude;
    const treasureLng = loc.longitude ?? loc._longitude;

    if (typeof treasureLat !== "number" || typeof treasureLng !== "number") {
      console.log("Tesoro sin coordenadas válidas. Abortando.");
      return;
    }

      console.log("Tesoro creado en:", treasureLat, treasureLng);
    // Obtener usuarios
    const usersSnapshot = await db.collection("users").get();

    const notifications = [];

    console.log("TOTAL USERS:", usersSnapshot.size);
    usersSnapshot.forEach((userDoc) => {
      const user = userDoc.data();

    console.log("---- USER ----");
    console.log("ID:", userDoc.id);
    console.log("RAW DATA:", user);

        const loc = user.lastKnownLocation ?? user.location;

         if (!loc) {
    console.log(`⛔ Usuario ${userDoc.id} sin ubicación`);
    console.log("USER DATA:", JSON.stringify(user, null, 2));

    return; // ✅ SALIMOS ANTES DE USAR loc
  }

  console.log("LOCATION TYPE:", loc.constructor?.name);

  let userLat, userLng;

  // ✅ Firestore GeoPoint en Admin SDK
  if (typeof loc.latitude === "function") {
    userLat = loc.latitude();
    userLng = loc.longitude();
  }
  // ✅ GeoPoint llegado desde cliente (._latitude)
  else {
    userLat = loc.latitude ?? loc._latitude;
    userLng = loc.longitude ?? loc._longitude;
  }

  if (typeof userLat !== "number" || typeof userLng !== "number") {
    console.log(`⛔ Usuario ${userDoc.id} con coordenadas inválidas`, loc);
    return;
  }

  const distance = geolib.getDistance(
    { latitude: treasureLat, longitude: treasureLng },
    { latitude: userLat, longitude: userLng }
  );

  console.log(`✅ Distancia con ${userDoc.id}: ${distance}m`);
  

        if (distance <= 100 && user.fcmToken) {
          notifications.push({
            token: user.fcmToken,
            notification: {
              title: "Nuevo tesoro cercano",
              body: `¡Tienes un tesoro a ${Math.round(distance)}m de ti! ¡Ve por el!`,
            },
            data: {
              treasureId: context.params.treasureId,
              distance: distance.toString(),
            },
          });
        }
      });

    if (notifications.length === 0) {
      console.log("No hay usuarios cercanos para notificar.");
      return;
    }

    console.log(`Enviando ${notifications.length} notificaciones...`);

    const batchResponse = await admin.messaging().sendEach(notifications);
    console.log("Resultados del envío:", batchResponse);
    return batchResponse;
  });
  
