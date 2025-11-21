# 🌍 GeoHunt

> **La plataforma definitiva de exploración y geolocalización.**
> *Conecta el mundo físico con el virtual: esconde tesoros digitales y cázalos usando tecnología GPS de vanguardia y sensores de movimiento.*

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

---

## 🚀 Novedades de la Versión Actual (v2.1)

Esta versión eleva la experiencia de juego con mecánicas interactivas y retroalimentación visual en tiempo real:

* **👋 Mecánica "Shake to Claim":** Utiliza el acelerómetro del dispositivo. Cuando estás cerca de un tesoro (< 5m), ¡agita el teléfono para reclamarlo!
* **🎨 Marcadores Dinámicos:** Los pines del mapa cambian de color según su estado:
    * 🔴 **Rojo:** Tesoro disponible (lejos).
    * 🟢 **Verde:** En rango (¡Agita ahora!).
    * 🔘 **Gris:** Tesoro ya encontrado (Bloqueado).
* **🖼️ Perfiles Completos:** Gestión de avatar con cámara/galería tanto para Admins como para Usuarios.
* **📍 Ruta Inteligente Filtrada:** El algoritmo de ruta ahora ignora automáticamente los tesoros que ya has encontrado.

---

## 👥 Roles y Funcionalidades

La aplicación adapta su interfaz y lógica de juego según el perfil del usuario.

| Característica | 🕵️‍♂️ Explorador (Usuario) | 👑 Administrador (Admin) |
| :--- | :---: | :---: |
| **Login** | Email / Contraseña | **Google Sign-In** / Email |
| **Objetivo Principal** | Cazar y Acumular Puntos | Crear y Gestionar el Mundo |
| **Mapa** | Ver, Navegar y **Reclamar (Shake)** | Ver, Crear, Editar y Borrar (CRUD) |
| **Rutas** | Ruta inteligente hacia tesoros pendientes | Trazado de rutas de prueba |
| **Perfil** | Edición, Foto y Estadísticas | Edición completa y Gestión |
| **Ranking** | Acceso al **Top 10 Global** | Visualización (sin participar) |

---

## 🧠 Tecnología y Algoritmos

GeoHunt combina sensores de hardware con lógica de nube en tiempo real:

### 1. Sistema de Reclamo (Proximidad + Sensores)
* **Geofencing Local:** La app calcula la distancia (`latlong2`) en cada actualización del GPS.
* **Estado de Alerta:** Si la distancia es `< 5 metros`, el marcador se vuelve verde y se activa el listener del acelerómetro (`sensors_plus`).
* **Detección de Gesto:** Se monitorea la fuerza G. Si se detecta una aceleración brusca (> 15 m/s²), se dispara el evento de captura.

### 2. Smart Route (Algoritmo Greedy)
El trazado de ruta se recalcula dinámicamente:
1.  Filtra los tesoros `foundTreasures` del usuario.
2.  Selecciona los restantes en un radio de **200 metros**.
3.  Conecta los puntos usando la lógica del *Vecino Más Cercano* para optimizar la caminata.

---

## 🛠️ Stack Tecnológico

Arquitectura escalable basada en **Flutter** y servicios en la nube.

### 📱 Frontend & Plugins

| Paquete | Función Principal |
| :--- | :--- |
| `flutter_map` | Renderizado de mapas OpenStreetMap (Sin costos de API). |
| `geolocator` | Rastreo de posición GPS en tiempo real. |
| `sensors_plus` | **Acceso al Acelerómetro** para la mecánica de Shake. |
| `image_picker` | Acceso nativo a la Cámara y Galería. |
| `permission_handler`| Gestión segura de permisos de Android. |

### 🔥 Backend (Firebase)

| Servicio | Uso en GeoHunt |
| :--- | :--- |
| **Authentication** | Login tradicional y Google Sign-In con validación SHA-1. |
| **Firestore BD** | Base de datos NoSQL. Índices compuestos para Leaderboards. |
| **Storage** | Almacenamiento de imágenes de perfil optimizadas. |

---

## ⚙️ Requisitos e Instalación

### Permisos de Android (`AndroidManifest.xml`)
Para que la experiencia de juego sea completa, se requieren los siguientes permisos:

* 🛰️ **Ubicación:** `ACCESS_FINE_LOCATION` (Vital para detectar los 5 metros).
* 📸 **Multimedia:** `READ_MEDIA_IMAGES` / `CAMERA` (Para el perfil).
* 🌐 **Red:** `INTERNET`.

### Requisitos de Hardware
* Dispositivo Android (SDK Min 21).
* **GPS Funcional** (Alta precisión).
* **Acelerómetro** (Indispensable para reclamar tesoros).

---

## 📂 Estructura del Proyecto

```text
lib/
├── models/
│   ├── users.dart        # Modelo de Explorador (con Score e Historial)
│   ├── admin_model.dart  # Modelo de Administrador
│   └── tesoro.dart       # Modelo de Tesoro (GeoPoint, Dificultad)
├── screens/
│   ├── login.dart        # Router de Roles
│   ├── admin.dart        # Dashboard Admin (CRUD + Mapa)
│   └── pagina.dart       # Interfaz de Juego (Mapa + Shake + Ranking)
├── services/
│   ├── base.dart         # Lógica de Firestore
│   └── registro_google.dart # Autenticación federada
└── main.dart             # Inicialización
