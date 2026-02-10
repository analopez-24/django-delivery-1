# User Stories — Conduit (Django DRF)

User Stories recuperadas mediante ingeniería inversa del código fuente. Cada historia está trazada a los archivos y módulos específicos que la implementan.

---

## Épica 1: Autenticación y Gestión de Usuarios

### US-01: Registro de usuario

> **Como** visitante, **quiero** registrarme con email, username y password **para** crear una cuenta y obtener un token JWT.

**Context / Domain:**
Identity & Access Management (Core)

**Criterios de aceptación (inferidos del código):**
- El password debe tener entre 8 y 128 caracteres (`serializers.py:16-17`).
- El email debe ser único (`models.py:73`).
- El username debe ser único (`models.py:66`).
- Al crearse el User, se crea automáticamente un Profile asociado (`signals.py`).
- La respuesta incluye el token JWT.

**Archivos:**
- `conduit/apps/authentication/views.py` → `RegistrationAPIView.post()`
- `conduit/apps/authentication/serializers.py` → `RegistrationSerializer`
- `conduit/apps/authentication/models.py` → `UserManager.create_user()`
- `conduit/apps/authentication/signals.py` → `create_related_profile()`

**Endpoint:** `POST /api/users`  
**Permisos:** `AllowAny`

---

### US-02: Inicio de sesión

> **Como** usuario registrado, **quiero** iniciar sesión con email y password **para** obtener un token JWT.

**Context / Domain:**
Identity & Access Management (Core)

**Criterios de aceptación:**
- Valida que email y password no estén vacíos y presentes.
- Usa `django.contrib.auth.authenticate()` para verificar credenciales.
- Verifica que el usuario esté activo (`is_active`).
- Una autenticación exitosa retorna: email, username y token.

**Archivos:**
- `conduit/apps/authentication/views.py` → `LoginAPIView.post()`
- `conduit/apps/authentication/serializers.py` → `LoginSerializer.validate()`

**Endpoint:** `POST /api/users/login`  
**Permisos:** `AllowAny`

---

### US-03: Ver perfil propio

> **Como** usuario autenticado, **quiero** ver mi información actual (email, username, bio, imagen de perfil) **para** verificar mis datos.

**Context / Domain:**
Identity & Access Management (Core)

**Criterios de aceptación:**
- Returna email, username, bio, e imagen de perfil para un usuario autenticado. 
- Rechaza solicitudes no autenticadas. 

**Archivos:**
- `conduit/apps/authentication/views.py` → `UserRetrieveUpdateAPIView.retrieve()`
- `conduit/apps/authentication/serializers.py` → `UserSerializer`

**Endpoint:** `GET /api/user`  
**Permisos:** `IsAuthenticated`

---

### US-04: Actualizar perfil propio

> **Como** usuario autenticado, **quiero** actualizar mi username, email, password, bio e imagen **para** mantener mi perfil al día.

**Context / Domain:**
Identity & Access Management (Core)

**Criterios de aceptación:**
- El password se hashea con `set_password()` (no se guarda en texto plano).
- Los campos de Profile (bio, image) se actualizan por separado.
- Soporta actualizaciones parciales (`partial=True`).

**Archivos:**
- `conduit/apps/authentication/views.py` → `UserRetrieveUpdateAPIView.update()`
- `conduit/apps/authentication/serializers.py` → `UserSerializer.update()`

**Endpoint:** `PUT /api/user`  
**Permisos:** `IsAuthenticated`

---

### US-05: Autenticación JWT

> **Como** sistema, **quiero** autenticar cada request mediante un token JWT en el header `Authorization: Token <jwt>` **para** proteger los endpoints.

**Context / Domain:**
Identity & Access Management (Core / Infrastructure)

**Criterios de aceptación:**
- El token se decodifica con `jwt.decode()` usando `SECRET_KEY`.
- El request se rechaza si:
   - Si el token es inválido o el usuario no existe.
   - Si el usuario está desactivado.
