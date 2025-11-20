🌍 GeoHunt
¡Bienvenido a GeoHunt! La plataforma definitiva de exploración y geolocalización. GeoHunt conecta el mundo físico con el virtual, permitiendo a los administradores esconder tesoros digitales y a los exploradores cazarlos usando tecnología GPS de vanguardia.

🚀 Novedades de la Última Versión
Esta versión introduce un sistema robusto de Roles (Admin/Usuario) y Navegación Inteligente:

🗺️ OpenStreetMap Integrado: Mapas libres y detallados sin costos de API.

📍 Ruta Inteligente (Algoritmo Greedy): El sistema detecta tu ubicación y traza automáticamente la ruta óptima para recoger los tesoros más cercanos en un radio de 200 metros.

🛡️ Panel de Administración Completo: Gestión total de tesoros con interfaz visual (CRUD) y autenticación segura.

👥 Roles de Usuario
La aplicación divide la experiencia en dos perfiles clave:

1. 🕵️‍♂️ Explorador (Usuario Normal)
Objetivo: Navegar hasta los puntos de interés.

Interacción: Visualiza el mapa y su posición en tiempo real.

Confirmación: Al llegar al radio del tesoro, debe completar un desafío físico (uso de sensores/acelerómetro) para reclamar la recompensa.

2. 👑 Administrador (Admin)
Acceso Exclusivo: Login diferenciado (opción de Google Sign-In o Correo).

Gestión de Tesoros (CRUD):

Crear: Tocar cualquier punto del mapa para esconder un tesoro.

Editar: Modificar dificultad, descripción o si es de "Tiempo Limitado".

Eliminar: Borrar tesoros obsoletos desde el mapa o la lista.

Herramientas de Ruta: Visualización de rutas de recolección optimizadas para probar la experiencia de juego.

Vistas Flexibles: Alterna entre Vista de Mapa y Lista de Inventario Detallada.

✨ Características Técnicas Destacadas
🧠 Algoritmo de Rutas (Nearest Neighbor)
GeoHunt no solo muestra puntos en un mapa. Implementa una lógica de Ruta Inteligente:

Detecta la ubicación GPS del dispositivo.

Filtra los tesoros en un radio de 200 metros.

Calcula la distancia entre puntos usando latlong2.

Dibuja una línea polilínea (PolylineLayer) conectando los tesoros en el orden más eficiente de distancia, guiando al usuario paso a paso.

📱 Interfaz y Navegación
Drawer Personalizado: Menú lateral para navegación fluida entre Mapa, Inventario y Perfil.

Bottom Navigation Bar: Acceso rápido para activar/desactivar el modo "Trazar Ruta" en el mapa.

Feedback Visual: Marcadores personalizados, chips de dificultad (Fácil/Medio/Difícil) y alertas visuales (Snackbars) para acciones de la base de datos.

🛠️ Stack Tecnológico
El proyecto está construido con Flutter y una arquitectura escalable conectada a la nube.

Frontend & Mapas
Flutter Map (flutter_map): Renderizado de mapas OpenStreetMap.

Geolocator: Rastreo de posición GPS en tiempo real (Stream<Position>).

Latlong2: Cálculos geodésicos y manejo de coordenadas.

Backend (Firebase)
Firebase Authentication:

Login tradicional (Email/Password).

Google Sign-In: Autenticación federada con gestión de huella SHA-1 segura.

Cloud Firestore: Base de datos NoSQL en tiempo real.

Colección users: Almacena perfiles y roles (admin/user).

Colección treasures: Almacena documentos con GeoPoint, timestamps y metadatos del tesoro.

⚙️ Requisitos del Sistema
Android: Versión mínima SDK 21.

Permisos:

ACCESS_FINE_LOCATION (Para la ruta inteligente).

ACCESS_COARSE_LOCATION.

INTERNET.

Hardware: GPS funcional y Acelerómetro (para la confirmación de hallazgo).
