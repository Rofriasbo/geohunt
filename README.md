# 🌍 GeoHunt

> **La plataforma definitiva de exploración y geolocalización.**
> *Conecta el mundo físico con el virtual: esconde tesoros digitales y cázalos usando tecnología GPS de vanguardia y sensores de movimiento.*

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

---

## 🚀 Novedades de la Versión Actual (v2.2)

Esta versión perfecciona la jugabilidad con ayudas visuales y optimización de rendimiento:

* **📸 Pistas Visuales:** Los administradores ahora pueden adjuntar **fotos del lugar real** a los tesoros de dificultad *Fácil* y *Media* para ayudar a los exploradores.
* **⚡ Optimización de Imágenes:** Algoritmo de compresión inteligente que reduce el peso de las fotos (Avatars y Pistas) en un **90%** sin perder calidad visual, ahorrando datos y almacenamiento.
* **👋 Mecánica "Shake to Claim":** Sistema de detección de movimiento para reclamar tesoros al estar en rango (< 5m).
* **🎨 Marcadores Dinámicos:** Feedback visual en el mapa (Rojo/Verde/Gris) según el estado del tesoro.

---

## 👥 Roles y Funcionalidades

La aplicación adapta su interfaz y lógica de juego según el perfil del usuario.

| Característica | 🕵️‍♂️ Explorador (Usuario) | 👑 Administrador (Admin) |
| :--- | :---: | :---: |
| **Login** | Email / Contraseña | **Google Sign-In** / Email |
| **Objetivo** | Cazar y Acumular Puntos | Crear y Gestionar el Mundo |
| **Mapa** | Ver, Navegar y Reclamar | CRUD Completo de Tesoros |
| **Pistas** | **Ver Foto del Lugar** (Si existe) | **Subir Foto** (Cámara/Galería) |
| **Rutas** | Ruta inteligente hacia pendientes | Trazado de rutas de prueba |
| **Perfil** | Edición, Foto y Estadísticas | Edición completa y Gestión |
| **Ranking** | Acceso al **Top 10 Global** | Visualización (sin participar) |

---

## 🧠 Tecnología y Algoritmos

GeoHunt combina sensores de hardware con lógica de nube en tiempo real:

### 1. Sistema de Reclamo (Proximidad + Sensores)
* **Geofencing Local:** Cálculo de distancia geodésica (`latlong2`) en tiempo real.
* **Estado de Alerta:** Al entrar en el radio de **5 metros**, el marcador cambia a verde.
* **Detección de Gesto:** Monitoreo del acelerómetro (`sensors_plus`) para detectar el "Shake" (> 15 m/s²).

### 2. Smart Route (Algoritmo Greedy)
* **Lógica:** Filtra tesoros ya encontrados y traza la ruta óptima entre los restantes (radio 200m) usando el algoritmo del *Vecino Más Cercano*.

### 3. Compresión de Medios
* **Lógica:** Antes de subir a Firebase Storage, las imágenes se redimensionan (máx 1024px para tesoros, 512px para perfiles) y se comprimen (calidad 60-70%), garantizando cargas rápidas.

---

## 🛠️ Stack Tecnológico

Arquitectura escalable basada en **Flutter** y servicios en la nube.

### 📱 Frontend & Plugins

| Paquete | Función Principal |
| :--- | :--- |
| `flutter_map` | Renderizado de mapas OpenStreetMap (Sin costos de API). |
| `geolocator` | Rastreo de posición GPS en tiempo real. |
| `sensors_plus` | Acceso al Acelerómetro para la mecánica de juego. |
| `image_picker` | Selección de fotos (Cámara/Galería) con parámetros de calidad. |
| `permission_handler`| Gestión segura de permisos de Android. |
| ´flutter_local_notifications´ | Manejo de notificaciones locales. |

### 🔥 Backend (Firebase)

| Servicio | Uso en GeoHunt |
| :--- | :--- |
| **Authentication** | Login tradicional y Google Sign-In con validación SHA-1. |
| **Firestore BD** | Base de datos NoSQL. Índices compuestos para Leaderboards. |
| **Storage** | Almacenamiento de imágenes de perfil optimizadas. |
| **Messaging** | Envío de notificaciones push dinámicamente al usuario. |

---

## 🚨 Sistema de notificaciones locales y push
- Cuando un usuario se encuentra a cinco metros de un tesoro sin reclamar, automáticamente le llega una notificación
  indicando que realice el gesto de "agitar" (shake) el celular, para así, obtener su recompensa.
- Al crearse un punto que se encuentra a un rango de un kilómetro del usuario, llegará una notificación para que
  vaya a reclamar dicho punto mientras está disponible.

## ⚙️ Requisitos e Instalación

### Permisos de Android (`AndroidManifest.xml`)
* 🛰️ **Ubicación:** `ACCESS_FINE_LOCATION` (Vital para el juego).
* 📸 **Multimedia:** `READ_MEDIA_IMAGES` / `CAMERA` (Perfiles y Pistas).
* 🌐 **Red:** `INTERNET`.

### Requisitos de Hardware
* Dispositivo Android (SDK Min 21).
* **GPS Funcional** (Alta precisión).
* **Acelerómetro** (Indispensable para reclamar).

---

## 📂 Estructura del Proyecto

```text
lib/
├── models/
│   ├── users.dart        # Modelo de Explorador
│   ├── admin_model.dart  # Modelo de Administrador (Permisos)
│   └── tesoro.dart       # Modelo de Tesoro (GeoPoint, ImageUrl)
├── screens/
│   ├── login.dart        # Inicio de sesión de usuarios
│   ├── admin.dart        # Dashboard: Mapa CRUD, Fotos, Usuarios
│   ├── registro.dart     # Registro de usuarios
│   └── pagina.dart       # Juego: Mapa, Shake, Ranking, Pistas
├── services/
│   ├── database_service.dart   # Lógica de Firestore
│   ├── fcm_service.dart        # Lógica para generar el Firbase Cloud Messaging Token 
│   └── registro_google.dart    # Autenticación federada
└── main.dart                   # Inicialización