- Si no hay header de auth, se permite continuar sin autenticar (para endpoints públicos.

**Archivos:**
- `conduit/apps/authentication/backends.py` → `JWTAuthentication.authenticate()` y `_authenticate_credentials()`
- `conduit/settings.py` → `REST_FRAMEWORK.DEFAULT_AUTHENTICATION_CLASSES`

**Endpoint:** Todos los endpoints (middleware global)  
**Permisos:** N/A (infraestructura)

---

## Épica 2: Gestión de Artículos

### US-06: Crear artículo

> **Como** usuario autenticado, **quiero** crear un artículo con título, descripción, cuerpo y tags **para** publicar contenido.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Se genera un slug único automáticamente a partir del título (`signals.py`).
- El slug se limita a 255 caracteres.
- Los tags se crean si no existen (`TagRelatedField.to_internal_value()`).
- El autor se asigna desde `request.user.profile`.

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticleViewSet.create()`
- `conduit/apps/articles/serializers.py` → `ArticleSerializer.create()`
- `conduit/apps/articles/signals.py` → `add_slug_to_article_if_not_exists()`
- `conduit/apps/articles/relations.py` → `TagRelatedField`
- `conduit/apps/core/utils.py` → `generate_random_string()`

**Endpoint:** `POST /api/articles`  
**Permisos:** `IsAuthenticatedOrReadOnly`

---

### US-07: Listar artículos con filtros

> **Como** visitante, **quiero** listar artículos filtrando por autor, tag o favoritos **para** encontrar contenido relevante.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Filtro por autor: `?author=username` filtra por `author__user__username`.
- Filtro por tag: `?tag=tagname` filtra por `tags__tag`.
- Filtro por favoritos: `?favorited=username` filtra por `favorited_by__user__username`.
- Los resultados están paginados (LimitOffset, 20 por página).
- Orden: más reciente primero (`-created_at, -updated_at`).

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticleViewSet.list()` y `get_queryset()`
- `conduit/apps/articles/serializers.py` → `ArticleSerializer`

**Endpoint:** `GET /api/articles?author=X&tag=Y&favorited=Z`  
**Permisos:** `AllowAny` (lectura)

---

### US-08: Ver detalle de artículo

> **Como** visitante, **quiero** ver el detalle completo de un artículo por su slug **para** leer su contenido.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Devuelve un unico articulo utilizando el slug como identificador. 
- Devuelve el contenido completo de un articulo incluyendo el autor y las tags. 
- Devuele un error si el articulo no existe. 

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticleViewSet.retrieve()`

**Endpoint:** `GET /api/articles/{slug}`  
**Permisos:** `AllowAny`

---

### US-09: Actualizar artículo

> **Como** autor, **quiero** actualizar mi artículo (título, descripción, cuerpo) **para** corregir o mejorar el contenido.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Solo se actualizan los campos enviados (`partial=True`).
- Se busca el artículo por slug.

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticleViewSet.update()`

**Endpoint:** `PUT /api/articles/{slug}`  
**Permisos:** `IsAuthenticatedOrReadOnly`

---

### US-10: Listar tags

> **Como** visitante, **quiero** ver la lista de todos los tags disponibles **para** explorar contenido por categoría.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- No tiene paginación (`pagination_class = None`).
- Retorna un array de strings (nombres de tags).

**Archivos:**
- `conduit/apps/articles/views.py` → `TagListAPIView.list()`
- `conduit/apps/articles/serializers.py` → `TagSerializer`

**Endpoint:** `GET /api/tags`  
**Permisos:** `AllowAny`

---

### US-11: Generación automática de slug

> **Como** sistema, **quiero** generar automáticamente un slug único para cada artículo nuevo **para** tener URLs legibles.

**Context / Domain:**
Article & Comment Management (Infrastructure Concern)

**Criterios de aceptación:**
- El slug se genera a partir del título con `slugify()`.
- Se agrega un string aleatorio de 6 caracteres para unicidad.
- El slug total no excede 255 caracteres.
- Si el slug es muy largo, se recorta inteligentemente por guiones.

**Archivos:**
- `conduit/apps/articles/signals.py` → `add_slug_to_article_if_not_exists()` (signal `pre_save`)
- `conduit/apps/core/utils.py` → `generate_random_string()`

**Endpoint:** N/A (lógica interna)

---

## Épica 3: Interacciones Sociales

### US-12: Seguir a un usuario

> **Como** usuario autenticado, **quiero** seguir a otro usuario **para** ver su contenido en mi feed.

**Context / Domain:**
Profile Management (Supporting)

**Criterios de aceptación:**
- No se puede seguir a uno mismo (`follower.pk is followee.pk` → ValidationError).
- La relación es unidireccional (`symmetrical=False`).
- No se permite duplicar el seguimiento.

**Archivos:**
- `conduit/apps/profiles/views.py` → `ProfileFollowAPIView.post()`
- `conduit/apps/profiles/models.py` → `Profile.follow()`

**Endpoint:** `POST /api/profiles/{username}/follow`  
**Permisos:** `IsAuthenticated`

---

### US-13: Dejar de seguir a un usuario

> **Como** usuario autenticado, **quiero** dejar de seguir a un usuario **para** que su contenido no aparezca en mi feed.

**Context / Domain:** 
Profile Management (Supporting)

**Criterios de aceptación:**
- Remueve la relación de seguimiento si existe. 
- La operación es idempotente (dejar de seguir a un usuario que no es seguido no devuelve error).

**Archivos:**
- `conduit/apps/profiles/views.py` → `ProfileFollowAPIView.delete()`
- `conduit/apps/profiles/models.py` → `Profile.unfollow()`

**Endpoint:** `DELETE /api/profiles/{username}/follow`  
**Permisos:** `IsAuthenticated`

---

### US-14: Ver perfil público

> **Como** visitante, **quiero** ver el perfil público de un usuario (username, bio, imagen, si lo sigo) **para** conocer al autor.

**Context / Domain:**
Profile Management (Supporting)

**Criterios de aceptación:**
- Retorna el username, bio y la imagen del perfil. 
- Si no tiene imagen, retorna una imagen por defecto (`smiley-cyrus.jpg`).
- El campo `following` indica si el usuario autenticado sigue al perfil consultado.

**Archivos:**
- `conduit/apps/profiles/views.py` → `ProfileRetrieveAPIView.retrieve()`
- `conduit/apps/profiles/serializers.py` → `ProfileSerializer`

**Endpoint:** `GET /api/profiles/{username}`  
**Permisos:** `AllowAny`

---

### US-15: Marcar artículo como favorito

> **Como** usuario autenticado, **quiero** marcar un artículo como favorito **para** guardarlo y aumentar su contador de favoritos.

**Context / Domain:**
Engagement (Cross-Context)

**Criterios de aceptación:**
- Agrega una relación de favorito entre el perfil del usuario y el articulo. 
- Incrementa el conteo de favoritos del usuario. 
- La operación es idempotente. 

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticlesFavoriteAPIView.post()`
- `conduit/apps/profiles/models.py` → `Profile.favorite()`

**Endpoint:** `POST /api/articles/{slug}/favorite`  
**Permisos:** `IsAuthenticated`

---

### US-16: Quitar artículo de favoritos

> **Como** usuario autenticado, **quiero** quitar un artículo de mis favoritos **para** dejar de destacarlo.

**Context / Domain:**
Engagement (Cross-Context)

**Criterios de aceptación:**
- Remueve la relación de favoritos, si existe. 
- Decrementa el conteo de favoritos del usuario. 
- La operación es idempotente. 

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticlesFavoriteAPIView.delete()`
- `conduit/apps/profiles/models.py` → `Profile.unfavorite()`

**Endpoint:** `DELETE /api/articles/{slug}/favorite`  
**Permisos:** `IsAuthenticated`

---

### US-17: Agregar comentario a un artículo

> **Como** usuario autenticado, **quiero** agregar un comentario a un artículo **para** participar en la discusión.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- El contenido del comentario es requerido. 
- El usuario autenticado se establece como el autor del comentario. 
- El comentario esta asociado con el articulo. 

**Archivos:**
- `conduit/apps/articles/views.py` → `CommentsListCreateAPIView.create()`
- `conduit/apps/articles/serializers.py` → `CommentSerializer.create()`

**Endpoint:** `POST /api/articles/{slug}/comments`  
**Permisos:** `IsAuthenticatedOrReadOnly`

---

### US-18: Ver comentarios de un artículo

> **Como** visitante, **quiero** ver los comentarios de un artículo **para** leer la discusión.

**Context / Domain:**
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Retorna todos los comentarios asociados con el articulo. 
- Los resultados retornados estan ordenados por fecha de creación. 
- Si no hay comentarios, retorna una lista vacía. 

**Archivos:**
- `conduit/apps/articles/views.py` → `CommentsListCreateAPIView.list()` y `filter_queryset()`

**Endpoint:** `GET /api/articles/{slug}/comments`  
**Permisos:** `AllowAny`

---

### US-19: Eliminar comentario

> **Como** usuario autenticado, **quiero** eliminar un comentario **para** retractarme de lo dicho.

**Nota:** El código actual no verifica que el usuario sea el autor del comentario — cualquier usuario autenticado podría eliminar cualquier comentario. Esto es un bug/feature gap.

**Context / Domain:** 
Article & Comment Management (Supporting)

**Criterios de aceptación:**
- Cuaquier usario que no se encuentre autenticado, no puede eliminar comentarios. 

**Archivos:**
- `conduit/apps/articles/views.py` → `CommentsDestroyAPIView.destroy()`

**Endpoint:** `DELETE /api/articles/{slug}/comments/{id}`  
**Permisos:** `IsAuthenticatedOrReadOnly`

---

### US-20: Feed personalizado

> **Como** usuario autenticado, **quiero** ver un feed con artículos de los usuarios que sigo **para** mantenerme al día con su contenido.

**Context / Domain:**
Engagement (Cross-Context)

**Criterios de aceptación:**
- Solo muestra artículos de autores que el usuario sigue (`author__in=profile.follows.all()`).
- Paginado con LimitOffset.

**Archivos:**
- `conduit/apps/articles/views.py` → `ArticlesFeedAPIView.get_queryset()` y `list()`
- `conduit/apps/profiles/models.py` → `Profile.follows` (M2M)

**Endpoint:** `GET /api/articles/feed`  
**Permisos:** `IsAuthenticated`

---

## Matriz de Trazabilidad: User Stories → Endpoints

| US | Método | Endpoint | Permisos | Módulo |
|---|---|---|---|---|
| US-01 | `POST` | `/api/users` | AllowAny | authentication |
| US-02 | `POST` | `/api/users/login` | AllowAny | authentication |
| US-03 | `GET` | `/api/user` | IsAuthenticated | authentication |
| US-04 | `PUT` | `/api/user` | IsAuthenticated | authentication |
| US-06 | `POST` | `/api/articles` | IsAuthenticated | articles |
| US-07 | `GET` | `/api/articles?author=&tag=&favorited=` | AllowAny | articles |
| US-08 | `GET` | `/api/articles/{slug}` | AllowAny | articles |
| US-09 | `PUT` | `/api/articles/{slug}` | IsAuthenticated | articles |
| US-10 | `GET` | `/api/tags` | AllowAny | articles |
| US-12 | `POST` | `/api/profiles/{username}/follow` | IsAuthenticated | profiles |
| US-13 | `DELETE` | `/api/profiles/{username}/follow` | IsAuthenticated | profiles |
| US-14 | `GET` | `/api/profiles/{username}` | AllowAny | profiles |
| US-15 | `POST` | `/api/articles/{slug}/favorite` | IsAuthenticated | articles |
| US-16 | `DELETE` | `/api/articles/{slug}/favorite` | IsAuthenticated | articles |
| US-17 | `POST` | `/api/articles/{slug}/comments` | IsAuthenticated | articles |
| US-18 | `GET` | `/api/articles/{slug}/comments` | AllowAny | articles |
| US-19 | `DELETE` | `/api/articles/{slug}/comments/{id}` | IsAuthenticated | articles |
| US-20 | `GET` | `/api/articles/feed` | IsAuthenticated | articles |
