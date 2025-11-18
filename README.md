# 🌍 GeoHunt

¡Bienvenido a **GeoHunt**! El juego de exploración móvil que te convierte en un cazador de tesoros moderno. Usa tu GPS y el mapa para encontrar puntos de interés virtuales creades por la comunidad.

---

## 🎯 Objetivo del Juego

El objetivo principal de GeoHunt es **navegar hasta un punto de interés virtual** usando la geolocalización de tu dispositivo. Una vez que te encuentres en el radio de búsqueda del tesoro, deberás **completar un desafío físico** usando un sensor de tu dispositivo para confirmar el hallazgo, ganar puntos y ascender en las clasificaciones.

---

## ✨ Características Principales

* **Búsqueda Interactiva:** Visualiza tesoros virtuales en un **mapa interactivo** y sigue tu ubicación en tiempo real para la navegación.
* **Desafío de Confirmación:** Usa el **acelerómetro o giroscopio** del dispositivo para realizar un gesto específico (ej. **agitar el teléfono**) y confirmar que has llegado y encontrado el tesoro dentro de la zona objetivo.
* **Comunidad y Creación:** Los tesoros son creados y gestionados por la propia comunidad de jugadores.
* **Notificaciones de Oportunidad:** Recibe **notificaciones** cuando te encuentres cerca de un punto de interés. Algunos tesoros son de **tiempo limitado** y ofrecen una mayor puntuación al primer jugador que los reclame.

---

## 🛠️ Elementos Tecnológicos Empleados

Este proyecto se construye sobre una base tecnológica robusta para asegurar una experiencia de juego fluida y escalable.

### Backend y Almacenamiento

* **Firebase Authentication:** Gestiona el **registro**, **inicio de sesión** y los **perfiles de usuario** de forma segura.
* **Firebase BD (Firestore):** Se utiliza para el almacenamiento de datos clave del juego:
    * **Tesoros:** Coordenadas geográficas, descripción y nivel de dificultad.
    * **Historial de descubrimientos:** Seguimiento de los hallazgos de cada usuario.

### Funcionalidades del Dispositivo

* **Mapas y GPS:** Esencial para la **visualización** de los tesoros en el mapa y el **seguimiento de la ubicación** del usuario para la navegación.
* **Sensor (Acelerómetro/Giroscopio):** Utilizado para la **detección del gesto** requerido (ej. **Shake**) que confirma el hallazgo en la ubicación objetivo.

---

## ⚙️ Requisitos del Dispositivo

* Dispositivo móvil con soporte de **GPS**.
* Dispositivo móvil con **acelerómetro o giroscopio** funcional.
* Conexión a internet para acceder a los mapas y a la base de datos de Firebase.

---

## 🗺️ ¡Empieza tu Aventura!

¡Prepárate para explorar el mundo a tu alrededor y descubrir los tesoros que la comunidad ha escondido!
