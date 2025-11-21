# 🌍 GeoHunt

> **La plataforma definitiva de exploración y geolocalización.**
> *Conecta el mundo físico con el virtual: esconde tesoros digitales y cázalos usando tecnología GPS de vanguardia.*

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

---

## 🚀 Novedades de la Versión Actual (v2.0)

Esta versión transforma la experiencia con un sistema robusto de gestión y personalización:

* **🖼️ Perfiles Personalizados:** Integración con **Firebase Storage** para subir fotos de perfil desde la **Cámara** o **Galería**.
* **🗺️ OpenStreetMap Integrado:** Mapas libres y detallados renderizados con `flutter_map`.
* **📍 Ruta Inteligente (Smart Routing):** Algoritmo de "Vecino más cercano" que traza la ruta óptima para recoger tesoros en un radio de **200 metros**.
* **🛡️ Panel Admin CRUD:** Gestión visual completa de tesoros y usuarios.

---

## 👥 Roles y Funcionalidades

La aplicación adapta su interfaz según el perfil del usuario.

| Característica | 🕵️‍♂️ Explorador (Usuario) | 👑 Administrador (Admin) |
| :--- | :---: | :---: |
| **Login** | Email / Contraseña | **Google Sign-In** / Email |
| **Objetivo Principal** | Cazar Tesoros | Crear y Gestionar Tesoros |
| **Mapa** | Ver ubicación y tesoros | Ver, Crear, Editar y Borrar (CRUD) |
| **Rutas** | Navegación básica | **Trazado de Rutas de Prueba** |
| **Perfil** | Visualización básica | **Edición completa con Foto** |
| **Sensores** | Uso de Acelerómetro (Shake) | N/A |

---

## 🧠 La Tecnología "Smart Route"

GeoHunt no solo muestra puntos en un mapa. Implementa una lógica de optimización de rutas en tiempo real para el Administrador:

1.  📡 **Detección:** Obtiene la posición GPS precisa (`Geolocator`).
2.  🔍 **Filtrado:** Selecciona solo los tesoros dentro de un radio de **200 metros**.
3.  📐 **Cálculo Geodésico:** Utiliza la librería `latlong2` para calcular distancias exactas.
4.  🔗 **Algoritmo Greedy:** Conecta los puntos usando la lógica del *Vecino Más Cercano*, dibujando una `Polyline` azul en el mapa para guiar la recolección.

---

## 🛠️ Stack Tecnológico

Arquitectura escalable basada en **Flutter** y servicios en la nube.

### 📱 Frontend & Plugins

| Paquete | Función Principal |
| :--- | :--- |
| `flutter_map` | Renderizado de mapas OpenStreetMap (Sin costos de API). |
| `geolocator` | Rastreo de posición GPS en tiempo real (`Stream<Position>`). |
| `latlong2` | Cálculos matemáticos de coordenadas y distancias. |
| `image_picker` | Acceso nativo a la **Cámara** y **Galería**. |
| `permission_handler`| Gestión segura de permisos de Android (GPS, Almacenamiento). |

### 🔥 Backend (Firebase)

| Servicio | Uso en GeoHunt |
| :--- | :--- |
| **Authentication** | Login tradicional y **Google Sign-In** con validación SHA-1. |
| **Firestore BD** | Base de datos NoSQL. Colecciones: `users` (Roles) y `treasures` (GeoPoints). |
| **Storage** | Almacenamiento de imágenes de perfil optimizadas (Compresión JPG). |

---

## ⚙️ Requisitos e Instalación

### Permisos de Android (`AndroidManifest.xml`)
Para que la aplicación funcione al 100%, requiere los siguientes permisos:

* 🛰️ **Ubicación:**
    * `android.permission.ACCESS_FINE_LOCATION` (Ruta precisa).
    * `android.permission.ACCESS_COARSE_LOCATION`.
* 📸 **Multimedia:**
    * `android.permission.READ_EXTERNAL_STORAGE` (Galería Android <13).
    * `android.permission.READ_MEDIA_IMAGES` (Galería Android 13+).
    * `android.permission.CAMERA`.
* 🌐 **Red:**
    * `android.permission.INTERNET`.

### Requisitos de Hardware
* Dispositivo Android (SDK Min 21).
* GPS Funcional.
* Cámara (Opcional para perfil).

---

## 📂 Estructura del Proyecto (Clave)

```text
lib/
├── models/
│   ├── users.dart        # Modelo para Explorador
│   ├── admin_model.dart  # Modelo detallado para Admin
│   └── tesoro.dart       # Modelo de Tesoro con GeoPoint
├── screens/
│   ├── login.dart        # Autenticación y Router de Roles
│   ├── admin.dart        # Dashboard, Mapa Admin, Perfil
│   └── pagina.dart       # Pantalla Usuario Normal
├── services/
│   ├── base.dart         # Lógica de Firestore
│   └── registro_google.dart # Botón de Google con lógica de Admin
└── main.dart             # Inicialización
